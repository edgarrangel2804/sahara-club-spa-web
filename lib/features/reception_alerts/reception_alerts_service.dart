import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reception_alert.dart';

/// Acceso a la tabla `reception_alerts`: lectura, realtime y marcado de estado.
/// La escritura de alertas la hacen las Edge Functions (service_role) vía el RPC
/// `log_reception_alert`; aquí recepción solo lee y actualiza el estado.
class ReceptionAlertsService {
  const ReceptionAlertsService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<ReceptionAlert>> fetchRecent({int limit = 50}) async {
    // La campana solo muestra notificaciones PENDIENTES (unseen/seen) y de los
    // últimos 20 días. Las atendidas ('resolved') se ocultan al instante; las
    // de más de 20 días no se muestran (y un job en la BD las borra por hora).
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 20))
        .toIso8601String();
    final rows = await _client
        .from('reception_alerts')
        .select()
        .neq('status', 'resolved')
        .gte('created_at', cutoff)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ReceptionAlert.fromMap)
        .toList();
  }

  Future<int> fetchUnseenCount() async {
    final rows = await _client
        .from('reception_alerts')
        .select('id')
        .eq('status', 'unseen');
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
                onInserted(ReceptionAlert.fromMap(payload.newRecord));
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
