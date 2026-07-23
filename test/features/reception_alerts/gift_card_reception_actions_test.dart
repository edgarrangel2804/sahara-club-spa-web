import 'package:flutter_test/flutter_test.dart';
import 'package:sahara_club_spa_web/features/reception_alerts/gift_card_reception_actions.dart';

void main() {
  group('gift card reception action helpers', () {
    const giftCardId = '123e4567-e89b-42d3-a456-426614174000';

    test('validates UUIDs and builds function payloads', () {
      expect(isValidGiftCardId(giftCardId), isTrue);
      expect(isValidGiftCardId('not-a-uuid'), isFalse);

      expect(
        giftCardReceptionActionPayload(
          giftCardId: ' $giftCardId ',
          action: 'download_link',
        ),
        {'gift_card_id': giftCardId, 'action': 'download_link'},
      );

      expect(
        () => giftCardReceptionActionPayload(
          giftCardId: giftCardId,
          action: 'delete',
        ),
        throwsArgumentError,
      );
    });

    test('allows only trusted asset URLs', () {
      expect(
        isSafeGiftCardAssetUrl(
          'https://fkbyxhwdcsgrrixalzwf.supabase.co/storage/v1/object/sign/gift-card-assets/card.pdf?token=abc',
        ),
        isTrue,
      );
      expect(
        isSafeGiftCardAssetUrl(
          'http://127.0.0.1:54321/storage/v1/object/sign/gift-card-assets/card.pdf?token=abc',
        ),
        isTrue,
      );
      expect(isSafeGiftCardAssetUrl('javascript:alert(1)'), isFalse);
      expect(
        isSafeGiftCardAssetUrl('https://evil.example.com/card.pdf'),
        isFalse,
      );
      expect(
        isSafeGiftCardAssetUrl('https://user:pass@saharaclubspa.com/card.pdf'),
        isFalse,
      );
    });

    test('sanitizes known function errors into user-safe copy', () {
      expect(
        sanitizeGiftCardReceptionActionError('buyer_copy_not_requested'),
        'Esta compra no solicito copia para el comprador.',
      );
      expect(
        sanitizeGiftCardReceptionActionError(
          'token abc.def +52 646 123 4567 invalid_token',
        ),
        'Tu sesion expiro. Vuelve a iniciar sesion.',
      );
      expect(
        sanitizeGiftCardReceptionActionError('unexpected secret payload'),
        'No se pudo completar la accion de la Gift Card.',
      );
    });

    test('parses function responses without exposing download tokens', () {
      const token =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
      final response = GiftCardReceptionActionResponse.fromFunctionData({
        'ok': true,
        'action': 'download_link',
        'download_url':
            'https://fkbyxhwdcsgrrixalzwf.supabase.co/storage/v1/object/sign/gift-card-assets/card.pdf?token=abc',
        'download_token': token,
        'asset_status': 'generated',
        'delivery_status': 'sent',
        'reception': {
          'gift_card_id': giftCardId,
          'recipient_phone_masked': '****7654',
          'purchaser_phone_masked': '****4321',
          'purchaser_name': 'Laura Perez',
          'recipient_name': 'Maria Garcia',
          'service_name': 'Masaje Sahara',
          'valid_from': '2026-07-22',
          'expires_on': '2026-10-22',
          'digital_asset_status': 'generated',
          'delivery_status': 'sent',
          'buyer_copy_requested': true,
          'status': 'active',
        },
      });

      expect(response.ok, isTrue);
      expect(response.downloadTokenReceived, isTrue);
      expect(response.safeDownloadUri, isNotNull);
      expect(response.assetStatus, 'generated');
      expect(response.deliveryStatus, 'sent');
      expect(response.reception?.recipientPhoneMasked, '****7654');
      expect(response.reception?.buyerCopyRequested, isTrue);
      expect(response.toString(), isNot(contains(token)));
    });

    test(
      'prevents double-click actions and ignores disposed completions',
      () async {
        final gate = GiftCardReceptionActionGate();
        var calls = 0;
        final first = gate.run(() async {
          calls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 'first';
        });

        final second = await gate.run(() async {
          calls += 1;
          return 'second';
        });

        expect(second, isNull);
        expect(await first, 'first');
        expect(calls, 1);

        final disposedGate = GiftCardReceptionActionGate();
        final pending = disposedGate.run(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 'late';
        });
        disposedGate.dispose();
        expect(await pending, isNull);
        expect(disposedGate.disposed, isTrue);
      },
    );
  });
}
