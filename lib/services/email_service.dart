import 'dart:convert';
import 'dart:typed_data';
import 'supabase_service.dart';

/// One reusable attachment shape for both the email log and the edge function.
class EmailAttachment {
  final String filename;
  final Uint8List bytes;
  final String contentType;
  const EmailAttachment({
    required this.filename,
    required this.bytes,
    this.contentType = 'application/pdf',
  });

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'contentBase64': base64Encode(bytes),
        'contentType': contentType,
      };
}

/// Subject + HTML body for each transactional email template used by the
/// post-approval recruitment pipeline. `data` keys are template-specific —
/// see each builder below.
typedef _TemplateBuilder = (String subject, String html) Function(Map<String, dynamic> data);

/// The single reusable email entry point the recruitment pipeline uses:
/// `EmailService.sendEmail(templateName: ..., recipient: ..., data: {...})`.
///
/// Every send is logged to `email_logs` before/after the actual SMTP call
/// (via `SupabaseService.sendEmail`, which talks to the `send-email` Edge
/// Function). Swapping SMTP for Microsoft Graph API later only touches that
/// Edge Function — this file and every call site stay the same.
class EmailService {
  static const Map<String, _TemplateBuilder> _templates = {
    'pre_offer': _preOfferTemplate,
    'onboarding_invite': _onboardingInviteTemplate,
    'employee_activation': _employeeActivationTemplate,
  };

  static Future<String?> sendEmail({
    required String templateName,
    required String recipient,
    required Map<String, dynamic> data,
    List<EmailAttachment> attachments = const [],
    String? relatedCandidateId,
    String? relatedOnboardingId,
  }) async {
    final builder = _templates[templateName];
    if (builder == null) return 'Unknown email template: $templateName';
    final (subject, html) = builder(data);
    final attachmentJson = attachments.map((a) => a.toJson()).toList();

    final logId = await SupabaseService.insertEmailLog({
      'template_name': templateName,
      'recipient': recipient,
      'subject': subject,
      'html_body': html,
      'variables': data,
      'attachments': attachmentJson.map((a) => {'filename': a['filename'], 'contentType': a['contentType']}).toList(),
      'status': 'pending',
      'related_candidate_id': relatedCandidateId,
      'related_onboarding_id': relatedOnboardingId,
    });

    final error = await SupabaseService.sendEmail(
      to: recipient,
      subject: subject,
      body: _stripHtml(html),
      html: html,
      attachments: attachmentJson,
    );

    if (logId != null) {
      await SupabaseService.updateEmailLog(logId, error == null
          ? {'status': 'sent', 'sent_at': DateTime.now().toUtc().toIso8601String()}
          : {'status': 'failed', 'error_message': error});
    }
    return error;
  }

