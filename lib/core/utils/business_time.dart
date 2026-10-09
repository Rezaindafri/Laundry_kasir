/// Reporting uses WIB, regardless of the device timezone. Stored instants stay
/// UTC. Wall-clock values below are calendar/display values, not instants.
abstract final class BusinessTime {
  static const offset = Duration(hours: 7);

  static DateTime wallTime(DateTime instant) => instant.toUtc().add(offset);

  /// Encode calendar fields for date-only API filters (never an instant).
  static String dateParameter(DateTime calendar) =>
      '${calendar.year.toString().padLeft(4, '0')}-'
      '${calendar.month.toString().padLeft(2, '0')}-'
      '${calendar.day.toString().padLeft(2, '0')}';

  static DateTime calendarNow() {
    final wall = wallTime(DateTime.now());
    return DateTime(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
      wall.millisecond,
      wall.microsecond,
    );
  }

  /// Convert fields selected in a WIB date/time picker to a real UTC instant.
  static DateTime utcFromWallTime(DateTime wall) => DateTime.utc(
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
        wall.second,
        wall.millisecond,
        wall.microsecond,
      ).subtract(offset);
}
