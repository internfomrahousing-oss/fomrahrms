import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/onboarding_form_config.dart';
import '../models/user_session.dart';
import '../utils/form_version_label.dart';
import '../widgets/back_button.dart';

const _blue = Color(0xFF2563EB);

// Built-in (non-editable) field names per onboarding section

const _obSectionIcons = <String, IconData>{
  'basic_info':        Icons.person_rounded,
  'personal_data':     Icons.assignment_ind_rounded,
  'family_details':    Icons.family_restroom_rounded,
  'education':         Icons.school_rounded,
  'experience':        Icons.work_history_rounded,
  'last_position':     Icons.business_center_rounded,
  'additional_info':   Icons.info_outline_rounded,
  'emergency_details': Icons.emergency_rounded,
  'attachments':       Icons.attach_file_rounded,
  'hr_policy':         Icons.policy_rounded,
  'declaration':       Icons.verified_rounded,
};

class EditOnboardingFormPage extends StatefulWidget {
  const EditOnboardingFormPage({super.key});

  @override
  State<EditOnboardingFormPage> createState() =>
      _EditOnboardingFormPageState();
}

class _EditOnboardingFormPageState extends State<EditOnboardingFormPage> {
  late List<Map<String, dynamic>> _sections;
  bool _loading = true;
  bool _saving = false;
  int _nextVersionNumber = 1;
  List<Map<String, dynamic>> _history = [];
  Map<int, String> _versionLabels = {};
  bool _historyLoading = false;

