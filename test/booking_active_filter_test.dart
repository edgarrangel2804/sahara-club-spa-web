import 'package:flutter_test/flutter_test.dart';
import 'package:sahara_club_spa_web/features/bookings/booking_active_filter.dart';

void main() {
  group('activeBookingStatuses', () {
    test('includes paid', () {
      expect(activeBookingStatuses.contains('paid'), isTrue);
    });

    test('includes completed', () {
      expect(activeBookingStatuses.contains('completed'), isTrue);
    });

    test('includes awaiting_payment', () {
      expect(activeBookingStatuses.contains('awaiting_payment'), isTrue);
    });

    test('includes confirmed', () {
      expect(activeBookingStatuses.contains('confirmed'), isTrue);
    });

    test('includes in_progress', () {
      expect(activeBookingStatuses.contains('in_progress'), isTrue);
    });

    test('does NOT include cancelled', () {
      expect(activeBookingStatuses.contains('cancelled'), isFalse);
    });

    test('does NOT include no_show', () {
      expect(activeBookingStatuses.contains('no_show'), isFalse);
    });

    test('all previously-active statuses are preserved', () {
      const previouslyActive = {
        'scheduled', 'pending', 'pending_reception', 'pending_payment',
        'payment_received', 'confirmed', 'checked_in', 'in_progress',
        'completed', 'awaiting_payment',
      };
      for (final s in previouslyActive) {
        expect(activeBookingStatuses.contains(s), isTrue,
            reason: '$s should still be active');
      }
    });
  });

  group('attendedTerminalStatuses', () {
    test('includes completed', () {
      expect(attendedTerminalStatuses.contains('completed'), isTrue);
    });

    test('includes awaiting_payment', () {
      expect(attendedTerminalStatuses.contains('awaiting_payment'), isTrue);
    });

    test('rejects in_progress', () {
      expect(attendedTerminalStatuses.contains('in_progress'), isFalse);
    });

    test('rejects unknown status', () {
      expect(attendedTerminalStatuses.contains('unknown_status'), isFalse);
      expect(attendedTerminalStatuses.contains('paid'), isFalse);
      expect(attendedTerminalStatuses.contains('confirmed'), isFalse);
    });
  });

  group('isActiveBookingStatus', () {
    test('returns true for paid', () {
      expect(isActiveBookingStatus('paid'), isTrue);
    });

    test('returns false for cancelled', () {
      expect(isActiveBookingStatus('cancelled'), isFalse);
    });

    test('returns false for no_show', () {
      expect(isActiveBookingStatus('no_show'), isFalse);
    });
  });

  group('isAttendedTerminalStatus', () {
    test('completed is attended', () {
      expect(isAttendedTerminalStatus('completed'), isTrue);
    });

    test('awaiting_payment is attended', () {
      expect(isAttendedTerminalStatus('awaiting_payment'), isTrue);
    });

    test('in_progress is NOT attended', () {
      expect(isAttendedTerminalStatus('in_progress'), isFalse);
    });

    test('paid alone is NOT attended', () {
      expect(isAttendedTerminalStatus('paid'), isFalse);
    });
  });
}
