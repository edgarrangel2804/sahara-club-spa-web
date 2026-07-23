import 'package:flutter_test/flutter_test.dart';
import 'package:sahara_club_spa_web/features/reception_alerts/reception_alert.dart';
import 'package:sahara_club_spa_web/features/reception_alerts/reception_alerts_service.dart';

void main() {
  group('ReceptionAlertsService helpers', () {
    final today = DateTime(2026, 7, 22);

    test('keeps future, same-day, and booking-less alerts', () {
      expect(
        ReceptionAlertsService.shouldKeepAlert(
          _alert(id: 'future', bookingDate: DateTime(2026, 7, 23)),
          today: today,
        ),
        isTrue,
      );
      expect(
        ReceptionAlertsService.shouldKeepAlert(
          _alert(id: 'today', bookingDate: DateTime(2026, 7, 22)),
          today: today,
        ),
        isTrue,
      );
      expect(
        ReceptionAlertsService.shouldKeepAlert(
          _alert(id: 'commercial'),
          today: today,
        ),
        isTrue,
      );
    });

    test('drops resolved and past booking alerts', () {
      expect(
        ReceptionAlertsService.shouldKeepAlert(
          _alert(id: 'past', bookingDate: DateTime(2026, 7, 21)),
          today: today,
        ),
        isFalse,
      );
      expect(
        ReceptionAlertsService.shouldKeepAlert(
          _alert(id: 'resolved', status: 'resolved'),
          today: today,
        ),
        isFalse,
      );
    });

    test('deduplicates by id and sorts newest first', () {
      final normalized = ReceptionAlertsService.normalizeAlertList([
        _alert(id: 'a', createdAt: DateTime.utc(2026, 7, 22, 17)),
        _alert(id: 'b', createdAt: DateTime.utc(2026, 7, 22, 19)),
        _alert(
          id: 'a',
          status: 'seen',
          createdAt: DateTime.utc(2026, 7, 22, 20),
        ),
        _alert(
          id: 'past',
          bookingDate: DateTime(2026, 7, 21),
          createdAt: DateTime.utc(2026, 7, 22, 21),
        ),
        _alert(
          id: 'resolved',
          status: 'resolved',
          createdAt: DateTime.utc(2026, 7, 22, 22),
        ),
      ], today: today);

      expect(normalized.map((alert) => alert.id), ['a', 'b']);
      expect(normalized.first.status, 'seen');
    });

    test(
      'keeps gift card alerts without booking date in newest-first order',
      () {
        final normalized = ReceptionAlertsService.normalizeAlertList([
          _alert(
            id: 'booking',
            bookingDate: DateTime(2026, 7, 22),
            createdAt: DateTime.utc(2026, 7, 22, 18),
          ),
          _alert(
            id: 'gift-card',
            eventType: 'gift_card_purchased',
            createdAt: DateTime.utc(2026, 7, 22, 20),
          ),
        ], today: today);

        expect(normalized.map((alert) => alert.id), ['gift-card', 'booking']);
        expect(normalized.first.isGiftCardPurchase, isTrue);
        expect(normalized.first.bookingDate, isNull);
      },
    );

    test('computes today using Tijuana commercial date', () {
      expect(
        ReceptionAlertsService.todayPeninsula(
          nowUtc: DateTime.utc(2026, 7, 22, 6, 30),
        ),
        '2026-07-21',
      );
      expect(
        ReceptionAlertsService.todayPeninsula(
          nowUtc: DateTime.utc(2026, 7, 22, 7, 30),
        ),
        '2026-07-22',
      );
    });
  });
}

ReceptionAlert _alert({
  required String id,
  String status = 'unseen',
  String eventType = 'booking_pending_reception',
  DateTime? bookingDate,
  DateTime? createdAt,
}) {
  return ReceptionAlert(
    id: id,
    eventType: eventType,
    status: status,
    channel: 'whatsapp',
    createdAt: createdAt ?? DateTime.utc(2026, 7, 22, 18),
    bookingDate: bookingDate,
  );
}
