import 'package:flutter/material.dart';

// â”€â”€ Verification state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// Models the result of checking whether a paid booking was actually attended.
enum HistoryVerificationState {
  /// Query is still in flight.
  loading,

  /// Query succeeded â€” the booking passed through completed or awaiting_payment.
  successAttended,

  /// Query succeeded â€” the booking never reached a terminal attended status.
  successNotAttended,

  /// Query failed (RLS, network, timeout). Cannot determine attendance.
  failure,
}

// â”€â”€ Historical visual variants (for "Atendida y cobrada") â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// The four approved visual variants for the historical (attended + paid) state.
/// Only ONE is active at a time, controlled by [AppointmentHistoryRules.historicalStyle].
enum HistoricalVariant {
  winePremium,
  intenseOrange,
  elegantBlack,
  historicalGray,
}

/// Holds the colour triple for a historical visual variant.
class HistoricalStyle {
  const HistoricalStyle(this.bg, this.text, this.accent);
  final Color bg;
  final Color text;
  final Color accent;

  static const _winePremium = HistoricalStyle(
    Color(0xFF6D2335),
    Color(0xFFFFFFFF),
    Color(0xFF481722),
  );
  static const _intenseOrange = HistoricalStyle(
    Color(0xFFFF8A00),
    Color(0xFF111111),
    Color(0xFFB85E00),
  );
  static const _elegantBlack = HistoricalStyle(
    Color(0xFF111111),
    Color(0xFFFFFFFF),
    Color(0xFF3A3A3A),
  );
  static const _historicalGray = HistoricalStyle(
    Color(0xFFE8E5DE),
    Color(0xFF333333),
    Color(0xFF8C8478),
  );

  static const Map<HistoricalVariant, HistoricalStyle> _map = {
    HistoricalVariant.winePremium: _winePremium,
    HistoricalVariant.intenseOrange: _intenseOrange,
    HistoricalVariant.elegantBlack: _elegantBlack,
    HistoricalVariant.historicalGray: _historicalGray,
  };

  static HistoricalStyle of(HistoricalVariant v) => _map[v]!;
}

// â”€â”€ Operational styles (not historical variants) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// Colours for the "Pendiente de cobro" state (awaiting_payment).
const awaitingPaymentBg = Color(0xFFFFF3E0);
const awaitingPaymentAccent = Color(0xFFB85E00);

/// Colours for paid bookings whose history verification failed or is loading.
const unverifiedPaidBg = Color(0xFFEDEAE3);
const unverifiedPaidAccent = Color(0xFF7A7A7A);

/// Colours for paid bookings without attendance (successNotAttended).
const paidNotAttendedBg = Color(0xFFEDEAE3);
const paidNotAttendedAccent = Color(0xFFC68A17); // gold-ish

// â”€â”€ Central rules â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// Single source of truth for all appointment-history business rules.
///
/// Agenda consumes these rules through [_Booking] getters. Tests import
/// this file directly so they verify the same logic used in production.
class AppointmentHistoryRules {
  const AppointmentHistoryRules._();

  // â”€â”€ Active variant (change here to switch historical style) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const HistoricalVariant historicalVariant =
      HistoricalVariant.winePremium;

  static HistoricalStyle get historicalStyle =>
      HistoricalStyle.of(historicalVariant);

  // â”€â”€ Attendance proof â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// Statuses that prove the service was finished (not merely started).
  static const Set<String> attendedTerminalStatuses = {
    'completed',
    'awaiting_payment',
  };

  /// True when [status] proves service completion.
  static bool isAttendedStatus(String status) =>
      attendedTerminalStatuses.contains(status);

  // â”€â”€ Historical rule â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static bool isHistoricalAttendedAndPaid(
    String status,
    HistoryVerificationState verification,
  ) {
    return status == 'paid' &&
        verification == HistoryVerificationState.successAttended;
  }

  // â”€â”€ Lock rule â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static bool isInteractionLocked(
    String status,
    HistoryVerificationState verification,
  ) {
    if (status == 'cancelled' || status == 'no_show') return true;
    if (status != 'paid') return false;
    // Paid bookings: locked if attended, loading, or failed.
    // Only successNotAttended leaves them unlocked (payment without service).
    return verification != HistoryVerificationState.successNotAttended;
  }

  // â”€â”€ Labels â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static String statusLabel(
    String status,
    HistoryVerificationState verification,
  ) {
    if (isHistoricalAttendedAndPaid(status, verification)) {
      return 'Atendida y cobrada';
    }
    switch (status) {
      case 'awaiting_payment':
        return 'Pendiente de cobro';
      case 'paid':
        switch (verification) {
          case HistoryVerificationState.loading:
            return 'Pagada \u00b7 verificando atenci\u00f3n';
          case HistoryVerificationState.failure:
            return 'Pagada \u00b7 verificaci\u00f3n pendiente';
          case HistoryVerificationState.successNotAttended:
          case HistoryVerificationState.successAttended:
            return 'Pagada';
        }
      case 'completed':
        return 'Finalizada';
      case 'cancelled':
        return 'Cancelada';
      case 'no_show':
        return 'No asistio';
      default:
        return status;
    }
  }

  // â”€â”€ Visual styles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Color cardBg(String status, HistoryVerificationState verification) {
    if (isHistoricalAttendedAndPaid(status, verification)) {
      return historicalStyle.bg;
    }
    switch (status) {
      case 'awaiting_payment':
        return awaitingPaymentBg;
      case 'paid':
        switch (verification) {
          case HistoryVerificationState.loading:
          case HistoryVerificationState.failure:
            return unverifiedPaidBg;
          case HistoryVerificationState.successNotAttended:
            return paidNotAttendedBg;
          case HistoryVerificationState.successAttended:
            return historicalStyle.bg; // already handled above
        }
      default:
        return const Color(0xFFEDEAE3); // arena Sahara default
    }
  }

  static Color cardAccent(String status, HistoryVerificationState verification) {
    if (isHistoricalAttendedAndPaid(status, verification)) {
      return historicalStyle.accent;
    }
    switch (status) {
      case 'awaiting_payment':
        return awaitingPaymentAccent;
      case 'paid':
        switch (verification) {
          case HistoryVerificationState.loading:
          case HistoryVerificationState.failure:
            return unverifiedPaidAccent;
          case HistoryVerificationState.successNotAttended:
            return paidNotAttendedAccent;
          case HistoryVerificationState.successAttended:
            return historicalStyle.accent; // already handled above
        }
      default:
        return const Color(0xFFC68A17); // gold default
    }
  }
}
