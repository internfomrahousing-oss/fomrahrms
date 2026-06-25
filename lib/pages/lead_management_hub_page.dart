import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/lead_service.dart';

class LeadManagementHubPage extends StatefulWidget {
  final String leadsRoute;
  const LeadManagementHubPage({super.key, required this.leadsRoute});

  @override
  State<LeadManagementHubPage> createState() => _LeadManagementHubPageState();
}

class _LeadManagementHubPageState extends State<LeadManagementHubPage> {
  static const _blue    = Color(0xFF0D47A1);
  static const _fbBlue  = Color(0xFF1877F2);

  String _sourceName = 'Meta Leads';
  bool   _loadingName = true;

  @override
  void initState() {
    super.initState();
    LeadService.getSourceName().then((n) {
      if (mounted) setState(() { _sourceName = n; _loadingName = false; });
    });
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _sourceName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename source',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Meta Leads',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await LeadService.saveSourceName(result);
      if (mounted) setState(() => _sourceName = result.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.leaderboard_rounded,
                    color: _blue, size: 26),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Lead Management',
                    style: Theme.of(context).textTheme.headlineMedium),
                const Text('Select a lead source',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
              ]),
            ]),
            const SizedBox(height: 32),

            // Source card
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 600;
              return SizedBox(
                width: wide ? 260 : double.infinity,
                child: _loadingName
                    ? const Center(child: CircularProgressIndicator())
                    : _SourceCard(
                        name: _sourceName,
                        route: widget.leadsRoute,
                        onRename: _editName,
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final String name;
  final String route;
  final VoidCallback onRename;
  const _SourceCard({
    required this.name,
    required this.route,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    const fbBlue = Color(0xFF1877F2);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: fbBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: fbBlue, size: 34),
              ),
              const SizedBox(height: 16),

              // Editable name row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onRename,
                    child: const Icon(Icons.edit_rounded,
                        size: 15, color: Color(0xFF78909C)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Facebook & Instagram leads',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF78909C)),
              ),
              const SizedBox(height: 12),

              // View button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: fbBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('View Leads',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: fbBlue)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: fbBlue),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
