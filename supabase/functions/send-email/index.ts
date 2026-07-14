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
    const { to, subject, body } = await req.json();
    if (!to || !subject || !body) {
      return new Response(JSON.stringify({ error: "to, subject, and body are required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    await transporter.sendMail({
      from: `"Fomra Housing & Infrastructure" <${Deno.env.get("SMTP_USER")}>`,
      to,
      subject,
      text: body,
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
