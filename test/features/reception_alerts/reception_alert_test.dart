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

    test('parses gift card purchase alerts without booking fields', () {
      final alert = ReceptionAlert.fromMap({
        'id': 'alert-2',
        'event_type': 'gift_card_purchased',
        'status': 'seen',
        'channel': 'web',
        'created_at': '2026-07-21T20:00:00Z',
        'booking_id': null,
        'booking_date': null,
        'booking_time': null,
        'order_id': 'order-1',
        'order_item_id': 'item-1',
        'gift_card_id': '123e4567-e89b-42d3-a456-426614174000',
        'payment_id': 'payment-1',
        'buyer_name': 'Laura Perez',
        'buyer_email': 'la***@example.com',
        'buyer_phone': '****4321',
        'client_name': 'Maria Garcia',
        'client_phone': '****7654',
        'product_name': 'Masaje Sahara',
        'amount_paid': '1200.50',
        'currency': 'mxn',
        'purchase_channel': 'whatsapp',
        'occurred_at': '2026-07-21T19:59:30Z',
        'metadata': {
          'recipient_name': 'Maria Garcia',
          'recipient_phone_mask': '****7654',
          'valid_from': '2026-07-22',
          'expires_on': '2026-10-22',
          'delivery_status': 'sent',
          'digital_asset_status': 'generated',
          'buyer_copy_requested': true,
          'admin_notification_status': 'sent',
          'gift_card_code_last4': '9XYZ',
        },
      });

      expect(alert.bookingId, isNull);
      expect(alert.bookingDate, isNull);
      expect(alert.bookingTime, isNull);
      expect(alert.isUnseen, isFalse);
      expect(alert.isResolved, isFalse);
      expect(alert.isGiftCardPurchase, isTrue);
      expect(alert.title, 'Gift Card adquirida');
      expect(alert.icon, Icons.card_giftcard_outlined);
      expect(alert.displayClientName, 'Laura Perez');
      expect(alert.recipientName, 'Maria Garcia');
      expect(alert.displayPhone, '****7654');
      expect(alert.buyerPhoneMasked, '****4321');
      expect(alert.displayProductName, 'Masaje Sahara');
      expect(alert.amountPaid, 1200.50);
      expect(alert.currency, 'mxn');
      expect(alert.purchaseChannelLabel, 'WhatsApp');
      expect(alert.validityLabel, '2026-07-22 a 2026-10-22');
      expect(alert.deliveryStatus, 'sent');
      expect(alert.digitalAssetStatus, 'generated');
      expect(alert.adminNotificationStatus, 'sent');
      expect(alert.buyerCopyRequested, isTrue);
      expect(alert.maskedGiftCardCode, '****9XYZ');
      expect(alert.accent, const Color(0xFFB7791F));
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
