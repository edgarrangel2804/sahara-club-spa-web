import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/sahara_theme.dart';

// ── UUID helper ───────────────────────────────────────────────────────────────
String _genUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int n) => n.toRadixString(16).padLeft(2, '0');
  return '${h(b[0])}${h(b[1])}${h(b[2])}${h(b[3])}-'
      '${h(b[4])}${h(b[5])}-${h(b[6])}${h(b[7])}-'
      '${h(b[8])}${h(b[9])}-'
      '${h(b[10])}${h(b[11])}${h(b[12])}${h(b[13])}${h(b[14])}${h(b[15])}';
}

// ── Models ────────────────────────────────────────────────────────────────────
class _SaleItem {
  final String id;
  String name;
  double price;
  int    quantity    = 1;
  double discountPct = 0;

  _SaleItem({
    String? id,
    required this.name,
    required this.price,
  }) : id = id ?? _genUuid();

  double get subtotal => price * quantity * (1 - discountPct / 100);
}

class _Sale {
  final String  id;
  final String  clientId;
  final String  clientName;
  final double  total;
  final String  paymentMethod;
  final String  status;
  final String  notes;
  final DateTime createdAt;
  final List<Map<String, dynamic>> items;

  const _Sale({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.notes,
    required this.createdAt,
    this.items = const [],
  });

  factory _Sale.fromMap(Map<String, dynamic> m) => _Sale(
    id:            m['id']             as String,
    clientId:      m['client_id']      as String? ?? '',
    clientName:    (m['client'] as Map?)?['full_name'] as String? ?? 'Sin cliente',
    total:         (m['total'] as num?)?.toDouble() ?? 0,
    paymentMethod: m['payment_method'] as String? ?? 'efectivo',
    status:        m['status']         as String? ?? 'paid',
    notes:         m['notes']          as String? ?? '',
    createdAt:     m['created_at'] != null
        ? DateTime.parse(m['created_at'] as String)
        : DateTime.now(),
    items:         (m['sale_items'] as List?)?.cast<Map<String, dynamic>>() ?? [],
  );
}

// ── Constants ─────────────────────────────────────────────────────────────────
const _kMethods = [
  ('efectivo',      'Efectivo',      Icons.payments_outlined),
  ('tarjeta',       'Tarjeta',       Icons.credit_card_outlined),
  ('transferencia', 'Transferencia', Icons.account_balance_outlined),
  ('qr',            'QR / App',      Icons.qr_code_outlined),
];

const _kStatusMeta = {
  'paid':      ('Pagado',    Color(0xFF52C41A)),
  'pending':   ('Pendiente', Color(0xFFFFB347)),
  'cancelled': ('Cancelado', Color(0xFFB32D2D)),
};

// ─────────────────────────────────────────────────────────────────────────────
// SalesModule  (entry point)
// ─────────────────────────────────────────────────────────────────────────────
class SalesModule extends StatefulWidget {
  const SalesModule({super.key});

  @override
  State<SalesModule> createState() => _SalesModuleState();
}

