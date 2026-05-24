import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/sahara_theme.dart';

class WhatsAppQueueDashboard extends StatefulWidget {
  const WhatsAppQueueDashboard({super.key});

  @override
  State<WhatsAppQueueDashboard> createState() => _WhatsAppQueueDashboardState();
}

class _Metrics {
  final int sent, delivered, read, failed, retry, queueSize, deadLetter, stuck;
  final num? deliveryRate, readRate, successRate, avgDelivSec;
  final DateTime? lastWorker;

  _Metrics({
    required this.sent, required this.delivered, required this.read,
    required this.failed, required this.retry, required this.queueSize,
    required this.deadLetter, required this.stuck,
    required this.deliveryRate, required this.readRate, required this.successRate,
    required this.avgDelivSec, required this.lastWorker,
  });

  factory _Metrics.fromMap(Map<String, dynamic> m) => _Metrics(
        sent: (m['sent_count'] as num?)?.toInt() ?? 0,
        delivered: (m['delivered_count'] as num?)?.toInt() ?? 0,
        read: (m['read_count'] as num?)?.toInt() ?? 0,
        failed: (m['failed_count'] as num?)?.toInt() ?? 0,
        retry: (m['retry_count'] as num?)?.toInt() ?? 0,
        queueSize: (m['queue_size'] as num?)?.toInt() ?? 0,
        deadLetter: (m['dead_letter_size'] as num?)?.toInt() ?? 0,
        stuck: (m['stuck_jobs'] as num?)?.toInt() ?? 0,
        deliveryRate: m['delivery_rate_pct'] as num?,
        readRate: m['read_rate_pct'] as num?,
        successRate: m['success_rate_pct'] as num?,
        avgDelivSec: m['avg_delivery_seconds'] as num?,
        lastWorker: m['last_worker_run_at'] == null
            ? null : DateTime.tryParse(m['last_worker_run_at'] as String),
      );
}

class _QueueRow {
  final String id, status, eventType;
  final String? metaTemplateName, errorMessage, deadLetterReason, customerName, customerPhone;
  final int retryCount;
  final int? lastErrorCode;
  final DateTime? scheduledAt, lastAttemptAt;

  _QueueRow({
    required this.id, required this.status, required this.eventType,
    required this.metaTemplateName, required this.errorMessage, required this.deadLetterReason,
    required this.customerName, required this.customerPhone,
    required this.retryCount, required this.lastErrorCode,
    required this.scheduledAt, required this.lastAttemptAt,
  });

  factory _QueueRow.fromMap(Map<String, dynamic> m) => _QueueRow(
        id: m['id'] as String,
        status: (m['status'] as String?) ?? 'queued',
        eventType: (m['event_type'] as String?) ?? '',
        metaTemplateName: m['meta_template_name'] as String?,
        errorMessage: m['error_message'] as String?,
        deadLetterReason: m['dead_letter_reason'] as String?,
        customerName: m['customer_name'] as String?,
        customerPhone: m['customer_phone'] as String?,
        retryCount: (m['retry_count'] as num?)?.toInt() ?? 0,
        lastErrorCode: (m['last_error_code'] as num?)?.toInt(),
        scheduledAt: m['scheduled_at'] == null
            ? null : DateTime.tryParse(m['scheduled_at'] as String),
        lastAttemptAt: m['last_attempt_at'] == null
            ? null : DateTime.tryParse(m['last_attempt_at'] as String),
      );
}

