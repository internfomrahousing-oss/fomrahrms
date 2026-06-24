import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lead_model.dart';

class LeadService {
  // Paste your deployed Apps Script URL here after following the setup steps.
  // Deploy → New deployment → Web app → Execute as: Me → Who has access: Anyone
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbz8SLT61HEbG30WaI9SOPp55kgzpQhVxn-smZTU7KSIIp_h2bNO6diGt1VijIkyPLBUWw/exec';

  static Future<List<Lead>> fetchLeads() async {
    final uri = Uri.parse('$_scriptUrl?action=list');
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
    final uri = Uri.parse(_scriptUrl).replace(queryParameters: {
      'action': 'update',
      'LEAD ID': lead.leadId.toString(),
      'NAME': lead.name,
      'PHONE': lead.phone,
      'PROJECT': lead.project,
      'SOURCE': lead.source,
      'STATUS': lead.status,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }

  static Future<void> addLead(Lead lead) async {
    final uri = Uri.parse(_scriptUrl).replace(queryParameters: {
      'action': 'add',
      'LEAD ID': lead.leadId.toString(),
      'NAME': lead.name,
      'PHONE': lead.phone,
      'PROJECT': lead.project,
      'SOURCE': lead.source,
      'STATUS': lead.status,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }
}