  bool get _isManagement => UserSession.role == UserRole.management;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final active = await SupabaseService.fetchActiveOnboardingFormVersion();
      final config = active != null
          ? Map<String, dynamic>.from(active['form_config'] as Map)
          : OnboardingFormConfig.defaults();
      _sections = OnboardingFormConfig.getSections(config);
      _nextVersionNumber =
          await SupabaseService.getNextOnboardingFormVersionNumber();
    } catch (_) {
      _sections = List<Map<String, dynamic>>.from(
          OnboardingFormConfig.getSections(OnboardingFormConfig.defaults()));
    }
    if (mounted) setState(() => _loading = false);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    final versions = await SupabaseService.fetchOnboardingFormVersions();
    if (mounted) {
      setState(() {
        _history = versions;
        _versionLabels = computeFormVersionLabels(versions);
        _historyLoading = false;
      });
    }
  }

  Future<void> _saveAction() async {
    if (_isManagement) {
      await _publishDirectly();
    } else {
      await _sendForApproval();
    }
  }

  Future<void> _publishDirectly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update & Publish Onboarding Form',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
        content: const Text(
            'This will immediately update the live Onboarding Form for new employees. '
            'The current version will be saved to history.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update & Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final vNum = _nextVersionNumber;
      await SupabaseService.saveOnboardingFormVersion({
        'form_config': {'sections': _sections},
        'status': 'approved',
        'version_number': vNum,
        'created_by': UserSession.name.isNotEmpty ? UserSession.name : 'Management',
        'approved_by': UserSession.name.isNotEmpty ? UserSession.name : 'Management',
        'approved_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        setState(() => _nextVersionNumber = vNum + 1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Onboarding form v$vNum published!'),
          backgroundColor: const Color(0xFF22C55E),
          duration: const Duration(seconds: 4),
        ));
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _sendForApproval() async {
    final pendingCount =
        _history.where((v) => (v['status'] as String?) == 'pending').length;
    if (pendingCount > 0) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pending Approval Exists',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange)),
          content: const Text(
              'There is already an onboarding form version waiting for approval.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send for Approval',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _blue)),
        content: const Text(
            'The updated onboarding form will be sent to Management for approval.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send for Approval'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await SupabaseService.saveOnboardingFormVersion({
        'form_config': {'sections': _sections},
        'status': 'pending',
        'version_number': _nextVersionNumber,
        'created_by':
            UserSession.name.isNotEmpty ? UserSession.name : 'HR',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Onboarding form sent to Management for approval'),
          backgroundColor: Color(0xFF22C55E),
        ));
        _nextVersionNumber++;
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  void _toggleSection(int idx, bool val) =>
      setState(() => _sections[idx]['enabled'] = val);

  void _toggleBuiltInField(int idx, String fieldId) {
    setState(() {
      final hidden = List<String>.from(
          (_sections[idx]['hidden_field_ids'] as List?)?.cast<String>() ?? []);
      if (hidden.contains(fieldId)) {
        hidden.remove(fieldId);
      } else {
        hidden.add(fieldId);
      }
      _sections[idx]['hidden_field_ids'] = hidden;
    });
  }

  void _onReorderSection(int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;
      final item = _sections.removeAt(oldIdx);
      _sections.insert(newIdx, item);
    });
  }

  void _editTitle(int idx) async {
    final ctrl = TextEditingController(
        text: (_sections[idx]['title'] as String?) ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Section',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: _blue)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Section Title',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
          onSubmitted: (_) {
            setState(() => _sections[idx]['title'] = ctrl.text.trim());
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() => _sections[idx]['title'] = ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSection() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Section',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: _blue)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Section Title *',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
              'Custom fields can be added after the section is created.',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final title = ctrl.text.trim();
              if (title.isEmpty) return;
              setState(() => _sections.add({
                'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                'title': title,
                'enabled': true,
              }));
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteSection(int idx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Section',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red)),
        content: Text(
            'Remove "${(_sections[idx]['title'] as String?) ?? 'this section'}"?',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) setState(() => _sections.removeAt(idx));
  }

  Future<void> _addOrEditCustomField(int sectionIdx,
      [Map<String, dynamic>? existing, int? fieldIdx]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _FieldEditorDialog(existing: existing),
    );
    if (result == null) return;
    setState(() {
      final raw = _sections[sectionIdx]['custom_fields'];
      final fields = raw is List
          ? List<Map<String, dynamic>>.from(
              raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)))
          : <Map<String, dynamic>>[];
      if (fieldIdx != null) {
        fields[fieldIdx] = result;
      } else {
        fields.add(result);
      }
      _sections[sectionIdx]['custom_fields'] = fields;
    });
  }

  void _deleteCustomField(int sectionIdx, int fieldIdx) {
    setState(() {
      final raw = _sections[sectionIdx]['custom_fields'];
      final fields = raw is List
          ? List<Map<String, dynamic>>.from(
              raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)))
          : <Map<String, dynamic>>[];
      fields.removeAt(fieldIdx);
      _sections[sectionIdx]['custom_fields'] = fields;
    });
  }

  Future<void> _editPolicyText(int sectionIdx) async {
    final current = (_sections[sectionIdx]['policy_text'] as String?) ?? '';
    final ctrl = TextEditingController(text: current.isEmpty
        ? OnboardingFormConfig.defaultPolicyText
        : current);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF15803D),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(children: [
              const Icon(Icons.policy_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Edit HR Policy Text',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'This text will be displayed to candidates on the onboarding form. They must read and agree to it before submitting.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: TextField(
                  controller: ctrl,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                    hintText: 'Enter policy text…',
                  ),
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save Policy'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
                  onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
    ctrl.dispose();
    if (saved != null) {
      setState(() => _sections[sectionIdx]['policy_text'] = saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    final pad = narrow ? 16.0 : 24.0;

    return Material(
      color: null,
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 24, pad, 16),
          child: Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_note_rounded,
                  color: _blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Onboarding Form',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _blue)),
                    Text(
                        _isManagement
                            ? 'Edit sections · Add custom fields · Update & Publish'
                            : 'Edit sections · Add custom fields · Send for Management approval',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ]),
            ),
            if (!_loading) ...[
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveAction,
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(
                        _isManagement
                            ? Icons.publish_rounded
                            : Icons.send_rounded,
                        size: 16),
                label: Text(
                    _saving
                        ? (_isManagement ? 'Publishing…' : 'Sending…')
                        : (_isManagement ? 'Update & Publish' : 'Send for Approval'),
                    style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isManagement
                      ? _blue
                      : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _blue))
                  : const Icon(Icons.refresh_rounded, color: _blue),
            ),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(pad),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info banner
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFDBEAFE)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.info_outline_rounded,
                                  color: _blue, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Toggle sections on/off, rename them, drag to reorder, '
                                  'or add custom fields. Tap a field chip × to hide it. '
                                  'Click "Update & Publish" when done.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280)),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 22),

                          // ── Sections ────────────────────────────
                          Row(children: [
                            const Expanded(child: _HeadingRow(
                                label: 'Onboarding Form Sections',
                                icon: Icons.view_list_rounded)),
                            TextButton.icon(
                              onPressed: _addSection,
                              icon: const Icon(Icons.add_rounded, size: 15),
                              label: const Text('Add Section',
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                  foregroundColor: _blue),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          const Text('Drag  ⠿  to reorder sections',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280))),
                          const SizedBox(height: 8),
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            onReorder: _onReorderSection,
                            children: _sections.asMap().entries.map((e) =>
                                _ObSectionTile(
                                  key: ValueKey(e.value['id'] ?? e.key),
                                  index: e.key,
                                  section: e.value,
                                  onToggle: (v) =>
                                      _toggleSection(e.key, v),
                                  onRename: () => _editTitle(e.key),
                                  onDelete: () => _deleteSection(e.key),
                                  onToggleBuiltInField: (fId) =>
                                      _toggleBuiltInField(e.key, fId),
                                  onAddField: () =>
                                      _addOrEditCustomField(e.key),
                                  onEditField: (field, fieldIdx) =>
                                      _addOrEditCustomField(
                                          e.key, field, fieldIdx),
                                  onDeleteField: (fieldIdx) =>
                                      _deleteCustomField(e.key, fieldIdx),
                                  onEditPolicyText: (e.value['id'] == 'hr_policy')
                                      ? () => _editPolicyText(e.key)
                                      : null,
                                )).toList(),
                          ),

                          const SizedBox(height: 30),

                          // ── History ─────────────────────────────
                          const _HeadingRow(
                              label: 'Version History',
                              icon: Icons.history_rounded),
                          const SizedBox(height: 12),
                          if (_historyLoading)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: _blue),
                              ),
                            )
                          else if (_history.isEmpty)
                            _EmptyHistory()
                          else
                            ..._history.map((v) => _VersionHistoryCard(
                                version: v,
                                label: _versionLabels[
                                    (v['version_number'] as num?)?.toInt()])),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ── Section tile ──────────────────────────────────────────────────────────────

