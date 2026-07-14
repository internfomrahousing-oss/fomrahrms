import 'dart:async';
import 'package:flutter/material.dart';
import '../models/banner_quote_notifier.dart';
import '../models/user_session.dart';
import 'lotus_motif.dart';
import 'profile_avatar_button.dart';

class WelcomeBanner extends StatefulWidget {
  final String subtitle;
  final IconData avatarIcon;
  final VoidCallback? onRefresh;

  const WelcomeBanner({
    super.key,
    this.subtitle = 'Fomra Housing & Infrastructure',
    this.avatarIcon = Icons.admin_panel_settings_rounded,
    this.onRefresh,
  });

  @override
  State<WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<WelcomeBanner> {
  static const _navy = Color(0xFF3B4258);

  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Update greeting at the start of each minute
    _timer = Timer.periodic(const Duration(minutes: 1),
        (_) { if (mounted) setState(() => _now = DateTime.now()); });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Happy Morning';
    if (h < 17) return 'Happy Afternoon';
    return 'Happy Evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = UserSession.name.isNotEmpty ? UserSession.name : 'Admin';
    final wide = MediaQuery.of(context).size.width > 500;
    return ListenableBuilder(
      listenable: bannerQuoteNotifier,
      builder: (context, _) => _bannerBody(name, wide),
    );
  }

  Widget _bannerBody(String name, bool wide) {
    final quote = bannerQuoteNotifier.value;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFBF1E7), Color(0xFFF3ECF4), Color(0xFFE9F1F8)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(right: 4, bottom: -8, child: LotusMotif(size: 128)),
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 18, wide ? 28 : 16, 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_greeting, $name \u{1F44B}',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: TextStyle(color: _navy.withValues(alpha: 0.55), fontSize: 12.5, height: 1.3)),
                    if (quote.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '“${quote.text}”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _navy.withValues(alpha: 0.75),
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                      if (quote.author.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('— ${quote.author}',
                            style: TextStyle(
                                color: _navy.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ],
                ),
              ),
              if (widget.onRefresh != null) ...[
                Tooltip(
                  message: 'Refresh',
                  child: InkWell(
                    onTap: widget.onRefresh,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.refresh_rounded, color: _navy.withValues(alpha: 0.45), size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const ProfileAvatarButton(large: true, avatarRadius: 36, light: true),
            ]),
          ),
        ],
      ),
    );
  }
}
