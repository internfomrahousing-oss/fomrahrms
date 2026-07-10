import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/appraisal_store.dart';
import '../models/user_session.dart';
import '../services/appraisal_pdf_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

class AppraisalFormEditorPage extends StatefulWidget {
  final AppUser employee;
  final AppraisalForm? existing;
  const AppraisalFormEditorPage({super.key, required this.employee, this.existing});

  @override
  State<AppraisalFormEditorPage> createState() => _AppraisalFormEditorPageState();
}

class _AppraisalFormEditorPageState extends State<AppraisalFormEditorPage> {
  static Color get _color => AppTheme.primaryBlue;
  late AppraisalForm _form;
  bool _saving = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _form = widget.existing ?? AppraisalForm.newFor(widget.employee, AppraisalStore.generateId());
  }

  Future<void> _save({bool complete = false}) async {
    setState(() => _saving = true);
    final prevStatus = _form.status;
    final prevMoved = _form.movedToSalaryHike;
    final prevKraNotified = _form.kraStartNotified;
    _form.lastEditedBy = UserSession.name;
    _form.updatedAt = DateTime.now();
    if (complete) {
      _form.status = 'completed';
      _form.movedToSalaryHike = true;
    }
    final shouldNotifyKraStart = !_form.kraStartNotified && _form.kra.isNotEmpty;
    if (shouldNotifyKraStart) _form.kraStartNotified = true;

    try {
      await SupabaseService.saveAppraisalForm(_form);
    } catch (e) {
      // Roll back the local flags so a failed save doesn't leave the UI
      // showing "completed"/notified state that was never persisted.
      _form.status = prevStatus;
      _form.movedToSalaryHike = prevMoved;
      _form.kraStartNotified = prevKraNotified;
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save — nothing was persisted: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (shouldNotifyKraStart) {
      if (UserSession.role == UserRole.reportingManager) {
        await NotificationService.appraisalStartedByManager(employeeName: _form.employeeName);
      } else if (_form.reportingManager.trim().isNotEmpty) {
        await NotificationService.appraisalStarted(
          employeeName: _form.employeeName,
          reportingManagerName: _form.reportingManager,
        );
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(complete ? 'Appraisal completed and moved to Salary Hike Engine' : 'Draft saved'),
        backgroundColor: _color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    if (complete && context.canPop()) context.pop();
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await AppraisalPdfService.download(_form);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate PDF: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _pickDate(TextEditingController ctrl, void Function(String) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final s = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    ctrl.text = s;
    onPicked(s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const NavBackButton(),
              const SizedBox(width: 8),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.fact_check_rounded, color: _color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_form.employeeName} — Self Appraisal Form',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text(
                      _form.status == 'completed'
                          ? 'Completed · moved to Salary Hike Engine'
                          : 'Draft',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ]),
              ),
              OutlinedButton.icon(
                onPressed: _downloading ? null : _download,
                icon: _downloading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _color,
                  side: BorderSide(color: _color.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            _SectionCard(
              title: '1. Employee Information',
              icon: Icons.badge_rounded,
              child: _EmployeeInfoSection(form: _form, onPickDate: _pickDate),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: '2. Self-Appraisal Rating Scale',
              icon: Icons.star_rounded,
              child: const _RatingScaleLegend(),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: '3. Key Responsibility Areas (KRA) — Core Job Responsibilities (60%)',
              icon: Icons.checklist_rounded,
              subtitle: 'Add each responsibility relevant to this employee.',
              child: _RatingRowsEditor(
                rows: _form.kra,
                onChanged: (rows) => setState(() => _form.kra = rows),
              ),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: '4. Functional & Operational Competencies (20%)',
              icon: Icons.settings_suggest_rounded,
              subtitle: 'Add each competency relevant to this employee.',
              child: _RatingRowsEditor(
                rows: _form.functional,
                onChanged: (rows) => setState(() => _form.functional = rows),
              ),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: '5. Behavioural Competencies (15%)',
              icon: Icons.psychology_rounded,
              child: _RatingRowsEditor(
                rows: _form.behavioural,
                onChanged: (rows) => setState(() => _form.behavioural = rows),
              ),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: '6. Key Achievements During the Review Period (5%)',
              icon: Icons.emoji_events_rounded,
              child: _LinesEditor(lines: _form.achievements, onChanged: (v) => _form.achievements = v),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '7. Challenges Faced During the Review Period',
              icon: Icons.report_problem_rounded,
              child: _LinesEditor(lines: _form.challenges, onChanged: (v) => _form.challenges = v),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '8. Training / Support Required',
              icon: Icons.school_rounded,
              child: _LinesEditor(lines: _form.trainingSupport, onChanged: (v) => _form.trainingSupport = v),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '9. Goals & Action Plan for Next Review Period',
              icon: Icons.flag_rounded,
              child: _LinesEditor(lines: _form.goals, onChanged: (v) => _form.goals = v),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '10. Where Do You See Yourself (3 Professional Aspects)',
              icon: Icons.trending_up_rounded,
              child: _LinesEditor(lines: _form.professionalAspects, onChanged: (v) => _form.professionalAspects = v),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '11. Expectations from the Organization',
              icon: Icons.volunteer_activism_rounded,
              child: _LinesEditor(lines: _form.expectationsFromOrg, onChanged: (v) => _form.expectationsFromOrg = v),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '12. Things You Love About the Organization',
              icon: Icons.favorite_rounded,
              child: _LinesEditor(lines: _form.thingsLoveAboutOrg, onChanged: (v) => _form.thingsLoveAboutOrg = v),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: '13. Employee Declaration',
              icon: Icons.fingerprint_rounded,
              child: Text(
                'Signed physically after printing — this section is not filled digitally.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: '14. Final Score Summary',
              icon: Icons.score_rounded,
              child: _ScoreSummarySection(form: _form, onChanged: () => setState(() {})),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: '15. Final Recommendation of Reporting Manager',
              icon: Icons.thumb_up_alt_rounded,
              child: _RecommendationSection(form: _form, onChanged: () => setState(() {})),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: '16. Recommended Designation & Salary Increase',
              icon: Icons.currency_rupee_rounded,
              child: _RecommendedChangeSection(form: _form),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: '17. MD & CEO Remarks',
              icon: Icons.verified_rounded,
              child: _LinesEditor(lines: _form.mdCeoRemarks, onChanged: (v) => _form.mdCeoRemarks = v),
            ),
            const SizedBox(height: 24),

            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _save(),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save Draft'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _color,
                    side: BorderSide(color: _color.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : () => _save(complete: true),
                  icon: _saving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Mark Complete & Move to Salary Hike Engine'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Section card shell ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue, letterSpacing: 0.2)),
              ),
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: AppTheme.primaryBlue, size: 20) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
      ),
      filled: true, fillColor: Colors.white,
      labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

// ── Section 1 ────────────────────────────────────────────────────────────────

class _EmployeeInfoSection extends StatefulWidget {
  final AppraisalForm form;
  final Future<void> Function(TextEditingController, void Function(String)) onPickDate;
  const _EmployeeInfoSection({required this.form, required this.onPickDate});

  @override
  State<_EmployeeInfoSection> createState() => _EmployeeInfoSectionState();
}

class _EmployeeInfoSectionState extends State<_EmployeeInfoSection> {
  late final TextEditingController _periodFrom;
  late final TextEditingController _periodTo;
  late final TextEditingController _submission;

  @override
  void initState() {
    super.initState();
    _periodFrom = TextEditingController(text: widget.form.reviewPeriodFrom);
    _periodTo = TextEditingController(text: widget.form.reviewPeriodTo);
    _submission = TextEditingController(text: widget.form.selfAppraisalSubmissionDate);
  }

  @override
  void dispose() {
    _periodFrom.dispose();
    _periodTo.dispose();
    _submission.dispose();
    super.dispose();
  }

  Widget _dateField(TextEditingController ctrl, String label, void Function(String) onPicked) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      onTap: () => widget.onPickDate(ctrl, onPicked),
      decoration: _dec(label, icon: Icons.calendar_today_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.form;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 640;
      final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          initialValue: f.employeeName,
          decoration: _dec('Employee Name', icon: Icons.person_rounded),
          onChanged: (v) => f.employeeName = v,
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: f.employeeId,
          decoration: _dec('Employee ID', icon: Icons.badge_rounded),
          onChanged: (v) => f.employeeId = v,
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: f.designation,
          decoration: _dec('Designation', icon: Icons.work_outline_rounded),
          onChanged: (v) => f.designation = v,
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: f.department,
          decoration: _dec('Department', icon: Icons.account_tree_rounded),
          onChanged: (v) => f.department = v,
        ),
      ]);
      final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          initialValue: f.dateOfJoining,
          decoration: _dec('Date of Joining', icon: Icons.event_rounded),
          onChanged: (v) => f.dateOfJoining = v,
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: f.reportingManager,
          decoration: _dec('Reporting Manager', icon: Icons.manage_accounts_rounded),
          onChanged: (v) => f.reportingManager = v,
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _dateField(_periodFrom, 'Review Period From', (v) => f.reviewPeriodFrom = v)),
          const SizedBox(width: 10),
          Expanded(child: _dateField(_periodTo, 'Review Period To', (v) => f.reviewPeriodTo = v)),
        ]),
        const SizedBox(height: 14),
        _dateField(_submission, 'Self-Appraisal Submission Date', (v) => f.selfAppraisalSubmissionDate = v),
      ]);
      if (!wide) {
        return Column(children: [left, const SizedBox(height: 14), right]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left),
        const SizedBox(width: 20),
        Expanded(child: right),
      ]);
    });
  }
}

