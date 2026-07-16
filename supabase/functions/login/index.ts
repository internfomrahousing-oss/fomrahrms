// Server-side login. Replaces the old client-side flow where the Flutter
// app downloaded the entire app_users table (every employee, including
// plaintext passwords) and compared passwords locally in Dart.
//
// The client now sends { email, password } here. This function checks the
// password against the bcrypt hash in app_users.password_hash via the
// verify_app_user_password RPC (see
// supabase/migrations/20260716000000_auth_foundation.sql — that RPC is
// service_role-only, so it can't be called directly by anon/authenticated
// clients). On success it mints a real Supabase Auth session for a shadow
// auth.users row linked to that employee (created lazily on first login
// after this migration ships) and returns the access/refresh tokens plus
// the caller's own profile fields — never another user's data, never any
// password material. The client calls supabase.auth.setSession(...) with
// the returned refresh token, so every later Postgres request carries a
// real JWT (auth.uid()/email) that RLS policies can key off.
//
// This deliberately does not touch the existing account-activation /
// password-reset token flow (still emailed via EmailService + the
// send-email function) — this function only replaces the final
// "check the password" step.
//
// Required secrets (set with `supabase secrets set`):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from "npm:@supabase/supabase-js@2";

type SupabaseLike = {
  from: (table: string) => {
    select: (columns: string) => {
      ilike: (column: string, value: string) => {
        maybeSingle: () => Promise<{ data: Record<string, unknown> | null; error: unknown }>;
      };
    };
  };
};

let supabase: ReturnType<typeof createClient> | null = null;

function getSupabase() {
  if (supabase) return supabase;

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be configured");
  }

  supabase = createClient(url, key);
  return supabase;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Escape PostgREST/ilike wildcards so an email containing `%` or `_`
// can't be used to match more than one row.
function escapeIlike(value: string) {
  return value.replace(/[%_]/g, "\\$&");
}

// Direct insert (service_role bypasses RLS) rather than the
// log_audit_event() RPC, since that RPC stamps the actor from the caller's
// own JWT — there isn't one yet on a failed login, and this function's
// session is the service role's, not the employee's.
async function logAudit(action: string, actorEmail: string, actorRole = "") {
  try {
    await getSupabase().from("audit_log").insert({
      action,
      actor_email: actorEmail,
      actor_role: actorRole,
      target_type: "app_users",
      target_id: actorEmail,
    });
  } catch (err) {
    console.error("audit log insert failed", err);
  }
}

function buildProfile(row: Record<string, unknown>) {
  return {
    email: row.email,
    name: row.name,
    employee_id: row.employee_id,
    role: row.role,
    active: row.active,
    designation: row.designation,
    department: row.department,
    reporting_manager: row.reporting_manager,
    is_reporting_manager: row.is_reporting_manager,
    work_location: row.work_location,
    permission_minutes_quota: row.permission_minutes_quota,
  };
}

