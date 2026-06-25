import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lead_model.dart';

class LeadService {
  // ── Script URL ─────────────────────────────────────────────────────────────
  static const String _defaultUrl =
      'https://script.google.com/macros/s/AKfycbzhSy5zTSuKfqb0ZB-7cHXrrAlMXTCSJ8Rlrx5hmG9iCUxGvEjSdMmMRVbHOc2GUC9asw/exec';
  static const String _urlPrefKey = 'lead_script_url';
  static String? _cachedUrl;

  static Future<String> getUrl() async {
    _cachedUrl ??=
        (await SharedPreferences.getInstance()).getString(_urlPrefKey) ??
            _defaultUrl;
    return _cachedUrl!;
  }

  static Future<void> saveUrl(String url) async {
    _cachedUrl = url.trim();
    await (await SharedPreferences.getInstance())
        .setString(_urlPrefKey, url.trim());
  }

  // ── Column mapping ─────────────────────────────────────────────────────────
  // Maps each app field to the UPPERCASE column name in the sheet.
  // Stored in SharedPreferences so changes survive app updates.
  static const String _mappingPrefKey = 'lead_col_mapping';

  static const Map<String, String> defaultMapping = {
    'leadId':  'LEAD ID',
    'name':    'NAME',
    'phone':   'PHONE',
    'project': 'PROJECT',
    'source':  'SOURCE',
    'status':  'STATUS',
  };

  static Map<String, String>? _cachedMapping;

  static Future<Map<String, String>> getColumnMapping() async {
    if (_cachedMapping != null) return Map.from(_cachedMapping!);
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_mappingPrefKey);
    if (s == null) return Map.from(defaultMapping);
    try {
      _cachedMapping = Map<String, String>.from(jsonDecode(s));
      return Map.from(_cachedMapping!);
    } catch (_) {
      return Map.from(defaultMapping);
    }
  }

  static Future<void> saveColumnMapping(Map<String, String> mapping) async {
    // Normalize values to uppercase so they match what the script returns
    _cachedMapping = {
      for (final e in mapping.entries) e.key: e.value.trim().toUpperCase()
    };
    await (await SharedPreferences.getInstance())
        .setString(_mappingPrefKey, jsonEncode(_cachedMapping));
  }

  // ── Connection test ────────────────────────────────────────────────────────
  static Future<({int count, List<String> columns})> testUrl(String url) async {
    final uri = Uri.parse('${url.trim()}?action=list');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Server returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['error'] != null) {
      throw Exception(decoded['error'].toString());
    }
    final List rows = decoded is List
        ? decoded
        : (decoded is Map ? (decoded['leads'] as List? ?? []) : []);

    List<String> columns = [];
    if (rows.isNotEmpty && rows[0] is Map) {
      columns = (rows[0] as Map).keys.map((k) => k.toString()).toList();
    }
    return (count: rows.length, columns: columns);
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────
  static Future<List<Lead>> fetchLeads() async {
    final base = await getUrl();
    final mapping = await getColumnMapping();
    final uri = Uri.parse('$base?action=list');
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

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
        .map((e) => Lead.fromMappedJson(Map<String, dynamic>.from(e as Map), mapping))
        .toList();
  }

  static Future<void> updateLead(Lead lead) async {
    final base = await getUrl();
    final m = await getColumnMapping();
    final uri = Uri.parse(base).replace(queryParameters: {
      'action':     'update',
      m['leadId']!: lead.leadId.toString(),
      m['name']!:   lead.name,
      m['phone']!:  lead.phone,
      m['project']!: lead.project,
      m['source']!: lead.source,
      m['status']!: lead.status,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    _checkWriteResponse(response.body);
  }

  static Future<void> addLead(Lead lead) async {
    final base = await getUrl();
    final m = await getColumnMapping();
    final uri = Uri.parse(base).replace(queryParameters: {
      'action':      'add',
      m['leadId']!:  lead.leadId.toString(),
      m['name']!:    lead.name,
      m['phone']!:   lead.phone,
      m['project']!: lead.project,
      m['source']!:  lead.source,
      m['status']!:  lead.status,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    _checkWriteResponse(response.body);
  }

  static Future<void> deleteLead(int leadId) async {
    final base = await getUrl();
    final m = await getColumnMapping();
    final uri = Uri.parse(base).replace(queryParameters: {
      'action':     'delete',
      m['leadId']!: leadId.toString(),
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
