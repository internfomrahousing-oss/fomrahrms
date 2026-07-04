import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/attendance_store.dart';
import '../models/user_session.dart';
import '../services/gps_tracking_service.dart';
import '../services/supabase_service.dart';

// ── Small tappable button shown on dashboards ─────────────────────────────────
class AttendanceShortcutCard extends StatefulWidget {
  final String attendanceRoute;
  final Color accentColor;

  const AttendanceShortcutCard({
    super.key,
    required this.attendanceRoute,
    required this.accentColor,
  });

  @override
  State<AttendanceShortcutCard> createState() => _AttendanceShortcutCardState();
}

class _AttendanceShortcutCardState extends State<AttendanceShortcutCard> {
  bool _loading = true;
  AttendanceRecord? _record;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rec = await SupabaseService.fetchTodayAttendance(UserSession.employeeId);
    if (!mounted) return;
    setState(() {
      _record = rec;
      _loading = false;
    });
    if (rec != null && rec.checkInTime.isNotEmpty && rec.checkOutTime.isEmpty) {
      AttendanceStore.isCheckedIn = true;
      GpsTrackingService.start();
      _ticker ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _showHRPolicy() async {
    if (!mounted) return;

    String policyText = _kHRPolicyText;
    Map<String, dynamic>? pending;
    try {
      final results = await Future.wait([
        SupabaseService.fetchHRPolicy(),
        SupabaseService.fetchPendingHRPolicyVersion(),
      ]).timeout(const Duration(seconds: 6), onTimeout: () => [null, null]);
      policyText = (results[0] as String?) ?? _kHRPolicyText;
      pending    = results[1] as Map<String, dynamic>?;
    } catch (_) {}

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dlgCtx) => _HRPolicyDialog(
        approvedText: policyText,
        pendingVersion: pending,
        canEdit: UserSession.role == UserRole.hr,
        isManagement: UserSession.role == UserRole.management,
      ),
    );
  }

  static const String _kHRPolicyText = '''
FOMRA HOUSING & INFRASTRUCTURE PVT LTD
Human Resource Policy – 2026 (Version 1.0)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. WORKING HOURS & ATTENDANCE

1.1 Work Days & Timings
• The company follows a 6-day work week (Monday to Saturday).
• Employee working hours: 9:30 AM to 6:30 PM.
• Property Sourcing employees: 9:00 AM to 6:30 PM.
• Sales employees work Monday to Sunday depending on project requirements. They receive a weekly off on either Tuesday or Thursday, predefined by the Reporting Manager / Head of Operations / MD — this cannot be changed on a need basis.

Example:
  Sales Employees: If a client or office meeting falls on their weekly off (Tue/Thu), they cannot avail an alternative off — the weekly off lapses.
  Other Employees: If a client or office meeting falls on their weekly off (Sunday), they can avail comp off for an alternative day with prior approval from their Reporting Manager / Head of Operations / MD.

1.2 Attendance Requirements
• All office employees must record attendance using the biometric system from their date of joining.
• Field employees must mark attendance by sharing their current location in the designated WhatsApp group daily. Land Acquisition employees must keep their live location active at all times during working hours.
• Failure to record or mark attendance will be treated as Absent, resulting in Loss of Pay (LOP).
• Any employee leaving work premises during working hours must obtain prior approval from the Reporting Manager. Failure to do so will result in LOP. Repeated violations lead to formal warnings or termination.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2. LATE ARRIVAL & PERMISSIONS POLICY

2.1 Late Arrival Policy
• Employees are permitted a maximum of 3 late arrivals per month.
• A grace period of up to 10 minutes is allowed per late arrival.
• Beyond 3 late arrivals in a month, each subsequent instance is treated as Half-Day LOP or adjusted against available leave balance.

2.2 Permission Policy
• Maximum of 2 hours of permission per month (applicable for Confirmed employees and Probationers).
• Permission can be availed in a single instance or split (minimum 30 minutes per instance, up to 4 occasions).
  - 30+ minutes = counted as 1 hour
  - 1+ hours = counted as 1.5 hours
  - 1.5+ hours = counted as 2 hours
• Beyond monthly limit, further permissions are adjusted against Casual Leave balance.
• Permissions cannot be clubbed with late arrival / early departure.
• Permission requests must be submitted in the pre-determined format provided by HR, or via WhatsApp approval from the Reporting Manager — one day prior, or immediately after the permission day in case of urgency.

2.3 Lunch Hours
• 30-minute lunch break between 1:00 PM and 2:00 PM.
• 15-minute bio break, once in the morning and once in the evening.
• Exceeding the lunch or bio break limit repeatedly will lead to 4 formal warnings per month; if it exceeds Half-Day, it results in LOP or termination.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

3. HOLIDAYS

• Maximum of 9 paid holidays annually, covering national holidays and major festivals.
• The holiday list is published by the HR Department before the start of each year.
• Employees required to work on public holidays are eligible for compensatory off with prior written / WhatsApp approval from their Reporting Manager / Head of Operations / MD.

Sales Employees (weekly off on Tue/Thu):
  If a public holiday falls on the same day as their weekly off, no additional comp off is provided.

Other Employees (excluding Sales):
  If a public holiday falls on a weekday, employees who work on that day are eligible for compensatory off with Reporting Manager approval.

Holidays – 2026:
  1 Jan   – New Year's Day
  14 Jan  – Pongal
  15 Jan  – Thiruvalluvar Day
  26 Jan  – Republic Day
  14 Apr  – Tamil New Year's Day
  15 Aug  – Independence Day
  2 Oct   – Gandhi Jayanthi
  20 Oct  – Ayutha Pooja
  8 Nov   – Diwali
  25 Dec  – Christmas

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

4. LEAVE POLICY

4.1 General Leave Rules
• Leave can be availed in half-day units.
• Leave cannot be adjusted against future leave credits (CL, ML, EL).
• CL, ML, and EL cannot be combined / clubbed together.
• All leave requests must be approved by the Reporting Manager and forwarded to HR at least one day in advance.
• Reporting Managers can approve up to 2 days. Beyond 2 days requires MD & Head of Operations approval.
• Sales Team: Reporting Manager approves up to 1 day; beyond 1 day requires MD approval.

4.2 Form Submission
• All Permission, Leave, Comp Off, and On-Duty (OD) forms must be approved by the Reporting Manager and submitted to HR — one day before leave, or on the day of return.
• Failure to submit approved forms results in LOP.

4.3 Leave Types (On-Role Employees)

Casual Leave (CL):
• 12 days per year (1 per month).
• Can be availed up to 2 days at a time.
• Cannot be carried forward; unused CL lapses at year-end and upon resignation.
• Cannot be clubbed with any other leave type.

Medical Leave (ML):
• 12 days per year.
• Beyond 3 consecutive days requires a medical certificate, else treated as LOP.
• Cannot be carried forward; lapses upon resignation.

Employees on Probation:
• Eligible for 1 day of leave per month (emergencies only).
• No CL, ML, or EL until probation is completed.
• Leave cannot be accumulated or carried forward.
• Eligible for permissions as per the Permission Policy.

Earned Leave (EL):
• For employees who have completed probation and 1 year of continuous service from the date of confirmation.
• 12 days EL per year (accrued at 1 day per completed month).
• Maximum accumulation: 20 days.
• EL balance exceeding 20 days can be encashed by employees with 2+ years of continuous service. Minimum 10 EL days must remain after encashment. Unavailed and unencashed EL lapses.
• Encashment formula: (Last Drawn Basic Salary ÷ Total days of month) × No. of days.

4.4 Sandwich Leave Policy
If leave is taken immediately before AND after a weekly off (Sunday) or declared holiday, the weekly off / holiday is also counted as leave.

Rules:
1. Leave on both sides of Sunday/holiday → Sunday/holiday counted as leave.
2. Leave only before OR after Sunday/holiday → Sunday/holiday not counted.
3. Leave type (CL/ML/EL/LOP) depends on available balance.
4. Leave on Sat+Sun or Sun+Mon is allowed once a month; twice or more = both days LOP.

Examples:
  Sat leave + Mon leave → Sun also becomes leave = 3 days total (sandwich).
  Fri leave + Sat leave, resumed Mon → only 2 days counted (Sun not counted).
  Mon leave only → 1 day (Sun not counted).
  Sat leave only → 1 day (Sun not counted).
  Fri leave + Mon leave, with Sat holiday → 4 days total (Fri + Sat + Sun + Mon).

4.5 Compensatory Off (Comp Off)
• Must be availed within the subsequent month of working on an approved holiday; else it lapses.
• Prior approval from Reporting Manager is mandatory.
• Sales team (rotational weekly offs) are not eligible for comp off on Saturdays & Sundays.
• Cannot be clubbed with weekly off or other leave types.
• Worked < 6 hours → Not eligible for comp off.
• Worked > 6 hours → Eligible for comp off.
• No prior approval → Comp off request rejected.

4.6 Wedding Leave
• Confirmed employees with minimum 2 years of continuous service are entitled to 7 days paid leave for their first legal marriage.
• Employees with more than 2 years of continuous service also receive a wedding gift of ₹25,000 from the company.

4.7 Maternity Leave
• Female employees with 3+ years of continuous service: 60 days (2 months) paid Maternity Leave.
• Miscarriage / medical termination of pregnancy (3+ years service): 42 days (6 weeks) with valid medical documents.
• May be availed up to 2 months before or after delivery, as per medical advice.
• Written notification and medical certificate are mandatory.
• Cannot be clubbed with CL / ML / EL.

4.8 Paternity Leave
• Male employees with 3+ years of continuous service: up to 3 days paid Paternity Leave, to be availed within one month of childbirth.
• Cannot be accumulated, carried forward, or encashed.
• Cannot be clubbed with CL / ML / EL.

4.9 Leave During Notice Period
• Permitted: 1 day of leave during notice period (with prior Reporting Manager approval).
• CL / ML balance lapses upon resignation.
• Available EL can be encashed with Full & Final Settlement as per policy.
• Unapproved leave during notice period is treated as LOP.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

5. GRATUITY POLICY

• Minimum 5 years of continuous service required to qualify.
• Formula: (Basic Salary × 15 × Completed Years of Service) ÷ 30
• Payment processed within 30 days from the official relieving date.
• May be partially or fully forfeited in cases of termination due to disciplinary action, misconduct, or unauthorized exit.
• Five-year requirement waived in cases of death or permanent disability; amount paid to legal nominee or beneficiary.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

6. OPERATIONAL POLICY

6.1 Dress Code
General:
• Employees must be clean, neat, and well-groomed at all times.
• Clothing must be professional, modest, and appropriate.
• Casual, workout, or outdoor attire is not permitted.
• Revealing, tight, or inappropriate clothing is strictly prohibited.
• Clothing must be clean, pressed, and free from visible damage.
• Clothing with offensive, political, or inappropriate messages is not allowed.

Male Employees: Formal attire with formal shoes; neat and well-groomed appearance.
Female Employees: Formal Indian or Western wear; sarees / traditional attire must be formal, sober, and professional.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

7. SEPARATION POLICY

7.1 Resignation
• Voluntary separation; Reporting Manager must discuss reasons and explore retention.
• Resignation must be submitted in writing or email and forwarded to HR.
• CL / ML balance lapses upon resignation.

7.2 Notice Period
• Employees must serve the applicable notice period or pay salary in lieu of shortfall.
• The company may relieve an employee earlier based on business needs.

Notice Period Structure:
  Deputy General Manager & Above : 60 Days
  Jr. Executive to Senior Manager : 30 Days
  Probationers                    : 15 Days

7.3 Full & Final Settlement (F&F)
• Salary not released during notice period on the regular salary date.
• F&F processed within 3 days after exit.
• All company property must be returned and clearances completed.
• Deductions apply for loss or damage beyond normal wear and tear.
• Final settlement held until all dues are cleared.

7.4 Termination
• May occur due to non-performance, misconduct, unethical behaviour, or falsification of information.
• Termination authority rests with the Reporting Manager.
• Salary paid only for actual days worked up to the date of termination.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

8. WORKPLACE CONDUCT & SAFETY

8.1 Visitors on Office Premises
• All visitors must sign in and provide identification at reception.
• Visitors must be escorted at all times by an authorized employee.
• Visitors are not permitted in restricted zones without authorization.
• Employees allowing unauthorized entry face disciplinary action.
• Dangerous items (weapons, explosives, hazardous materials) are strictly prohibited.

8.2 Drug, Alcohol & Smoke-Free Workplace
• Possession or consumption of alcohol, tobacco, or illegal substances on company premises or during work hours is strictly prohibited.
• Violation will lead to disciplinary action, including possible termination.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

9. HARASSMENT & DISCRIMINATION POLICY

9.1 Harassment Policy
Prohibited behaviour includes: demeaning remarks, unwelcome sexual advances, sexist / racist / religious slurs, offensive jokes or gestures, actions that create a hostile work environment, verbal or physical innuendoes, comments about appearance or attire, circulating offensive content, unwanted physical proximity, and spreading malicious rumours.

9.2 Discrimination Policy
The company strictly prohibits discrimination based on: gender or sexual orientation, race, caste or community, religion or nationality, age or disability, or marital / family status.

Retaliation against any employee who files a complaint or participates in an investigation is strictly forbidden.

9.3 Reporting & Redressal
If you experience harassment:
1. Clearly communicate that the behaviour is unwelcome.
2. If it continues, report to the ICC or HR.
3. Maintain records of incidents where possible.
4. Submit a written complaint within 15 days.

HR will maintain a confidential register, meet the complainant within 5 working days, record allegations, collect evidence, and provide the accused an opportunity to respond. Enquiry follows standard disciplinary procedures. Findings are reviewed by HOD & HR.

9.4 Confidentiality
Confidential information (personnel data, financial reports, client information) must be handled securely and shared only with authorized personnel. Breach of confidentiality may result in disciplinary or legal action.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

10. VIOLATION POLICY

The following (not exhaustive) may lead to disciplinary action, including termination:
• Falsifying documents, records, or timesheets
• Using threatening, abusive, or coercive language
• Violating safety protocols
• Mistreating colleagues, clients, or vendors
• Unauthorized overtime or off-duty work
• Consumption of alcohol, drugs, or tobacco during work hours
• Insubordination or refusal to follow instructions
• Theft, fraud, or misuse of company property
• Repeated absenteeism, tardiness, or negligence

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This policy is subject to revision at the sole discretion of the management of Fomra Housing & Infrastructure Pvt Ltd. From the date of revision, the new policy becomes applicable.

For any queries, please reach out to the HR Department.

Prepared by: Jose Jenin Jeevi J, HR Manager
Verified by:  Ronak Surana, Head of Operations
Approved by: Sharad Fomra, CEO & MD
''';

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttendanceSheet(
        record: _record,
        accentColor: widget.accentColor,
        attendanceRoute: widget.attendanceRoute,
        onDone: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final rec     = _record;
    final accent  = widget.accentColor;

    // Determine status visuals
    final IconData  statusIcon;
    final Color     statusColor;
    final String    statusText;

    if (_loading) {
      statusIcon  = Icons.access_time_rounded;
      statusColor = accent;
      statusText  = 'Attendance';
    } else if (rec != null && rec.checkOutTime.isNotEmpty) {
      statusIcon  = Icons.check_circle_rounded;
      statusColor = isDark ? Colors.blue.shade300 : const Color(0xFF1565C0);
      final dur   = _durationStr(rec);
      statusText  = 'Done · ${rec.checkInTime} – ${rec.checkOutTime}${dur != null ? ' ($dur)' : ''}';
    } else if (rec != null && rec.checkInTime.isNotEmpty) {
      statusIcon  = Icons.check_circle_rounded;
      statusColor = isDark ? Colors.green.shade300 : const Color(0xFF2E7D32);
      statusText  = 'Checked in at ${rec.checkInTime}';
    } else {
      statusIcon  = Icons.fingerprint_rounded;
      statusColor = accent;
      statusText  = 'Check In / Out';
    }

    return Row(children: [
        // ── Attendance check-in/out button ───────────────────────────────
        Flexible(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _loading ? null : _openSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_loading)
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  )
                else
                  Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(statusText,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _loading
                              ? cs.onSurface.withValues(alpha: 0.5)
                              : cs.onSurface)),
                ),
                if (!_loading && rec != null && rec.checkInTime.isNotEmpty && rec.checkOutTime.isEmpty) ...[
                  const SizedBox(width: 7),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
        ),

        const SizedBox(width: 8),

        // ── HR Policy button ──────────────────────────────────────────────
        Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showHRPolicy,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.policy_rounded, size: 18,
                    color: isDark ? Colors.blue.shade300 : const Color(0xFF0D47A1)),
                const SizedBox(width: 7),
                Text('HR Policy',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.blue.shade300 : const Color(0xFF0D47A1))),
              ]),
            ),
          ),
        ),
      ]);
  }

  static String? _durationStr(AttendanceRecord rec) {
    try {
      final inP  = rec.checkInTime.split(':');
      final outP = rec.checkOutTime.split(':');
      if (inP.length == 2 && outP.length == 2) {
        final diff = (int.parse(outP[0]) * 60 + int.parse(outP[1])) -
                     (int.parse(inP[0])  * 60 + int.parse(inP[1]));
        if (diff > 0) {
          final h = diff ~/ 60, m = diff % 60;
          return h > 0 ? '${h}h ${m}m' : '${m}m';
        }
      }
    } catch (_) {}
    return null;
  }
}

