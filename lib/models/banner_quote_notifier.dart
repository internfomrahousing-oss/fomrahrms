import 'package:flutter/foundation.dart';
import '../data/mahatria_quotes.dart';
import '../services/supabase_service.dart';

/// Quote + attribution shown on [WelcomeBanner] across every role's dashboard.
class BannerQuote {
  final String text;
  final String author;
  const BannerQuote(this.text, this.author);
}

int _dayOfYear(DateTime d) => d.difference(DateTime(d.year, 1, 1)).inDays;

/// Deterministic pick so every user sees the same quote on a given calendar
/// day — rotates automatically, no server round trip needed.
BannerQuote quoteOfTheDay([DateTime? now]) {
  final index = _dayOfYear(now ?? DateTime.now()) % mahatriaQuotes.length;
  return BannerQuote(mahatriaQuotes[index], 'Mahatria Ra');
}

/// Shared across all sessions via `app_settings`, same pattern as
/// [colorThemeNotifier]. By default the banner rotates through
/// [mahatriaQuotes] once a day; if Management sets a custom quote it
/// overrides the rotation for everyone until Management clears it.
class BannerQuoteNotifier extends ValueNotifier<BannerQuote> {
  BannerQuoteNotifier() : super(quoteOfTheDay());

  /// True when the current [value] is a Management-set override rather than
  /// today's auto-rotated quote.
  bool isOverride = false;

  Future<void> loadInitial() async {
    final data = await SupabaseService.fetchBannerQuote();
    final quote = data?['quote'] ?? '';
    if (quote.isNotEmpty) {
      isOverride = true;
      value = BannerQuote(quote, data?['author'] ?? '');
    } else {
      isOverride = false;
      value = quoteOfTheDay();
    }
  }

  Future<void> setQuote(String text, String author) async {
    isOverride = true;
    value = BannerQuote(text, author);
    await SupabaseService.setBannerQuote(text, author);
  }

  /// Reverts everyone's banner back to the daily Mahatria Ra rotation.
  Future<void> clearOverride() async {
    isOverride = false;
    value = quoteOfTheDay();
    await SupabaseService.setBannerQuote('', '');
  }
}

final bannerQuoteNotifier = BannerQuoteNotifier();