class _ObSectionTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> section;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(String fieldId) onToggleBuiltInField;
  final VoidCallback onAddField;
  final void Function(Map<String, dynamic> field, int fieldIdx) onEditField;
  final void Function(int fieldIdx) onDeleteField;
  final VoidCallback? onEditPolicyText;

  const _ObSectionTile({
    super.key,
    required this.index,
    required this.section,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    required this.onToggleBuiltInField,
    required this.onAddField,
    required this.onEditField,
    required this.onDeleteField,
    this.onEditPolicyText,
  });

  @override
  Widget build(BuildContext context) {
    final id = (section['id'] as String?) ?? '';
    final title = (section['title'] as String?) ?? id;
    final enabled = (section['enabled'] as bool?) ?? true;
    final icon = _obSectionIcons[id] ?? Icons.segment_rounded;
    final customFields = OnboardingFormConfig.getCustomFields(section);
    final builtInFieldDefs = OnboardingFormConfig.builtInFieldDefs[id] ?? [];
    final hiddenFieldIds = OnboardingFormConfig.getHiddenFieldIds(section);
    final isCustomSection = !_obSectionIcons.containsKey(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled
              ? const Color(0xFFE5E7EB)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 14, 8),
          child: Row(children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Icon(Icons.drag_handle_rounded,
                    size: 20, color: Color(0xFFE5E7EB)),
              ),
            ),
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: enabled
                    ? _blue.withValues(alpha: 0.1)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  color: enabled ? _blue : const Color(0xFFE5E7EB),
                  size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? const Color(0xFF6B7280)
                        : const Color(0xFFE5E7EB),
                  )),
            ),
            IconButton(
              tooltip: 'Rename section',
              icon: Icon(Icons.edit_rounded,
                  size: 16,
                  color: enabled
                      ? const Color(0xFF6B7280)
                      : const Color(0xFFDDDDDD)),
              onPressed: enabled ? onRename : null,
            ),
            if (isCustomSection)
              IconButton(
                tooltip: 'Remove section',
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Colors.red),
                onPressed: onDelete,
              ),
            Switch(
              value: enabled,
              onChanged: onToggle,
              activeColor: _blue,
            ),
          ]),
        ),

        // Built-in fields — interactive: tap X to hide, tap restore to show again
        if (enabled && builtInFieldDefs.isNotEmpty) ...[
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Built-in Fields',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.3)),
                  const SizedBox(width: 6),
                  const Text('(tap × to hide a field)',
                      style: TextStyle(fontSize: 9, color: Color(0xFFE5E7EB))),
                ]),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: builtInFieldDefs.map((f) {
                    final fId    = f['id']!;
                    final fLabel = f['label']!;
                    final isHidden = hiddenFieldIds.contains(fId);
                    return GestureDetector(
                      onTap: () => onToggleBuiltInField(fId),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isHidden
                              ? const Color(0xFFFEF3C7)
                              : _blue.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isHidden
                                ? const Color(0xFFFEF3C7)
                                : _blue.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (isHidden)
                            const Icon(Icons.visibility_off_rounded,
                                size: 10, color: Color(0xFFF59E0B)),
                          if (!isHidden)
                            const Icon(Icons.check_rounded,
                                size: 10, color: _blue),
                          const SizedBox(width: 4),
                          Text(fLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isHidden
                                      ? const Color(0xFFF59E0B)
                                      : _blue,
                                  decoration: isHidden
                                      ? TextDecoration.lineThrough
                                      : null)),
                          const SizedBox(width: 4),
                          Icon(
                            isHidden
                                ? Icons.restore_rounded
                                : Icons.close_rounded,
                            size: 10,
                            color: isHidden
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF6B7280),
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        // Policy text editor (hr_policy section only)
        if (enabled && id == 'hr_policy' && onEditPolicyText != null) ...[
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              const Icon(Icons.description_rounded, size: 14, color: Color(0xFF15803D)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Policy document displayed to candidates — they must agree before submitting.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onEditPolicyText,
                icon: const Icon(Icons.edit_document, size: 14),
                label: const Text('Edit Policy Text', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF15803D),
                  side: const BorderSide(color: Color(0xFF15803D)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ]),
          ),
        ],

        // Custom fields sub-panel
        if (enabled) ...[
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Custom Fields',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280))),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onAddField,
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Add Field',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: _blue),
                  ),
                ]),
                if (customFields.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...customFields.asMap().entries.map((e) =>
                      _CustomFieldPreview(
                        field: e.value,
                        onEdit: () => onEditField(e.value, e.key),
                        onDelete: () => onDeleteField(e.key),
                      )),
                ],
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Custom field preview row (shared) ────────────────────────────────────────