// ── HR Policy dialog ─────────────────────────────────────────────────────────
class _HRPolicyDialog extends StatefulWidget {
  final String approvedText;
  final Map<String, dynamic>? pendingVersion;
  final bool canEdit;        // true for HR
  final bool isManagement;   // true for Management
  const _HRPolicyDialog({
    required this.approvedText,
    required this.pendingVersion,
    required this.canEdit,
    required this.isManagement,
  });

  @override
  State<_HRPolicyDialog> createState() => _HRPolicyDialogState();
}

class _HRPolicyDialogState extends State<_HRPolicyDialog> {
  bool _editing   = false;
  bool _saving    = false;
  // When Management is previewing the pending version
  bool _previewPending = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.approvedText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submitForApproval() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.submitHRPolicyForApproval(
          _ctrl.text, UserSession.name);
      if (!mounted) return;
      setState(() { _editing = false; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Policy submitted to Management for approval.'),
          backgroundColor: Color(0xFF1565C0),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    }
  }

  String get _displayText =>
      _previewPending && widget.pendingVersion != null
          ? (widget.pendingVersion!['content'] as String? ?? '')
          : (_editing ? _ctrl.text : widget.approvedText);

  @override
  Widget build(BuildContext context) {
    final hasPending    = widget.pendingVersion != null;
    final pendingBy     = hasPending
        ? (widget.pendingVersion!['created_by'] as String? ?? 'HR')
        : '';
    final pendingVer    = hasPending
        ? 'v${widget.pendingVersion!['version_number'] ?? ''}'
        : '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              const Icon(Icons.policy_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _previewPending
                      ? 'HR Policy – Pending ($pendingVer)'
                      : 'HR Policy',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              if (widget.canEdit && !_editing && !hasPending)
                IconButton(
                  tooltip: 'Edit & submit for approval',
                  icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
                  onPressed: () => setState(() => _editing = true),
                ),
              if (_editing)
                IconButton(
                  tooltip: 'Cancel edit',
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: () {
                    _ctrl.text = widget.approvedText;
                    setState(() => _editing = false);
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
            ]),
          ),

