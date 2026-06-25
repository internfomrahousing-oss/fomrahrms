import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lead_model.dart';

// ── Model ─────────────────────────────────────────────────────────────────────
class LeadSource {
  final String id;
  String name;
  final String url;

  LeadSource({required this.id, required this.name, required this.url});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};

  factory LeadSource.fromJson(Map<String, dynamic> j) => LeadSource(
        id:   j['id']   as String,
        name: j['name'] as String,
        url:  j['url']  as String,
      );
}

// ── Service ───────────────────────────────────────────────────────────────────
class LeadService {
  // The single permanent GAS deployment — handles ALL sheets via spreadsheetId param
  static const String _gasBaseUrl =
      'https://script.google.com/macros/s/AKfycbxo0DuztEe4hIAPiEjbttV-LPJDEvvaTSFyUs6M-LNRWhNucJTUJw6bJ-4AuK4OS6t6Yw/exec';

  static const String _defaultUrl = _gasBaseUrl;

  // Legacy single-source pref keys — kept only for migration
  static const String _legacyUrlKey  = 'lead_script_url';
  static const String _legacyNameKey = 'lead_source_name';

  static const String _sourcesKey = 'lead_sources_v2';

  static List<LeadSource>? _cachedSources;

  // Per-URL schema cache so switching sheets re-detects columns correctly
  static final Map<String, List<String>> _schemaCache = {};

  static List<String> schemaFor(String url) =>
      List.from(_schemaCache[url] ?? []);

  // ── Sources persistence ───────────────────────────────────────────────────

  /// Force the next getSources() call to re-read from SharedPreferences.
  static void invalidateCache() => _cachedSources = null;

  static Future<List<LeadSource>> getSources() async {
    if (_cachedSources != null) return _cachedSources!;

    final prefs = await SharedPreferences.getInstance();
    final json  = prefs.getString(_sourcesKey);

    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        _cachedSources =
            list.map((e) => LeadSource.fromJson(e as Map<String, dynamic>)).toList();
        return _cachedSources!;
      } catch (_) {
        // Corrupt data — fall through to migration below
      }
    }

    // First run or corrupt — migrate from old single-source storage
    final oldUrl  = prefs.getString(_legacyUrlKey)  ?? _defaultUrl;
    final oldName = prefs.getString(_legacyNameKey) ?? 'Meta Leads';
    _cachedSources = [
      LeadSource(id: _id(), name: oldName, url: oldUrl),
    ];
    await _persist(prefs);
    return _cachedSources!;
  }

  static Future<LeadSource> addSource(String name, String url) async {
    final sources = await getSources();
    final source  = LeadSource(
        id: _id(),
        name: name.trim().isEmpty ? 'New Source' : name.trim(),
        url: resolveUrl(url)); // auto-convert Sheets URL → GAS URL
    sources.add(source);
    await _persist();
    return source;
  }

  static Future<void> renameSource(String id, String newName) async {
    final sources = await getSources();
    final s = sources.firstWhere((s) => s.id == id, orElse: () => throw Exception('Not found'));
    s.name = newName.trim().isEmpty ? s.name : newName.trim();
    await _persist();
  }

  static Future<void> deleteSource(String id) async {
    final sources = await getSources();
    sources.removeWhere((s) => s.id == id);
    _schemaCache.remove(id);
    await _persist();
  }

  static Future<void> _persist([SharedPreferences? p]) async {
    final prefs = p ?? await SharedPreferences.getInstance();
    await prefs.setString(
        _sourcesKey,
        jsonEncode(_cachedSources!.map((s) => s.toJson()).toList()));
  }

  static String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Converts a Google Sheets URL or bare sheet ID into the full GAS URL.
  /// Already-correct GAS exec URLs are passed through unchanged.
  static String resolveUrl(String input) {
    input = input.trim();
    if (input.contains('script.google.com')) return input; // already a GAS URL
    final m = RegExp(r'spreadsheets/d/([a-zA-Z0-9_-]+)').firstMatch(input);
    if (m != null) return '$_gasBaseUrl?spreadsheetId=${m.group(1)}';
    if (RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(input)) {
      return '$_gasBaseUrl?spreadsheetId=$input'; // bare sheet ID
    }
    return input; // unknown format — pass as-is
  }

  /// Merges extra params into a URL that may already have query parameters.
  static Uri _buildUri(String url, Map<String, String> extra) {
    final base = Uri.parse(url);
    return base.replace(queryParameters: {...base.queryParameters, ...extra});
  }

  // ── Connection test ───────────────────────────────────────────────────────

  static Future<({int count, List<String> columns})> testUrl(String url) async {
    final uri      = _buildUri(resolveUrl(url), {'action': 'list'});
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

  // ── Fetch leads from a specific URL ──────────────────────────────────────

  static Future<List<Lead>> fetchLeads(String url) async {
    final uri      = _buildUri(url, {'action': 'list'});
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

    // Cache schema per URL
    if (rows.isNotEmpty && rows[0] is Map) {
      _schemaCache[url] = (rows[0] as Map).keys.map((k) => k.toString()).toList();
    }

    return rows.where((e) => e is Map).map((e) {
      final fields = <String, String>{
        for (final entry in (e as Map).entries)
          entry.key.toString(): entry.value?.toString() ?? '',
      };
      return Lead(fields: fields);
    }).toList();
  }

  // ── CRUD — all operations scoped to the provided URL ─────────────────────

  static Future<void> addLead(String url, Lead lead) async {
    final uri = _buildUri(url, {...lead.fields, 'action': 'add'});
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    _checkWriteResponse(response.body, expectSuccess: true);
  }

  static Future<void> updateLead(String url, Lead lead) async {
    final uri = _buildUri(url, {...lead.fields, 'action': 'update'});
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    _checkWriteResponse(response.body, expectSuccess: true);
  }

  static Future<void> deleteLead(String url, Lead lead) async {
    final uri = _buildUri(url, {lead.rowKeyColumn: lead.rowKeyValue, 'action': 'delete'});
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    _checkWriteResponse(response.body, expectSuccess: true);
  }

  static void _checkWriteResponse(String body, {bool expectSuccess = false}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        if (decoded['error'] != null) {
          throw Exception(decoded['error'].toString());
        }
        // If the response looks like a list response (has 'leads' key but no success
        // indicator), the GAS script probably doesn't support this action
        if (expectSuccess &&
            decoded.containsKey('leads') &&
            !decoded.containsKey('success') &&
            !decoded.containsKey('result') &&
            !decoded.containsKey('message')) {
          throw Exception(
              'Google Sheet script returned data instead of confirming the write. '
              'Make sure the script supports add/update/delete actions.');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }
  }
}
