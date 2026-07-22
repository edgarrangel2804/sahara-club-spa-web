import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahara_club_spa_web/features/receipts/deposit_receipt_actions.dart';

void main() {
  group('deposit receipt helpers', () {
    const bookingId = '00000000-0000-4000-8000-000000000000';

    test('builds stable folios and validates UUID booking ids', () {
      expect(depositReceiptFolio(bookingId), 'SAHARA-00000000');
      expect(isValidBookingId(bookingId), isTrue);
      expect(isValidBookingId('booking-1'), isFalse);
      expect(isValidBookingId('00000000-0000-0000-0000-000000000000'), isFalse);
    });

    test('accepts only safe HTTPS receipt URLs', () {
      expect(
        isSafeReceiptUrl(
          'https://fkbyxhwdcsgrrixalzwf.supabase.co/storage/v1/object/sign/receipts/$bookingId.pdf',
        ),
        isTrue,
      );
      expect(isSafeReceiptUrl('http://example.com/$bookingId.pdf'), isFalse);
      expect(
        isSafeReceiptUrl('https://user@example.com/$bookingId.pdf'),
        isFalse,
      );
      expect(isSafeReceiptUrl('javascript:alert(1)'), isFalse);
      expect(isSafeReceiptUrl(null), isFalse);
    });

    test('parses function responses without trusting malformed payloads', () {
      final ok = DepositReceiptResponse.fromFunctionData({
        'ok': true,
        'folio': 'SAHARA-00000000',
        'signed_url': 'https://example.com/receipt.pdf',
        'whatsapp_sent': true,
      });

      expect(ok.ok, isTrue);
      expect(ok.folio, 'SAHARA-00000000');
      expect(ok.signedUrl, 'https://example.com/receipt.pdf');
      expect(ok.whatsappSent, isTrue);

      final pending = DepositReceiptResponse.fromFunctionData({
        'ok': false,
        'error': 'deposit_not_paid',
      });
      expect(pending.ok, isFalse);
      expect(pending.error, 'deposit_not_paid');

      final invalid = DepositReceiptResponse.fromFunctionData(['bad']);
      expect(invalid.ok, isFalse);
      expect(invalid.error, 'invalid_response');
    });

    test('sanitizes receipt errors into bounded user messages', () {
      expect(
        sanitizeReceiptError(
          'deposit_not_paid for https://secret.example/token',
        ),
        'El anticipo aun no esta confirmado como pagado.',
      );
      expect(
        sanitizeReceiptError('network fetch failed'),
        'No se pudo conectar con Supabase. Intenta de nuevo.',
      );
      expect(
        sanitizeReceiptError('raw signed_url=secret-token'),
        'No se pudo completar la accion del comprobante.',
      );
    });

    test(
      'prevents duplicate actions and drops results after dispose',
      () async {
        final gate = DepositReceiptActionGate();
        final completer = Completer<String>();

        final first = gate.run(() => completer.future);
        final second = await gate.run(() async => 'second');
        expect(second, isNull);
        expect(gate.busy, isTrue);

        completer.complete('first');
        expect(await first, 'first');
        expect(gate.busy, isFalse);

        final afterComplete = await gate.run(() async => 'third');
        expect(afterComplete, 'third');

        final disposedGate = DepositReceiptActionGate();
        final lateCompleter = Completer<String>();
        final late = disposedGate.run(() => lateCompleter.future);
        disposedGate.dispose();
        lateCompleter.complete('late');
        expect(await late, isNull);
        expect(await disposedGate.run(() async => 'never'), isNull);
      },
    );

    test('builds explicit function payloads and voucher URLs', () {
      expect(sendDepositReceiptPayload(bookingId), {'booking_id': bookingId});
      expect(() => sendDepositReceiptPayload('booking-1'), throwsArgumentError);

      final base = Uri.parse('https://example.supabase.co/functions/v1');
      final tokenUri = buildDepositVoucherUri(
        functionsBaseUri: base,
        token: 'abcdefghijklmnopqrstuvwx',
      );
      expect(
        tokenUri.toString(),
        'https://example.supabase.co/functions/v1/deposit_voucher?token=abcdefghijklmnopqrstuvwx',
      );

      final sessionUri = buildDepositVoucherUri(
        functionsBaseUri: base,
        sessionId: 'cs_live_1234567890abcdef',
      );
      expect(
        sessionUri.toString(),
        'https://example.supabase.co/functions/v1/deposit_voucher?session_id=cs_live_1234567890abcdef',
      );

      expect(
        buildDepositVoucherUri(functionsBaseUri: base, token: 'short'),
        isNull,
      );
      expect(
        buildDepositVoucherUri(functionsBaseUri: base, sessionId: bookingId),
        isNull,
      );
    });
  });
}
