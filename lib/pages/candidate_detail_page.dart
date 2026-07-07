// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../models/candidate_store.dart';
import '../widgets/back_button.dart';

const _blue = Color(0xFF2563EB);

void _openUrl(String url) {
  if (url.isEmpty) return;
  final a = html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener noreferrer';
  html.document.body?.append(a);
  a.click();
  a.remove();
}

class CandidateDetailPage extends StatelessWidget {
  const CandidateDetailPage({super.key});

  String _val(Map<String, dynamic> d, String key) =>
      (d[key] ?? '').toString().trim();

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final d = CandidateStore.selected;
    if (d == null) {
      return const Scaffold(
        body: Center(child: Text('No candidate selected.')),
      );
    }

    final narrow = MediaQuery.of(context).size.width < 700;
    final pad    = narrow ? 16.0 : 24.0;

    return Material(
      color: null,
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 20, pad, 16),
          child: Row(children: [
            const NavBackButton(),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_val(d, 'name').isEmpty ? 'Candidate Details' : _val(d, 'name'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: _blue)),
                Text('Applied on ${_fmtDate(_val(d, 'submitted_at'))}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ),
            // Resume button
            if (_val(d, 'resume_url').isNotEmpty)
              ElevatedButton.icon(
                onPressed: () => _openUrl(_val(d, 'resume_url')),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Resume', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: CandidateDetailBody(data: d, narrow: narrow),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Full read-only body — reused wherever a candidate application needs to
// be shown in full (this page, and HR's employee profile dialog) ──────────
class CandidateDetailBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool narrow;
  const CandidateDetailBody({super.key, required this.data, this.narrow = false});

  String _val(Map<String, dynamic> d, String key) =>
      (d[key] ?? '').toString().trim();

  List<Map<String, dynamic>> _asList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFBBCCF0)),
    ),
    child: Text(text,
        style: const TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w500)),
  );

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Personal ────────────────────────────────────
        _Section(title: 'Personal Information', icon: Icons.person_rounded),
        _InfoGrid(narrow: narrow, items: [
          _Info('Name',           _val(d, 'name')),
          _Info('Mobile',         _val(d, 'mobile')),
          _Info('Email',          _val(d, 'email')),
          _Info('Place',          _val(d, 'place')),
          _Info('Date of Birth',  _val(d, 'dob')),
          _Info('Age',            _val(d, 'age')),
          _Info('Nationality',    _val(d, 'nationality')),
          _Info('Gender',         _val(d, 'gender')),
          _Info('Marital Status', _val(d, 'marital_status')),
        ]),

        const SizedBox(height: 20),
        // ── Interview ───────────────────────────────────
        _Section(title: 'Interview Details', icon: Icons.event_note_rounded),
        _InfoGrid(narrow: narrow, items: [
          _Info('Interview Date', _val(d, 'interview_date')),
          _Info('Post Applied',   _val(d, 'post_applied')),
        ]),

        const SizedBox(height: 20),
        // ── Education ───────────────────────────────────
        _Section(title: 'Educational Qualifications', icon: Icons.school_rounded),
        if (_val(d, 'standing_arrears').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _chip('Standing Arrears in Degree: ${_val(d, 'standing_arrears')}'),
          ),
        _EduTable(rows: _asList(d['education_history'])),

        const SizedBox(height: 20),
        // ── Experience ──────────────────────────────────
        _Section(title: 'Experience & CTC', icon: Icons.work_history_rounded),
        _InfoGrid(narrow: narrow, items: [
          _Info('Total Experience',    _val(d, 'total_experience')),
          _Info('Relevant Experience', _val(d, 'relevant_experience')),
          _Info('Reason for Change',   _val(d, 'reason_for_change')),
          _Info('Current CTC (INR)',   _val(d, 'current_ctc')),
          _Info('Expected CTC (INR)',  _val(d, 'expected_ctc')),
          _Info('Notice Period',       _val(d, 'notice_period')),
        ]),

        const SizedBox(height: 20),
        // ── Employment History ──────────────────────────
        _Section(title: 'Employment History', icon: Icons.business_center_rounded),
        _EmpTable(rows: _asList(d['employment_history'])),

        const SizedBox(height: 20),
        // ── Source ──────────────────────────────────────
        _Section(title: 'Source', icon: Icons.campaign_rounded),
        _InfoGrid(narrow: narrow, items: [
          _Info('Source',            _val(d, 'source')),
          _Info('Job Portal',        _val(d, 'job_portal')),
          _Info('Referred By',       _val(d, 'referred_by')),
          _Info('Related Employee',  _val(d, 'related_employee')),
          _Info('Applied Before',    _val(d, 'applied_before')),
        ]),

        const SizedBox(height: 20),
        // ── Referrals ───────────────────────────────────
        _Section(title: 'Referrals', icon: Icons.group_add_rounded),
        _RefTable(rows: _asList(d['referrals'])),

        const SizedBox(height: 20),
        // ── Address & Declaration ───────────────────────
        _Section(title: 'Address & Declaration', icon: Icons.location_on_rounded),
        _InfoGrid(narrow: narrow, items: [
          _Info('Address',          _val(d, 'address')),
          _Info('Declaration Name', _val(d, 'declaration_name')),
          _Info('Signature Date',   _val(d, 'signature_date')),
        ]),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  const _Section({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: _blue, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
      ]),
    );
  }
}