class _SalesModuleState extends State<SalesModule> {
  List<_Sale> _sales   = [];
  bool        _loading = true;
  String      _search  = '';
  String      _filter  = 'all'; // 'today' | 'week' | 'month' | 'all'
  _Sale?      _detail;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('sales')
          .select('''
            id, client_id, total, payment_method, status, notes, created_at,
            client:profiles!sales_client_id_fkey(full_name),
            sale_items(id, name, price, quantity, discount_pct)
          ''')
          .order('created_at', ascending: false)
          .limit(200) as List;
      if (!mounted) return;
      setState(() {
        _sales   = data.map((m) => _Sale.fromMap(m as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('loadSales: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Sale> get _filtered {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var list    = _sales;

    // Date filter
    if (_filter == 'today') {
      list = list.where((s) => s.createdAt.isAfter(today)).toList();
    } else if (_filter == 'week') {
      final weekAgo = today.subtract(const Duration(days: 7));
      list = list.where((s) => s.createdAt.isAfter(weekAgo)).toList();
    } else if (_filter == 'month') {
      final monthStart = DateTime(now.year, now.month, 1);
      list = list.where((s) => s.createdAt.isAfter(monthStart)).toList();
    }

    // Text search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((s) =>
          s.clientName.toLowerCase().contains(q) ||
          s.paymentMethod.contains(q)).toList();
    }
    return list;
  }

  // ── Stats helpers ──────────────────────────────────────────────────────────
  double _sumFor(DateTime from) => _sales
      .where((s) => s.createdAt.isAfter(from) && s.status == 'paid')
      .fold(0.0, (acc, s) => acc + s.total);

  @override
  Widget build(BuildContext context) {
    final now        = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart  = todayStart.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    final todayTotal = _sumFor(todayStart);
    final weekTotal  = _sumFor(weekStart);
    final monthTotal = _sumFor(monthStart);
    final todayCount = _sales
        .where((s) => s.createdAt.isAfter(todayStart) && s.status == 'paid')
        .length;

    return Container(
      color: const Color(0xFFF5F3EF),
      child: Column(
        children: [
          // ── Top toolbar ──────────────────────────────────────────────────
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE0DDD8))),
            ),
            child: Row(children: [
              Text('Ventas',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(width: 24),
              // Period chips
              ..._kPeriods.map((p) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _PeriodChip(
                  label:   p.$2,
                  active:  _filter == p.$1,
                  onTap:   () => setState(() { _filter = p.$1; _detail = null; }),
                ),
              )),
              const Spacer(),
              // Search
              SizedBox(
                width: 220,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText:   'Buscar…',
                    hintStyle:  GoogleFonts.inter(
                        color: Colors.black38, fontSize: 12),
                    prefixIcon: const Icon(Icons.search,
                        size: 15, color: Colors.black38),
                    isDense:    true,
                    filled:     true,
                    fillColor:  const Color(0xFFF5F3EF),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                          color: Color(0xFFE0DDD8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                          color: SaharaTheme.gold, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openNewSale(context),
                style: FilledButton.styleFrom(
                  backgroundColor: SaharaTheme.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 15),
                label: Text('Nueva Venta',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

          // ── Stats bar ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(children: [
              _StatCard(
                label: 'Hoy',
                value: '\$${_fmt(todayTotal)}',
                sub:   '$todayCount venta${todayCount == 1 ? '' : 's'}',
                color: SaharaTheme.gold,
                icon:  Icons.today_outlined,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Esta semana',
                value: '\$${_fmt(weekTotal)}',
                color: const Color(0xFF5B8FF9),
                icon:  Icons.view_week_outlined,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Este mes',
                value: '\$${_fmt(monthTotal)}',
                color: const Color(0xFF52C41A),
                icon:  Icons.calendar_month_outlined,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Total ventas',
                value: '${_filtered.length}',
                sub:   _filter == 'today' ? 'hoy'
                    : _filter == 'week'   ? 'últimos 7 días'
                    : _filter == 'month'  ? 'este mes'
                    : 'todos',
                color: const Color(0xFFB37FEB),
                icon:  Icons.receipt_long_outlined,
              ),
            ]),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sales list
                Expanded(
                  flex: _detail != null ? 5 : 1,
                  child: Container(
                    margin: const EdgeInsets.only(left: 24, right: 12, bottom: 24),
                    decoration: BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: const Color(0xFFECECEC)),
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(
                            color: SaharaTheme.gold))
                        : _filtered.isEmpty
                            ? _EmptyState(
                                icon:  Icons.receipt_long_outlined,
                                title: 'Sin ventas',
                                sub:   'Registra la primera venta con el botón "Nueva Venta"',
                                onAction: () => _openNewSale(context),
                                actionLabel: 'Nueva Venta',
                              )
                            : _SalesList(
                                sales:    _filtered,
                                selected: _detail,
                                onTap: (s) =>
                                    setState(() => _detail = _detail?.id == s.id ? null : s),
                              ),
                  ),
                ),
                // Detail panel
                if (_detail != null)
                  SizedBox(
                    width: 340,
                    child: Container(
                      margin: const EdgeInsets.only(right: 24, bottom: 24),
                      decoration: BoxDecoration(
                        color:        Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:       Border.all(color: const Color(0xFFECECEC)),
                      ),
                      child: _SaleDetail(
                        sale:      _detail!,
                        onClose:   () => setState(() => _detail = null),
                        onDeleted: () {
                          setState(() => _detail = null);
                          _loadSales();
                        },
                        onStatusChanged: () => _loadSales(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openNewSale(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _NewSaleDialog(
        onSaved: () { Navigator.pop(ctx); _loadSales(); },
      ),
    );
  }
}

const _kPeriods = [
  ('today', 'Hoy'),
  ('week',  'Semana'),
  ('month', 'Mes'),
  ('all',   'Todos'),
];

String _fmt(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

String _fmtFull(double v) {
  final parts = v.toStringAsFixed(0).split('').reversed.toList();
  final withDots = <String>[];
  for (int i = 0; i < parts.length; i++) {
    if (i > 0 && i % 3 == 0) withDots.add('.');
    withDots.add(parts[i]);
  }
  return withDots.reversed.join();
}

String _fmtDate(DateTime d) {
  const m = ['ene','feb','mar','abr','may','jun',
              'jul','ago','sep','oct','nov','dic'];
  return '${d.day} ${m[d.month - 1]}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Sales list table
// ─────────────────────────────────────────────────────────────────────────────
class _SalesList extends StatelessWidget {
  const _SalesList({
    required this.sales,
    required this.selected,
    required this.onTap,
  });
  final List<_Sale>           sales;
  final _Sale?                selected;
  final ValueChanged<_Sale>   onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF0EDE8))),
          ),
          child: Row(children: [
            _Th('FECHA',    flex: 2),
            _Th('CLIENTE',  flex: 3),
            _Th('MÉTODO',   flex: 2),
            _Th('ESTADO',   flex: 2),
            _Th('TOTAL',    flex: 2, right: true),
          ]),
        ),
        // Rows
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: sales.length,
            itemBuilder: (_, i) {
              final s = sales[i];
              final sel = selected?.id == s.id;
              final statusMeta = _kStatusMeta[s.status] ??
                  const ('—', Color(0xFF888888));
              final methodIcon = _kMethods
                  .firstWhere((m) => m.$1 == s.paymentMethod,
                      orElse: () => _kMethods[0])
                  .$3;

              return InkWell(
                onTap: () => onTap(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? SaharaTheme.gold.withValues(alpha: 0.06)
                        : Colors.transparent,
                    border: Border(
                      left:   BorderSide(
                        color: sel ? SaharaTheme.gold : Colors.transparent,
                        width: 3,
                      ),
                      bottom: const BorderSide(color: Color(0xFFF5F3EF)),
                    ),
                  ),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text(
                      _fmtDate(s.createdAt),
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.black54),
                    )),
                    Expanded(flex: 3, child: Text(
                      s.clientName,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    )),
                    Expanded(flex: 2, child: Row(children: [
                      Icon(methodIcon, size: 13, color: Colors.black38),
                      const SizedBox(width: 5),
                      Flexible(child: Text(
                        _kMethods.firstWhere(
                            (m) => m.$1 == s.paymentMethod,
                            orElse: () => _kMethods[0]).$2,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ])),
                    Expanded(flex: 2, child: _StatusChip(
                      label: statusMeta.$1,
                      color: statusMeta.$2,
                    )),
                    Expanded(flex: 2, child: Text(
                      '\$${_fmtFull(s.total)}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    )),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sale Detail panel
// ─────────────────────────────────────────────────────────────────────────────
class _SaleDetail extends StatelessWidget {
  const _SaleDetail({
    required this.sale,
    required this.onClose,
    required this.onDeleted,
    required this.onStatusChanged,
  });
  final _Sale           sale;
  final VoidCallback    onClose;
  final VoidCallback    onDeleted;
  final VoidCallback    onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final statusMeta =
        _kStatusMeta[sale.status] ?? const ('—', Color(0xFF888888));
    final methodInfo = _kMethods.firstWhere(
        (m) => m.$1 == sale.paymentMethod,
        orElse: () => _kMethods[0]);

    return Column(
      children: [
        // Header
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFECECEC))),
          ),
          child: Row(children: [
            Text('Detalle de venta',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.black38),
              onPressed: onClose,
            ),
          ]),
        ),
        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client + status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sale.clientName,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        const SizedBox(height: 3),
                        Text(_fmtDate(sale.createdAt),
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.black38)),
                      ],
                    )),
                    _StatusChip(
                        label: statusMeta.$1,
                        color: statusMeta.$2),
                  ],
                ),
                const SizedBox(height: 12),

                // Payment method
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFF5F3EF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    Icon(methodInfo.$3, size: 15, color: Colors.black45),
                    const SizedBox(width: 8),
                    Text(methodInfo.$2,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.black54)),
                  ]),
                ),
                const SizedBox(height: 16),

                // Items
                if (sale.items.isNotEmpty) ...[
                  Text('Servicios / Productos',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.black38,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  ...sale.items.map((item) {
                    final price   = (item['price'] as num?)?.toDouble() ?? 0;
                    final qty     = (item['quantity'] as int?) ?? 1;
                    final disc    = (item['discount_pct'] as num?)?.toDouble() ?? 0;
                    final sub     = price * qty * (1 - disc / 100);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 4, height: 32,
                          decoration: BoxDecoration(
                            color: SaharaTheme.gold.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'] as String? ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87)),
                            Text('$qty × \$${_fmtFull(price)}'
                                '${disc > 0 ? '  −${disc.toStringAsFixed(0)}%' : ''}',
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: Colors.black38)),
                          ],
                        )),
                        Text('\$${_fmtFull(sub)}',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                      ]),
                    );
                  }),
                  const Divider(color: Color(0xFFECECEC)),
                ],

                // Total
                Row(children: [
                  Text('TOTAL',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black45,
                          letterSpacing: 1)),
                  const Spacer(),
                  Text('\$${_fmtFull(sale.total)}',
                      style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                ]),

                if (sale.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFF5F3EF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(sale.notes,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.black54)),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Footer actions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFECECEC))),
          ),
          child: Row(children: [
            if (sale.status != 'cancelled')
              OutlinedButton(
                onPressed: () => _changeStatus(context, 'cancelled'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('Cancelar',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            const Spacer(),
            if (sale.status == 'pending')
              FilledButton.icon(
                onPressed: () => _changeStatus(context, 'paid'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF52C41A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.check, size: 14),
                label: Text('Marcar pagado',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ],
    );
  }

  Future<void> _changeStatus(BuildContext ctx, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('sales')
          .update({'status': newStatus})
          .eq('id', sale.id);
      onStatusChanged();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New Sale Dialog  (POS)
// ─────────────────────────────────────────────────────────────────────────────
class _NewSaleDialog extends StatefulWidget {
  const _NewSaleDialog({required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<_NewSaleDialog> createState() => _NewSaleDialogState();
}

class _NewSaleDialogState extends State<_NewSaleDialog> {
  final _clientCtrl  = TextEditingController();
  final _clientFocus = FocusNode();
  final _notesCtrl   = TextEditingController();

  String?            _clientId;
  String             _paymentMethod = 'efectivo';
  String             _status        = 'paid';
  bool               _saving        = false;
  final List<_SaleItem> _items       = [];
  List<Map<String, dynamic>> _services = [];
  double _globalDiscount = 0;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _items.add(_SaleItem(name: '', price: 0));
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _clientFocus.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final data = await Supabase.instance.client
          .from('services')
          .select('id, name, duration, price')
          .order('name') as List;
      if (mounted) setState(() => _services = data.cast());
    } catch (_) {}
  }

  Future<Iterable<Map<String, dynamic>>> _searchClients(TextEditingValue v) async {
    final q = v.text.trim();
    if (q.length < 2) return const [];
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email')
          .eq('role', 'client')
          .ilike('full_name', '%$q%')
          .order('full_name')
          .limit(8) as List;
      return data.cast<Map<String, dynamic>>();
    } catch (_) { return const []; }
  }

  double get _subtotal => _items.fold(0, (acc, i) => acc + i.subtotal);
  double get _discount => _subtotal * _globalDiscount / 100;
  double get _total    => _subtotal - _discount;

  Future<void> _save() async {
    if (_items.every((i) => i.name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un servicio o producto.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // Resolve client
      String? finalClientId = _clientId;
      if (finalClientId == null && _clientCtrl.text.trim().isNotEmpty) {
        final q = await Supabase.instance.client
            .from('profiles').select('id')
            .eq('full_name', _clientCtrl.text.trim())
            .eq('role', 'client').maybeSingle();
        finalClientId = q?['id'] as String?;
      }

      final saleId = _genUuid();
      await Supabase.instance.client.from('sales').insert({
        'id':             saleId,
        'client_id':      finalClientId,
        'total':          _total,
        'payment_method': _paymentMethod,
        'status':         _status,
        'notes':          _notesCtrl.text.trim(),
      });

      // Insert items
      final validItems = _items.where((i) => i.name.isNotEmpty).toList();
      if (validItems.isNotEmpty) {
        await Supabase.instance.client.from('sale_items').insert(
          validItems.map((i) => {
            'id':           _genUuid(),
            'sale_id':      saleId,
            'name':         i.name,
            'price':        i.price,
            'quantity':     i.quantity,
            'discount_pct': i.discountPct,
          }).toList(),
        );
      }

      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade100,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF5F3EF),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(
                    bottom: BorderSide(color: Color(0xFFECE9E4))),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 18, color: Colors.black45),
                const SizedBox(width: 10),
                Text('Nueva Venta',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const Spacer(),
                // Status badge
                _MethodBadge(
                  label:     _status == 'paid' ? 'Pagado' : 'Pendiente',
                  color:     _status == 'paid'
                      ? const Color(0xFF52C41A)
                      : const Color(0xFFFFB347),
                  onToggle:  () => setState(() =>
                      _status = _status == 'paid' ? 'pending' : 'paid'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: Colors.black38),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            // Body — two-column layout
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Left: items ────────────────────────────────────────
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Client
                          _SectionCard(title: 'Cliente', children: [
                            RawAutocomplete<Map<String, dynamic>>(
                              textEditingController: _clientCtrl,
                              focusNode:             _clientFocus,
                              optionsBuilder:        _searchClients,
                              displayStringForOption: (o) =>
                                  o['full_name'] as String? ?? '',
                              onSelected: (o) => setState(
                                  () => _clientId = o['id'] as String),
                              fieldViewBuilder: (_, ctrl, focus, onSub) =>
                                  TextField(
                                controller: ctrl,
                                focusNode:  focus,
                                onChanged:  (_) {
                                  if (_clientId != null) {
                                    setState(() => _clientId = null);
                                  }
                                },
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: Colors.black87),
                                decoration: _deco('Buscar cliente…',
                                    Icons.search_outlined),
                              ),
                              optionsViewBuilder: (ctx, onSel, opts) => Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation:    6,
                                  borderRadius: BorderRadius.circular(8),
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      padding:    EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount:  opts.length,
                                      itemBuilder: (_, i) {
                                        final o = opts.elementAt(i);
                                        return InkWell(
                                          onTap: () => onSel(o),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 10),
                                            child: Text(
                                              o['full_name'] as String? ?? '',
                                              style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: Colors.black87),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ]),

                          const SizedBox(height: 12),

                          // Items
                          _SectionCard(title: 'Servicios / Productos', children: [
                            ..._items.asMap().entries.map((entry) {
                              final idx  = entry.key;
                              final item = entry.value;
                              return _ItemRow(
                                item:      item,
                                services:  _services,
                                onRemove:  _items.length > 1
                                    ? () => setState(() => _items.removeAt(idx))
                                    : null,
                                onChange: setState,
                              );
                            }),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => setState(() =>
                                  _items.add(_SaleItem(name: '', price: 0))),
                              style: TextButton.styleFrom(
                                  foregroundColor: SaharaTheme.gold),
                              icon: const Icon(Icons.add, size: 15),
                              label: Text('Agregar ítem',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),

                          const SizedBox(height: 12),

                          // Notes
                          _SectionCard(title: 'Notas (opcional)', children: [
                            TextField(
                              controller: _notesCtrl,
                              maxLines:   2,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.black87),
                              decoration: _deco(
                                  'Observaciones internas…', null),
                            ),
                          ]),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // ── Right: payment + summary ───────────────────────────
                    SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Payment method
                          _SectionCard(title: 'Método de pago', children: [
                            ..._kMethods.map((m) => InkWell(
                              onTap: () =>
                                  setState(() => _paymentMethod = m.$1),
                              borderRadius: BorderRadius.circular(6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _paymentMethod == m.$1
                                      ? SaharaTheme.gold
                                          .withValues(alpha: 0.10)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: _paymentMethod == m.$1
                                        ? SaharaTheme.gold
                                        : const Color(0xFFDDD9D3),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(children: [
                                  Icon(m.$3,
                                      size: 16,
                                      color: _paymentMethod == m.$1
                                          ? SaharaTheme.gold
                                          : Colors.black38),
                                  const SizedBox(width: 10),
                                  Text(m.$2,
                                      style: GoogleFonts.inter(
                                        fontSize:   13,
                                        color: _paymentMethod == m.$1
                                            ? SaharaTheme.gold
                                            : Colors.black54,
                                        fontWeight: _paymentMethod == m.$1
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      )),
                                  const Spacer(),
                                  if (_paymentMethod == m.$1)
                                    Icon(Icons.check_circle,
                                        size: 14, color: SaharaTheme.gold),
                                ]),
                              ),
                            )),
                          ]),

                          const SizedBox(height: 12),

                          // Summary
                          _SectionCard(title: 'Resumen', children: [
                            _SummaryRow('Subtotal',
                                '\$${_fmtFull(_subtotal)}'),
                            const SizedBox(height: 6),
                            // Global discount
                            Row(children: [
                              Text('Descuento',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: Colors.black54)),
                              const Spacer(),
                              SizedBox(
                                width: 64,
                                child: TextField(
                                  textAlign: TextAlign.right,
                                  keyboardType:
                                      TextInputType.number,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.black87),
                                  decoration: InputDecoration(
                                    hintText:    '0',
                                    hintStyle:   GoogleFonts.inter(
                                        color: Colors.black38,
                                        fontSize: 12),
                                    suffixText:  '%',
                                    isDense:     true,
                                    filled:      true,
                                    fillColor:   const Color(0xFFF5F3EF),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFDDD9D3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      borderSide: BorderSide(
                                          color: SaharaTheme.gold,
                                          width: 1.5),
                                    ),
                                  ),
                                  onChanged: (v) => setState(() =>
                                    _globalDiscount =
                                        double.tryParse(v) ?? 0),
                                ),
                              ),
                            ]),
                            if (_globalDiscount > 0) ...[
                              const SizedBox(height: 4),
                              _SummaryRow('− Descuento',
                                  '−\$${_fmtFull(_discount)}',
                                  color: Colors.red),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                  height: 1, color: Color(0xFFECECEC)),
                            ),
                            Row(children: [
                              Text('TOTAL',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black45,
                                      letterSpacing: 1)),
                              const Spacer(),
                              Text('\$${_fmtFull(_total)}',
                                  style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87)),
                            ]),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border(
                    top: BorderSide(color: Color(0xFFECE9E4))),
              ),
              child: Row(children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.black54),
                  child: Text('Cancelar',
                      style: GoogleFonts.inter(fontSize: 13)),
                ),
                const Spacer(),
                Text('\$${_fmtFull(_total)}',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: SaharaTheme.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.check, size: 16),
                  label: Text('Guardar venta',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item Row  (inside the POS dialog)
// ─────────────────────────────────────────────────────────────────────────────
class _ItemRow extends StatefulWidget {
  const _ItemRow({
    required this.item,
    required this.services,
    required this.onChange,
    this.onRemove,
  });
  final _SaleItem                  item;
  final List<Map<String, dynamic>> services;
  final void Function(void Function()) onChange;
  final VoidCallback?              onRemove;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final _nameCtrl  = TextEditingController(text: widget.item.name);
  late final _priceCtrl = TextEditingController(
      text: widget.item.price > 0 ? widget.item.price.toStringAsFixed(0) : '');
  late final _qtyCtrl   = TextEditingController(
      text: widget.item.quantity.toString());
  bool _showServices = false;
  String _search = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.services.where((s) {
      if (_search.isEmpty) return true;
      return (s['name'] as String? ?? '')
          .toLowerCase()
          .contains(_search.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Name
            Expanded(
              flex: 3,
              child: Stack(children: [
                TextField(
                  controller:  _nameCtrl,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.black87),
                  decoration: _deco('Nombre del ítem…', null),
                  onChanged: (v) {
                    widget.onChange(() => widget.item.name = v);
                    setState(() => _showServices = v.length >= 2);
                    _search = v;
                  },
                  onTap: () =>
                      setState(() => _showServices = _nameCtrl.text.length >= 2),
                ),
                if (_showServices && filtered.isNotEmpty)
                  Positioned(
                    top: 42, left: 0, right: 0,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView.builder(
                          padding:    EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount:  filtered.length,
                          itemBuilder: (_, i) {
                            final s = filtered[i];
                            return InkWell(
                              onTap: () {
                                final price = (s['price'] as num?)
                                        ?.toDouble() ?? 0;
                                widget.onChange(() {
                                  widget.item.name  = s['name'] as String? ?? '';
                                  widget.item.price = price;
                                });
                                _nameCtrl.text  = widget.item.name;
                                _priceCtrl.text = price.toStringAsFixed(0);
                                setState(() {
                                  _showServices = false;
                                  _search = '';
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                child: Row(children: [
                                  Expanded(child: Text(
                                    s['name'] as String? ?? '',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.black87),
                                  )),
                                  Text(
                                    '\$${_fmtFull((s['price'] as num?)?.toDouble() ?? 0)}',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.black45),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 6),
            // Price
            SizedBox(
              width: 88,
              child: TextField(
                controller:   _priceCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.black87),
                textAlign: TextAlign.right,
                decoration: _deco('\$0', null).copyWith(
                  prefixText:  '\$',
                  prefixStyle: GoogleFonts.inter(
                      fontSize: 12, color: Colors.black38),
                ),
                onChanged: (v) => widget.onChange(
                    () => widget.item.price =
                        double.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 6),
            // Qty
            SizedBox(
              width: 52,
              child: TextField(
                controller:   _qtyCtrl,
                keyboardType:  TextInputType.number,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.black87),
                textAlign: TextAlign.center,
                decoration: _deco('1', null),
                onChanged: (v) => widget.onChange(
                    () => widget.item.quantity =
                        int.tryParse(v) ?? 1),
              ),
            ),
            const SizedBox(width: 6),
            // Remove
            if (widget.onRemove != null)
              InkWell(
                onTap: widget.onRemove,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 15, color: Colors.black38),
                ),
              )
            else
              const SizedBox(width: 27),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.sub,
  });
  final String   label;
  final String   value;
  final Color    color;
  final IconData icon;
  final String?  sub;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(
                fontSize: 10, color: Colors.black38, letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: Colors.black87)),
            if (sub != null)
              Text(sub!, style: GoogleFonts.inter(
                  fontSize: 10, color: Colors.black38)),
          ],
        )),
      ]),
    ),
  );
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String       label;
  final bool         active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        active
            ? SaharaTheme.gold.withValues(alpha: 0.12)
            : Colors.transparent,
        border:       Border.all(
            color: active ? SaharaTheme.gold : Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
            color:      active ? SaharaTheme.gold : Colors.black54,
            fontSize:   11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          )),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label,
        style: GoogleFonts.inter(
            fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({
    required this.label,
    required this.color,
    required this.onToggle,
  });
  final String       label;
  final Color        color;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, color: color,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down, size: 14, color: color),
      ]),
    ),
  );
}

