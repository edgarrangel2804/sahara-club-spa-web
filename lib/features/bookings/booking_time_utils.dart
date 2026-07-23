class BookingTimeUtils {
  const BookingTimeUtils._();

  static String yyyyMmDd(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool isValidClockTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) {
      return false;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return false;
    }
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  static String tijuanaDateTimeIso(DateTime date, String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final local = DateTime(date.year, date.month, date.day, hour, minute);
    final offsetHours = likelyTijuanaUtcOffsetHours(local);
    final sign = offsetHours >= 0 ? '+' : '-';
    final absHours = offsetHours.abs().toString().padLeft(2, '0');
    return '${yyyyMmDd(local)}T'
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00'
        '$sign$absHours:00';
  }

  static String tijuanaDateStringFromUtc(DateTime utcDateTime) {
    return yyyyMmDd(tijuanaWallClockFromUtc(utcDateTime));
  }

  static DateTime tijuanaWallClockFromUtc(DateTime utcDateTime) {
    final utc = utcDateTime.toUtc();
    final firstGuess = utc.add(const Duration(hours: -8));
    final firstOffset = likelyTijuanaUtcOffsetHours(firstGuess);
    final secondGuess = utc.add(Duration(hours: firstOffset));
    final confirmedOffset = likelyTijuanaUtcOffsetHours(secondGuess);
    if (confirmedOffset == firstOffset) {
      return secondGuess;
    }
    return utc.add(Duration(hours: confirmedOffset));
  }

  static int likelyTijuanaUtcOffsetHours(DateTime local) {
    final dstStart = _secondSunday(local.year, 3);
    final dstEnd = _firstSunday(local.year, 11);
    final wallClock = DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
    final inDst =
        !wallClock.isBefore(DateTime.utc(local.year, 3, dstStart, 2)) &&
        wallClock.isBefore(DateTime.utc(local.year, 11, dstEnd, 2));
    return inDst ? -7 : -8;
  }

  static int _firstSunday(int year, int month) {
    final first = DateTime(year, month);
    return 1 + ((DateTime.sunday - first.weekday) % 7);
  }

  static int _secondSunday(int year, int month) {
    return _firstSunday(year, month) + 7;
  }
}