class _WhatsAppQueueDashboardState extends State<WhatsAppQueueDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  _Metrics? _metrics;
  List<_QueueRow> _rows = [];
  String _statusFilter = 'all';
  String? _flash;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final supa = Supabase.instance.client;
      final m = await supa
          .from('whatsapp_metrics_24h').select().maybeSingle();
      if (m != null) _metrics = _Metrics.fromMap(Map<String, dynamic>.from(m));
      var q = supa.from('whatsapp_queue_dashboard').select();
      if (_statusFilter != 'all') q = q.eq('status', _statusFilter);
      final data = await q
          .order('priority', ascending: true)
          .order('scheduled_at', ascending: false)
          .limit(200);
      _rows = (data as List)
          .map((e) => _QueueRow.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      _flash = 'Error: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invoke(String action, {String? id, Map<String, dynamic>? extra}) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'whatsapp_admin_actions',
        body: {'action': action, if (id != null) 'id': id, ...?extra},
      );
      _flash = (res.data is Map && (res.data as Map)['ok'] == true)
          ? '✓ $action OK'
          : '✗ $action: ${res.data}';
      await _load();
    } catch (e) {
      _flash = 'Error $action: $e';
      if (mounted) setState(() {});
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'sent':
      case 'delivered':
      case 'read':
      case 'processed':
        return const Color(0xFF1A9E65);
      case 'processing':
        return const Color(0xFF2D6DB3);
      case 'retrying':
      case 'pending':
      case 'queued':
        return const Color(0xFFC68A17);
      case 'failed':
      case 'dead_letter':
        return const Color(0xFFB32D2D);
      case 'cancelled':
      case 'skipped':
        return Colors.black45;
      default:
        return Colors.black54;
    }
  }

  Widget _kpi(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: color ?? SaharaTheme.grisCarbon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsBlock() {
    final m = _metrics;
    if (m == null) return const SizedBox.shrink();
    return GridView.count(
      crossAxisCount: 4, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.9,
      children: [
        _kpi('Enviados (24h)', '${m.sent}', color: const Color(0xFF1A9E65)),
        _kpi('Entregados', '${m.delivered}'),
        _kpi('Leídos', '${m.read}'),
        _kpi('Fallidos', '${m.failed}', color: const Color(0xFFB32D2D)),
        _kpi('Delivery rate', '${m.deliveryRate?.toStringAsFixed(1) ?? '—'}%'),
        _kpi('Read rate', '${m.readRate?.toStringAsFixed(1) ?? '—'}%'),
        _kpi('En cola', '${m.queueSize}', color: const Color(0xFFC68A17)),
        _kpi('Dead-letter', '${m.deadLetter}',
            color: m.deadLetter > 0 ? const Color(0xFFB32D2D) : null),
        _kpi('Stuck jobs (>5m)', '${m.stuck}',
            color: m.stuck > 0 ? const Color(0xFFB32D2D) : null),
        _kpi(
          'Avg delivery',
          m.avgDelivSec == null ? '—' : '${m.avgDelivSec!.toStringAsFixed(1)} s',
        ),
        _kpi(
          'Último worker',
          m.lastWorker == null
              ? '—'
              : '${DateTime.now().difference(m.lastWorker!).inSeconds}s ago',
          color: m.lastWorker != null &&
                  DateTime.now().difference(m.lastWorker!).inSeconds > 180
              ? const Color(0xFFB32D2D) : null,
        ),
      ],
    );
  }

  Widget _filters() {
    final opts = ['all','queued','retrying','processing','sent','dead_letter','failed','cancelled'];
    return Wrap(
      spacing: 6,
      children: opts.map((o) {
        final sel = _statusFilter == o;
        return ChoiceChip(
          label: Text(o),
          selected: sel,
          onSelected: (_) {
            setState(() => _statusFilter = o);
            _load();
          },
        );
      }).toList(),
    );
  }

  Widget _queueRowTile(_QueueRow r) {
    final color = _statusColor(r.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  r.status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w800, color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${r.eventType} · ${r.metaTemplateName ?? "—"}',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (r.retryCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('↻${r.retryCount}',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
                ),
              if (r.status == 'dead_letter' || r.status == 'failed')
                IconButton(
                  tooltip: 'Reintentar',
                  icon: const Icon(Icons.replay, size: 18),
                  onPressed: () => _invoke('requeue', id: r.id),
                ),
              if (['queued','retrying','dead_letter'].contains(r.status))
                IconButton(
                  tooltip: 'Cancelar',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _invoke('cancel', id: r.id),
                ),
            ],
          ),
          if (r.customerName != null || r.customerPhone != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${r.customerName ?? ""} · ${r.customerPhone ?? ""}',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
              ),
            ),
          if (r.lastErrorCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Meta error code=${r.lastErrorCode}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB32D2D)),
              ),
            ),
          if (r.deadLetterReason != null && r.deadLetterReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                r.deadLetterReason!,
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB32D2D)),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            )
          else if (r.errorMessage != null && r.errorMessage!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                r.errorMessage!,
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB32D2D)),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),
          if (r.scheduledAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Programado: ${r.scheduledAt}',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.black45),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'WhatsApp Queue & Logs',
              style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: SaharaTheme.grisCarbon,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refrescar',
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
            TextButton.icon(
              icon: const Icon(Icons.cleaning_services_outlined, size: 16),
              label: const Text('Limpieza'),
              onPressed: () => _invoke('cleanup'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar dead-letter'),
              onPressed: () => _invoke('bulk_requeue_dead_letter'),
            ),
          ],
        ),
        if (_flash != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F1E7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_flash!, style: GoogleFonts.inter(fontSize: 12)),
          ),
        ],
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          _metricsBlock(),
          const SizedBox(height: 16),
          _filters(),
          const SizedBox(height: 8),
          ..._rows.map(_queueRowTile),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Sin elementos para este filtro.',
                style: GoogleFonts.inter(color: Colors.black54),
              ),
            ),
        ],
      ],
    );
  }
}