          // ── Pending approval banner ─────────────────────────────────────
          if (hasPending && !_editing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFFF8E1),
              child: Row(children: [
                const Icon(Icons.pending_actions_rounded,
                    size: 16, color: Color(0xFFF57F17)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isManagement
                        ? '$pendingVer submitted by $pendingBy — awaiting your approval'
                        : '$pendingVer submitted by you — awaiting Management approval',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF7B4F00)),
                  ),
                ),
                if (widget.isManagement)
                  TextButton(
                    onPressed: () =>
                        setState(() => _previewPending = !_previewPending),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0)),
                    child: Text(
                      _previewPending ? 'View current' : 'Preview changes',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF1565C0)),
                    ),
                  ),
              ]),
            ),

          // ── Body ───────────────────────────────────────────────────────
          Expanded(
            child: _editing
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 13, height: 1.6,
                          color: Color(0xFF37474F)),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(
                      _displayText,
                      style: const TextStyle(fontSize: 13, height: 1.6,
                          color: Color(0xFF37474F)),
                    ),
                  ),
          ),

          // ── Footer ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _editing
                ? Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () {
                          _ctrl.text = widget.approvedText;
                          setState(() => _editing = false);
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _submitForApproval,
                        child: _saving
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Submit for Approval'),
                      ),
                    ),
                  ])
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ── Bottom-sheet popup ────────────────────────────────────────────────────────
class _AttendanceSheet extends StatefulWidget {
  final AttendanceRecord? record;
  final Color accentColor;
  final String attendanceRoute;
  final VoidCallback onDone;

