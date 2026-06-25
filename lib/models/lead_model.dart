class Lead {
  /// All sheet columns in order, exactly as returned by the Apps Script.
  final Map<String, String> fields;

  const Lead({required this.fields});

  // ── Row identification ────────────────────────────────────────────────────
  /// First column name (e.g. "SNO") — used as the row key for update/delete.
  String get rowKeyColumn => fields.keys.firstOrNull ?? '';
  /// First column value (e.g. "1") — the actual identifier.
  String get rowKeyValue  => fields.values.firstOrNull ?? '';
  bool   get canDelete    => rowKeyValue.isNotEmpty;
  int    get leadId       => int.tryParse(rowKeyValue) ?? 0; // for legacy checks

  // ── Auto-detected display fields (keyword heuristics) ────────────────────
  String _find(List<String> keywords, {int fallbackIndex = -1}) {
    for (final key in fields.keys) {
      final k = key.toUpperCase();
      if (keywords.any((kw) => k.contains(kw))) return fields[key] ?? '';
    }
    if (fallbackIndex >= 0) return fields.values.elementAtOrNull(fallbackIndex) ?? '';
    return '';
  }

  String get name    => _find(['CANDIDATE NAME', 'CUSTOMER NAME', 'FULL NAME', 'NAME',
                                'CANDIDATE', 'CUSTOMER', 'CLIENT'], fallbackIndex: 1);
  String get phone   => _find(['PHONE', 'MOBILE', 'CONTACT NO', 'CONTACT']);
  String get status  => _find(['CALL STATUS', 'STATUS', 'STAGE', 'INTERVIEW STATUS']);
  String get project => _find(['APPLIED POSITION', 'POSITION', 'PROJECT', 'PROPERTY', 'APPLIED']);
  String get source  => _find(['SOURCE', 'REFERRAL', 'CHANNEL']);
}
