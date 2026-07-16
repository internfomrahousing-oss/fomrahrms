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

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, password } = await req.json();
    if (!email || !password) {
      return json({ error: "email and password are required" }, 400);
    }

    const { data: row, error: rowError } = await supabase
      .from("app_users")
      .select(
        "email, name, employee_id, role, active, designation, department, " +
          "reporting_manager, is_reporting_manager, work_location, " +
          "permission_minutes_quota, auth_user_id, has_password",
      )
      .ilike("email", escapeIlike(email))
      .maybeSingle();

    // Same generic error whether the email doesn't exist or the password is
    // wrong — no user-enumeration hints, matching the old client-side
    // behavior (login_page.dart always showed "Invalid email or password.").
    if (rowError || !row) {
      return json({ error: "Invalid email or password" }, 401);
    }
    if (!row.active) {
      return json({ error: "not_activated" }, 403);
    }
    if (!row.has_password) {
      // Matches the old "first login, no password set yet" branch — the
      // client shows the Set Password card. Whatever the caller typed as a
      // password is irrelevant here, same as before.
      return json({ needsPasswordSetup: true, profile: buildProfile(row) });
    }

    const { data: verified, error: verifyError } = await supabase.rpc(
      "verify_app_user_password",
      { p_email: email, p_password: password },
    );
    if (verifyError || !verified) {
      return json({ error: "Invalid email or password" }, 401);
    }

    // Lazily provision a shadow auth.users row the first time this employee
    // logs in after the migration — its password is random/unusable, since
    // verify_app_user_password above is the real credential check.
    let authUserId = row.auth_user_id as string | null;
    if (!authUserId) {
      const { data: created, error: createError } = await supabase.auth.admin.createUser({
        email,
        email_confirm: true,
        password: crypto.randomUUID() + crypto.randomUUID(),
      });
      if (createError || !created?.user) {
        console.error("createUser failed", createError);
        return json({ error: "Could not start session" }, 500);
      }
      authUserId = created.user.id;
      await supabase.from("app_users").update({ auth_user_id: authUserId }).eq("email", email);
    }

    // Mint a session for that auth user without ever needing its real
    // password: generate a magic-link token server-side, then immediately
    // redeem it ourselves via verifyOtp to get back a session.
    const { data: link, error: linkError } = await supabase.auth.admin.generateLink({
      type: "magiclink",
      email,
    });
    const hashedToken = link?.properties?.hashed_token;
    if (linkError || !hashedToken) {
      console.error("generateLink failed", linkError);
      return json({ error: "Could not start session" }, 500);
    }

    const { data: session, error: sessionError } = await supabase.auth.verifyOtp({
      type: "magiclink",
      token_hash: hashedToken,
    });
    if (sessionError || !session?.session) {
      console.error("verifyOtp failed", sessionError);
      return json({ error: "Could not start session" }, 500);
    }

    return json({
      access_token: session.session.access_token,
      refresh_token: session.session.refresh_token,
      profile: buildProfile(row),
    });
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500);
  }
});
