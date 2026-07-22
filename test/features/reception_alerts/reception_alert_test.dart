import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahara_club_spa_web/features/reception_alerts/reception_alert.dart';

void main() {
  group('ReceptionAlert.fromMap', () {
    test('parses a booking alert with nullable-safe fields', () {
      final alert = ReceptionAlert.fromMap({
        'id': 'alert-1',
        'event_type': 'booking_pending_reception',
        'status': 'unseen',
        'channel': 'whatsapp',
        'created_at': '2026-07-21T19:00:00Z',
        'booking_id': 'booking-1',
        'client_record_id': 'client-1',
        'client_name': 'Ana Lopez',
        'client_phone': '6641234567',
        'service_name': 'Masaje relajante',
        'booking_date': '2026-07-22',
        'booking_time': '10:30:00',
        'message': 'Nueva cita por validar',
        'amount_mxn': '250.50',
      });

      expect(alert.id, 'alert-1');
      expect(alert.eventType, 'booking_pending_reception');
      expect(alert.isUnseen, isTrue);
      expect(alert.bookingId, 'booking-1');
      expect(alert.clientRecordId, 'client-1');
      expect(alert.bookingDate, DateTime(2026, 7, 22));
      expect(alert.bookingTime, '10:30');
      expect(alert.amountMxn, 250.50);
      expect(alert.title, 'Cita nueva por validar');
      expect(alert.icon, Icons.event_available_outlined);
    });

    test('keeps valid commercial alerts without booking fields', () {
      final alert = ReceptionAlert.fromMap({
        'id': 'alert-2',
        'event_type': 'gift_card_purchased',
        'status': 'seen',
        'created_at': '2026-07-21T20:00:00Z',
        'booking_id': null,
        'booking_date': null,
        'booking_time': null,
      });

      expect(alert.bookingId, isNull);
      expect(alert.bookingDate, isNull);
      expect(alert.bookingTime, isNull);
      expect(alert.isUnseen, isFalse);
      expect(alert.isResolved, isFalse);
      expect(alert.title, 'Evento');
      expect(alert.icon, Icons.notifications_outlined);
      expect(alert.accent, Colors.black54);
    });

    test('detects resolved status and nullable amount', () {
      final alert = ReceptionAlert.fromMap({
        'id': 'alert-3',
        'event_type': 'deposit_paid',
        'status': 'resolved',
        'channel': null,
        'created_at': '2026-07-21T21:00:00Z',
        'amount_mxn': null,
      });

      expect(alert.isResolved, isTrue);
      expect(alert.isUnseen, isFalse);
      expect(alert.channel, 'whatsapp');
      expect(alert.amountMxn, isNull);
      expect(alert.title, 'Pago de anticipo');
      expect(alert.icon, Icons.payments_outlined);
    });
  });
}
