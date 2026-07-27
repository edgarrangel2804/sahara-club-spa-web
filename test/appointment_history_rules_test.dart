import 'package:flutter_test/flutter_test.dart';
import 'package:sahara_club_spa_web/features/bookings/appointment_history_rules.dart';

void main() {
  group('Attendance proof â€” attendedTerminalStatuses', () {
    test('completed proves attendance', () {
      expect(AppointmentHistoryRules.isAttendedStatus('completed'), isTrue);
    });

    test('awaiting_payment proves attendance', () {
      expect(AppointmentHistoryRules.isAttendedStatus('awaiting_payment'),
          isTrue);
    });

    test('in_progress does NOT prove attendance', () {
      expect(AppointmentHistoryRules.isAttendedStatus('in_progress'), isFalse);
    });

    test('unknown status does NOT prove attendance', () {
      expect(AppointmentHistoryRules.isAttendedStatus('unknown'), isFalse);
    });

    test('paid alone does NOT prove attendance', () {
      expect(AppointmentHistoryRules.isAttendedStatus('paid'), isFalse);
    });
  });

  group('Historical rule', () {
    test('paid + successAttended = historical', () {
      expect(
        AppointmentHistoryRules.isHistoricalAttendedAndPaid(
          'paid',
          HistoryVerificationState.successAttended,
        ),
        isTrue,
      );
    });

    test('paid + successNotAttended = not historical', () {
      expect(
        AppointmentHistoryRules.isHistoricalAttendedAndPaid(
          'paid',
          HistoryVerificationState.successNotAttended,
        ),
        isFalse,
      );
    });

    test('paid + loading = not historical', () {
      expect(
        AppointmentHistoryRules.isHistoricalAttendedAndPaid(
          'paid',
          HistoryVerificationState.loading,
        ),
        isFalse,
      );
    });

    test('paid + failure = not historical', () {
      expect(
        AppointmentHistoryRules.isHistoricalAttendedAndPaid(
          'paid',
          HistoryVerificationState.failure,
        ),
        isFalse,
      );
    });

    test('awaiting_payment is never historical', () {
      for (final v in HistoryVerificationState.values) {
        expect(
          AppointmentHistoryRules.isHistoricalAttendedAndPaid(
              'awaiting_payment', v),
          isFalse,
        );
      }
    });

    test('completed without payment is not historical', () {
      expect(
        AppointmentHistoryRules.isHistoricalAttendedAndPaid(
          'completed',
          HistoryVerificationState.successAttended,
        ),
        isFalse,
      );
    });
  });

  group('Lock rule â€” isInteractionLocked', () {
    test('historical (paid + successAttended) is locked', () {
      expect(
        AppointmentHistoryRules.isInteractionLocked(
          'paid',
          HistoryVerificationState.successAttended,
        ),
        isTrue,
      );
    });

    test('paid + successNotAttended is NOT locked', () {
      expect(
        AppointmentHistoryRules.isInteractionLocked(
          'paid',
          HistoryVerificationState.successNotAttended,
        ),
        isFalse,
      );
    });

    test('paid + loading IS locked (temporary)', () {
      expect(
        AppointmentHistoryRules.isInteractionLocked(
          'paid',
          HistoryVerificationState.loading,
        ),
        isTrue,
      );
    });

    test('paid + failure IS locked (safe degradation)', () {
      expect(
        AppointmentHistoryRules.isInteractionLocked(
          'paid',
          HistoryVerificationState.failure,
        ),
        isTrue,
      );
    });

    test('cancelled is always locked', () {
      for (final v in HistoryVerificationState.values) {
        expect(
          AppointmentHistoryRules.isInteractionLocked('cancelled', v),
          isTrue,
        );
      }
    });

    test('no_show is always locked', () {
      for (final v in HistoryVerificationState.values) {
        expect(
          AppointmentHistoryRules.isInteractionLocked('no_show', v),
          isTrue,
        );
      }
    });

    test('awaiting_payment is NOT locked', () {
      expect(
        AppointmentHistoryRules.isInteractionLocked(
          'awaiting_payment',
          HistoryVerificationState.successAttended,
        ),
        isFalse,
      );
    });
  });

  group('Status labels', () {
    test('historical â†’ "Atendida y cobrada"', () {
      expect(
        AppointmentHistoryRules.statusLabel(
          'paid',
          HistoryVerificationState.successAttended,
        ),
        'Atendida y cobrada',
      );
    });

    test('paid + successNotAttended â†’ "Pagada"', () {
      expect(
        AppointmentHistoryRules.statusLabel(
          'paid',
          HistoryVerificationState.successNotAttended,
        ),
        'Pagada',
      );
    });

    test('paid + loading â†’ "Pagada Â· verificando atenciÃ³n"', () {
      expect(
        AppointmentHistoryRules.statusLabel(
          'paid',
          HistoryVerificationState.loading,
        ),
        'Pagada \u00b7 verificando atenci\u00f3n',
      );
    });

    test('paid + failure â†’ "Pagada Â· verificaciÃ³n pendiente"', () {
      expect(
        AppointmentHistoryRules.statusLabel(
          'paid',
          HistoryVerificationState.failure,
        ),
        'Pagada \u00b7 verificaci\u00f3n pendiente',
      );
    });

    test('awaiting_payment â†’ "Pendiente de cobro"', () {
      expect(
        AppointmentHistoryRules.statusLabel(
          'awaiting_payment',
          HistoryVerificationState.successNotAttended,
        ),
        'Pendiente de cobro',
      );
    });
  });

  group('Visual styles â€” historical variant', () {
    test('historical style is winePremium', () {
      expect(AppointmentHistoryRules.historicalVariant,
          HistoricalVariant.winePremium);
    });

    test('winePremium exact colours', () {
      final s = AppointmentHistoryRules.historicalStyle;
      expect(s.bg.toARGB32(), 0xFF6D2335);
      expect(s.text.toARGB32(), 0xFFFFFFFF);
      expect(s.accent.toARGB32(), 0xFF481722);
    });

    test('intenseOrange exact colours', () {
      final s = HistoricalStyle.of(HistoricalVariant.intenseOrange);
      expect(s.bg.toARGB32(), 0xFFFF8A00);
      expect(s.text.toARGB32(), 0xFF111111);
      expect(s.accent.toARGB32(), 0xFFB85E00);
    });

    test('elegantBlack exact colours', () {
      final s = HistoricalStyle.of(HistoricalVariant.elegantBlack);
      expect(s.bg.toARGB32(), 0xFF111111);
      expect(s.text.toARGB32(), 0xFFFFFFFF);
      expect(s.accent.toARGB32(), 0xFF3A3A3A);
    });

    test('historicalGray exact colours', () {
      final s = HistoricalStyle.of(HistoricalVariant.historicalGray);
      expect(s.bg.toARGB32(), 0xFFE8E5DE);
      expect(s.text.toARGB32(), 0xFF333333);
      expect(s.accent.toARGB32(), 0xFF8C8478);
    });
  });

  group('Visual styles â€” operational (not historical)', () {
    test('awaiting_payment bg is NOT intenseOrange bg', () {
      final op = AppointmentHistoryRules.cardBg(
        'awaiting_payment',
        HistoryVerificationState.successNotAttended,
      );
      final hist = HistoricalStyle.of(HistoricalVariant.intenseOrange).bg;
      // awaiting_payment uses awaitingPaymentBg (#FFF3E0), not intenseOrange
      expect(op, isNot(hist));
    });

    test('paid + failure bg is NOT elegantBlack bg', () {
      final op = AppointmentHistoryRules.cardBg(
        'paid',
        HistoryVerificationState.failure,
      );
      final hist = HistoricalStyle.of(HistoricalVariant.elegantBlack).bg;
      expect(op, isNot(hist));
    });

    test('paid + loading bg is NOT any historical variant', () {
      final op = AppointmentHistoryRules.cardBg(
        'paid',
        HistoryVerificationState.loading,
      );
      for (final v in HistoricalVariant.values) {
        expect(op, isNot(HistoricalStyle.of(v).bg));
      }
    });
  });
}
