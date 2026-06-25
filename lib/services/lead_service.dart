import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lead_model.dart';

class LeadService {
  static const String _defaultUrl =
      'https://script.google.com/macros/s/AKfycbyOG5h_Pdh00gLTdaqB3JC7ivAAwBBk7J3Wk_2C9p2Ge_HO9sfktvJjqoCxnYvO_SOV/exec';
  static const String _urlPrefKey = 'lead_script_url';
  static String? _cachedUrl;

  /// Column names in sheet order — populated from the last successful fetchLeads().
  static List<String> _schema = [];
  static List<String> get columnSchema => List.from(_schema);

  // ── URL persistence ───────────────────────────────────────────────────────
  static Future<String> getUrl() async {
    _cachedUrl ??=
        (await SharedPreferences.getInstance()).getString(_urlPrefKey) ??
            _defaultUrl;
    return _cachedUrl!;
  }

  static Future<void> saveUrl(String url) async {
    _cachedUrl = url.trim();
    _schema    = []; // reset so columns re-detect from the new sheet
    await (await SharedPreferences.getInstance())
        .setString(_urlPrefKey, url.trim());
  }

  // ── Connection test ───────────────────────────────────────────────────────
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

  // ── Fetch all leads (fully automatic — no mapping config needed) ──────────
  static Future<List<Lead>> fetchLeads() async {
    final base     = await getUrl();
    final uri      = Uri.parse('$base?action=list');
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

    // Cache the schema (column names in order) from the first row
    if (rows.isNotEmpty && rows[0] is Map) {
      _schema = (rows[0] as Map).keys.map((k) => k.toString()).toList();
    }

    return rows.where((e) => e is Map).map((e) {
      final fields = <String, String>{
        for (final entry in (e as Map).entries)
          entry.key.toString(): entry.value?.toString() ?? '',
      };
      return Lead(fields: fields);
    }).toList();
  }

  // ── CRUD — all operations use the first column as the row identifier ───────
  static Future<void> addLead(Lead lead) async {
    final base = await getUrl();
    final uri  = Uri.parse(base).replace(queryParameters: {
      'action': 'add',
      ...lead.fields,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    _checkWriteResponse(response.body);
  }

  static Future<void> updateLead(Lead lead) async {
    final base = await getUrl();
    final uri  = Uri.parse(base).replace(queryParameters: {
      'action': 'update',
      ...lead.fields,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    _checkWriteResponse(response.body);
  }

  static Future<void> deleteLead(Lead lead) async {
    final base = await getUrl();
    final uri  = Uri.parse(base).replace(queryParameters: {
      'action':           'delete',
      lead.rowKeyColumn:  lead.rowKeyValue,
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