export async function findAppUserByLoginIdentifier(
  supabaseClient: SupabaseLike,
  identifier: string,
) {
  const normalized = identifier.trim();
  if (!normalized) {
    return { row: null as Record<string, unknown> | null, matchedField: null as string | null };
  }

  const selectColumns = [
    "email",
    "name",
    "employee_id",
    "role",
    "active",
    "designation",
    "department",
    "reporting_manager",
    "is_reporting_manager",
    "work_location",
    "permission_minutes_quota",
    "password",
    "password_hash",
    "auth_user_id",
    "company_email",
  ].join(", ");

  const columns = ["email", "company_email", "employee_id"] as const;
  for (const column of columns) {
    const { data, error } = await supabaseClient
      .from("app_users")
      .select(selectColumns)
      .ilike(column, escapeIlike(normalized))
      .maybeSingle();

    if (!error && data) {
      return { row: data as Record<string, unknown>, matchedField: column };
    }
  }

  return { row: null, matchedField: null };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, password } = await req.json();
    if (!email || !password) {
      return json({ error: "email and password are required" }, 400);
    }

    const { row, matchedField } = await findAppUserByLoginIdentifier(getSupabase(), email);
    const entry = row as Record<string, unknown> | null;

    // Same generic error whether the email doesn't exist or the password is
    // wrong — no user-enumeration hints, matching the old client-side
    // behavior (login_page.dart always showed "Invalid email or password.").
    if (!entry || matchedField == null) {
      await logAudit("login_failed", email);
      return json({ error: "Invalid email or password" }, 401);
    }
    if (!entry.active) {
      return json({ error: "not_activated" }, 403);
    }

    const legacyPassword = typeof entry.password === "string" ? entry.password : "";
    const passwordHash = typeof entry.password_hash === "string" ? entry.password_hash : "";
    const hasPasswordMaterial = (passwordHash || legacyPassword).trim().length > 0;
    if (!hasPasswordMaterial) {
      // Matches the old "first login, no password set yet" branch — the
      // client shows the Set Password card. Whatever the caller typed as a
      // password is irrelevant here, same as before.
      return json({ needsPasswordSetup: true, profile: buildProfile(entry) });
    }

    const loginEmail = String(entry.email ?? "").trim();
    let verified = false;

    if (passwordHash) {
      try {
        const { data, error } = await getSupabase().rpc(
          "verify_app_user_password",
          { p_email: loginEmail, p_password: password },
        );
        verified = !error && Boolean(data);
      } catch {
        verified = false;
      }
    } else if (legacyPassword === password) {
      verified = true;
    }

    if (!verified) {
      await logAudit("login_failed", loginEmail, String(entry.role ?? ""));
      return json({ error: "Invalid email or password" }, 401);
    }

    // Lazily provision a shadow auth.users row the first time this employee
    // logs in after the migration — its password is random/unusable, since
    // verify_app_user_password above is the real credential check. Reuse an
    // existing auth user if one already exists for that email.
    let authUserId = entry.auth_user_id as string | null;
    if (!authUserId) {
      try {
        const { data: existingUser, error: getUserError } = await getSupabase().auth.admin.getUserByEmail(loginEmail);
        if (!getUserError && existingUser?.user) {
          authUserId = existingUser.user.id;
        } else {
          const { data: created, error: createError } = await getSupabase().auth.admin.createUser({
            email: loginEmail,
            email_confirm: true,
            password: crypto.randomUUID() + crypto.randomUUID(),
          });
          if (createError || !created?.user) {
            console.error("createUser failed", createError);
            return json({ error: "Could not start session" }, 500);
          }
          authUserId = created.user.id;
        }
        await getSupabase().from("app_users").update({ auth_user_id: authUserId }).eq("email", loginEmail);
      } catch (createErr) {
        console.error("createUser failed", createErr);
        return json({ error: "Could not start session" }, 500);
      }
    }

    // Mint a session for that auth user without ever needing its real
    // password: generate a magic-link token server-side, then immediately
    // redeem it ourselves via verifyOtp to get back a session.
    const { data: link, error: linkError } = await getSupabase().auth.admin.generateLink({
      type: "magiclink",
      email: loginEmail,
    });
    const hashedToken = link?.properties?.hashed_token;
    if (linkError || !hashedToken) {
      console.error("generateLink failed", linkError);
      return json({ error: "Could not start session" }, 500);
    }

    const { data: session, error: sessionError } = await getSupabase().auth.verifyOtp({
      type: "magiclink",
      token_hash: hashedToken,
    });
    if (sessionError || !session?.session) {
      console.error("verifyOtp failed", sessionError);
      return json({ error: "Could not start session" }, 500);
    }

    await logAudit("login_success", loginEmail, String(entry.role ?? ""));

    return json({
      access_token: session.session.access_token,
      refresh_token: session.session.refresh_token,
      profile: buildProfile(entry),
    });
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500);
  }
});
