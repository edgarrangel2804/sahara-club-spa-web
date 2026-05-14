import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_mode.dart';
import '../../theme/sahara_theme.dart';

class FinanzasModule extends StatefulWidget {
  const FinanzasModule({super.key});

  @override
  State<FinanzasModule> createState() => _FinanzasModuleState();
}

class _FinanzasModuleState extends State<FinanzasModule>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 8, vsync: this);
  bool _loading = true;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _fixedExpenses = [];
  List<Map<String, dynamic>> _supplierExpenses = [];
  List<Map<String, dynamic>> _payrollEntries = [];
  List<Map<String, dynamic>> _staff = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _load() async {
    setState(() => _loading = true);
    final sales = await _loadSalesSafe();
    final bookings = await _loadBookingsSafe();
    final fixed = await _safeSelect('fixed_expenses');
    final supplier = await _safeSelect('supplier_expenses');
    final payroll = await _safeSelect('payroll_entries');
    final staff = await _safeSelect('staff');

    if (!mounted) return;
    setState(() {
      _sales = sales;
      _bookings = bookings;
      _fixedExpenses = fixed;
      _supplierExpenses = supplier;
      _payrollEntries = payroll;
      _staff = staff;
      _loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _loadSalesSafe() async {
    try {
      return await _loadSales();
    } catch (error) {
      debugPrint('finanzas _loadSalesSafe: $error');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadBookingsSafe() async {
    try {
      return await _loadBookings();
    } catch (error) {
      debugPrint('finanzas _loadBookingsSafe: $error');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadSales() async {
    try {
      final data = await _client.from('sales').select('''
        id,
        appointment_id,
        client_id,
        customer_id,
        total,
        payment_method,
        status,
        payment_status,
        sale_status,
        professional_id,
        created_at,
        sale_items(
          id,
          description,
          name,
          quantity,
          unit_price,
          price,
          total_price,
          service_id,
          product_id
        )
      ''').order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      final data = await _client.from('sales').select('''
        id,
        client_id,
        customer_id,
        total,
        payment_method,
        status,
        payment_status,
        sale_status,
        created_at,
        sale_items(id, name, quantity, price)
      ''').order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    }
  }

  Future<List<Map<String, dynamic>>> _loadBookings() async {
    final data = await _client.from('bookings').select('''
      id,
      status,
      booking_date,
      therapist_id,
      therapist:staff(full_name),
      service:services(name)
    ''').order('booking_date', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> _safeSelect(String table) async {
    try {
      final data = await _client.from(table).select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (error) {
      debugPrint('finanzas _safeSelect($table): $error');
      return [];
    }
  }

  bool _isPaidSale(Map<String, dynamic> sale) {
    final paymentStatus = (sale['payment_status'] as String?)?.toLowerCase();
    final legacyStatus = (sale['status'] as String?)?.toLowerCase();
    return paymentStatus == 'paid' || legacyStatus == 'paid';
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStart {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return start.subtract(Duration(days: start.weekday - 1));
  }

  DateTime get _monthStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  double _salesTotalSince(DateTime from) {
    return _sales.where((sale) {
      final date = _parseDate(sale['created_at']);
      return date != null && !date.isBefore(from) && _isPaidSale(sale);
    }).fold<double>(0, (sum, sale) => sum + _amount(sale['total']));
  }

  int _salesCountSince(DateTime from) {
    return _sales.where((sale) {
      final date = _parseDate(sale['created_at']);
      return date != null && !date.isBefore(from) && _isPaidSale(sale);
    }).length;
  }

  double _amount(dynamic value) => (value as num?)?.toDouble() ?? 0;

  double get _ingresosTotales => _sales
      .where(_isPaidSale)
      .fold<double>(0, (sum, sale) => sum + _amount(sale['total']));

  double get _egresosTotales {
    final fixed = _fixedExpenses
        .where((row) => (row['status'] as String?)?.toLowerCase() == 'pagado')
        .fold<double>(0, (sum, row) => sum + _amount(row['amount']));
    final supplier = _supplierExpenses
        .where((row) => (row['status'] as String?)?.toLowerCase() == 'pagado')
        .fold<double>(0, (sum, row) => sum + _amount(row['amount']));
    final payroll = _payrollEntries
        .where((row) => const ['pagado', 'parcial']
            .contains((row['payment_status'] as String?)?.toLowerCase()))
        .fold<double>(0, (sum, row) => sum + _amount(row['total_pay']));
    return fixed + supplier + payroll;
  }

  double get _ticketPromedio {
    final paidCount = _sales.where(_isPaidSale).length;
    if (paidCount == 0) return 0;
    return _ingresosTotales / paidCount;
  }

  int get _serviciosRealizados => _bookings.where((booking) {
        final status = (booking['status'] as String?)?.toLowerCase();
        return status == 'completed' || status == 'paid';
      }).length;

  int get _citasCompletadas => _bookings
      .where((booking) => (booking['status'] as String?)?.toLowerCase() == 'completed')
      .length;

  int get _citasPendientesCobro => _bookings
      .where((booking) =>
          (booking['status'] as String?)?.toLowerCase() == 'awaiting_payment')
      .length;

  Map<String, double> get _ventasPorMetodo {
    final map = <String, double>{};
    for (final sale in _sales.where(_isPaidSale)) {
      final method = (sale['payment_method'] as String?)?.trim();
      final key = method == null || method.isEmpty ? 'pendiente' : method;
      map[key] = (map[key] ?? 0) + _amount(sale['total']);
    }
    return map;
  }

  Map<String, double> get _ventasPorTipo {
    final map = <String, double>{
      'servicios': 0,
      'productos': 0,
      'membresias': 0,
      'gift_cards': 0,
    };
    for (final sale in _sales.where(_isPaidSale)) {
      final items = (sale['sale_items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      for (final item in items) {
        final label = ((item['description'] ?? item['name']) as String? ?? '')
            .toLowerCase();
        final total = _amount(item['total_price']) > 0
            ? _amount(item['total_price'])
            : _amount(item['unit_price']) > 0
                ? _amount(item['unit_price']) *
                    ((item['quantity'] as num?)?.toDouble() ?? 1)
                : _amount(item['price']) *
                    ((item['quantity'] as num?)?.toDouble() ?? 1);
        if (label.contains('gift')) {
          map['gift_cards'] = (map['gift_cards'] ?? 0) + total;
        } else if (label.contains('membres')) {
          map['membresias'] = (map['membresias'] ?? 0) + total;
        } else if (item['service_id'] != null) {
          map['servicios'] = (map['servicios'] ?? 0) + total;
        } else {
          map['productos'] = (map['productos'] ?? 0) + total;
        }
      }
    }
    return map;
  }

  Map<String, int> get _topServicios {
    final map = <String, int>{};
    for (final sale in _sales.where(_isPaidSale)) {
      final items = (sale['sale_items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      for (final item in items) {
        final label = ((item['description'] ?? item['name']) as String? ?? 'Sin concepto').trim();
        map[label] = (map[label] ?? 0) + ((item['quantity'] as num?)?.toInt() ?? 1);
      }
    }
    return map;
  }

  List<_TherapistPerformance> get _therapistPerformance {
    final byTherapist = <String, _TherapistPerformance>{};
    final saleByAppointment = <String, Map<String, dynamic>>{};

    for (final sale in _sales.where(_isPaidSale)) {
      final appointmentId = sale['appointment_id']?.toString();
      if (appointmentId != null && appointmentId.isNotEmpty) {
        saleByAppointment[appointmentId] = sale;
      }
    }

    for (final booking in _bookings) {
      final therapistId = booking['therapist_id']?.toString() ?? 'sin_terapeuta';
      final therapistName = (booking['therapist'] as Map?)?['full_name'] as String? ??
          'Sin terapeuta';
      final status = (booking['status'] as String?)?.toLowerCase() ?? '';
      final perf = byTherapist.putIfAbsent(
        therapistId,
        () => _TherapistPerformance(id: therapistId, name: therapistName),
      );

      if (status == 'completed' || status == 'paid') {
        perf.servicesCompleted += 1;
      }
      if (status == 'cancelled') {
        perf.cancelled += 1;
      }
      if (status == 'no_show') {
        perf.noShows += 1;
      }

      final linkedSale = saleByAppointment[booking['id']?.toString() ?? ''];
      if (linkedSale != null) {
        perf.revenue += _amount(linkedSale['total']);
      }
    }

    return byTherapist.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
  }

  Future<void> _openCreateDialog() async {
    if (_tab.index == 2) {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => const _FixedExpenseDialog(),
      );
      if (created == true) _load();
      return;
    }
    if (_tab.index == 3) {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => const _SupplierExpenseDialog(),
      );
      if (created == true) _load();
      return;
    }
    if (_tab.index == 4) {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => _PayrollDialog(staff: _staff),
      );
      if (created == true) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EF),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  'Finanzas',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: TabBar(
                    controller: _tab,
                    isScrollable: true,
                    labelColor: const Color(0xFFC6A76A),
                    unselectedLabelColor: Colors.black45,
                    indicatorColor: const Color(0xFFC6A76A),
                    tabs: const [
                      Tab(text: 'Resumen financiero'),
                      Tab(text: 'Ventas'),
                      Tab(text: 'Gastos fijos'),
                      Tab(text: 'Gastos proveedores'),
                      Tab(text: 'Nómina'),
                      Tab(text: 'Terapeutas / rendimiento'),
                      Tab(text: 'Comparativas'),
                      Tab(text: 'Reportes exportables'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedBuilder(
                  animation: _tab,
                  builder: (_, __) {
                    final canCreate = _tab.index == 2 || _tab.index == 3 || _tab.index == 4;
                    return Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Actualizar'),
                        ),
                        if (canCreate) ...[
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _openCreateDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              _tab.index == 2
                                  ? 'Nuevo gasto fijo'
                                  : _tab.index == 3
                                      ? 'Nuevo gasto proveedor'
                                      : 'Nuevo pago de nómina',
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : TabBarView(
                    controller: _tab,
                    children: [
                      _ResumenFinancieroTab(
                        ventasHoy: _salesTotalSince(_todayStart),
                        ventasSemana: _salesTotalSince(_weekStart),
                        ventasMes: _salesTotalSince(_monthStart),
                        ingresosTotales: _ingresosTotales,
                        egresosTotales: _egresosTotales,
                        gananciaNeta: _ingresosTotales - _egresosTotales,
                        ticketPromedio: _ticketPromedio,
                        serviciosRealizados: _serviciosRealizados,
                        citasCompletadas: _citasCompletadas,
                        citasPendientesCobro: _citasPendientesCobro,
                      ),
                      _VentasTab(
                        ventasHoy: _salesTotalSince(_todayStart),
                        ventasSemana: _salesTotalSince(_weekStart),
                        ventasMes: _salesTotalSince(_monthStart),
                        ventasPorMetodo: _ventasPorMetodo,
                        ventasPorTipo: _ventasPorTipo,
                        topServicios: _topServicios,
                        sales: _sales.where(_isPaidSale).toList(),
                      ),
                      _ExpensesListTab(
                        title: 'Gastos fijos',
                        emptyMessage: 'Todavía no has registrado gastos fijos.',
                        rows: _fixedExpenses,
                        valueKey: 'amount',
                        titleBuilder: (row) =>
                            row['description']?.toString().trim().isNotEmpty == true
                                ? row['description'].toString()
                                : (row['category']?.toString() ?? 'Gasto fijo'),
                        subtitleBuilder: (row) {
                          final negocio =
                              row['name']?.toString().trim().isNotEmpty == true
                                  ? row['name'].toString()
                                  : 'Sahara Club Spa';
                          final categoria =
                              row['category']?.toString().trim().isNotEmpty == true
                                  ? row['category'].toString()
                                  : 'Sin categoria';
                          final frecuencia =
                              row['frequency']?.toString().trim().isNotEmpty == true
                                  ? row['frequency'].toString()
                                  : 'Sin frecuencia';
                          final estado =
                              row['status']?.toString().trim().isNotEmpty == true
                                  ? row['status'].toString()
                                  : 'Pendiente';
                          return '$negocio - $categoria - $frecuencia - $estado';
                        },
                      ),
                      _ExpensesListTab(
                        title: 'Gastos de proveedor',
                        emptyMessage: 'Todavía no hay gastos de proveedor.',
                        rows: _supplierExpenses,
                        valueKey: 'amount',
                        titleBuilder: (row) =>
                            row['supplier_name']?.toString() ?? 'Proveedor',
                        subtitleBuilder: (row) =>
                            '${row['category'] ?? 'Sin categoría'} • ${row['description'] ?? ''}',
                      ),
                      _PayrollTab(rows: _payrollEntries, staff: _staff),
                      _TherapistsTab(rows: _therapistPerformance),
                      _ComparativasTab(
                        ventasHoy: _salesTotalSince(_todayStart),
                        ventasAyer: _salesTotalSince(_todayStart.subtract(const Duration(days: 1))) -
                            _salesTotalSince(_todayStart),
                        ventasSemana: _salesTotalSince(_weekStart),
                        ventasSemanaPasada: _salesTotalSince(_weekStart.subtract(const Duration(days: 7))) -
                            _salesTotalSince(_weekStart),
                        ventasMes: _salesTotalSince(_monthStart),
                        ventasMesPasado: _salesTotalSince(DateTime(_monthStart.year, _monthStart.month - 1, 1)) -
                            _salesTotalSince(_monthStart),
                        ingresosTotales: _ingresosTotales,
                        egresosTotales: _egresosTotales,
                        topServicio: _topServicios.entries.isEmpty
                            ? null
                            : _topServicios.entries.first,
                        topTherapist:
                            _therapistPerformance.isEmpty ? null : _therapistPerformance.first,
                      ),
                      const _ExportablesTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResumenFinancieroTab extends StatelessWidget {
  const _ResumenFinancieroTab({
    required this.ventasHoy,
    required this.ventasSemana,
    required this.ventasMes,
    required this.ingresosTotales,
    required this.egresosTotales,
    required this.gananciaNeta,
    required this.ticketPromedio,
    required this.serviciosRealizados,
    required this.citasCompletadas,
    required this.citasPendientesCobro,
  });

  final double ventasHoy;
  final double ventasSemana;
  final double ventasMes;
  final double ingresosTotales;
  final double egresosTotales;
  final double gananciaNeta;
  final double ticketPromedio;
  final int serviciosRealizados;
  final int citasCompletadas;
  final int citasPendientesCobro;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _FinanceStat('Ventas de hoy', _money(ventasHoy), Icons.today_outlined),
      _FinanceStat('Ventas de la semana', _money(ventasSemana), Icons.view_week_outlined),
      _FinanceStat('Ventas del mes', _money(ventasMes), Icons.calendar_month_outlined),
      _FinanceStat('Ingresos totales', _money(ingresosTotales), Icons.payments_outlined),
      _FinanceStat('Egresos totales', _money(egresosTotales), Icons.trending_down_outlined),
      _FinanceStat('Ganancia neta', _money(gananciaNeta), Icons.insights_outlined),
      _FinanceStat('Ticket promedio', _money(ticketPromedio), Icons.receipt_long_outlined),
      _FinanceStat('Servicios realizados', '$serviciosRealizados', Icons.spa_outlined),
      _FinanceStat('Citas completadas', '$citasCompletadas', Icons.task_alt_outlined),
      _FinanceStat(
        'Citas pendientes de cobro',
        '$citasPendientesCobro',
        Icons.point_of_sale_outlined,
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: stats.map((stat) => _StatCard(stat: stat)).toList(),
      ),
    );
  }
}

class _VentasTab extends StatelessWidget {
  const _VentasTab({
    required this.ventasHoy,
    required this.ventasSemana,
    required this.ventasMes,
    required this.ventasPorMetodo,
    required this.ventasPorTipo,
    required this.topServicios,
    required this.sales,
  });

  final double ventasHoy;
  final double ventasSemana;
  final double ventasMes;
  final Map<String, double> ventasPorMetodo;
  final Map<String, double> ventasPorTipo;
  final Map<String, int> topServicios;
  final List<Map<String, dynamic>> sales;

  @override
  Widget build(BuildContext context) {
    final topServices = topServicios.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MiniFinanceCard(title: 'Ventas del día', value: _money(ventasHoy)),
            _MiniFinanceCard(title: 'Ventas de la semana', value: _money(ventasSemana)),
            _MiniFinanceCard(title: 'Ventas del mes', value: _money(ventasMes)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'Ventas por método de pago',
                child: Column(
                  children: ventasPorMetodo.entries
                      .map((entry) => _LineRow(entry.key, _money(entry.value)))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Ventas por categoría',
                child: Column(
                  children: ventasPorTipo.entries
                      .map((entry) => _LineRow(entry.key, _money(entry.value)))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'Servicios más vendidos',
                child: Column(
                  children: (topServices.take(8).toList())
                      .map((entry) => _LineRow(entry.key, '${entry.value}'))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Ventas recientes',
                child: Column(
                  children: sales.take(10).map((sale) {
                    final date = DateTime.tryParse(sale['created_at']?.toString() ?? '');
                    final label = sale['client_name']?.toString().trim().isNotEmpty == true
                        ? sale['client_name'].toString()
                        : 'Venta';
                    final method = sale['payment_method']?.toString() ?? 'pendiente';
                    return _LineRow(
                      '$label • ${date != null ? '${date.day}/${date.month}' : ''} • $method',
                      _money((sale['total'] as num?)?.toDouble() ?? 0),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExpensesListTab extends StatelessWidget {
  const _ExpensesListTab({
    required this.title,
    required this.emptyMessage,
    required this.rows,
    required this.valueKey,
    required this.titleBuilder,
    required this.subtitleBuilder,
  });

  final String title;
  final String emptyMessage;
  final List<Map<String, dynamic>> rows;
  final String valueKey;
  final String Function(Map<String, dynamic>) titleBuilder;
  final String Function(Map<String, dynamic>) subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Panel(
          title: title,
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    emptyMessage,
                    style: GoogleFonts.inter(color: Colors.black54),
                  ),
                )
              : Column(
                  children: rows.map((row) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        titleBuilder(row),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(subtitleBuilder(row)),
                      trailing: Text(
                        _money((row[valueKey] as num?)?.toDouble() ?? 0),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: SaharaTheme.gold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _PayrollTab extends StatelessWidget {
  const _PayrollTab({required this.rows, required this.staff});

  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> staff;

  @override
  Widget build(BuildContext context) {
    final staffNames = <String, String>{
      for (final item in staff)
        item['id']?.toString() ?? '': item['full_name']?.toString() ?? 'Empleado'
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Panel(
          title: 'Nómina',
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Todavía no hay registros de nómina.',
                    style: GoogleFonts.inter(color: Colors.black54),
                  ),
                )
              : Column(
                  children: rows.map((row) {
                    final employeeName =
                        staffNames[row['employee_id']?.toString() ?? ''] ?? 'Empleado';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        employeeName,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${row['period_start'] ?? ''} • ${row['period_end'] ?? ''} • ${row['payment_status'] ?? 'pendiente'}',
                      ),
                      trailing: Text(
                        _money((row['total_pay'] as num?)?.toDouble() ?? 0),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: SaharaTheme.gold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _TherapistsTab extends StatelessWidget {
  const _TherapistsTab({required this.rows});

  final List<_TherapistPerformance> rows;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Panel(
          title: 'Terapeutas / rendimiento',
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Todavía no hay datos suficientes para rendimiento.',
                    style: GoogleFonts.inter(color: Colors.black54),
                  ),
                )
              : Column(
                  children: rows.map((row) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        row.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Servicios: ${row.servicesCompleted} • Canceladas: ${row.cancelled} • No-shows: ${row.noShows}',
                      ),
                      trailing: Text(
                        _money(row.revenue),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: SaharaTheme.gold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _ComparativasTab extends StatelessWidget {
  const _ComparativasTab({
    required this.ventasHoy,
    required this.ventasAyer,
    required this.ventasSemana,
    required this.ventasSemanaPasada,
    required this.ventasMes,
    required this.ventasMesPasado,
    required this.ingresosTotales,
    required this.egresosTotales,
    required this.topServicio,
    required this.topTherapist,
  });

  final double ventasHoy;
  final double ventasAyer;
  final double ventasSemana;
  final double ventasSemanaPasada;
  final double ventasMes;
  final double ventasMesPasado;
  final double ingresosTotales;
  final double egresosTotales;
  final MapEntry<String, int>? topServicio;
  final _TherapistPerformance? topTherapist;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _ComparisonCard(
              title: 'Hoy vs ayer',
              primary: _money(ventasHoy),
              secondary: _money(ventasAyer),
            ),
            _ComparisonCard(
              title: 'Semana actual vs pasada',
              primary: _money(ventasSemana),
              secondary: _money(ventasSemanaPasada),
            ),
            _ComparisonCard(
              title: 'Mes actual vs pasado',
              primary: _money(ventasMes),
              secondary: _money(ventasMesPasado),
            ),
            _ComparisonCard(
              title: 'Ingresos vs egresos',
              primary: _money(ingresosTotales),
              secondary: _money(egresosTotales),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Hallazgos clave',
          child: Column(
            children: [
              _LineRow(
                'Servicio más vendido',
                topServicio == null ? 'Sin datos' : '${topServicio!.key} (${topServicio!.value})',
              ),
              _LineRow(
                'Terapeuta más rentable',
                topTherapist == null
                    ? 'Sin datos'
                    : '${topTherapist!.name} • ${_money(topTherapist!.revenue)}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExportablesTab extends StatelessWidget {
  const _ExportablesTab();

  @override
  Widget build(BuildContext context) {
    final reports = const [
      'Ventas del día',
      'Corte de caja',
      'Nómina',
      'Gastos',
      'Utilidad mensual',
      'Rendimiento por terapeuta',
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Panel(
          title: 'Reportes exportables',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: reports.map((report) {
              return _ExportButton(report: report);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FixedExpenseDialog extends StatefulWidget {
  const _FixedExpenseDialog();

  @override
  State<_FixedExpenseDialog> createState() => _FixedExpenseDialogState();
}

class _FixedExpenseDialogState extends State<_FixedExpenseDialog> {
  static const String _defaultBusiness = 'Sahara Club Spa';
  static const String _otherCategory = 'otro';
  static const Map<String, String> _categoryLabels = {
    'cfe_electricidad': 'CFE / Electricidad',
    'telnor_internet': 'Telnor / Internet',
    'cespe_agua': 'CESPE / Agua',
    'renta_local': 'Renta del local',
    'telefono': 'Telefono',
    'gas': 'Gas',
    'limpieza': 'Limpieza',
    'mantenimiento': 'Mantenimiento',
    'seguridad': 'Seguridad',
    'contabilidad': 'Contabilidad',
    'software_suscripciones': 'Software / suscripciones',
    'publicidad_fija': 'Publicidad fija',
    'seguro': 'Seguro',
    'nomina': 'Nomina',
    'otro': 'Otro',
  };
  final _businessCtrl = TextEditingController(text: _defaultBusiness);
  final _customCategoryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();
  String _selectedCategory = 'cfe_electricidad';
  String _frequency = 'mensual';
  String _paymentMethod = 'transferencia';
  String _status = 'pendiente';
  bool _saving = false;
  bool get _isOtherCategory => _selectedCategory == _otherCategory;
  @override
  void dispose() {
    _businessCtrl.dispose();
    _customCategoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    _dueDayCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
  String get _resolvedCategory {
    if (_isOtherCategory) {
      final custom = _customCategoryCtrl.text.trim();
      return custom.isEmpty ? 'Otro' : custom;
    }
    return _categoryLabels[_selectedCategory] ?? 'Otro';
  }
  Future<void> _save() async {
    final negocio = _businessCtrl.text.trim().isEmpty
        ? _defaultBusiness
        : _businessCtrl.text.trim();
    final descripcion = _descriptionCtrl.text.trim();
    final monto = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (descripcion.isEmpty || monto <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Descripcion del gasto y monto son obligatorios.'),
          ),
        );
      }
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'branch_id': kDefaultBranchId,
      'name': negocio,
      'category': _resolvedCategory,
      'description': descripcion,
      'amount': monto,
      'frequency': _frequency,
      'due_day': int.tryParse(_dueDayCtrl.text.trim()) ?? 1,
      'payment_method': _paymentMethod,
      'status': _status,
      'notes': _notesCtrl.text.trim(),
    };
    try {
      try {
        await Supabase.instance.client.from('fixed_expenses').insert(payload);
      } catch (_) {
        final fallbackPayload = Map<String, dynamic>.from(payload)
          ..remove('description')
          ..['notes'] = [
            if (descripcion.isNotEmpty) 'Descripcion: ' + descripcion,
            if (_notesCtrl.text.trim().isNotEmpty) _notesCtrl.text.trim(),
          ].join('\n');
        await Supabase.instance.client.from('fixed_expenses').insert(fallbackPayload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return _BaseAdminDialog(
      title: 'Nuevo gasto fijo',
      saving: _saving,
      onSave: _save,
      child: Column(
        children: [
          _LabeledField(controller: _businessCtrl, label: 'Negocio'),
          _LabeledDropdown(
            label: 'Categoria',
            value: _selectedCategory,
            items: _categoryLabels.keys.toList(),
            labels: _categoryLabels,
            onChanged: (value) =>
                setState(() => _selectedCategory = value ?? _selectedCategory),
          ),
          if (_isOtherCategory)
            _LabeledField(
              controller: _customCategoryCtrl,
              label: 'Categoria personalizada',
            ),
          _LabeledField(
            controller: _descriptionCtrl,
            label: 'Descripcion del gasto',
            lines: 2,
          ),
          _LabeledField(controller: _amountCtrl, label: 'Monto', number: true),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  controller: _dueDayCtrl,
                  label: 'Dia de vencimiento',
                  number: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledDropdown(
                  label: 'Frecuencia',
                  value: _frequency,
                  items: const ['mensual', 'semanal', 'quincenal', 'anual'],
                  onChanged: (value) =>
                      setState(() => _frequency = value ?? _frequency),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _LabeledDropdown(
                  label: 'Metodo de pago',
                  value: _paymentMethod,
                  items: const [
                    'efectivo',
                    'tarjeta',
                    'transferencia',
                    'stripe',
                    'gift_card',
                    'membresia',
                  ],
                  labels: const {
                    'gift_card': 'Gift card',
                    'membresia': 'Membresia',
                  },
                  onChanged: (value) =>
                      setState(() => _paymentMethod = value ?? _paymentMethod),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledDropdown(
                  label: 'Estado',
                  value: _status,
                  items: const ['pendiente', 'pagado', 'vencido'],
                  onChanged: (value) => setState(() => _status = value ?? _status),
                ),
              ),
            ],
          ),
          _LabeledField(controller: _notesCtrl, label: 'Notas', lines: 3),
        ],
      ),
    );
  }
}
class _SupplierExpenseDialog extends StatefulWidget {
  const _SupplierExpenseDialog();

  @override
  State<_SupplierExpenseDialog> createState() => _SupplierExpenseDialogState();
}

class _SupplierExpenseDialogState extends State<_SupplierExpenseDialog> {
  final _supplierCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'transferencia';
  String _status = 'pendiente';
  bool _saving = false;

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    _invoiceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('supplier_expenses').insert({
        'branch_id': kDefaultBranchId,
        'supplier_name': _supplierCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
        'invoice_number': _invoiceCtrl.text.trim(),
        'payment_method': _paymentMethod,
        'expense_date': DateTime.now().toIso8601String().substring(0, 10),
        'status': _status,
        'notes': _notesCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseAdminDialog(
      title: 'Nuevo gasto de proveedor',
      saving: _saving,
      onSave: _save,
      child: Column(
        children: [
          _LabeledField(controller: _supplierCtrl, label: 'Proveedor'),
          _LabeledField(controller: _categoryCtrl, label: 'Categoría'),
          _LabeledField(controller: _descriptionCtrl, label: 'Descripción', lines: 2),
          _LabeledField(controller: _amountCtrl, label: 'Monto', number: true),
          _LabeledField(controller: _invoiceCtrl, label: 'Factura / referencia'),
          Row(
            children: [
              Expanded(
                child: _LabeledDropdown(
                  label: 'Método de pago',
                  value: _paymentMethod,
                  items: const ['efectivo', 'tarjeta', 'transferencia', 'stripe'],
                  onChanged: (value) => setState(() => _paymentMethod = value ?? _paymentMethod),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledDropdown(
                  label: 'Estado',
                  value: _status,
                  items: const ['pendiente', 'pagado'],
                  onChanged: (value) => setState(() => _status = value ?? _status),
                ),
              ),
            ],
          ),
          _LabeledField(controller: _notesCtrl, label: 'Notas', lines: 3),
        ],
      ),
    );
  }
}

class _PayrollDialog extends StatefulWidget {
  const _PayrollDialog({required this.staff});

  final List<Map<String, dynamic>> staff;

  @override
  State<_PayrollDialog> createState() => _PayrollDialogState();
}

class _PayrollDialogState extends State<_PayrollDialog> {
  String? _employeeId;
  final _baseCtrl = TextEditingController();
  final _commissionsCtrl = TextEditingController(text: '0');
  final _bonusesCtrl = TextEditingController(text: '0');
  final _tipsCtrl = TextEditingController(text: '0');
  final _deductionsCtrl = TextEditingController(text: '0');
  final _periodStartCtrl = TextEditingController();
  final _periodEndCtrl = TextEditingController();
  String _status = 'pendiente';
  bool _saving = false;

  @override
  void dispose() {
    _baseCtrl.dispose();
    _commissionsCtrl.dispose();
    _bonusesCtrl.dispose();
    _tipsCtrl.dispose();
    _deductionsCtrl.dispose();
    _periodStartCtrl.dispose();
    _periodEndCtrl.dispose();
    super.dispose();
  }

  double _num(TextEditingController ctrl) =>
      double.tryParse(ctrl.text.trim()) ?? 0;

  Future<void> _save() async {
    setState(() => _saving = true);
    final total = _num(_baseCtrl) +
        _num(_commissionsCtrl) +
        _num(_bonusesCtrl) +
        _num(_tipsCtrl) -
        _num(_deductionsCtrl);
    try {
      await Supabase.instance.client.from('payroll_entries').insert({
        'branch_id': kDefaultBranchId,
        'employee_id': _employeeId,
        'period_start': _periodStartCtrl.text.trim(),
        'period_end': _periodEndCtrl.text.trim(),
        'base_salary': _num(_baseCtrl),
        'commissions': _num(_commissionsCtrl),
        'bonuses': _num(_bonusesCtrl),
        'tips': _num(_tipsCtrl),
        'deductions': _num(_deductionsCtrl),
        'total_pay': total,
        'payment_status': _status,
        'paid_at': _status == 'pagado' ? DateTime.now().toIso8601String() : null,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseAdminDialog(
      title: 'Nuevo registro de nómina',
      saving: _saving,
      onSave: _employeeId == null ? null : _save,
      child: Column(
        children: [
          _LabeledDropdown(
            label: 'Empleado',
            value: _employeeId,
            items: widget.staff
                .map((item) => item['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList(),
            labels: {
              for (final item in widget.staff)
                item['id']?.toString() ?? '':
                    item['full_name']?.toString() ?? 'Empleado'
            },
            onChanged: (value) => setState(() => _employeeId = value),
          ),
          Row(
            children: [
              Expanded(child: _LabeledField(controller: _periodStartCtrl, label: 'Periodo inicio (YYYY-MM-DD)')),
              const SizedBox(width: 12),
              Expanded(child: _LabeledField(controller: _periodEndCtrl, label: 'Periodo fin (YYYY-MM-DD)')),
            ],
          ),
          _LabeledField(controller: _baseCtrl, label: 'Sueldo base', number: true),
          Row(
            children: [
              Expanded(child: _LabeledField(controller: _commissionsCtrl, label: 'Comisiones', number: true)),
              const SizedBox(width: 12),
              Expanded(child: _LabeledField(controller: _bonusesCtrl, label: 'Bonos', number: true)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _LabeledField(controller: _tipsCtrl, label: 'Propinas', number: true)),
              const SizedBox(width: 12),
              Expanded(child: _LabeledField(controller: _deductionsCtrl, label: 'Descuentos', number: true)),
            ],
          ),
          _LabeledDropdown(
            label: 'Estado de pago',
            value: _status,
            items: const ['pendiente', 'pagado', 'parcial'],
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ],
      ),
    );
  }
}

class _BaseAdminDialog extends StatelessWidget {
  const _BaseAdminDialog({
    required this.title,
    required this.child,
    required this.saving,
    required this.onSave,
  });

  final String title;
  final Widget child;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                child,
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: saving ? null : onSave,
                      child: Text(saving ? 'Guardando...' : 'Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.controller,
    required this.label,
    this.number = false,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool number;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labels = const {},
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(labels[item] ?? item),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _FinanceStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaharaTheme.gold.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, size: 18, color: SaharaTheme.gold),
          const SizedBox(height: 12),
          Text(
            stat.title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFinanceCard extends StatelessWidget {
  const _MiniFinanceCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: SaharaTheme.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Text(
            primary,
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Comparativo: $secondary',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.report});

  final String report;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportación de "$report" disponible en la siguiente fase.')),
        );
      },
      icon: const Icon(Icons.download_outlined, size: 16),
      label: Text(report),
    );
  }
}

class _FinanceStat {
  const _FinanceStat(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

class _TherapistPerformance {
  _TherapistPerformance({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
  int servicesCompleted = 0;
  int cancelled = 0;
  int noShows = 0;
  double revenue = 0;
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';



