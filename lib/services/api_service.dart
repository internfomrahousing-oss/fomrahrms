import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Android emulator → 10.0.2.2  |  Real device on same Wi-Fi → 10.44.1.99
const String _kBaseUrl = 'http://10.44.1.99:3000';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static const _tokenKey = 'auth_token';
  static const _timeout  = Duration(seconds: 15);

  // ── Token storage ──────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ── HTTP helpers ───────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, body['error'] ?? 'Unknown error');
    }
    return body;
  }

  static List<dynamic> _parseList(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(res.statusCode, body['error'] ?? 'Unknown error');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http
        .post(
          Uri.parse('$_kBaseUrl/api/auth/login'),
          headers: await _headers(auth: false),
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String role = 'employee',
    String? department,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_kBaseUrl/api/auth/register'),
          headers: await _headers(),
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            'role': role,
            if (department != null) 'department': department,
          }),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  // ── Employees ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getEmployees() async {
    final res = await http
        .get(Uri.parse('$_kBaseUrl/api/employees'), headers: await _headers())
        .timeout(_timeout);
    return _parseList(res);
  }

  static Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    final res = await http
        .post(
          Uri.parse('$_kBaseUrl/api/employees'),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateEmployee(int id, Map<String, dynamic> data) async {
    final res = await http
        .put(
          Uri.parse('$_kBaseUrl/api/employees/$id'),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  static Future<void> deleteEmployee(int id) async {
    final res = await http
        .delete(Uri.parse('$_kBaseUrl/api/employees/$id'), headers: await _headers())
        .timeout(_timeout);
    _parse(res);
  }

  // ── Leaves ─────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getLeaves() async {
    final res = await http
        .get(Uri.parse('$_kBaseUrl/api/leaves'), headers: await _headers())
        .timeout(_timeout);
    return _parseList(res);
  }

  static Future<List<dynamic>> getMyLeaves() async {
    final res = await http
        .get(Uri.parse('$_kBaseUrl/api/leaves/my'), headers: await _headers())
        .timeout(_timeout);
    return _parseList(res);
  }

  static Future<Map<String, dynamic>> submitLeave(Map<String, dynamic> data) async {
    final res = await http
        .post(
          Uri.parse('$_kBaseUrl/api/leaves'),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateManagerLeaveStatus(
      int id, String status) async {
    final res = await http
        .patch(
          Uri.parse('$_kBaseUrl/api/leaves/$id/manager-status'),
          headers: await _headers(),
          body: jsonEncode({'status': status}),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateHrLeaveStatus(
      int id, String status) async {
    final res = await http
        .patch(
          Uri.parse('$_kBaseUrl/api/leaves/$id/hr-status'),
          headers: await _headers(),
          body: jsonEncode({'status': status}),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  // ── Tasks ──────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getTasks() async {
    final res = await http
        .get(Uri.parse('$_kBaseUrl/api/tasks'), headers: await _headers())
        .timeout(_timeout);
    return _parseList(res);
  }

  static Future<List<dynamic>> getMyTasks() async {
    final res = await http
        .get(Uri.parse('$_kBaseUrl/api/tasks/my'), headers: await _headers())
        .timeout(_timeout);
    return _parseList(res);
  }

  static Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    final res = await http
        .post(
          Uri.parse('$_kBaseUrl/api/tasks'),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateTaskStatus(int id, String status) async {
    final res = await http
        .patch(
          Uri.parse('$_kBaseUrl/api/tasks/$id/status'),
          headers: await _headers(),
          body: jsonEncode({'status': status}),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  // ── Attendance ─────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getAttendance() async {
    final res = await http
        .get(Uri.parse('$_kBaseUrl/api/attendance'), headers: await _headers())
        .timeout(_timeout);
    return _parseList(res);
  }

  static Future<List<dynamic>> getMyAttendance() async {
    final res = await http
        .get(Uri.parse('$_kBaseUrl/api/attendance/my'), headers: await _headers())
        .timeout(_timeout);
    return _parseList(res);
  }

  static Future<Map<String, dynamic>> checkIn(String time, String location) async {
    final res = await http
        .post(
          Uri.parse('$_kBaseUrl/api/attendance/check-in'),
          headers: await _headers(),
          body: jsonEncode({'check_in_time': time, 'location': location}),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> checkOut(String time, String location) async {
    final res = await http
        .patch(
          Uri.parse('$_kBaseUrl/api/attendance/check-out'),
          headers: await _headers(),
          body: jsonEncode({'check_out_time': time, 'location': location}),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  // ── Health ─────────────────────────────────────────────────────────────────

  static Future<bool> isReachable() async {
    try {
      final res = await http
          .get(Uri.parse('$_kBaseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
