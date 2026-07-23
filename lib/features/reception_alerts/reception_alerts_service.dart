import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bookings/booking_time_utils.dart';
import 'reception_alert.dart';

/// Acceso a la tabla `reception_alerts`: lectura, realtime y marcado de estado.
/// La escritura de alertas la hacen las Edge Functions (service_role) vía el RPC
/// `log_reception_alert`; aquí recepción solo lee y actualiza el estado.
class ReceptionAlertsService {
  const ReceptionAlertsService();

  SupabaseClient get _client => Supabase.instance.client;

  /// Fecha de hoy (YYYY-MM-DD) en horario comercial de Tijuana/Ensenada.
  /// Sirve para ocultar alertas de citas que ya pasaron.
  static String todayPeninsula({DateTime? nowUtc}) {
    return BookingTimeUtils.tijuanaDateStringFromUtc(
      nowUtc ?? DateTime.now().toUtc(),
    );
  }

  static bool shouldKeepAlert(ReceptionAlert alert, {required DateTime today}) {
    if (alert.isResolved) {
      return false;
    }
    final bookingDate = alert.bookingDate;
    if (bookingDate == null) {
      return true;
    }
    return !BookingTimeUtils.dateOnly(
      bookingDate,
    ).isBefore(BookingTimeUtils.dateOnly(today));
  }

  static List<ReceptionAlert> normalizeAlertList(
    Iterable<ReceptionAlert> alerts, {
    required DateTime today,
  }) {
    final byId = <String, ReceptionAlert>{};
    for (final alert in alerts) {
      if (!shouldKeepAlert(alert, today: today)) {
        continue;
      }
      final existing = byId[alert.id];
      if (existing == null || existing.createdAt.isBefore(alert.createdAt)) {
        byId[alert.id] = alert;
      }
    }
    final list = byId.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Solo alertas vigentes para el widget de recepción:
  /// - se excluyen las ya atendidas (`status = 'resolved'`);
  /// - se excluyen las de citas pasadas (`booking_date` anterior a hoy);
  ///   las alertas sin `booking_date` se conservan (no se puede saber si caducaron).
  Future<List<ReceptionAlert>> fetchRecent({int limit = 50}) async {
    final today = todayPeninsula();
    final rows = await _client
        .from('reception_alerts')
        .select()
        .neq('status', 'resolved')
        .or('booking_date.gte.$today,booking_date.is.null')
        .order('created_at', ascending: false)
        .limit(limit);
    final alerts = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ReceptionAlert.fromMap)
        .toList();
    return normalizeAlertList(
      alerts,
      today: DateTime.parse(today),
    ).take(limit).toList();
  }

  Future<int> fetchUnseenCount() async {
    final today = todayPeninsula();
    final rows = await _client
        .from('reception_alerts')
        .select('id')
        .eq('status', 'unseen')
        .or('booking_date.gte.$today,booking_date.is.null');
    return (rows as List).length;
  }

  RealtimeChannel subscribe({
    required String channelName,
    required VoidCallback onChanged,
    void Function(ReceptionAlert alert)? onInserted,
  }) {
    return _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reception_alerts',
          callback: (payload) {
            onChanged();
            if (onInserted != null) {
              try {
                final alert = ReceptionAlert.fromMap(payload.newRecord);
                if (shouldKeepAlert(
                  alert,
                  today: DateTime.parse(todayPeninsula()),
                )) {
                  onInserted(alert);
                }
              } catch (_) {}
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'reception_alerts',
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> markSeen(String id) async {
    await _client
        .from('reception_alerts')
        .update({
          'status': 'seen',
          'seen_at': DateTime.now().toUtc().toIso8601String(),
          'seen_by': _client.auth.currentUser?.id,
        })
        .eq('id', id)
        .eq('status', 'unseen');
  }

  Future<void> markResolved(String id) async {
    await _client
        .from('reception_alerts')
        .update({
          'status': 'resolved',
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          'resolved_by': _client.auth.currentUser?.id,
        })
        .eq('id', id);
  }

  Future<void> markAllSeen() async {
    await _client
        .from('reception_alerts')
        .update({
          'status': 'seen',
          'seen_at': DateTime.now().toUtc().toIso8601String(),
          'seen_by': _client.auth.currentUser?.id,
        })
        .eq('status', 'unseen');
  }
}
