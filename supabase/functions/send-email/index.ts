// Sends email via the company's Netcore Cloudmail SMTP server, from
// whichever mailbox SMTP_USER/SMTP_PASSWORD authenticate as. Called
// directly from the Flutter app (not DB-trigger-driven, unlike send-push)
// since the caller needs a pass/fail result to react to — see the "Send
// Offer Letter" dialog in lib/pages/interview_process_page.dart.
//
// Required secrets (set with `supabase secrets set` or the dashboard):
//   SMTP_USER — the sending mailbox, e.g. jose@fomrahousing.in
//   SMTP_PASSWORD — that mailbox's login password (Netcore Cloudmail doesn't
//     use separate app passwords the way Google/Zoho do).
//
// Host/port confirmed against this domain's actual MX/DNS setup: Netcore
// Cloudmail exposes SMTP at mail.<yourdomain> (here, mail.fomrahousing.in),
// port 465 (SSL) — see https://netcoresupport.freshdesk.com/support/solutions/articles/26000034883

import nodemailer from "npm:nodemailer@6";

const transporter = nodemailer.createTransport({
  host: "mail.fomrahousing.in",
  port: 465,
  secure: true,
  auth: {
    user: Deno.env.get("SMTP_USER"),
    pass: Deno.env.get("SMTP_PASSWORD"),
  },
});

Deno.serve(async (req) => {
  try {
    // html/attachments are optional additions for the recruitment email
    // pipeline (EmailService) — existing {to, subject, body} callers are
    // unaffected.
    const { to, subject, body, html, attachments } = await req.json();
    if (!to || !subject || !(body || html)) {
      return new Response(JSON.stringify({ error: "to, subject, and body (or html) are required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
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

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
