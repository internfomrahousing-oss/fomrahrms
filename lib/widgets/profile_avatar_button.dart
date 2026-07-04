import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_session.dart';
import '../models/theme_notifier.dart';
import '../services/session_storage.dart';

/// Circular avatar + name/ID that opens a profile dropdown on tap.
/// Use [large] = true for the welcome banner (bigger avatar, vertical layout).
class ProfileAvatarButton extends StatefulWidget {
  final bool large;
  const ProfileAvatarButton({super.key, this.large = false});

  @override
  State<ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<ProfileAvatarButton> {
  final _key = GlobalKey();

  void _openMenu() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos    = box.localToGlobal(Offset.zero);
    final size   = box.size;
    final screen = MediaQuery.of(context).size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (_) => Stack(
        children: [
          Positioned(
            top:   pos.dy + size.height + 6,
            right: screen.width - pos.dx - size.width,
            child: _ProfileDropdown(
              onNavigate: (route) {
                Navigator.of(context).pop();
                context.go(route);
              },
              onSignOut: () {
                Navigator.of(context).pop();
                themeNotifier.reset();
                SessionStorage.clear();
                UserSession.clear();
                context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name      = UserSession.name;
    final empId     = UserSession.employeeId;
    final photoUrl  = UserSession.photoUrl;
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    if (widget.large) {
      // ── Banner variant: big avatar on top, name/ID below ─────────────
      return GestureDetector(
        key: _key,
        onTap: _openMenu,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: Colors.white.withValues(alpha: 0.20),
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 38))
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            name.isEmpty ? 'User' : name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
          if (empId.isNotEmpty)
            Text(
              empId,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11),
            ),
          const SizedBox(height: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.70), size: 18),
        ]),
      );
    }

    // ── Top-bar variant: compact horizontal ──────────────────────────────
    return GestureDetector(
      key: _key,
      onTap: _openMenu,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white.withValues(alpha: 0.20),
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14))
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'User' : name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              if (empId.isNotEmpty)
                Text(
                  empId,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10),
                ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down_rounded,
              color: Colors.white.withValues(alpha: 0.70), size: 18),
        ]),
      ),
    );
  }
}

// ── Dropdown card ─────────────────────────────────────────────────────────────
class _ProfileDropdown extends StatelessWidget {
  final void Function(String route) onNavigate;
  final VoidCallback onSignOut;

  const _ProfileDropdown({required this.onNavigate, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final name       = UserSession.name;
    final empId      = UserSession.employeeId;
    final designation= UserSession.designation;
    final manager    = UserSession.reportingManager;
    final photoUrl   = UserSession.photoUrl;
    final initial    = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 260,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF060F1E), Color(0xFF0A2472)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name.isEmpty ? 'User' : name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (empId.isNotEmpty)
                    Text(empId,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11)),
                  if (designation.isNotEmpty)
                    Text(designation,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),

          // ── Details ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(children: [
              if (designation.isNotEmpty)
                _InfoRow(Icons.work_outline_rounded, 'Designation', designation),
              if (manager.isNotEmpty)
                _InfoRow(Icons.manage_accounts_rounded, 'Reporting Manager', manager),
            ]),
          ),

          const Divider(height: 1),

          // ── My Profile ───────────────────────────────────────────────
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_rounded, size: 18,
                color: Color(0xFF0D47A1)),
            title: const Text('My Profile',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            onTap: () => onNavigate(UserSession.profileRoute),
          ),

          const Divider(height: 1),

          // ── Sign Out ─────────────────────────────────────────────────
          ListTile(
            dense: true,
            leading: const Icon(Icons.logout_rounded, size: 18,
                color: Color(0xFFE53935)),
            title: const Text('Sign Out',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE53935))),
            onTap: onSignOut,
          ),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: const Color(0xFF607D8B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF90A4AE),
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF37474F)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}