// ── Section 2 ────────────────────────────────────────────────────────────────

class _RatingScaleLegend extends StatelessWidget {
  const _RatingScaleLegend();

  static const _rows = [
    (5, 'Outstanding — Consistently exceeds expectations'),
    (4, 'Very Good — Frequently exceeds expectations'),
    (3, 'Good — Meets expectations consistently'),
    (2, 'Needs Improvement — Partially meets expectations'),
    (1, 'Unsatisfactory — Does not meet expectations'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${r.$1}', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryBlue, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 12.5))),
            ]),
          )).toList(),
    );
  }
}

// ── Dynamic rating rows (sections 3/4/5) ─────────────────────────────────────

class _RatingRowsEditor extends StatefulWidget {
  final List<AppraisalRatingRow> rows;
  final ValueChanged<List<AppraisalRatingRow>> onChanged;
  const _RatingRowsEditor({required this.rows, required this.onChanged});

  @override
  State<_RatingRowsEditor> createState() => _RatingRowsEditorState();
}

class _RatingRowsEditorState extends State<_RatingRowsEditor> {
  late List<AppraisalRatingRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.rows;
  }

  void _emit() => widget.onChanged(_rows);

  void _addRow() {
    setState(() => _rows = [..._rows, AppraisalRatingRow()]);
    _emit();
  }

  void _removeRow(int i) {
    setState(() => _rows = [..._rows]..removeAt(i));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_rows.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('No items yet — add one below.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
        ),
      for (var i = 0; i < _rows.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: _rows[i].description,
                  decoration: _dec('Description'),
                  onChanged: (v) { _rows[i].description = v; _emit(); },
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Remove',
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                onPressed: () => _removeRow(i),
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Self Rating:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              for (var star = 1; star <= 5; star++)
                ChoiceChip(
                  label: Text('$star'),
                  selected: _rows[i].selfRating == star,
                  onSelected: (_) {
                    setState(() => _rows[i].selfRating = _rows[i].selfRating == star ? 0 : star);
                    _emit();
                  },
                  selectedColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(
                      fontSize: 12,
                      color: _rows[i].selfRating == star ? Colors.white : const Color(0xFF111827),
                      fontWeight: FontWeight.w600),
                ),
            ]),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextFormField(
                  initialValue: _rows[i].selfRemarks,
                  maxLines: 2,
                  decoration: _dec('Self Remarks'),
                  onChanged: (v) { _rows[i].selfRemarks = v; _emit(); },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: _rows[i].rmRemarks,
                  maxLines: 2,
                  decoration: _dec('Reporting Manager Remarks'),
                  onChanged: (v) { _rows[i].rmRemarks = v; _emit(); },
                ),
              ),
            ]),
          ]),
        ),
      OutlinedButton.icon(
        onPressed: _addRow,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Add Row'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryBlue,
          side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);
  }
}

