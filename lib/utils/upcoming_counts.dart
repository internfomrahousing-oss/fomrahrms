/// How many items are worth attention behind each header icon.
///
/// The header showed four icons with no indication whether there was anything
/// behind them, so the only way to find out was to open each one — and the
/// same four blocks were repeated on the dashboard below, which is what made
/// the dashboard copy feel redundant. A badge answers the question without
/// opening anything, so the dashboard no longer has to.
class UpcomingCounts {
  /// Announcements posted in the last 7 days.
  final int announcements;

  /// Public holidays still ahead in the current month.
  final int holidays;

  /// Birthdays still ahead in the current month.
  final int birthdays;

  const UpcomingCounts({
    this.announcements = 0,
    this.holidays = 0,
    this.birthdays = 0,
  });

  int forIndex(int i) => switch (i) {
        0 => announcements,
        1 => holidays,
        // 2 is Employee of the Month: an award, not a queue of things to read.
        // A count there would be meaningless — it is always exactly one
        // person, and it is shown permanently rather than badged.
        3 => birthdays,
        _ => 0,
      };
}

/// Whether [iso] ('yyyy-MM-dd') falls between today and the end of this month.
///
/// "Upcoming" deliberately excludes days already past: a birthday last week is
/// not something to flag, and a badge that never clears is quickly ignored.
bool isUpcomingThisMonth(String iso, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime.tryParse(iso);
  if (d == null) return false;
  final start = DateTime(today.year, today.month, today.day);
  final end = DateTime(today.year, today.month + 1, 0);
  return !d.isBefore(start) && !d.isAfter(end);
}

/// Birthdays recur yearly, so the stored year is irrelevant — compare the day
/// and month against the current year instead.
bool isBirthdayUpcomingThisMonth(String iso, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime.tryParse(iso);
  if (d == null) return false;
  return isUpcomingThisMonth(
    '${today.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}',
    now: today,
  );
}

/// Announcements count as new for a week — long enough that someone away for
/// a few days still sees them, short enough that the badge clears.
bool isRecentAnnouncement(String iso, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime.tryParse(iso);
  if (d == null) return false;
  return today.difference(d).inDays.abs() <= 7;
}
