// Computes a "vX" / "vX.Y" display label for each version in a form's
// version history: adding, removing, or swapping a whole section bumps the
// major number (v1 -> v2); an edit within existing sections — a field added,
// edited, removed, hidden, or a section/policy title change — bumps the
// decimal (v1 -> v1.1 -> v1.2). This only affects the label shown in the UI;
// the underlying `version_number` integer keeps incrementing sequentially,
// since it's also used for ordering, shareable form links, and the
// next-version counter.

Set<String> _sectionIds(Map<String, dynamic> config) {
  final raw = config['sections'];
  if (raw is! List) return {};
  return raw
      .whereType<Map>()
      .map((s) => s['id']?.toString())
      .whereType<String>()
      .toSet();
}

/// [versionsDescending] is a form-version list as returned by the fetch*
/// helpers in SupabaseService (newest first, each row containing
/// `version_number` and `form_config`). Returns a map of
/// version_number -> display label, e.g. {1: 'v1', 2: 'v1.1', 3: 'v2'}.
Map<int, String> computeFormVersionLabels(
    List<Map<String, dynamic>> versionsDescending) {
  final ascending = versionsDescending.reversed.toList();
  final labels = <int, String>{};
  var major = 0;
  var minor = 0;
  Set<String>? prevSectionIds;

  for (final v in ascending) {
    final vNum = (v['version_number'] as num?)?.toInt();
    if (vNum == null) continue;
    final rawConfig = v['form_config'];
    final config =
        rawConfig is Map ? Map<String, dynamic>.from(rawConfig) : <String, dynamic>{};
    final sectionIds = _sectionIds(config);

    final sectionsChanged = prevSectionIds == null ||
        sectionIds.length != prevSectionIds.length ||
        !sectionIds.containsAll(prevSectionIds);

    if (sectionsChanged) {
      major += 1;
      minor = 0;
    } else {
      minor += 1;
    }

    labels[vNum] = minor == 0 ? 'v$major' : 'v$major.$minor';
    prevSectionIds = sectionIds;
  }
  return labels;
}