class _CustomFieldPreview extends StatelessWidget {
  final Map<String, dynamic> field;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CustomFieldPreview(
      {required this.field, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type = (field['type'] as String?) ?? 'short_answer';
    final label = (field['label'] as String?) ?? '';
    final isRequired = (field['required'] as bool?) ?? false;

    IconData typeIcon;
    String typeLabel;
    Color typeColor;
    switch (type) {
      case 'mcq':
        typeIcon = Icons.radio_button_checked_rounded;
        typeLabel = 'MCQ';
        typeColor = const Color(0xFF2563EB);
      case 'photo_upload':
        typeIcon = Icons.photo_camera_rounded;
        typeLabel = 'Photo Upload';
        typeColor = const Color(0xFFF59E0B);
      case 'file_upload':
        typeIcon = Icons.upload_file_rounded;
        typeLabel = 'File Upload';
        typeColor = const Color(0xFF3B82F6);
      case 'number':
        typeIcon = Icons.pin_rounded;
        typeLabel = 'Numbers Only';
        typeColor = const Color(0xFF0277BD);
      case 'date':
        typeIcon = Icons.calendar_today_rounded;
        typeLabel = 'Date / Calendar';
        typeColor = const Color(0xFF2563EB);
      case 'checkbox':
        typeIcon = Icons.check_box_rounded;
        typeLabel = 'Checkbox';
        typeColor = const Color(0xFF22C55E);
      default:
        typeIcon = Icons.short_text_rounded;
        typeLabel = 'Short Answer';
        typeColor = const Color(0xFF22C55E);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(typeIcon, size: 12, color: typeColor),
            const SizedBox(width: 4),
            Text(typeLabel,
                style: TextStyle(
                    fontSize: 10,
                    color: typeColor,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ),
        if (isRequired) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Required',
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.red,
                    fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.edit_rounded,
              size: 14, color: Color(0xFF6B7280)),
          onPressed: onEdit,
          constraints:
              const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              size: 14, color: Colors.red),
          onPressed: onDelete,
          constraints:
              const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
        ),
      ]),
    );
  }
}

