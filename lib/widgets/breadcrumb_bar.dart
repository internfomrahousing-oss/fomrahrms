import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// One clickable section a shell's sidebar already knows about — shells pass
/// their existing `_navItems`/`_personalNavItems` lists in as this shape so
/// the breadcrumb never needs its own separate route→label table.
typedef BreadcrumbSection = ({String label, String route});

/// Windows-Explorer-style breadcrumb trail ("Dashboard > Section > Detail"),
/// shown below the top bar on every page except the dashboard itself.
/// Matches [location] against the longest [sections] route prefix for the
/// main crumb, then humanizes any deeper path segments (e.g. an id or a
/// sub-page slug) into trailing, non-navigable crumbs since their exact
/// intermediate routes aren't known ahead of time.
class BreadcrumbBar extends StatelessWidget {
  final String location;
  final String homeRoute;
  final List<BreadcrumbSection> sections;
  const BreadcrumbBar({
    super.key,
    required this.location,
    required this.homeRoute,
    required this.sections,
  });

  static String _humanize(String segment) {
    final words = segment.replaceAll(RegExp(r'[-_]'), ' ').split(' ')
        .where((w) => w.isNotEmpty);
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  List<BreadcrumbSection> _crumbs() {
    BreadcrumbSection? matched;
    for (final s in sections) {
      if (s.route == homeRoute) continue;
      final isMatch = location == s.route || location.startsWith('${s.route}/');
      if (isMatch && (matched == null || s.route.length > matched.route.length)) {
        matched = s;
      }
    }

    final crumbs = <BreadcrumbSection>[];
    var remaining = location;
    if (matched != null) {
      crumbs.add(matched);
      remaining = location.substring(matched.route.length);
    }
    for (final seg in remaining.split('/').where((s) => s.isNotEmpty)) {
      crumbs.add((label: _humanize(seg), route: ''));
    }
    return crumbs;
  }

  @override
  Widget build(BuildContext context) {
    if (location == homeRoute) return const SizedBox.shrink();
    final crumbs = _crumbs();
    if (crumbs.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _crumb(context, 'Dashboard', homeRoute, icon: Icons.dashboard_rounded, isLast: false),
          for (var i = 0; i < crumbs.length; i++) ...[
            _separator(),
            _crumb(context, crumbs[i].label,
                crumbs[i].route.isEmpty ? null : crumbs[i].route,
                isLast: i == crumbs.length - 1),
          ],
        ]),
      ),
    );
  }

  Widget _separator() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textSecondary),
      );

  Widget _crumb(BuildContext context, String label, String? route,
      {IconData? icon, required bool isLast}) {
    final style = TextStyle(
      fontSize: 12.5,
      fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
      color: isLast ? AppTheme.textPrimary : AppTheme.textSecondary,
    );
    final content = Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 15, color: isLast ? AppTheme.textPrimary : AppTheme.primaryBlue),
        const SizedBox(width: 5),
      ],
      Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);

    if (isLast || route == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => context.go(route),
      child: content,
    );
  }
}
