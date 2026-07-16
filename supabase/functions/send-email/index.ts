// Sends email via the company's Netcore Cloudmail SMTP server, from
// whichever mailbox SMTP_USER/SMTP_PASSWORD authenticate as. Called
// directly from the Flutter app (not DB-trigger-driven, unlike send-push)
// since the caller needs a pass/fail result to react to — see the "Send
// Offer Letter" dialog in lib/pages/interview_process_page.dart.
//
// Security-audit hardening (see
// supabase/migrations/20260716000300_edge_function_hardening.sql):
//   - identifies the caller from the JWT minted by
//     supabase/functions/login/index.ts when one is present, and rate-limits
//     them generously by email. The one legitimate anon caller — "Forgot
//     password?" on the login screen, sent before anyone is signed in
//     (login_page.dart's _showForgotPasswordDialog) — is still allowed
//     through, but rate-limited tightly by IP instead. Previously *any*
//     caller, signed in or not, could send arbitrary email as the company
//     mailbox with no limit at all.
//   - CORS restricted to known app origins instead of "*".
// Deliberately NOT restricting the `to` address — legitimate sends already
// go to arbitrary personal candidate/employee emails (offer letters,
// activation links before a company mailbox exists), so an allowlist would
// break real use rather than stop abuse; identity + rate limiting is the
// actual fix for the open-relay risk.
//
// Required secrets (set with `supabase secrets set` or the dashboard):
//   SMTP_USER — the sending mailbox, e.g. jose@fomrahousing.in
//   SMTP_PASSWORD — that mailbox's login password (Netcore Cloudmail doesn't
//     use separate app passwords the way Google/Zoho do).
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY — for verifying the caller's
//     session and recording rate-limit hits.
//
// Host is Netcore Cloudmail's shared SMTP relay (smtp3.netcore.co.in, taken
// directly from the account's Cloudmail control panel) rather than a
// per-domain mail.<yourdomain> host — the previous mail.fomrahousing.in
// guess was reachable and spoke SMTP, but 535-rejected every login.

import nodemailer from "npm:nodemailer@6";
import { createClient } from "npm:@supabase/supabase-js@2";

const transporter = nodemailer.createTransport({
  host: "smtp3.netcore.co.in",
  port: 465,
  secure: true,
  auth: {
    user: Deno.env.get("SMTP_USER"),
    pass: Deno.env.get("SMTP_PASSWORD"),
  },
});

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// Known origins the Flutter Web app is actually served from. Add a new one
// here if you deploy to another domain — CORS is a browser-side check only
// (a non-browser caller ignores it), so this is defense-in-depth alongside
// the auth check below, not the real security boundary.
const ALLOWED_ORIGINS = ["https://fomrahrms-zeta.vercel.app"];

function corsHeadersFor(req: Request) {
  const origin = req.headers.get("Origin") ?? "";
  const allowOrigin =
    ALLOWED_ORIGINS.includes(origin) || origin.startsWith("http://localhost")
      ? origin
      : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

// Signed-in callers: generous, since HR legitimately sends many offer/
// activation emails in a session. Anon (forgot-password only): tight.
const RATE_LIMIT_MAX_AUTHENTICATED = 20;
const RATE_LIMIT_MAX_ANON = 5;
const RATE_LIMIT_WINDOW_MINUTES = 10;

Deno.serve(async (req) => {
  const corsHeaders = corsHeadersFor(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    let callerId: string | null = null;
    let rateLimitMax = RATE_LIMIT_MAX_ANON;
    if (token) {
      const { data: userData } = await supabase.auth.getUser(token);
      if (userData?.user?.email) {
        callerId = userData.user.email;
        rateLimitMax = RATE_LIMIT_MAX_AUTHENTICATED;
      }
    }
    if (!callerId) {
      // Not signed in — only legitimate for the "Forgot password?" flow.
      // Identify by IP so this can still be capped; Supabase's edge
      // network sets x-forwarded-for on every request.
      const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
      callerId = `anon:${ip || "unknown"}`;
    }

    const since = new Date(Date.now() - RATE_LIMIT_WINDOW_MINUTES * 60_000).toISOString();
    const { count } = await supabase
      .from("email_rate_limits")
      .select("id", { count: "exact", head: true })
      .eq("caller_email", callerId)
      .gte("sent_at", since);
    if ((count ?? 0) >= rateLimitMax) {
      return new Response(
        JSON.stringify({ error: "Too many emails sent recently. Please try again shortly." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // html/attachments are optional additions for the recruitment email
    // pipeline (EmailService) — existing {to, subject, body} callers are
    // unaffected.
    const { to, subject, body, html, attachments } = await req.json();
    if (!to || !subject || !(body || html)) {
      return new Response(JSON.stringify({ error: "to, subject, and body (or html) are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const mailAttachments = Array.isArray(attachments)
      ? attachments.map((a: { filename: string; contentBase64: string; contentType?: string }) => ({
          filename: a.filename,
          content: a.contentBase64,
          encoding: "base64",
          contentType: a.contentType,
        }))
      : undefined;

    await transporter.sendMail({
      from: `"Fomra Housing & Infrastructure" <${Deno.env.get("SMTP_USER")}>`,
      to,
      subject,
      text: body,
      html: html || undefined,
      attachments: mailAttachments,
    });

    await supabase.from("email_rate_limits").insert({ caller_email: callerId });

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
