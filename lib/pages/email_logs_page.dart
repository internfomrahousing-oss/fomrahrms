import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/email_service.dart';
import '../widgets/responsive_header_row.dart';
import '../theme/app_theme.dart';

/// HR-only view of every transactional email the recruitment pipeline has
/// sent (EmailService), with a Resend action for failures. Route: /email-logs.
class EmailLogsPage extends StatefulWidget {
  const EmailLogsPage({super.key});

  @override
  State<EmailLogsPage> createState() => _EmailLogsPageState();
}

class _EmailLogsPageState extends State<EmailLogsPage> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;
  final Set<String> _resending = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final logs = await SupabaseService.fetchEmailLogs();
      if (mounted) setState(() { _logs = logs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _resend(String id) async {
    setState(() => _resending.add(id));
    final error = await EmailService.resend(id);
    if (!mounted) return;
    setState(() => _resending.remove(id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error == null ? 'Email resent' : 'Resend failed: $error'),
      backgroundColor: error == null ? const Color(0xFF22C55E) : Colors.red,
    ));
    _fetch();
  }

  Color _statusColor(String s) => switch (s) {
        'sent' => const Color(0xFF22C55E),
        'failed' => const Color(0xFFEF4444),
        _ => const Color(0xFFF59E0B),
      };

  String _fmt(dynamic v) {
    if (v == null) return '—';
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad = narrow ? 16.0 : 24.0;

    return Material(
      color: null,
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 16),
          child: ResponsiveHeaderRow(
            icon: Icons.mark_email_read_outlined,
            color: AppTheme.primaryBlue,
            title: 'Email Logs',
            subtitle: '${_logs.length} email${_logs.length == 1 ? '' : 's'} sent',
            actions: [
              IconButton(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _logs.isEmpty
                      ? Center(
                          child: Text('No emails sent yet',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)))
                      : ListView.separated(
                          padding: EdgeInsets.all(pad),
                          itemCount: _logs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final log = _logs[i];
                            final id = log['id'].toString();
                            final status = (log['status'] as String?) ?? 'pending';
                            final retryCount = (log['retry_count'] as num?)?.toInt() ?? 0;
                            return Card(
                              elevation: 0,
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text((log['subject'] as String?) ?? '',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text('To: ${log['recipient'] ?? ''}  ·  ${log['template_name'] ?? ''}',
                                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                                      const SizedBox(height: 3),
                                      Text('Sent: ${_fmt(log['sent_at'] ?? log['created_at'])}'
                                          '${retryCount > 0 ? '  ·  retries: $retryCount' : ''}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                      if (status == 'failed' && (log['error_message'] as String?)?.isNotEmpty == true) ...[
                                        const SizedBox(height: 3),
                                        Text((log['error_message'] as String?) ?? '',
                                            style: const TextStyle(fontSize: 11, color: Colors.red)),
                                      ],
                                    ]),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(status,
                                        style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600)),
                                  ),
                                  if (status == 'failed') ...[
                                    const SizedBox(width: 8),
                                    _resending.contains(id)
                                        ? const SizedBox(width: 16, height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2))
                                        : IconButton(
                                            icon: const Icon(Icons.refresh_rounded, size: 18),
                                            tooltip: 'Resend',
                                            onPressed: () => _resend(id),
                                          ),
                                  ],
                                ]),
                              ),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
