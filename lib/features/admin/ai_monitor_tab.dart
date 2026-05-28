import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/sahara_theme.dart';

/// Vista de monitoreo en vivo de la operación IA / WhatsApp.
/// Resume lo que está pasando hoy en producción: conversaciones, citas creadas
/// por IA, pendientes de asignar y últimas interacciones.
class AiMonitorTab extends StatefulWidget {
  const AiMonitorTab({super.key});

  @override
  State<AiMonitorTab> createState() => _AiMonitorTabState();
}

class _AiMonitorTabState extends State<AiMonitorTab> {
  bool _loading = true;
  String? _error;
  Timer? _autoRefresh;

  int _conversationsToday = 0;
  int _messagesToday = 0;
  int _bookingsToday = 0;
  int _pendingAssign = 0;
  int _pendingReception = 0;
  double _costToday = 0;

  List<_RecentBooking> _recentBookings = [];
  List<_RecentConversation> _recentConvs = [];

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  String _todayKeyTj() {
    final tjNow = DateTime.now().toUtc().subtract(const Duration(hours: 7));
    return tjNow.toIso8601String().split('T').first;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = _recentBookings.isEmpty && _recentConvs.isEmpty;
      _error = null;
    });
    try {
      final sb = Supabase.instance.client;
      final today = _todayKeyTj();
      final dayStartIso = '${today}T00:00:00-07:00';
      final dayEndIso = '${today}T23:59:59-07:00';

      final results = await Future.wait<dynamic>([
        sb
            .from('ai_conversations')
            .select('id, customer_phone, last_message_at, total_cost_usd, message_count, status')
            .gte('last_message_at', dayStartIso)
            .lte('last_message_at', dayEndIso),
        sb
            .from('ai_messages')
            .select('id')
            .gte('created_at', dayStartIso)
            .lte('created_at', dayEndIso),
        sb
            .from('bookings')
            .select('''
              id,
              client_record_id,
              booking_date,
              booking_time,
              duration_min,
              status,
              therapist_id,
              booking_source,
              created_at,
              created_by_ai,
              service:services(name),
              client_record:clients(full_name, phone)
            ''')
            .eq('booking_date', today)
            .order('booking_time', ascending: true),
        sb
            .from('ai_conversations')
            .select('id, customer_phone, last_message_at, message_count, status, total_cost_usd')
            .order('last_message_at', ascending: false)
            .limit(10),
      ]);

      final convsToday =
          List<Map<String, dynamic>>.from(results[0] as List);
      final msgsToday = (results[1] as List).length;
      final bookingsToday =
          List<Map<String, dynamic>>.from(results[2] as List);
      final recentConvs =
          List<Map<String, dynamic>>.from(results[3] as List);

      final costToday = convsToday.fold<double>(
        0,
        (s, c) => s + ((c['total_cost_usd'] as num?)?.toDouble() ?? 0),
      );

      final aiBookings = bookingsToday
          .where((b) =>
              b['created_by_ai'] == true ||
              b['booking_source']?.toString() == 'whatsapp_ai')
          .toList();

      final pendingAssign = bookingsToday
          .where((b) =>
              (b['therapist_id'] == null ||
                  b['therapist_id'].toString().isEmpty) &&
              !{'cancelled', 'no_show', 'completed'}
                  .contains(b['status']?.toString()))
          .length;

      final pendingReception = bookingsToday
          .where((b) =>
              b['status']?.toString() == 'pending_reception' ||
              b['status']?.toString() == 'pending_payment')
          .length;

      final recentBookings = aiBookings.take(10).map((b) {
        final svc = b['service'] as Map?;
        final client = b['client_record'] as Map?;
        return _RecentBooking(
          id: b['id'] as String? ?? '',
          clientName: client?['full_name'] as String? ?? 'Cliente',
          phone: client?['phone'] as String? ?? '',
          serviceName: svc?['name'] as String? ?? 'Servicio',
          time: b['booking_time']?.toString().substring(0, 5) ?? '',
          status: b['status']?.toString() ?? '',
          unassigned: b['therapist_id'] == null ||
              b['therapist_id'].toString().isEmpty,
        );
      }).toList();

      final convs = recentConvs.map((c) {
        return _RecentConversation(
          id: c['id'] as String? ?? '',
          phone: c['customer_phone'] as String? ?? '',
          lastAt: DateTime.tryParse(c['last_message_at']?.toString() ?? ''),
          msgCount: (c['message_count'] as num?)?.toInt() ?? 0,
          status: c['status']?.toString() ?? '',
          costUsd: (c['total_cost_usd'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _conversationsToday = convsToday.length;
        _messagesToday = msgsToday;
        _bookingsToday = aiBookings.length;
        _pendingAssign = pendingAssign;
        _pendingReception = pendingReception;
        _costToday = costToday;
        _recentBookings = recentBookings;
        _recentConvs = convs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Error cargando monitor: $_error',
            style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Monitor IA · hoy',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A2E1F),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refrescar',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Se actualiza automáticamente cada 30 s.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            _KpiGrid(items: [
              _KpiItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Conversaciones',
                value: '$_conversationsToday',
                hint: '$_messagesToday mensajes',
              ),
              _KpiItem(
                icon: Icons.event_available_rounded,
                label: 'Citas creadas IA',
                value: '$_bookingsToday',
              ),
              _KpiItem(
                icon: Icons.person_off_outlined,
                label: 'Sin terapeuta',
                value: '$_pendingAssign',
                accent: _pendingAssign > 0
                    ? const Color(0xFFD9A23B)
                    : null,
              ),
              _KpiItem(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Pendientes recepción',
                value: '$_pendingReception',
                accent: _pendingReception > 0
                    ? const Color(0xFF5C8CC9)
                    : null,
              ),
              _KpiItem(
                icon: Icons.attach_money_rounded,
                label: 'Costo IA hoy',
                value: '\$${_costToday.toStringAsFixed(2)} USD',
              ),
            ]),
            const SizedBox(height: 28),
            _SectionTitle(
              icon: Icons.event_note_outlined,
              title: 'Últimas citas creadas por IA',
            ),
            const SizedBox(height: 8),
            _recentBookings.isEmpty
                ? _EmptyState(
                    icon: Icons.spa_outlined,
                    message: 'Sin citas creadas por la IA hoy.',
                  )
                : Column(
                    children: _recentBookings
                        .map((b) => _BookingRow(booking: b))
                        .toList(),
                  ),
            const SizedBox(height: 28),
            _SectionTitle(
              icon: Icons.forum_outlined,
              title: 'Últimas conversaciones',
            ),
            const SizedBox(height: 8),
            _recentConvs.isEmpty
                ? _EmptyState(
                    icon: Icons.inbox_outlined,
                    message: 'Sin conversaciones registradas todavía.',
                  )
                : Column(
                    children:
                        _recentConvs.map((c) => _ConvRow(conv: c)).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class _RecentBooking {
  _RecentBooking({
    required this.id,
    required this.clientName,
    required this.phone,
    required this.serviceName,
    required this.time,
    required this.status,
    required this.unassigned,
  });
  final String id;
  final String clientName;
  final String phone;
  final String serviceName;
  final String time;
  final String status;
  final bool unassigned;
}

class _RecentConversation {
  _RecentConversation({
    required this.id,
    required this.phone,
    required this.lastAt,
    required this.msgCount,
    required this.status,
    required this.costUsd,
  });
  final String id;
  final String phone;
  final DateTime? lastAt;
  final int msgCount;
  final String status;
  final double costUsd;
}

// ─────────────────────────────────────────────────────────────────────────────
// UI Pieces
// ─────────────────────────────────────────────────────────────────────────────
class _KpiItem {
  _KpiItem({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final Color? accent;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});
  final List<_KpiItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final cross = c.maxWidth >= 1100
            ? 5
            : c.maxWidth >= 800
                ? 3
                : c.maxWidth >= 520
                    ? 2
                    : 1;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cross,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.4,
          children: items.map((it) => _KpiCard(item: it)).toList(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});
  final _KpiItem item;

  @override
  Widget build(BuildContext context) {
    final accent = item.accent ?? SaharaTheme.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E4D8)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 20, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.hint != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    item.hint!,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: Colors.black45,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: SaharaTheme.gold),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF3A2E1F),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAE4D5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black38, size: 18),
          const SizedBox(width: 8),
          Text(
            message,
            style: GoogleFonts.inter(color: Colors.black54, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking});
  final _RecentBooking booking;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(booking.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAE4D5)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            alignment: Alignment.center,
            child: Text(
              booking.time,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A2E1F),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  booking.clientName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  booking.serviceName,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (booking.unassigned) ...[
            const SizedBox(width: 6),
            _StatusChip(
              label: 'Sin asignar',
              color: const Color(0xFFD9A23B),
            ),
          ],
          const SizedBox(width: 6),
          _StatusChip(label: _statusLabel(booking.status), color: statusColor),
        ],
      ),
    );
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'pending_reception':
        return 'Por validar';
      case 'pending_payment':
        return 'Anticipo';
      case 'confirmed':
        return 'Confirmada';
      case 'checked_in':
        return 'Llegó';
      case 'in_progress':
        return 'En curso';
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      case 'no_show':
        return 'No-show';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'confirmed':
      case 'checked_in':
      case 'in_progress':
      case 'completed':
        return const Color(0xFF5DAA6E);
      case 'pending_reception':
        return const Color(0xFF5C8CC9);
      case 'pending_payment':
        return const Color(0xFFD9A23B);
      case 'cancelled':
      case 'no_show':
        return const Color(0xFFC77878);
      default:
        return SaharaTheme.gold;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ConvRow extends StatelessWidget {
  const _ConvRow({required this.conv});
  final _RecentConversation conv;

  @override
  Widget build(BuildContext context) {
    final lastLabel = conv.lastAt == null ? '—' : _agoLabel(conv.lastAt!);
    final statusColor = conv.status == 'escalated_to_human'
        ? const Color(0xFFD9A23B)
        : conv.status == 'closed'
            ? Colors.black38
            : const Color(0xFF5DAA6E);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAE4D5)),
      ),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 16, color: SaharaTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  conv.phone,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${conv.msgCount} mensajes · \$${conv.costUsd.toStringAsFixed(3)} USD · $lastLabel',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(
            label: conv.status.isEmpty ? 'active' : conv.status,
            color: statusColor,
          ),
        ],
      ),
    );
  }

  static String _agoLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
