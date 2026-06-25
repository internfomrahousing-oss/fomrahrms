import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lead_model.dart';

class LeadService {
  static const String _defaultUrl =
      'https://script.google.com/macros/s/AKfycbzhSy5zTSuKfqb0ZB-7cHXrrAlMXTCSJ8Rlrx5hmG9iCUxGvEjSdMmMRVbHOc2GUC9asw/exec';
  static const String _prefKey = 'lead_script_url';
  static String? _cachedUrl;

  static Future<String> getUrl() async {
    _cachedUrl ??=
        (await SharedPreferences.getInstance()).getString(_prefKey) ??
            _defaultUrl;
    return _cachedUrl!;
  }

  static Future<void> saveUrl(String url) async {
    _cachedUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, url.trim());
  }

  // Temporarily tests a URL without saving it. Throws on failure.
  static Future<int> testUrl(String url) async {
    final uri = Uri.parse('${url.trim()}?action=list');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Server returned HTTP ${response.statusCode}');
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        throw Exception(decoded['error'].toString());
      }
      final List rows = decoded is List
          ? decoded
          : (decoded is Map ? (decoded['leads'] as List? ?? []) : []);
      return rows.length;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Invalid JSON response from script');
    }
  }

  static Future<List<Lead>> fetchLeads() async {
    final base = await getUrl();
    final uri = Uri.parse('$base?action=list');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response from Google Sheets');
    }

    List<dynamic> rows;
    if (decoded is List) {
      rows = decoded;
    } else if (decoded is Map) {
      if (decoded['error'] != null) throw Exception(decoded['error'].toString());
      rows = (decoded['leads'] as List?) ?? [];
    } else {
      throw Exception('Unexpected response format');
    }

    return rows
        .where((e) => e is Map)
        .map((e) => Lead.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> updateLead(Lead lead) async {
    final base = await getUrl();
    final uri = Uri.parse(base).replace(queryParameters: {
      'action': 'update',
      'LEAD ID': lead.leadId.toString(),
      'NAME': lead.name,
      'PHONE': lead.phone,
      'PROJECT': lead.project,
      'SOURCE': lead.source,
      'STATUS': lead.status,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    _checkWriteResponse(response.body);
  }

  static Future<void> addLead(Lead lead) async {
    final base = await getUrl();
    final uri = Uri.parse(base).replace(queryParameters: {
      'action': 'add',
      'LEAD ID': lead.leadId.toString(),
      'NAME': lead.name,
      'PHONE': lead.phone,
      'PROJECT': lead.project,
      'SOURCE': lead.source,
      'STATUS': lead.status,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    _checkWriteResponse(response.body);
  }

  static Future<void> deleteLead(int leadId) async {
    final base = await getUrl();
    final uri = Uri.parse(base).replace(queryParameters: {
      'action': 'delete',
      'LEAD ID': leadId.toString(),
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    _checkWriteResponse(response.body);
  }

  static void _checkWriteResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        throw Exception(decoded['error'].toString());
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }
  }
}