  /// Re-sends a previously logged email using its stored template/data/attachments.
  static Future<String?> resend(String emailLogId) async {
    final log = await SupabaseService.fetchEmailLog(emailLogId);
    if (log == null) return 'Email log not found';
    final templateName = (log['template_name'] as String?) ?? '';
    final recipient = (log['recipient'] as String?) ?? '';
    final data = log['variables'] is Map ? Map<String, dynamic>.from(log['variables'] as Map) : <String, dynamic>{};
    final builder = _templates[templateName];
    if (builder == null) return 'Unknown email template: $templateName';
    final (subject, html) = builder(data);

    final storedAttachments = (log['attachments'] as List?) ?? [];
    final error = await SupabaseService.sendEmail(
      to: recipient,
      subject: subject,
      body: _stripHtml(html),
      html: html,
      attachments: storedAttachments.isEmpty
          ? null
          : List<Map<String, dynamic>>.from(storedAttachments),
    );

    final retryCount = ((log['retry_count'] as num?)?.toInt() ?? 0) + 1;
    await SupabaseService.updateEmailLog(emailLogId, error == null
        ? {'status': 'sent', 'sent_at': DateTime.now().toUtc().toIso8601String(), 'retry_count': retryCount}
        : {'status': 'failed', 'error_message': error, 'retry_count': retryCount});
    return error;
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  // ── Templates ──────────────────────────────────────────────────────────

  static (String, String) _preOfferTemplate(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString();
    final designation = (data['designation'] ?? '').toString();
    final department = (data['department'] ?? '').toString();
    final acceptLink = (data['acceptLink'] ?? '').toString();
    final subject = 'Offer Letter – Fomra Housing & Infrastructure Pvt Ltd';
    final html = '''
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;color:#111827;">
        <h2 style="color:#1e3a8a;">Welcome to Fomra Housing & Infrastructure</h2>
        <p>Dear $name,</p>
        <p>Congratulations! We are pleased to offer you the position of
        <strong>$designation</strong>${department.isNotEmpty ? ' in the <strong>$department</strong> department' : ''}
        at Fomra Housing & Infrastructure Pvt Ltd.</p>
        <p>Please find your Pre-Offer Letter attached to this email as a PDF.</p>
        <p style="text-align:center;margin:28px 0;">
          <a href="$acceptLink" style="background:#2563eb;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;">
            Accept Offer
          </a>
        </p>
        <p>This offer is valid for 3 days from the date of this email.</p>
        <p>Warm regards,<br/>HR Team<br/>Fomra Housing & Infrastructure Pvt Ltd</p>
      </div>
    ''';
    return (subject, html);
  }

  static (String, String) _onboardingInviteTemplate(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString();
    final formLink = (data['formLink'] ?? '').toString();
    const subject = 'Complete Your Onboarding Form – Fomra Housing & Infrastructure';
    final html = '''
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;color:#111827;">
        <h2 style="color:#1e3a8a;">You're almost there, $name!</h2>
        <p>Thank you for accepting our offer. Please complete your onboarding / joining form
        using the secure link below before your date of joining.</p>
        <p style="text-align:center;margin:28px 0;">
          <a href="$formLink" style="background:#2563eb;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;">
            Complete Onboarding Form
          </a>
        </p>
        <p>If the button doesn't work, copy and paste this link into your browser:<br/>$formLink</p>
        <p>Warm regards,<br/>HR Team<br/>Fomra Housing & Infrastructure Pvt Ltd</p>
      </div>
    ''';
    return (subject, html);
  }

  static (String, String) _employeeActivationTemplate(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString();
    final employeeId = (data['employeeId'] ?? '').toString();
    final userId = (data['userId'] ?? '').toString();
    final setPasswordLink = (data['setPasswordLink'] ?? '').toString();
    final portalUrl = (data['portalUrl'] ?? '').toString();
    const subject = 'Welcome to Fomra Housing – Activate Your Employee Account';
    final html = '''
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;color:#111827;">
        <h2 style="color:#1e3a8a;">Welcome to Fomra Housing, $name!</h2>
        <p>Your employee account has been created. Here are your account details:</p>
        <table style="width:100%;border-collapse:collapse;margin:16px 0;">
          <tr><td style="padding:6px 0;color:#6b7280;">Employee ID</td><td style="padding:6px 0;font-weight:600;">$employeeId</td></tr>
          <tr><td style="padding:6px 0;color:#6b7280;">User ID</td><td style="padding:6px 0;font-weight:600;">$userId</td></tr>
        </table>
        <p>For your security, please set your own password using the link below.
        This link expires in 24 hours.</p>
        <p style="text-align:center;margin:28px 0;">
          <a href="$setPasswordLink" style="background:#2563eb;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;">
            Set Your Password
          </a>
        </p>
        <p>Once your password is set, sign in at: <a href="$portalUrl">$portalUrl</a></p>
        <p>Warm regards,<br/>HR Team<br/>Fomra Housing & Infrastructure Pvt Ltd</p>
      </div>
    ''';
    return (subject, html);
  }
}