// ── Numbered free-text lines (sections 6-12, 17) ─────────────────────────────

class _LinesEditor extends StatefulWidget {
  final List<String> lines;
  final ValueChanged<List<String>> onChanged;
  const _LinesEditor({required this.lines, required this.onChanged});

  @override
  State<_LinesEditor> createState() => _LinesEditorState();
}

class _LinesEditorState extends State<_LinesEditor> {
  late List<String> _lines;

  @override
  void initState() {
    super.initState();
    _lines = widget.lines;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              initialValue: _lines[i],
              maxLines: 2,
              decoration: _dec('${i + 1}.'),
              onChanged: (v) {
                _lines[i] = v;
                widget.onChanged(_lines);
              },
            ),
          ),
      ],
    );
  }
}

// ── Section 14 ───────────────────────────────────────────────────────────────

class _ScoreSummarySection extends StatelessWidget {
  final AppraisalForm form;
  final VoidCallback onChanged;
  const _ScoreSummarySection({required this.form, required this.onChanged});

  Widget _scoreField(String label, double value, void Function(double) set) {
    return Expanded(
      child: TextFormField(
        initialValue: value == 0 ? '' : value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _dec(label),
        onChanged: (v) => set(double.tryParse(v) ?? 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _scoreField('KRA (60%)', form.scoreKra, (v) { form.scoreKra = v; onChanged(); }),
        const SizedBox(width: 10),
        _scoreField('Functional (20%)', form.scoreFunctional, (v) { form.scoreFunctional = v; onChanged(); }),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _scoreField('Behavioural (15%)', form.scoreBehavioural, (v) { form.scoreBehavioural = v; onChanged(); }),
        const SizedBox(width: 10),
        _scoreField('Achievements (5%)', form.scoreAchievements, (v) { form.scoreAchievements = v; onChanged(); }),
      ]),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('Total Score: ${form.totalScore.toStringAsFixed(1)} / 100',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
      ),
    ]);
  }
}