// ── Info grid ──────────────────────────────────────────────────────────────────
class _Info { final String label, value; const _Info(this.label, this.value); }

class _InfoGrid extends StatelessWidget {
  final bool narrow;
  final List<_Info> items;
  const _InfoGrid({required this.narrow, required this.items});
  @override
  Widget build(BuildContext context) {
    final cols = narrow ? 1 : 2;
    return LayoutBuilder(builder: (context, constraints) {
      final itemWidth = narrow
          ? double.infinity
          : (constraints.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12, runSpacing: 12,
        children: items.where((i) => i.value.isNotEmpty).map((i) => SizedBox(
          width: itemWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(i.value,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF111827),
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        )).toList(),
      );
    });
  }
}

// ── Education table ────────────────────────────────────────────────────────────
class _EduTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _EduTable({required this.rows});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty();
    const headers = ['Academics','Degree/Specialization','School/College/University',
        'Month/Year of Passing','% Marks','Certificate'];
    const keys    = ['academics','degree','college','passing','marks','certificate'];
    const widths  = [150.0, 150.0, 190.0, 120.0, 80.0, 100.0];
    return _ScrollTable(headers: headers, keys: keys, widths: widths, rows: rows);
  }
}

// ── Employment table ───────────────────────────────────────────────────────────
class _EmpTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _EmpTable({required this.rows});
  @override
  Widget build(BuildContext context) {
    final filled = rows.where((r) =>
        r.values.any((v) => v.toString().trim().isNotEmpty)).toList();
    if (filled.isEmpty) return const _Empty();
    const headers = ['Organization','Position Held','From','To','Last CTC','Reason for Leaving'];
    const keys    = ['organization','position_held','from','to','last_ctc','reason_leaving'];
    const widths  = [160.0, 150.0, 100.0, 100.0, 120.0, 160.0];
    return _ScrollTable(headers: headers, keys: keys, widths: widths, rows: filled);
  }
}

// ── Referral table ─────────────────────────────────────────────────────────────
class _RefTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _RefTable({required this.rows});
  @override
  Widget build(BuildContext context) {
    final filled = rows.where((r) =>
        r.values.any((v) => v.toString().trim().isNotEmpty)).toList();
    if (filled.isEmpty) return const _Empty(text: 'No referrals provided.');
    const headers = ['Name','Organization','Designation','Relationship','Contact'];
    const keys    = ['name','organization','designation','relationship','contact'];
    const widths  = [130.0, 150.0, 140.0, 130.0, 130.0];
    return _ScrollTable(headers: headers, keys: keys, widths: widths, rows: filled);
  }
}

// ── Scrollable generic table ───────────────────────────────────────────────────
class _ScrollTable extends StatelessWidget {
  final List<String> headers, keys;
  final List<double> widths;
  final List<Map<String, dynamic>> rows;
  const _ScrollTable({required this.headers, required this.keys,
      required this.widths, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(children: [
          // Header
          Container(
            color: const Color(0xFFEFF6FF),
            child: Row(children: List.generate(headers.length, (i) => Container(
              width: widths[i],
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(border: Border(
                right: i < headers.length - 1
                    ? const BorderSide(color: Color(0xFFE5E7EB)) : BorderSide.none,
              )),
              child: Text(headers[i], style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _blue)),
            ))),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          // Rows
          ...rows.asMap().entries.map((e) => Column(children: [
            Container(
              color: e.key.isEven ? Colors.white : const Color(0xFFF8F9FA),
              child: Row(children: List.generate(keys.length, (i) => Container(
                width: widths[i],
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(border: Border(
                  right: i < keys.length - 1
                      ? const BorderSide(color: Color(0xFFE5E7EB)) : BorderSide.none,
                )),
                child: Text(
                  (e.value[keys[i]] ?? '').toString(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ))),
            ),
            if (e.key < rows.length - 1)
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ])),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({this.text = 'No data provided.'});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)));
}