// ── Field editor dialog ───────────────────────────────────────────────────────

class _FieldEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _FieldEditorDialog({this.existing});

  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  String _type = 'short_answer';
  final _labelCtrl = TextEditingController();
  bool _required = false;
  List<String> _mcqOptions = [];
  final _optionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = (e['type'] as String?) ?? 'short_answer';
      _labelCtrl.text = (e['label'] as String?) ?? '';
      _required = (e['required'] as bool?) ?? false;
      final opts = e['options'];
      if (opts is List && opts.isNotEmpty) {
        _mcqOptions = List<String>.from(opts.cast<String>());
      }
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _optionCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_labelCtrl.text.trim().isEmpty) return false;
    if (_type == 'mcq' && _mcqOptions.isEmpty) return false;
    return true;
  }

  Map<String, dynamic> _buildResult() {
    final result = <String, dynamic>{
      'id': (widget.existing?['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'type': _type,
      'label': _labelCtrl.text.trim(),
      'required': _required,
    };
    if (_type == 'mcq') result['options'] = List<String>.from(_mcqOptions);
    return result;
  }

  void _addOption() {
    final val = _optionCtrl.text.trim();
    if (val.isNotEmpty) {
      setState(() {
        _mcqOptions.add(val);
        _optionCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add Custom Field' : 'Edit Field',
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: _blue),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Field Type',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _TypeChip(
                  icon: Icons.short_text_rounded,
                  label: 'Short Answer',
                  value: 'short_answer',
                  selected: _type,
                  onTap: () => setState(() => _type = 'short_answer'),
                ),
                _TypeChip(
                  icon: Icons.radio_button_checked_rounded,
                  label: 'MCQ',
                  value: 'mcq',
                  selected: _type,
                  onTap: () => setState(() => _type = 'mcq'),
                ),
                _TypeChip(
                  icon: Icons.photo_camera_rounded,
                  label: 'Photo Upload',
                  value: 'photo_upload',
                  selected: _type,
                  onTap: () => setState(() => _type = 'photo_upload'),
                ),
                _TypeChip(
                  icon: Icons.upload_file_rounded,
                  label: 'File Upload',
                  value: 'file_upload',
                  selected: _type,
                  onTap: () => setState(() => _type = 'file_upload'),
                ),
                _TypeChip(
                  icon: Icons.pin_rounded,
                  label: 'Numbers Only',
                  value: 'number',
                  selected: _type,
                  onTap: () => setState(() => _type = 'number'),
                ),
                _TypeChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date / Calendar',
                  value: 'date',
                  selected: _type,
                  onTap: () => setState(() => _type = 'date'),
                ),
                _TypeChip(
                  icon: Icons.check_box_rounded,
                  label: 'Checkbox',
                  value: 'checkbox',
                  selected: _type,
                  onTap: () => setState(() => _type = 'checkbox'),
                ),
              ]),
              const SizedBox(height: 18),
              TextField(
                controller: _labelCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Question / Field Label *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Switch(
                  value: _required,
                  onChanged: (v) => setState(() => _required = v),
                  activeColor: _blue,
                ),
                const SizedBox(width: 8),
                const Text('Required field',
                    style:
                        TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ]),
              if (_type == 'mcq') ...[
                const SizedBox(height: 16),
                const Text('Answer Options',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                const Text('Drag to reorder · tap × to remove',
                    style:
                        TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                const SizedBox(height: 8),
                if (_mcqOptions.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ReorderableListView(
                      shrinkWrap: true,
                      onReorder: (oldIdx, newIdx) {
                        setState(() {
                          if (newIdx > oldIdx) newIdx--;
                          final item = _mcqOptions.removeAt(oldIdx);
                          _mcqOptions.insert(newIdx, item);
                        });
                      },
                      children: _mcqOptions
                          .asMap()
                          .entries
                          .map((e) => ListTile(
                                key: ValueKey(
                                    'mcqopt_${e.key}_${e.value}'),
                                dense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                leading: const Icon(
                                    Icons.drag_handle_rounded,
                                    size: 16,
                                    color: Color(0xFFE5E7EB)),
                                title: Text(e.value,
                                    style:
                                        const TextStyle(fontSize: 13)),
                                trailing: IconButton(
                                  icon: const Icon(
                                      Icons.close_rounded,
                                      size: 15,
                                      color: Colors.red),
                                  onPressed: () => setState(
                                      () => _mcqOptions.removeAt(e.key)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _optionCtrl,
                      decoration: InputDecoration(
                        hintText: 'Add option…',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _addOption(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addOption,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Add'),
                  ),
                ]),
              ],
              if (_type == 'photo_upload') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.photo_camera_rounded,
                        size: 14, color: Color(0xFFF59E0B)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Employee uploads a photo (JPG / PNG). Auto-compressed to ≤200 KB.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ]),
                ),
              ],
              if (_type == 'file_upload') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF90CAF9)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.upload_file_rounded,
                        size: 14, color: Color(0xFF3B82F6)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Employee uploads a document (PDF, DOC, DOCX, XLS, XLSX). Uploaded as-is.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                      ),
                    ),
                  ]),
                ),
              ],
              if (_type == 'number') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF90CAF9)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.pin_rounded, size: 14, color: Color(0xFF3B82F6)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Only numeric input is accepted (digits and decimal point).',
                        style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                      ),
                    ),
                  ]),
                ),
              ],
              if (_type == 'date') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF3B82F6)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 14, color: Color(0xFF2563EB)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'A calendar date picker will be shown to the employee.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ]),
                ),
              ],
              if (_type == 'checkbox') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_box_rounded,
                        size: 14, color: Color(0xFF22C55E)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'A single tick-box that the employee can check or leave unchecked.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF22C55E)),
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed:
              _canSave ? () => Navigator.pop(context, _buildResult()) : null,
          child: const Text('Save Field'),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;
  const _TypeChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _blue : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? _blue : const Color(0xFFE5E7EB)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF6B7280)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF6B7280),
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// ── Version history card ──────────────────────────────────────────────────────