class _Th extends StatelessWidget {
  const _Th(this.label, {this.flex = 1, this.right = false});
  final String label;
  final int    flex;
  final bool   right;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(label,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: GoogleFonts.inter(
          fontSize:   10,
          fontWeight: FontWeight.w700,
          color:      Colors.black38,
          letterSpacing: 0.8,
        )),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String         title;
  final List<Widget>   children;

  @override
  Widget build(BuildContext context) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: const Color(0xFFECE9E4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: GoogleFonts.inter(
        fontSize: 12, color: Colors.black54)),
    const Spacer(),
    Text(value, style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? Colors.black87)),
  ]);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onAction,
    required this.actionLabel,
  });
  final IconData     icon;
  final String       title;
  final String       sub;
  final VoidCallback onAction;
  final String       actionLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color:  SaharaTheme.gold.withValues(alpha: 0.08),
            shape:  BoxShape.circle,
            border: Border.all(
                color: SaharaTheme.gold.withValues(alpha: 0.25),
                width: 1.5),
          ),
          child: Icon(icon, color: SaharaTheme.gold, size: 28),
        ),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600,
            color: Colors.black87)),
        const SizedBox(height: 6),
        Text(sub, style: GoogleFonts.inter(
            fontSize: 12, color: Colors.black38),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAction,
          style: FilledButton.styleFrom(
            backgroundColor: SaharaTheme.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.add, size: 16),
          label: Text(actionLabel,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

InputDecoration _deco(String hint, IconData? prefix) => InputDecoration(
  hintText:   hint,
  hintStyle:  GoogleFonts.inter(color: Colors.black38, fontSize: 13),
  isDense:    true,
  filled:     true,
  fillColor:  Colors.white,
  prefixIcon: prefix != null
      ? Icon(prefix, size: 15, color: Colors.black38)
      : null,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: Color(0xFFDDD9D3)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide(color: SaharaTheme.gold, width: 1.5),
  ),
);
