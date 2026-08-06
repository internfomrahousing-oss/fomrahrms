import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// One person in a metric breakdown.
class PersonEntry {
  final String name;
  final String? subtitle;   // department, designation, time — whatever explains the row
  final String? trailing;   // check-in time, leave type, hours

  /// Opens this person's profile. Null when the caller could not resolve the
  /// name to an employee record — a row is then shown plainly rather than
  /// looking tappable and doing nothing.
  final VoidCallback? onTap;

  const PersonEntry({
    required this.name,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
}

/// Shows WHO is behind a number.
///
/// Every headline figure on the dashboards and in Reports & Analytics was a
/// dead end: "Absent Today 3" told you the count and nothing else, so the only
/// way to find out who was to go to another screen and filter it yourself.
///
/// Deliberately a single shared sheet rather than a bespoke dialog per metric.
/// The same figure appears on several screens, and the alternative — a
/// hand-written dialog at each call site — is how the late-reason prompt ended
/// up implemented three times with only one of them correct.
Future<void> showPeopleBreakdown(
  BuildContext context, {
  required String title,
  required List<PersonEntry> people,
  String? subtitle,
  Color? accentColor,
  IconData icon = Icons.people_alt_rounded,
  String emptyMessage = 'Nobody in this group',
}) {
  final color = accentColor ?? AppTheme.primaryBlue;

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final narrow = MediaQuery.of(ctx).size.width < 500;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
        contentPadding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 0, narrow ? 12 : 20, 8),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              // The count is repeated here so the sheet still says how many
              // even after the list is scrolled.
              Text(
                subtitle ?? '${people.length} ${people.length == 1 ? 'person' : 'people'}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 19),
            onPressed: () => Navigator.of(ctx).pop(),
            tooltip: 'Close',
          ),
        ]),
        content: SizedBox(
          width: narrow ? double.maxFinite : 400,
          child: people.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  child: Text(emptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic)),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: Scrollbar(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: people.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1, color: Colors.grey.shade200),
                      itemBuilder: (_, i) {
                        final p = people[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onTap: p.onTap == null
                              ? null
                              : () {
                                  // Close the breakdown first, so the profile
                                  // is not stacked on top of it and the back
                                  // gesture returns to the page rather than to
                                  // a list the user has finished with.
                                  Navigator.of(ctx).pop();
                                  p.onTap!();
                                },
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: color),
                            ),
                          ),
                          title: Text(p.name,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600)),
                          subtitle: (p.subtitle ?? '').isEmpty
                              ? null
                              : Text(p.subtitle!,
                                  style: TextStyle(
                                      fontSize: 11.5, color: Colors.grey.shade600)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if ((p.trailing ?? '').isNotEmpty)
                              Text(p.trailing!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: color)),
                            if (p.onTap != null) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded,
                                  size: 17, color: Colors.grey.shade400),
                            ],
                          ]),
                        );
                      },
                    ),
                  ),
                ),
        ),
      );
    },
  );
}