class _VersionHistoryCard extends StatelessWidget {
  final Map<String, dynamic> version;
  final String? label;
  const _VersionHistoryCard({required this.version, this.label});

  @override
  Widget build(BuildContext context) {
    final vNum = (version['version_number'] as int?) ?? 0;
    final vLabel = label ?? 'v$vNum';
    final status = (version['status'] as String?) ?? 'pending';
    final createdBy = (version['created_by'] as String?) ?? '';
    final approvedBy = (version['approved_by'] as String?) ?? '';
    final rejectionNote = (version['rejection_note'] as String?) ?? '';

    String dateStr = '';
    try {
      final createdAt = version['created_at'];
      if (createdAt != null) {
        final dt = DateTime.parse(createdAt.toString()).toLocal();
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    late Color statusBg;
    late Color statusFg;
    late IconData statusIcon;
    late String statusLabel;
    switch (status) {
      case 'approved':
        statusBg = const Color(0xFFDCFCE7);
        statusFg = const Color(0xFF22C55E);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Approved';
      case 'rejected':
        statusBg = const Color(0xFFFEE2E2);
        statusFg = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
      default:
        statusBg = const Color(0xFFFEF3C7);
        statusFg = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_empty_rounded;
        statusLabel = 'Pending Approval';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(vLabel,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _blue)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (createdBy.isNotEmpty)
                  Text('Created by $createdBy',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                if (dateStr.isNotEmpty)
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 12, color: statusFg),
              const SizedBox(width: 4),
              Text(statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      color: statusFg,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        if (approvedBy.isNotEmpty && status == 'approved') ...[
          const SizedBox(height: 6),
          Text('Approved by $approvedBy',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF22C55E))),
        ],
        if (rejectionNote.isNotEmpty && status == 'rejected') ...[
          const SizedBox(height: 6),
          Text('Reason: $rejectionNote',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFFEF4444))),
        ],
      ]),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _HeadingRow extends StatelessWidget {
  final String label;
  final IconData icon;
  const _HeadingRow({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: _blue, size: 15),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827))),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
    ]);
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.history_rounded, size: 38, color: Color(0xFFDBEAFE)),
          SizedBox(height: 10),
          Text('No versions yet',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          SizedBox(height: 4),
          Text('Submitted versions will appear here after approval.',
              style:
                  TextStyle(fontSize: 11, color: Color(0xFFE5E7EB))),
        ]),
      ),
    );
  }
}
