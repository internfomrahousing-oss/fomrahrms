// Fired by the `notifications_push_trigger` Postgres trigger (see the SQL
// block in lib/services/supabase_service.dart) on every INSERT into
// `notifications`. Resolves who the row is addressed to, drops anyone who
// muted that category, and pushes to their registered devices via FCM.
//
// Required secrets (set with `supabase secrets set`):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY — from Project Settings > API
//   FCM_SERVICE_ACCOUNT — full JSON contents of the Firebase service-account
//     key (Project Settings > Service Accounts > Generate new private key)

import { createClient } from "npm:@supabase/supabase-js@2";
import admin from "npm:firebase-admin@12";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!),
    ),
  });
}

// Mirrors the prefix rule in lib/models/notification_category.dart —
// keep these two lists in sync if a new notification type prefix is added.
const CATEGORY_PREFIXES: [string, string[]][] = [
  ["leave", ["leave_", "attendance_"]],
  ["onroll", ["onroll_"]],
  ["task", ["task_"]],
  ["maintenance", ["maintenance_"]],
  ["candidate", ["candidate_"]],
  ["onboarding", ["onboarding_"]],
  ["form_edit", ["form_edit_"]],
  ["payslip", ["payslip_"]],
  ["el", ["el_"]],
  ["milestone", ["tenure_"]],
  ["lead", ["lead_"]],
  ["announcement", ["announcement_"]],
];

function categoryFor(type: string): string {
  for (const [id, prefixes] of CATEGORY_PREFIXES) {
    if (prefixes.some((p) => type.startsWith(p))) return id;
  }
  return "other";
}

Deno.serve(async (req) => {
  try {
    const { record } = await req.json();
    if (!record) return new Response("no record", { status: 400 });

    const {
      type = "",
      title = "",
      body = "",
      route = "",
      target_email = "",
      target_role = "",
      target_reporting_manager = "",
    } = record;

    // ── Resolve recipient emails ────────────────────────────────────────
    let emails: string[] = [];
    if (target_email) {
      emails = [target_email];
    } else if (target_role === "ALL") {
      const { data } = await supabase.from("app_users").select("email").eq("active", true);
      emails = (data ?? []).map((r: { email: string }) => r.email);
    } else if (target_role) {
      const { data } = await supabase.from("app_users").select("email")
        .eq("active", true).eq("role", target_role);
      emails = (data ?? []).map((r: { email: string }) => r.email);
    } else if (target_reporting_manager) {
      const { data } = await supabase.from("app_users").select("email")
        .eq("active", true).eq("reporting_manager", target_reporting_manager);
      emails = (data ?? []).map((r: { email: string }) => r.email);
    }
    if (emails.length === 0) return new Response("no recipients", { status: 200 });

    // ── Drop anyone who muted this category ─────────────────────────────
    const categoryId = categoryFor(type);
    const { data: prefs } = await supabase
      .from("notification_preferences")
      .select("email, muted_categories")
      .in("email", emails);
    const muted = new Set(
      (prefs ?? [])
        .filter((p: { muted_categories?: string[] }) => (p.muted_categories ?? []).includes(categoryId))
        .map((p: { email: string }) => p.email),
    );
    const targetEmails = emails.filter((e) => !muted.has(e));
    if (targetEmails.length === 0) return new Response("all muted", { status: 200 });

    // ── Look up device tokens ────────────────────────────────────────────
    const { data: tokenRows } = await supabase
      .from("device_tokens")
      .select("token")
      .in("email", targetEmails);
    const tokens = (tokenRows ?? []).map((r: { token: string }) => r.token);
    if (tokens.length === 0) return new Response("no tokens", { status: 200 });

    // ── Send + prune tokens FCM reports as dead ──────────────────────────
    const deadTokens: string[] = [];
    await Promise.all(
      tokens.map(async (token: string) => {
        try {
          await admin.messaging().send({
            token,
            notification: { title, body },
            data: { route, type },
          });
        } catch (err) {
          const code = (err as { code?: string }).code;
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            deadTokens.push(token);
          }
        }
      }),
    );

    if (deadTokens.length > 0) {
      await supabase.from("device_tokens").delete().in("token", deadTokens);
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error(err);
    return new Response(String(err), { status: 500 });
  }
});
