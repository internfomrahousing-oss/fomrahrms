import 'package:flutter/material.dart';
import '../models/banner_quote_notifier.dart';
import '../theme/app_theme.dart';
import 'dashboard_info_blocks.dart';

/// Management-only control: overrides the quote shown on everyone's welcome
/// banner. By default the banner rotates through a built-in Mahatria Ra
/// quote every day; setting a quote here overrides that rotation for
/// everyone until cleared. Persisted globally (Supabase `app_settings`),
/// same pattern as [ThemePickerBlock] — picked up immediately for this
/// session, on next load for everyone else.
class QuotePickerBlock extends StatefulWidget {
  const QuotePickerBlock({super.key});

  @override
  State<QuotePickerBlock> createState() => _QuotePickerBlockState();
}

class _QuotePickerBlockState extends State<QuotePickerBlock> {
  late final TextEditingController _quoteCtrl;
  late final TextEditingController _authorCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = bannerQuoteNotifier.isOverride ? bannerQuoteNotifier.value : null;
    _quoteCtrl = TextEditingController(text: current?.text ?? '');
    _authorCtrl = TextEditingController(text: current?.author ?? '');
  }

  @override
  void dispose() {
    _quoteCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _quoteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    await bannerQuoteNotifier.setQuote(text, _authorCtrl.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Banner quote updated for everyone.'),
      backgroundColor: AppTheme.accentBlue,
    ));
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    await bannerQuoteNotifier.clearOverride();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _quoteCtrl.clear();
      _authorCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Banner reverted to the daily Mahatria Ra quote.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      icon: Icons.format_quote_rounded,
      title: 'Banner Quote',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          "By default everyone's banner shows a new Mahatria Ra quote each day. "
          'Set one below to override it for everyone, or clear it to go back to the daily rotation.',
          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _quoteCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Quote',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _authorCtrl,
          decoration: InputDecoration(
            labelText: 'Author (optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Quote'),
            ),
          ),
          if (bannerQuoteNotifier.isOverride) ...[
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _saving ? null : _clear,
              child: const Text('Clear'),
            ),
          ],
        ]),
      ]),
    );
  }
}
