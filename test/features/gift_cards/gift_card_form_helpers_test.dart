import 'package:flutter_test/flutter_test.dart';
import 'package:sahara_club_spa_web/features/gift_cards/gift_card_form_helpers.dart';
import 'package:sahara_club_spa_web/features/store/models/checkout_models.dart';

void main() {
  group('Gift card form validation', () {
    final now = DateTime(2026, 8, 15);

    GiftCardFormInput validInput({
      String recipientName = 'Luna',
      String recipientPhone = '646 151 9597',
      String senderName = 'Ana',
      DateTime? validFrom,
      bool termsAccepted = true,
      String dedicationMessage = '',
      bool sendCopyToBuyer = false,
    }) {
      return GiftCardFormInput(
        recipientName: recipientName,
        recipientPhone: recipientPhone,
        senderName: senderName,
        validFrom: validFrom ?? now,
        termsAccepted: termsAccepted,
        dedicationMessage: dedicationMessage,
        sendCopyToBuyer: sendCopyToBuyer,
      );
    }

    test('requires recipient, phone, sender and terms', () {
      expect(
        validateGiftCardForm(validInput(recipientName: ''), now: now).ok,
        isFalse,
      );
      expect(
        validateGiftCardForm(validInput(recipientPhone: '123'), now: now).ok,
        isFalse,
      );
      expect(
        validateGiftCardForm(validInput(senderName: ''), now: now).ok,
        isFalse,
      );
      expect(
        validateGiftCardForm(validInput(termsAccepted: false), now: now).ok,
        isFalse,
      );
    });

    test('normalizes recipient phone to E.164', () {
      expect(normalizeGiftCardPhoneE164('646 151 9597'), '+526461519597');
      expect(normalizeGiftCardPhoneE164('+52 646 151 9597'), '+526461519597');
      expect(normalizeGiftCardPhoneE164('+5216461519597'), '+526461519597');
      expect(normalizeGiftCardPhoneE164('001 602 587 7771'), '+16025877771');
      expect(normalizeGiftCardPhoneE164('12345'), isNull);
    });

    test('accepts empty and 350 character dedications but trims overflow', () {
      expect(sanitizeGiftCardDedication(''), '');
      final exact = 'x' * kGiftCardDedicationMaxLength;
      expect(
        sanitizeGiftCardDedication(exact).length,
        kGiftCardDedicationMaxLength,
      );
      final overflow = sanitizeGiftCardDedication('<b>${'x' * 400}</b>\u0000');
      expect(overflow.length, kGiftCardDedicationMaxLength);
      expect(overflow.contains('<'), isFalse);
      expect(overflow.contains('>'), isFalse);
      expect(overflow.contains('\u0000'), isFalse);
    });

    test(
      'rejects past date and calculates future expiration by calendar month',
      () {
        expect(
          validateGiftCardForm(
            validInput(validFrom: DateTime(2026, 8, 14)),
            now: now,
          ).ok,
          isFalse,
        );

        final result = validateGiftCardForm(
          validInput(validFrom: DateTime(2026, 8, 31)),
          now: now,
        );
        expect(result.ok, isTrue);
        expect(giftCardDateParam(result.validFrom!), '2026-08-31');
        expect(giftCardDateParam(result.expiresOn!), '2026-11-30');
        expect(
          addGiftCardCalendarMonths(DateTime(2026, 12, 1), 3),
          DateTime(2027, 3, 1),
        );
      },
    );

    test('preserves buyer copy opt-in and guards double taps', () {
      final result = validateGiftCardForm(
        validInput(sendCopyToBuyer: true),
        now: now,
      );
      expect(result.ok, isTrue);
      expect(result.sendCopyToBuyer, isTrue);
      expect(shouldIgnoreGiftCardTap(submitting: true), isTrue);
      expect(shouldIgnoreGiftCardTap(submitting: false), isFalse);
    });
  });

  group('Gift card checkout/download models', () {
    test('parses paid checkout response with gift card token', () {
      final result = CheckoutConfirmationResult.fromMap({
        'order_id': 'order_1',
        'status': 'paid',
        'payment_status': 'paid',
        'gift_cards': [
          {
            'gift_card_id': 'gc_1',
            'download_token': 'signed.token',
            'recipient_name': 'Luna',
            'service_name': 'Masaje',
            'valid_from': '2026-08-15',
            'expires_on': '2026-11-15',
            'digital_asset_status': 'generated',
            'delivery_status': 'sent',
            'status': 'active',
          },
        ],
      });

      expect(result.paymentStatus, 'paid');
      expect(result.giftCards.single.downloadToken, 'signed.token');
      expect(result.giftCards.single.deliveryStatus, 'sent');
    });

    test('parses download payload without PII fields', () {
      final result = GiftCardDownloadResult.fromMap({
        'ok': true,
        'download_url': 'https://example.com/gift-card.pdf',
        'asset_status': 'generated',
        'delivery_status': 'pending',
        'card': {
          'id': 'gc_1',
          'code': 'SAHARA-ABCDEFGH',
          'folio': 'SAHARA-GC-00000000',
          'service_name': 'Masaje',
          'recipient_name': 'Luna',
          'sender_name': 'Ana',
          'dedication_message': '',
          'valid_from': '2026-08-15',
          'expires_on': '2026-11-15',
          'status': 'active',
          'currency': 'MXN',
          'amount': 1250,
        },
      });

      expect(result.ok, isTrue);
      expect(result.downloadUrl, endsWith('gift-card.pdf'));
      expect(result.card.code, 'SAHARA-ABCDEFGH');
      expect(result.card.amount, 1250);
    });
  });
}
