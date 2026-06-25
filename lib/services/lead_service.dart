import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lead_model.dart';

class LeadService {
  // When _defaultUrl is updated, add the old value here so existing users
  // are automatically migrated to the new default on next launch.
  static const String _oldDefaultUrl =
      'https://script.google.com/macros/s/AKfycbyOG5h_Pdh00gLTdaqB3JC7ivAAwBBk7J3Wk_2C9p2Ge_HO9sfktvJjqoCxnYvO_SOV/exec';
  static const String _defaultUrl =
      'https://script.google.com/macros/s/AKfycbxo0DuztEe4hIAPiEjbttV-LPJDEvvaTSFyUs6M-LNRWhNucJTUJw6bJ-4AuK4OS6t6Yw/exec';
  static const String _urlPrefKey  = 'lead_script_url';
  static const String _nameKey     = 'lead_source_name';
  static String? _cachedUrl;
  static String? _cachedName;

  /// Column names in sheet order — populated from the last successful fetchLeads().
  static List<String> _schema = [];
  static List<String> get columnSchema => List.from(_schema);

  // ── URL persistence ───────────────────────────────────────────────────────
  static Future<String> getUrl() async {
    if (_cachedUrl == null) {
      final prefs  = await SharedPreferences.getInstance();
      final stored = prefs.getString(_urlPrefKey);
      // Migrate: if stored is the old default (or absent), switch to new default
      if (stored == null || stored == _oldDefaultUrl) {
        _cachedUrl = _defaultUrl;
        _schema    = [];
        await prefs.setString(_urlPrefKey, _defaultUrl);
      } else {
        _cachedUrl = stored;
      }
    }
    return _cachedUrl!;
  }

  static Future<void> saveUrl(String url) async {
    _cachedUrl = url.trim();
    _schema    = []; // reset so columns re-detect from the new sheet
    await (await SharedPreferences.getInstance())
        .setString(_urlPrefKey, url.trim());
  }

  // ── Source name persistence ───────────────────────────────────────────────
  static Future<String> getSourceName() async {
    _cachedName ??=
        (await SharedPreferences.getInstance()).getString(_nameKey) ??
            'Meta Leads';
    return _cachedName!;
  }

  static Future<void> saveSourceName(String name) async {
    _cachedName = name.trim().isEmpty ? 'Meta Leads' : name.trim();
    await (await SharedPreferences.getInstance())
        .setString(_nameKey, _cachedName!);
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
