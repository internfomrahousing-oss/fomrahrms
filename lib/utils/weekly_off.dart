/// Maps an AppUser.weeklyOffDay string ('' | 'Sunday' | 'Tuesday' | 'Wednesday'
/// | ...) to a DateTime.weekday constant. Defaults to Sunday, same as every
/// employee outside the Sales department.
int weeklyOffWeekdayFor(String weeklyOffDay) {
  switch (weeklyOffDay) {
    case 'Monday':    return DateTime.monday;
    case 'Tuesday':   return DateTime.tuesday;
    case 'Wednesday': return DateTime.wednesday;
    case 'Thursday':  return DateTime.thursday;
    case 'Friday':    return DateTime.friday;
    case 'Saturday':  return DateTime.saturday;
    default:          return DateTime.sunday; // '' or 'Sunday'
  }
}