// ── Section 15 ───────────────────────────────────────────────────────────────

class _RecommendationSection extends StatelessWidget {
  final AppraisalForm form;
  final VoidCallback onChanged;
  const _RecommendationSection({required this.form, required this.onChanged});

  Widget _tile(String label, bool value, void Function(bool) set) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) { set(v ?? false); onChanged(); },
      title: Text(label, style: const TextStyle(fontSize: 13)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: AppTheme.primaryBlue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = form.recommendation;
    return Column(children: [
      _tile('Confirmed in Role', r.confirmedInRole, (v) => r.confirmedInRole = v),
      _tile('Salary Revision Recommended', r.salaryRevision, (v) => r.salaryRevision = v),
      _tile('Promotion Recommended', r.promotion, (v) => r.promotion = v),
      _tile('Training / Development Plan Required', r.trainingPlan, (v) => r.trainingPlan = v),
      _tile('Performance Improvement Required', r.performanceImprovement, (v) => r.performanceImprovement = v),
    ]);
  }
}

// ── Section 16 ───────────────────────────────────────────────────────────────

class _RecommendedChangeSection extends StatelessWidget {
  final AppraisalForm form;
  const _RecommendedChangeSection({required this.form});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextFormField(
        initialValue: form.recommendedDesignation,
        decoration: _dec('Recommended Designation', icon: Icons.work_outline_rounded),
        onChanged: (v) => form.recommendedDesignation = v,
      ),
      const SizedBox(height: 14),
      TextFormField(
        initialValue: form.recommendedSalaryIncrease,
        decoration: _dec('Recommended Salary Increase', icon: Icons.currency_rupee_rounded),
        onChanged: (v) => form.recommendedSalaryIncrease = v,
      ),
    ]);
  }
}
