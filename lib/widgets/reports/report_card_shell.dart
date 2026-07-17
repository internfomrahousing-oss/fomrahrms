import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shared card shell (title row + body) for every chart/table/map section on
/// the Reports & Analytics page — same Card/cardRadius/border look as
/// AppStatCard, so the whole page reads as one consistent system.
class ReportCardShell extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  final double? bodyHeight;
  const ReportCardShell({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    required this.child,
    this.bodyHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppTheme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(title, style: AppTheme.cardHeading)),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel!,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 16),
            if (bodyHeight != null) SizedBox(height: bodyHeight, child: child) else child,
          ],
        ),
      ),
    );
  }
}
