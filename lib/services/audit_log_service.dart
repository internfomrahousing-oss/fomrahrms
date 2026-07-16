import 'supabase_service.dart';

/// Thin wrapper around the log_audit_event() RPC (see
/// supabase/migrations/20260716000400_audit_log.sql) — the actor is always
/// stamped server-side from the caller's own JWT, never taken from the
/// client, so this can't be used to log an event as someone else.
///
/// Best-effort and fire-and-forget: a failed audit write should never
/// block or break the action it's logging.
class AuditLogService {
  static Future<void> log(
    String action, {
    String targetType = '',
    String targetId = '',
    Map<String, dynamic>? details,
  }) async {
    try {
      await SupabaseService.logAuditEvent(
        action,
        targetType: targetType,
        targetId: targetId,
        details: details,
      );
    } catch (_) {}
  }
}
