import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/appraisal_store.dart';
import '../services/appraisal_pdf_service.dart';
import '../services/supabase_service.dart';
import '../services/user_store.dart';
import '../widgets/back_button.dart';
import '../theme/app_theme.dart';

class SalaryHikeEnginePage extends StatelessWidget {
  const SalaryHikeEnginePage({super.key});

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
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.monetization_on_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Salary Hike Engine',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text('Completed appraisals awaiting salary/designation action',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            const SalaryHikeEngineBody(),
          ],
        ),
      ),
    );
  }
}

/// Condensed view (Employee Information + sections 14-17) of every
/// appraisal moved here, scoped the same way as Performance Management.
/// Embedded here and inside the Task Management tab.
class SalaryHikeEngineBody extends StatefulWidget {
  const SalaryHikeEngineBody({super.key});

  @override
  State<SalaryHikeEngineBody> createState() => _SalaryHikeEngineBodyState();
}

class _SalaryHikeEngineBodyState extends State<SalaryHikeEngineBody> {
  List<AppraisalForm> _forms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      UserStore.load(),
      SupabaseService.fetchAppraisalForms(),
    ]);
    if (!mounted) return;
    final users = results[0] as List<AppUser>;
    final forms = results[1] as List<AppraisalForm>;
    final visibleEmails = visibleEmployeesForAppraisal(users).map((u) => u.email).toSet();
    setState(() {
      _forms = forms.where((f) => f.movedToSalaryHike && visibleEmails.contains(f.employeeEmail)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Spacer(),
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))),
            child: IconButton(
              tooltip: 'Refresh',
              icon: Icon(Icons.refresh_rounded, color: AppTheme.primaryBlue, size: 20),
              onPressed: _load,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_forms.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(children: [
                  Icon(Icons.monetization_on_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text('No appraisals here yet',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text('Complete an appraisal in Performance Management to see it here',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ]),
              ),
            ),
          )
        else
          ..._forms.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SalaryHikeCard(form: f),
              )),
      ],
    );
  }
}

class _SalaryHikeCard extends StatefulWidget {
  final AppraisalForm form;
  const _SalaryHikeCard({required this.form});

  @override
  State<_SalaryHikeCard> createState() => _SalaryHikeCardState();
}

class _SalaryHikeCardState extends State<_SalaryHikeCard> {
  bool _expanded = false;
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await AppraisalPdfService.downloadSummary(widget.form);
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

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _recTile(String label, bool value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(value ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
              size: 15, color: value ? Colors.green.shade600 : Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: value ? const Color(0xFF111827) : Colors.grey.shade500)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final f = widget.form;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                child: Text(f.employeeName.isNotEmpty ? f.employeeName[0].toUpperCase() : '?',
                    style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.employeeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${f.designation} · Total Score: ${f.totalScore.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade400),
            ]),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(),
              const SizedBox(height: 8),
              Text('Employee Information', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
              _info('Employee ID', f.employeeId),
              _info('Designation', f.designation),
              _info('Department', f.department),
              _info('Reporting Manager', f.reportingManager),
              _info('Review Period', '${f.reviewPeriodFrom} – ${f.reviewPeriodTo}'),
              const SizedBox(height: 12),
              Text('Final Score Summary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
              _info('KRA (60%)', '${f.scoreKra}'),
              _info('Functional (20%)', '${f.scoreFunctional}'),
              _info('Behavioural (15%)', '${f.scoreBehavioural}'),
              _info('Achievements (5%)', '${f.scoreAchievements}'),
              _info('Total', f.totalScore.toStringAsFixed(1)),
              const SizedBox(height: 12),
              Text('Final Recommendation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
              _recTile('Confirmed in Role', f.recommendation.confirmedInRole),
              _recTile('Salary Revision Recommended', f.recommendation.salaryRevision),
              _recTile('Promotion Recommended', f.recommendation.promotion),
              _recTile('Training / Development Plan Required', f.recommendation.trainingPlan),
              _recTile('Performance Improvement Required', f.recommendation.performanceImprovement),
              const SizedBox(height: 12),
              Text('Recommended Designation & Salary Increase', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
              _info('Designation', f.recommendedDesignation),
              _info('Salary Increase', f.recommendedSalaryIncrease),
              const SizedBox(height: 12),
              Text('MD & CEO Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
              for (var i = 0; i < f.mdCeoRemarks.length; i++)
                if (f.mdCeoRemarks[i].isNotEmpty)
                  Text('${i + 1}. ${f.mdCeoRemarks[i]}', style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _downloading ? null : _download,
                  icon: _downloading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
