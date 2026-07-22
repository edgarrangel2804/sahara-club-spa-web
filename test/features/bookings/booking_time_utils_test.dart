import 'package:flutter_test/flutter_test.dart';
import 'package:sahara_club_spa_web/features/bookings/booking_time_utils.dart';

void main() {
  group('BookingTimeUtils', () {
    test('formats date-only values consistently', () {
      expect(BookingTimeUtils.yyyyMmDd(DateTime(2026, 7, 2)), '2026-07-02');
      expect(
        BookingTimeUtils.dateOnly(DateTime(2026, 7, 2, 23, 59)),
        DateTime(2026, 7, 2),
      );
    });

    test('validates HH:mm values without accepting impossible times', () {
      expect(BookingTimeUtils.isValidClockTime('00:00'), isTrue);
      expect(BookingTimeUtils.isValidClockTime('23:59'), isTrue);
      expect(BookingTimeUtils.isValidClockTime('24:00'), isFalse);
      expect(BookingTimeUtils.isValidClockTime('10:60'), isFalse);
      expect(BookingTimeUtils.isValidClockTime('nope'), isFalse);
    });

    test('emits Tijuana ISO offsets from DST rules', () {
      expect(
        BookingTimeUtils.tijuanaDateTimeIso(DateTime(2026, 1, 15), '10:30'),
        '2026-01-15T10:30:00-08:00',
      );
      expect(
        BookingTimeUtils.tijuanaDateTimeIso(DateTime(2026, 7, 15), '10:30'),
        '2026-07-15T10:30:00-07:00',
      );
    });

    test('detects DST transition boundaries for Tijuana wall clock', () {
      expect(
        BookingTimeUtils.likelyTijuanaUtcOffsetHours(
          DateTime(2026, 3, 8, 1, 59),
        ),
        -8,
      );
      expect(
        BookingTimeUtils.likelyTijuanaUtcOffsetHours(DateTime(2026, 3, 8, 2)),
        -7,
      );
      expect(
        BookingTimeUtils.likelyTijuanaUtcOffsetHours(
          DateTime(2026, 11, 1, 1, 59),
        ),
        -7,
      );
      expect(
        BookingTimeUtils.likelyTijuanaUtcOffsetHours(DateTime(2026, 11, 1, 2)),
        -8,
      );
    });

    test('converts UTC instants to Tijuana commercial dates', () {
      expect(
        BookingTimeUtils.tijuanaDateStringFromUtc(
          DateTime.utc(2026, 7, 22, 6, 30),
        ),
        '2026-07-21',
      );
      expect(
        BookingTimeUtils.tijuanaDateStringFromUtc(
          DateTime.utc(2026, 7, 22, 7, 30),
        ),
        '2026-07-22',
      );

      final afterSpringForward = BookingTimeUtils.tijuanaWallClockFromUtc(
        DateTime.utc(2026, 3, 8, 10, 30),
      );
      expect(afterSpringForward.hour, 3);
      expect(afterSpringForward.minute, 30);
    });
  });
}
