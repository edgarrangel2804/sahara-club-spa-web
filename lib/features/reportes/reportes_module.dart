import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────
class ReportesModule extends StatefulWidget {
  const ReportesModule({super.key});

  @override
  State<ReportesModule> createState() => _ReportesModuleState();
}

class _ReportesModuleState extends State<ReportesModule> {
  bool _loading = true;

  // Stats
  int    _totalBookings    = 0;
  int    _attendedBookings = 0;
  int    _cancelledBookings = 0;
  double _totalRevenue     = 0;
  double _revenueThisMonth = 0;

  // Service ranking
  List<Map<String, dynamic>> _topServices = [];

  // Therapist ranking
  List<Map<String, dynamic>> _topTherapists = [];

  // Daily revenue (last 14 days)
  List<_DayRevenue> _dailyRevenue = [];

  // Period
  String _period = '30'; // '7', '30', '90'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final daysAgo = int.parse(_period);
      final since   = DateTime.now().subtract(Duration(days: daysAgo));
      final sinceStr = since.toIso8601String().substring(0, 10);

      late final List results;
      try {
        results = await Future.wait([
          Supabase.instance.client
              .from('bookings')
              .select('id, status, service_name, therapist_name, booking_date')
              .gte('booking_date', sinceStr),
          Supabase.instance.client
              .from('sales')
              .select('id, total, created_at, status, payment_status')
              .gte('created_at', since.toIso8601String()),
        ]);
      } catch (_) {
        results = await Future.wait([
          Supabase.instance.client
              .from('bookings')
              .select('id, status, service_name, therapist_name, booking_date')
              .gte('booking_date', sinceStr),
          Supabase.instance.client
              .from('sales')
              .select('id, total, created_at, status')
              .gte('created_at', since.toIso8601String()),
        ]);
      }

      final bookings = (results[0] as List)
          .map((m) => m as Map<String, dynamic>)
          .toList();
      final sales = (results[1] as List)
          .map((m) => m as Map<String, dynamic>)
          .toList();
      final paidSales = sales.where((sale) {
        final paymentStatus = (sale['payment_status'] as String?)?.toLowerCase();
        final legacyStatus = (sale['status'] as String?)?.toLowerCase();
        return paymentStatus == 'paid' || legacyStatus == 'paid';
      }).toList();

      // ── Booking stats ────────────────────────────────────────
      _totalBookings     = bookings.length;
      _attendedBookings  = bookings.where((b) =>
          (b['status'] as String?) == 'attended' ||
          (b['status'] as String?) == 'completed' ||
          (b['status'] as String?) == 'awaiting_payment' ||
          (b['status'] as String?) == 'paid').length;
      _cancelledBookings = bookings.where((b) =>
          (b['status'] as String?) == 'cancelled' ||
          (b['status'] as String?) == 'no_show').length;

      // ── Revenue ───────────────────────────────────────────────
      _totalRevenue = paidSales.fold(0, (sum, s) =>
          sum + ((s['total'] as num?)?.toDouble() ?? 0));

      final now = DateTime.now();
      _revenueThisMonth = paidSales
          .where((s) {
            final d = DateTime.tryParse((s['created_at'] as String?) ?? '');
            return d != null && d.month == now.month && d.year == now.year;
          })
          .fold(0, (sum, s) => sum + ((s['total'] as num?)?.toDouble() ?? 0));

      // ── Top services ──────────────────────────────────────────
      final svcCount = <String, int>{};
      for (final b in bookings) {
        final svc = (b['service_name'] as String?) ?? 'Sin servicio';
        svcCount[svc] = (svcCount[svc] ?? 0) + 1;
      }
      _topServices = svcCount.entries
          .map((e) => {'name': e.key, 'count': e.value})
          .toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      if (_topServices.length > 6) _topServices = _topServices.sublist(0, 6);

      // ── Top therapists ────────────────────────────────────────
      final thCount = <String, int>{};
      for (final b in bookings) {
        final th = (b['therapist_name'] as String?) ?? 'Sin terapeuta';
        thCount[th] = (thCount[th] ?? 0) + 1;
      }
      _topTherapists = thCount.entries
          .map((e) => {'name': e.key, 'count': e.value})
          .toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      if (_topTherapists.length > 5) _topTherapists = _topTherapists.sublist(0, 5);