  const _AttendanceSheet({
    required this.record,
    required this.accentColor,
    required this.attendanceRoute,
    required this.onDone,
  });

  @override
  State<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<_AttendanceSheet> {
  static const _green = Color(0xFF2E7D32);
  static const _teal  = Color(0xFF00695C);

  late final TextEditingController _timeCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _timeCtrl = TextEditingController(text: _nowTime());
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    super.dispose();
  }

  String _nowTime() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _checkIn() async {
    setState(() => _submitting = true);
    final now = DateTime.now();
    final empName = UserSession.name.isNotEmpty ? UserSession.name : 'Employee';

    AttendanceStore.isCheckedIn = true;
    GpsTrackingService.start();

    final lat = GpsTrackingService.latestLat;
    final lng = GpsTrackingService.latestLng;
    final loc = (lat != null && lng != null) ? '$lat,$lng' : '';

    final err = await SupabaseService.saveCheckIn(
      employeeName: empName,
      employeeId:   UserSession.employeeId,
      date:         _fmtDate(now),
      time:         _timeCtrl.text,
      location:     loc,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sync error: $err'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } else {
      widget.onDone();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Checked in at ${_timeCtrl.text}'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  Future<void> _checkOut() async {
    setState(() => _submitting = true);
    final now = DateTime.now();

    GpsTrackingService.stop();
    AttendanceStore.isCheckedIn = false;

    await SupabaseService.saveCheckOut(
      employeeId: UserSession.employeeId,
      date:       _fmtDate(now),
      time:       _timeCtrl.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    widget.onDone();
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Checked out at ${_timeCtrl.text}'),
      backgroundColor: _teal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final rec     = widget.record;
    final accent  = widget.accentColor;

    final isCheckedIn = rec != null && rec.checkInTime.isNotEmpty && rec.checkOutTime.isEmpty;
    final isDone      = rec != null && rec.checkOutTime.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        const SizedBox(height: 12),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.access_time_rounded, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const Spacer(),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(widget.attendanceRoute);
            },
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('View Details', style: TextStyle(fontSize: 12, color: accent,
                  fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: accent),
            ]),
          ),
        ]),
        const SizedBox(height: 20),

        // Status banner
        if (isDone) ...[
          _doneBanner(rec!, isDark),
          const SizedBox(height: 16),
        ] else if (isCheckedIn) ...[
          _statusBanner(
            icon: Icons.check_circle_rounded,
            text: 'Checked in at ${rec!.checkInTime}',
            fg: isDark ? Colors.green.shade300 : _green,
            bg: isDark ? Colors.green.withValues(alpha: 0.12) : Colors.green.shade50,
            border: isDark ? Colors.green.shade700 : Colors.green.shade200,
          ),
          const SizedBox(height: 16),
        ] else ...[
          _statusBanner(
            icon: Icons.schedule_rounded,
            text: "Not checked in yet today",
            fg: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
            bg: isDark ? Colors.orange.withValues(alpha: 0.12) : Colors.orange.shade50,
            border: isDark ? Colors.orange.shade700 : Colors.orange.shade200,
          ),
          const SizedBox(height: 16),
        ],

        // Time field (hide when done)
        if (!isDone) ...[
          TextField(
            controller: _timeCtrl,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: isCheckedIn ? 'Check-Out Time' : 'Check-In Time',
              prefixIcon: Icon(
                isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
                color: isCheckedIn ? _teal : accent,
                size: 20,
              ),
              suffixIcon: IconButton(
                tooltip: 'Use current time',
                icon: Icon(Icons.schedule_rounded,
                    color: isCheckedIn ? _teal : accent),
                onPressed: () => setState(() => _timeCtrl.text = _nowTime()),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: isCheckedIn ? _teal : accent, width: 2),
              ),
              filled: true,
              fillColor: cs.surface,
            ),
          ),
          const SizedBox(height: 16),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : (isCheckedIn ? _checkOut : _checkIn),
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(isCheckedIn ? Icons.logout_rounded : Icons.login_rounded, size: 18),
              label: Text(isCheckedIn ? 'Check Out' : 'Check In',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCheckedIn ? _teal : accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _statusBanner({
    required IconData icon,
    required String text,
    required Color fg,
    required Color bg,
    required Color border,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: fg),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _doneBanner(AttendanceRecord rec, bool isDark) {
    final dur  = _AttendanceShortcutCardState._durationStr(rec);
    final blue = isDark ? Colors.blue.shade300 : const Color(0xFF1565C0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D47A1).withValues(alpha: 0.12) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_rounded, size: 14, color: blue),
          const SizedBox(width: 6),
          Text('Attendance Complete',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: blue)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _timeBlock('Check In',  rec.checkInTime,  blue),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: blue),
          ),
          _timeBlock('Check Out', rec.checkOutTime, blue),
        ]),
        if (dur != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(dur,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: blue)),
          ),
        ],
      ]),
    );
  }

  Widget _timeBlock(String label, String time, Color color) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
      const SizedBox(height: 2),
      Text(time, style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800,
          fontFamily: 'monospace', color: color)),
    ]);
  }
}
