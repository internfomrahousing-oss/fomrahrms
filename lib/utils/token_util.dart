import 'package:uuid/uuid.dart';

/// Secure tokens for the recruitment pipeline's public links
/// (pre-offer accept, onboarding form, set-password activation).
class TokenUtil {
  static const _uuid = Uuid();

  static String generate() => _uuid.v4();

  /// ISO datetime string [hours] from now, used as an expiry timestamp.
  static String expiresInHours(int hours) =>
      DateTime.now().toUtc().add(Duration(hours: hours)).toIso8601String();

  static bool isExpired(String isoExpiry) {
    if (isoExpiry.isEmpty) return true;
    final t = DateTime.tryParse(isoExpiry);
    if (t == null) return true;
    return DateTime.now().toUtc().isAfter(t);
  }
}