      // ── Daily revenue (last 14 days) ──────────────────────────
      final dailyMap = <String, double>{};
      final today = DateTime.now();
      final days  = daysAgo.clamp(1, 30);
      for (var i = days - 1; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        dailyMap['${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}'] = 0;
      }
      for (final s in paidSales) {
        final raw = (s['created_at'] as String?) ?? '';
        if (raw.length >= 10) {
          final key = raw.substring(0, 10);
          dailyMap[key] = (dailyMap[key] ?? 0) + ((s['total'] as num?)?.toDouble() ?? 0);
        }
      }
      _dailyRevenue = dailyMap.entries
          .map((e) => _DayRevenue(day: e.key, amount: e.value))
          .toList();

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Top bar ────────────────────────────────────────────
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: Row(
            children: [
              Text('Reportes',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20, fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                )),
              const Spacer(),
              ...['7', '30', '90'].map((p) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _PeriodChip(
                  label:    p == '7' ? '7 días' : p == '30' ? '30 días' : '90 días',
                  selected: _period == p,
                  onTap:    () { setState(() => _period = p); _load(); },
                ),
              )),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh_outlined, size: 18),
                onPressed: _load,
                tooltip: 'Actualizar',
              ),
            ],
          ),
        ),

        // ── Content ────────────────────────────────────────────
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI row
                    Row(children: [
                      _KpiCard(
                        label: 'RESERVAS',
                        value: '$_totalBookings',
                        sub:   'en los últimos $_period días',
                        icon:  Icons.calendar_today_outlined,
                        color: const Color(0xFF5B8FF9),
                      ),
                      const SizedBox(width: 14),
                      _KpiCard(
                        label: 'ASISTENCIA',
                        value: _totalBookings > 0
                            ? '${(_attendedBookings / _totalBookings * 100).toStringAsFixed(0)}%'
                            : '–',
                        sub:   '$_attendedBookings asistieron',
                        icon:  Icons.check_circle_outline,
                        color: const Color(0xFF52C41A),
                      ),
                      const SizedBox(width: 14),
                      _KpiCard(
                        label: 'NO ASISTIERON',
                        value: '$_cancelledBookings',
                        sub:   'cancelados + no-shows',
                        icon:  Icons.cancel_outlined,
                        color: const Color(0xFFFF4444),
                      ),
                      const SizedBox(width: 14),
                      _KpiCard(
                        label: 'INGRESOS (${_period}d)',
                        value: '\$${_fmtNum(_totalRevenue)}',
                        sub:   'Este mes: \$${_fmtNum(_revenueThisMonth)}',
                        icon:  Icons.attach_money_outlined,
                        color: const Color(0xFFC6A76A),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Revenue chart
                        Expanded(
                          flex: 3,
                          child: _SectionCard(
                            title: 'INGRESOS POR DÍA',
                            child: _RevenueChart(data: _dailyRevenue),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Top services
                        Expanded(
                          flex: 2,
                          child: _SectionCard(
                            title: 'SERVICIOS MÁS SOLICITADOS',
                            child: _topServices.isEmpty
                              ? _noData()
                              : _RankList(
                                  items: _topServices,
                                  maxCount: _topServices.isEmpty ? 1
                                      : (_topServices.first['count'] as int),
                                  color: const Color(0xFFC6A76A),
                                ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top therapists
                        Expanded(
                          child: _SectionCard(
                            title: 'TERAPEUTAS CON MÁS RESERVAS',
                            child: _topTherapists.isEmpty
                              ? _noData()
                              : _RankList(
                                  items: _topTherapists,
                                  maxCount: _topTherapists.isEmpty ? 1
                                      : (_topTherapists.first['count'] as int),
                                  color: const Color(0xFF5B8FF9),
                                ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Attendance breakdown
                        Expanded(
                          child: _SectionCard(
                            title: 'RESUMEN DE ASISTENCIA',
                            child: _AttendanceChart(
                              attended:  _attendedBookings,
                              cancelled: _cancelledBookings,
                              total:     _totalBookings,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  Widget _noData() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Center(child: Text('Sin datos en este período',
      style: GoogleFonts.inter(fontSize: 13, color: Colors.black38))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Revenue bar chart (pure widgets, no dependency)
// ─────────────────────────────────────────────────────────────────────────────
class _DayRevenue {
  final String day;
  final double amount;
  const _DayRevenue({required this.day, required this.amount});
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.data});
  final List<_DayRevenue> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('Sin ventas registradas',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.black38))),
      );
    }
    final maxVal = data.fold(0.0, (m, d) => d.amount > m ? d.amount : m);
    final show = data.length > 14 ? data.sublist(data.length - 14) : data;
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: show.map((d) {
          final ratio = maxVal > 0 ? d.amount / maxVal : 0.0;
          final label = d.day.length >= 10 ? d.day.substring(5) : d.day;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (d.amount > 0)
                    Text('\$${_fmtNum(d.amount)}',
                      style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFC6A76A))),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: (ratio * 100).clamp(2.0, 100.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6A76A).withValues(alpha: d.amount > 0 ? 0.8 : 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(label,
                    style: GoogleFonts.inter(fontSize: 9, color: Colors.black38),
                    overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rank list (services / therapists)
// ─────────────────────────────────────────────────────────────────────────────
class _RankList extends StatelessWidget {
  const _RankList({required this.items, required this.maxCount, required this.color});
  final List<Map<String, dynamic>> items;
  final int   maxCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final name  = item['name'] as String;
        final count = item['count'] as int;
        final ratio = maxCount > 0 ? count / maxCount : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(name,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                  overflow: TextOverflow.ellipsis)),
                Text('$count', style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: Colors.black54)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: color.withValues(alpha: 0.1),
                  color: color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance donut-style chart
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceChart extends StatelessWidget {
  const _AttendanceChart({
    required this.attended,
    required this.cancelled,
    required this.total,
  });
  final int attended, cancelled, total;

  @override
  Widget build(BuildContext context) {
    final pending = total - attended - cancelled;
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('Sin reservas en este período',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.black38))),
      );
    }
    return Column(
      children: [
        _AttRow('Asistieron',      attended,  const Color(0xFF52C41A), total),
        _AttRow('No asistieron',   cancelled, const Color(0xFFFF4444), total),
        _AttRow('Otros / pendiente', pending, const Color(0xFFFFB347), total),
      ],
    );
  }
}

class _AttRow extends StatelessWidget {
  const _AttRow(this.label, this.count, this.color, this.total);
  final String label;
  final int count, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(label,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black54))),
          Text('$count  (${(pct * 100).toStringAsFixed(0)}%)',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.1),
            color: color,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });
  final String   label, value, sub;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(
                fontSize: 10, letterSpacing: 1.2,
                color: Colors.black38, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A))),
              Text(sub, style: GoogleFonts.inter(fontSize: 11, color: Colors.black38)),
            ],
          )),
        ]),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: GoogleFonts.inter(
              fontSize: 11, letterSpacing: 1.4,
              color: Colors.black38, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool   selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC6A76A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 12,
          color: selected ? Colors.white : Colors.black54,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }
}

String _fmtNum(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}
