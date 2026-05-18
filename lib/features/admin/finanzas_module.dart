import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_mode.dart';
import '../../theme/sahara_theme.dart';

const Color _financeInk = Color(0xFF1D1813);
const Color _financeMuted = Color(0xFF7D7265);
const Color _financeBorder = Color(0xFFE8DED0);
const Color _financeSidebarTop = Color(0xFF13100D);
const Color _financeSidebarBottom = Color(0xFF2A211A);
const Color _financePositive = Color(0xFF4B8B6B);
const Color _financeNegative = Color(0xFFB96352);
const Color _financeBlue = Color(0xFF6F7C98);
const Color _financeViolet = Color(0xFF8B7AA8);

class FinanzasModule extends StatefulWidget {
  const FinanzasModule({super.key});

  @override
  State<FinanzasModule> createState() => _FinanzasModuleState();
}

class _FinanzasModuleState extends State<FinanzasModule> {
  bool _loading = true;
  int _selectedSection = 0;
  Map<String, dynamic>? _dashboardPayload;
  Map<String, dynamic>? _incomePayload;
  Map<String, dynamic>? _expensePayload;
  Map<String, dynamic>? _fixedExpensePayload;
  Map<String, dynamic>? _supplierPayload;
  Map<String, dynamic>? _payrollPayload;
  Map<String, dynamic>? _performancePayload;
  bool _detailsLoaded = false;
  bool _incomeLoaded = false;
  bool _expenseLoaded = false;
  bool _fixedExpenseLoaded = false;
  bool _supplierLoaded = false;
  bool _payrollLoaded = false;
  bool _performanceLoaded = false;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _fixedExpenses = [];
  List<Map<String, dynamic>> _supplierExpenses = [];
  List<Map<String, dynamic>> _payrollEntries = [];
  List<Map<String, dynamic>> _staff = [];

  static const List<_FinanceSectionMeta> _sections = [
    _FinanceSectionMeta(
      title: 'Dashboard',
      subtitle: 'Resumen general de finanzas y flujo operativo.',
      icon: Icons.dashboard_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Ingresos',
      subtitle: 'Ventas, metodos de pago y comportamiento comercial.',
      icon: Icons.trending_up_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Gastos',
      subtitle: 'Vista consolidada de egresos y presion operativa.',
      icon: Icons.payments_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Gastos Fijos',
      subtitle: 'Servicios, renta y compromisos recurrentes.',
      icon: Icons.receipt_long_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Proveedores',
      subtitle: 'Facturas, compras y compromisos pendientes.',
      icon: Icons.groups_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Nomina',
      subtitle: 'Pagos al equipo, estatus y cargas por periodo.',
      icon: Icons.badge_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Rendimiento',
      subtitle: 'Desempeno de terapeutas y rentabilidad por servicio.',
      icon: Icons.insights_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Comparativas',
      subtitle: 'Lectura comparativa de ventas, utilidad y ritmo operativo.',
      icon: Icons.compare_arrows_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Caja Chica',
      subtitle: 'Control de efectivo disponible y movimientos menores.',
      icon: Icons.account_balance_wallet_outlined,
    ),
    _FinanceSectionMeta(
      title: 'Cuentas por Pagar',
      subtitle: 'Compromisos pendientes con proveedores, nomina y fijos.',
      icon: Icons.outbox_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Cuentas por Cobrar',
      subtitle: 'Cobros pendientes, vencimientos y seguimiento comercial.',
      icon: Icons.move_to_inbox_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Reportes',
      subtitle: 'Exportaciones, cortes y consolidado operativo financiero.',
      icon: Icons.bar_chart_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Alertas',
      subtitle: 'Riesgos, pendientes y focos de atencion del negocio.',
      icon: Icons.notifications_active_outlined,
    ),
    _FinanceSectionMeta(
      title: 'Presupuestos',
      subtitle: 'Planeacion de gasto, control por categoria y desviaciones.',
      icon: Icons.pie_chart_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Metas',
      subtitle: 'Objetivos de ingresos, margen, cobranza y productividad.',
      icon: Icons.flag_rounded,
    ),
    _FinanceSectionMeta(
      title: 'Configuracion Financiera',
      subtitle: 'Parametros, reglas y salud del modulo financiero.',
      icon: Icons.settings_rounded,
    ),
  ];

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    final payload = await _loadDashboardPayloadSafe();
    if (payload != null) {
      if (!mounted) return;
      setState(() {
        _dashboardPayload = payload;
        _loading = false;
      });
      if (!_detailsLoaded) {
        _loadDetailedData(refreshDashboard: false, preserveLoadingState: true);
      }
      return;
    }

    await _loadDetailedData(refreshDashboard: false, preserveLoadingState: true);
  }

  Future<void> _load() async {
    if (_selectedSection == 0 && !_detailsLoaded) {
      await _loadInitial();
      return;
    }
    if (_selectedSection == 1 && !_detailsLoaded) {
      await _loadIncomeInitial();
      return;
    }
    if (_selectedSection == 2 && !_detailsLoaded) {
      await _loadExpenseInitial();
      return;
    }
    if (_selectedSection == 3 && !_detailsLoaded) {
      await _loadFixedExpenseInitial();
      return;
    }
    if (_selectedSection == 4 && !_detailsLoaded) {
      await _loadSupplierInitial();
      return;
    }
    if (_selectedSection == 5 && !_detailsLoaded) {
      await _loadPayrollInitial();
      return;
    }
    if (_selectedSection == 6 && !_detailsLoaded) {
      await _loadPerformanceInitial();
      return;
    }
    await _loadDetailedData(refreshDashboard: true);
  }

  Future<void> _loadIncomeInitial() async {
    setState(() => _loading = true);
    final payload = await _loadIncomePayloadSafe();
    if (payload != null) {
      if (!mounted) return;
      setState(() {
        _incomePayload = payload;
        _incomeLoaded = true;
        _loading = false;
      });
      return;
    }

    await _loadDetailedData(refreshDashboard: true, preserveLoadingState: true);
  }

  Future<void> _loadExpenseInitial() async {
    setState(() => _loading = true);
    final payload = await _loadExpensePayloadSafe();
    if (payload != null) {
      if (!mounted) return;
      setState(() {
        _expensePayload = payload;
        _expenseLoaded = true;
        _loading = false;
      });
      return;
    }

    await _loadDetailedData(refreshDashboard: true, preserveLoadingState: true);
  }

  Future<void> _loadSupplierInitial() async {
    setState(() => _loading = true);
    final payload = await _loadSupplierPayloadSafe();
    if (payload != null) {
      if (!mounted) return;
      setState(() {
        _supplierPayload = payload;
        _supplierLoaded = true;
        _loading = false;
      });
      return;
    }

    await _loadDetailedData(refreshDashboard: true, preserveLoadingState: true);
  }

  Future<void> _loadFixedExpenseInitial() async {
    setState(() => _loading = true);
    final payload = await _loadFixedExpensePayloadSafe();
    if (payload != null) {
      if (!mounted) return;
      setState(() {
        _fixedExpensePayload = payload;
        _fixedExpenseLoaded = true;
        _loading = false;
      });
      return;
    }

    await _loadDetailedData(refreshDashboard: true, preserveLoadingState: true);
  }

  Future<void> _loadPayrollInitial() async {
    setState(() => _loading = true);
    final payload = await _loadPayrollPayloadSafe();
    if (payload != null) {
      if (!mounted) return;
      setState(() {
        _payrollPayload = payload;
        _payrollLoaded = true;
        _loading = false;
      });
      return;
    }

    await _loadDetailedData(refreshDashboard: true, preserveLoadingState: true);
  }

  Future<void> _loadPerformanceInitial() async {
    setState(() => _loading = true);
    final payload = await _loadPerformancePayloadSafe();
    if (payload != null) {
      if (!mounted) return;
      setState(() {
        _performancePayload = payload;
        _performanceLoaded = true;
        _loading = false;
      });
      return;
    }

    await _loadDetailedData(refreshDashboard: true, preserveLoadingState: true);
  }

  Future<void> _loadDetailedData({
    bool refreshDashboard = true,
    bool preserveLoadingState = false,
  }) async {
    if (!preserveLoadingState) {
      setState(() => _loading = true);
    }

    final results = await Future.wait<dynamic>([
      refreshDashboard
          ? _loadDashboardPayloadSafe()
          : Future<Map<String, dynamic>?>.value(_dashboardPayload),
      _loadSalesSafe(),
      _loadBookingsSafe(),
      _safeSelect('fixed_expenses'),
      _safeSelect('supplier_expenses'),
      _safeSelect('payroll_entries'),
      _safeSelect('staff'),
    ]);

    if (!mounted) return;
    setState(() {
      _dashboardPayload = results[0] as Map<String, dynamic>?;
      _sales = results[1] as List<Map<String, dynamic>>;
      _bookings = results[2] as List<Map<String, dynamic>>;
      _fixedExpenses = results[3] as List<Map<String, dynamic>>;
      _supplierExpenses = results[4] as List<Map<String, dynamic>>;
      _payrollEntries = results[5] as List<Map<String, dynamic>>;
      _staff = results[6] as List<Map<String, dynamic>>;
      _detailsLoaded = true;
      _loading = false;
    });
  }

  Future<void> _handleSectionChange(int index) async {
    if (index == _selectedSection) return;

    if (index == 0 ||
        (index == 1 && _incomeLoaded) ||
        (index == 2 && _expenseLoaded) ||
        (index == 3 && _fixedExpenseLoaded) ||
        (index == 4 && _supplierLoaded) ||
        (index == 5 && _payrollLoaded) ||
        (index == 6 && _performanceLoaded) ||
        _detailsLoaded) {
      setState(() => _selectedSection = index);
      return;
    }

    if (index == 1) {
      setState(() {
        _selectedSection = index;
        _loading = true;
      });
      await _loadIncomeInitial();
      return;
    }

    if (index == 2) {
      setState(() {
        _selectedSection = index;
        _loading = true;
      });
      await _loadExpenseInitial();
      return;
    }

    if (index == 3) {
      setState(() {
        _selectedSection = index;
        _loading = true;
      });
      await _loadFixedExpenseInitial();
      return;
    }

    if (index == 4) {
      setState(() {
        _selectedSection = index;
        _loading = true;
      });
      await _loadSupplierInitial();
      return;
    }

    if (index == 5) {
      setState(() {
        _selectedSection = index;
        _loading = true;
      });
      await _loadPayrollInitial();
      return;
    }

    if (index == 6) {
      setState(() {
        _selectedSection = index;
        _loading = true;
      });
      await _loadPerformanceInitial();
      return;
    }

    setState(() {
      _selectedSection = index;
      _loading = true;
    });
    await _loadDetailedData(refreshDashboard: true, preserveLoadingState: true);
  }

  Future<Map<String, dynamic>?> _loadDashboardPayloadSafe() async {
    try {
      final data = await _client.rpc(
        'finance_dashboard_payload',
        params: {'p_branch_id': kDefaultBranchId},
      );
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (error) {
      debugPrint('finanzas _loadDashboardPayloadSafe: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadIncomePayloadSafe() async {
    try {
      final data = await _client.rpc(
        'finance_income_payload',
        params: {'p_branch_id': kDefaultBranchId},
      );
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (error) {
      debugPrint('finanzas _loadIncomePayloadSafe: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadExpensePayloadSafe() async {
    try {
      final data = await _client.rpc(
        'finance_expense_payload',
        params: {'p_branch_id': kDefaultBranchId},
      );
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (error) {
      debugPrint('finanzas _loadExpensePayloadSafe: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadFixedExpensePayloadSafe() async {
    try {
      final data = await _client.rpc(
        'finance_fixed_expense_payload',
        params: {'p_branch_id': kDefaultBranchId},
      );
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (error) {
      debugPrint('finanzas _loadFixedExpensePayloadSafe: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadSupplierPayloadSafe() async {
    try {
      final data = await _client.rpc(
        'finance_supplier_payload',
        params: {'p_branch_id': kDefaultBranchId},
      );
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (error) {
      debugPrint('finanzas _loadSupplierPayloadSafe: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadPayrollPayloadSafe() async {
    try {
      final data = await _client.rpc(
        'finance_payroll_payload',
        params: {'p_branch_id': kDefaultBranchId},
      );
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (error) {
      debugPrint('finanzas _loadPayrollPayloadSafe: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadPerformancePayloadSafe() async {
    try {
      final data = await _client.rpc(
        'finance_performance_payload',
        params: {'p_branch_id': kDefaultBranchId},
      );
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (error) {
      debugPrint('finanzas _loadPerformancePayloadSafe: $error');
      return null;
    }
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
        client_name,
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
        client_name,
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
      booking_time,
      therapist_id,
      therapist:staff(full_name),
      service:services(name, price)
    ''').order('booking_date', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> _safeSelect(String table) async {
    try {
      final data = await _client
          .from(table)
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (error) {
      debugPrint('finanzas _safeSelect($table): $error');
      return [];
    }
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  List<dynamic> _listValue(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  double _payloadAmount(dynamic value) => (value as num?)?.toDouble() ?? 0;

  int _payloadInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _payloadString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Map<String, dynamic> get _dashboardSummaryPayload =>
      _mapValue(_dashboardPayload?['summary']);

  List<_KpiData> get _dashboardCardsFromPayload {
    if (_dashboardPayload == null) return const [];
    final summary = _dashboardSummaryPayload;
    final ingresosTotales = _payloadAmount(summary['ingresos_totales']);
    final egresosTotales = _payloadAmount(summary['egresos_totales']);
    final gananciaNeta = _payloadAmount(summary['ganancia_neta']);
    final margenGanancia = _payloadAmount(summary['margen_ganancia']);
    final pendingPayrollAmount = _payloadAmount(summary['pending_payroll_amount']);
    final pendingSupplierAmount = _payloadAmount(summary['pending_supplier_amount']);
    final cuentasPorCobrar = _payloadAmount(summary['cuentas_por_cobrar_estimadas']);
    final ticketPromedio = _payloadAmount(summary['ticket_promedio']);
    final operacionesCobradas = _payloadInt(summary['operaciones_cobradas']);
    final egresosCount = _payloadInt(summary['egresos_count']);
    final pendingPayrollCount = _payloadInt(summary['pending_payroll_count']);
    final pendingSupplierCount = _payloadInt(summary['pending_supplier_count']);
    final citasPendientesCobro = _payloadInt(summary['citas_pendientes_cobro']);

    return [
      _KpiData(
        title: 'Ingresos Totales',
        value: _money(ingresosTotales),
        caption: '$operacionesCobradas operaciones cobradas',
        color: _financePositive,
        icon: Icons.attach_money_rounded,
      ),
      _KpiData(
        title: 'Gastos Totales',
        value: _money(egresosTotales),
        caption: '$egresosCount egresos registrados',
        color: _financeNegative,
        icon: Icons.south_rounded,
      ),
      _KpiData(
        title: 'Ganancia Neta',
        value: _money(gananciaNeta),
        caption: gananciaNeta >= 0 ? 'Operacion positiva' : 'Operacion presionada',
        color: SaharaTheme.gold,
        icon: Icons.wallet_outlined,
      ),
      _KpiData(
        title: 'Margen de Ganancia',
        value: _percent(margenGanancia),
        caption: 'Sobre ingresos totales',
        color: _financeViolet,
        icon: Icons.pie_chart_outline_rounded,
      ),
      _KpiData(
        title: 'Nomina Pendiente',
        value: _money(pendingPayrollAmount),
        caption: '$pendingPayrollCount pagos pendientes',
        color: _financeNegative,
        icon: Icons.badge_outlined,
      ),
      _KpiData(
        title: 'Proveedores Pendientes',
        value: _money(pendingSupplierAmount),
        caption: '$pendingSupplierCount facturas pendientes',
        color: _financeBlue,
        icon: Icons.local_shipping_outlined,
      ),
      _KpiData(
        title: 'Cuentas por Cobrar',
        value: _money(cuentasPorCobrar),
        caption: '$citasPendientesCobro citas por cobrar',
        color: SaharaTheme.bronceOscuro,
        icon: Icons.receipt_long_outlined,
      ),
      _KpiData(
        title: 'Ticket Promedio',
        value: _money(ticketPromedio),
        caption: 'Promedio por operacion cobrada',
        color: _financeInk,
        icon: Icons.confirmation_number_outlined,
      ),
    ];
  }

  List<_TrendPoint> get _dashboardTrendFromPayload => _listValue(
        _dashboardPayload?['trend'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _TrendPoint(
          label: _payloadString(row['label'], fallback: '-'),
          ingresos: _payloadAmount(row['ingresos']),
          egresos: _payloadAmount(row['egresos']),
        );
      }).toList();

  List<_CategoryAmount> get _dashboardExpenseBreakdownFromPayload => _listValue(
        _dashboardPayload?['expense_breakdown'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin categoria'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<MapEntry<String, double>> get _dashboardTopServicesFromPayload =>
      _listValue(_dashboardPayload?['top_services']).map((entry) {
        final row = _mapValue(entry);
        return MapEntry(
          _payloadString(row['label'], fallback: 'Sin concepto'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<_TherapistPerformance> get _dashboardTopTherapistsFromPayload =>
      _listValue(_dashboardPayload?['top_therapists']).map((entry) {
        final row = _mapValue(entry);
        final therapist = _TherapistPerformance(
          id: _payloadString(row['id'], fallback: 'sin_terapeuta'),
          name: _payloadString(row['name'], fallback: 'Sin terapeuta'),
        );
        therapist.revenue = _payloadAmount(row['revenue']);
        therapist.servicesCompleted = _payloadInt(row['services_completed']);
        therapist.cancelled = _payloadInt(row['cancelled']);
        therapist.noShows = _payloadInt(row['no_shows']);
        return therapist;
      }).toList();

  List<_CategoryAmount> get _dashboardCashFlowFromPayload =>
      _listValue(_dashboardPayload?['cash_flow']).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: '-'),
          _payloadAmount(row['value']),
        );
      }).toList();

  Color _alertToneForKind(String kind) {
    switch (kind) {
      case 'receivables':
        return _financeBlue;
      case 'payroll_pending':
        return _financeNegative;
      case 'suppliers_pending':
        return SaharaTheme.gold;
      case 'low_margin':
        return _financeViolet;
      case 'no_sales_today':
        return _financeMuted;
      default:
        return _financePositive;
    }
  }

  IconData _alertIconForKind(String kind) {
    switch (kind) {
      case 'receivables':
        return Icons.receipt_long_outlined;
      case 'payroll_pending':
        return Icons.badge_outlined;
      case 'suppliers_pending':
        return Icons.local_shipping_outlined;
      case 'low_margin':
        return Icons.show_chart_rounded;
      case 'no_sales_today':
        return Icons.event_busy_outlined;
      default:
        return Icons.verified_outlined;
    }
  }

  List<_MetricAlert> get _dashboardAlertsFromPayload => _listValue(
        _dashboardPayload?['alerts'],
      ).map((entry) {
        final row = _mapValue(entry);
        final kind = _payloadString(row['kind'], fallback: 'stable');
        return _MetricAlert(
          title: _payloadString(row['title'], fallback: 'Alerta'),
          message: _payloadString(row['message'], fallback: 'Sin detalle'),
          tone: _alertToneForKind(kind),
          icon: _alertIconForKind(kind),
          stamp: _payloadString(row['stamp'], fallback: 'Actual'),
        );
      }).toList();

  int get _currentAlertCount {
    final payloadAlerts = _dashboardAlertsFromPayload;
    if (payloadAlerts.isNotEmpty) return payloadAlerts.length;
    return _alerts.length;
  }

  Map<String, dynamic> get _incomeSummaryPayload => _mapValue(_incomePayload?['summary']);

  List<_KpiData> get _incomeCardsFromPayload {
    if (_incomePayload == null) return const [];
    final summary = _incomeSummaryPayload;
    return [
      _KpiData(
        title: 'Ingresos de Hoy',
        value: _money(_payloadAmount(summary['ingresos_hoy'])),
        caption: '${_payloadInt(summary['operaciones_hoy'])} operaciones cobradas',
        color: _financePositive,
        icon: Icons.today_outlined,
      ),
      _KpiData(
        title: 'Ingresos de la Semana',
        value: _money(_payloadAmount(summary['ingresos_semana'])),
        caption:
            'Comparado con ${_money(_payloadAmount(summary['ingresos_semana_anterior']))} semana previa',
        color: SaharaTheme.gold,
        icon: Icons.view_week_outlined,
      ),
      _KpiData(
        title: 'Ingresos del Mes',
        value: _money(_payloadAmount(summary['ingresos_mes'])),
        caption:
            'Comparado con ${_money(_payloadAmount(summary['ingresos_mes_anterior']))} mes previo',
        color: _financeInk,
        icon: Icons.calendar_month_outlined,
      ),
      _KpiData(
        title: 'Servicios Realizados',
        value: '${_payloadInt(summary['servicios_realizados'])}',
        caption: '${_payloadInt(summary['citas_completadas'])} citas completadas',
        color: _financeBlue,
        icon: Icons.spa_outlined,
      ),
      _KpiData(
        title: 'Ticket Promedio',
        value: _money(_payloadAmount(summary['ticket_promedio'])),
        caption: 'Valor promedio por operacion',
        color: _financeViolet,
        icon: Icons.receipt_outlined,
      ),
      _KpiData(
        title: 'Operaciones Cobradas',
        value: '${_payloadInt(summary['operaciones_cobradas'])}',
        caption: 'Historial acumulado',
        color: SaharaTheme.bronceOscuro,
        icon: Icons.point_of_sale_outlined,
      ),
    ];
  }

  List<_TrendPoint> get _incomeTrendFromPayload => _listValue(
        _incomePayload?['trend'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _TrendPoint(
          label: _payloadString(row['label'], fallback: '-'),
          ingresos: _payloadAmount(row['ingresos']),
          egresos: _payloadAmount(row['egresos']),
        );
      }).toList();

  List<_CategoryAmount> get _incomePaymentBreakdownFromPayload => _listValue(
        _incomePayload?['payment_breakdown'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin metodo'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<_CategoryAmount> get _incomeTypeBreakdownFromPayload => _listValue(
        _incomePayload?['type_breakdown'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin tipo'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<Map<String, dynamic>> get _incomeRecentSalesFromPayload => _listValue(
        _incomePayload?['recent_sales'],
      ).map((entry) => _mapValue(entry)).toList();

  List<_SummaryRow> get _incomeSummaryRowsFromPayload => _listValue(
        _incomePayload?['summary_rows'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _SummaryRow(
          _payloadString(row['label'], fallback: '-'),
          _payloadString(row['value'], fallback: 'Sin datos'),
        );
      }).toList();

  Map<String, dynamic> get _expenseSummaryPayload => _mapValue(_expensePayload?['summary']);

  List<_KpiData> get _expenseCardsFromPayload {
    if (_expensePayload == null) return const [];
    final summary = _expenseSummaryPayload;
    final gastosTotales = _payloadAmount(summary['gastos_totales']);
    final gastosConComprobante = _payloadAmount(summary['gastos_con_comprobante']);
    return [
      _KpiData(
        title: 'Gastos Totales',
        value: _money(gastosTotales),
        caption: '${_payloadInt(summary['movimientos_count'])} movimientos',
        color: _financeNegative,
        icon: Icons.payments_outlined,
      ),
      _KpiData(
        title: 'Gastos Operativos',
        value: _money(_payloadAmount(summary['gastos_operativos'])),
        caption: 'Operacion del mes en curso',
        color: SaharaTheme.bronceOscuro,
        icon: Icons.business_center_rounded,
      ),
      _KpiData(
        title: 'Gastos con Comprobante',
        value: _money(gastosConComprobante),
        caption: _percent(
          gastosTotales == 0 ? 0 : (gastosConComprobante / gastosTotales) * 100,
        ),
        color: _financeBlue,
        icon: Icons.receipt_long_rounded,
      ),
      _KpiData(
        title: 'Gastos sin Comprobante',
        value: _money(_payloadAmount(summary['gastos_sin_comprobante'])),
        caption: '${_payloadInt(summary['gastos_sin_comprobante_count'])} movimientos',
        color: SaharaTheme.gold,
        icon: Icons.warning_rounded,
      ),
      _KpiData(
        title: 'Gastos Imprevistos',
        value: _money(_payloadAmount(summary['gastos_imprevistos'])),
        caption: 'Incidencias o mantenimiento',
        color: _financeViolet,
        icon: Icons.report_problem_rounded,
      ),
      _KpiData(
        title: 'Promedio Diario',
        value: _money(_payloadAmount(summary['promedio_diario'])),
        caption: '${DateTime.now().day} dias transcurridos',
        color: _financePositive,
        icon: Icons.calendar_month_rounded,
      ),
    ];
  }

  List<_TrendPoint> get _expenseTrendFromPayload => _listValue(
        _expensePayload?['trend'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _TrendPoint(
          label: _payloadString(row['label'], fallback: '-'),
          ingresos: _payloadAmount(row['ingresos']),
          egresos: _payloadAmount(row['egresos']),
        );
      }).toList();

  List<_CategoryAmount> get _expenseBreakdownFromPayload => _listValue(
        _expensePayload?['expense_breakdown'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin categoria'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<_CategoryAmount> get _expenseStatusBreakdownFromPayload => _listValue(
        _expensePayload?['status_breakdown'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin estado'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<_DetailedExpenseRow> get _recentExpensesFromPayload => _listValue(
        _expensePayload?['recent_expenses'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _DetailedExpenseRow(
          category: _payloadString(row['category'], fallback: 'Gasto'),
          rawCategory: _payloadString(row['raw_category'], fallback: 'Sin categoria'),
          title: _payloadString(row['title'], fallback: 'Gasto'),
          subtitle: _payloadString(row['subtitle'], fallback: ''),
          amount: _payloadAmount(row['amount']),
          status: _payloadString(row['status'], fallback: 'pendiente'),
          date: DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime.now(),
          paymentMethod: _payloadString(row['payment_method'], fallback: 'Sin definir'),
          responsible: _payloadString(row['responsible'], fallback: 'Responsable'),
          hasReceipt: row['has_receipt'] == true,
          source: _payloadString(row['source'], fallback: 'gasto'),
        );
      }).toList();

  List<_SummaryRow> get _expenseSummaryRowsFromPayload => _listValue(
        _expensePayload?['summary_rows'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _SummaryRow(
          _payloadString(row['label'], fallback: '-'),
          _payloadString(row['value'], fallback: 'Sin datos'),
        );
      }).toList();

  Map<String, dynamic> get _fixedExpenseSummaryPayload =>
      _mapValue(_fixedExpensePayload?['summary']);

  List<_KpiData> get _fixedExpenseCardsFromPayload {
    if (_fixedExpensePayload == null) return const [];
    final summary = _fixedExpenseSummaryPayload;
    final nextTitle = _payloadString(summary['next_payment_title']);
    final nextDate = DateTime.tryParse(summary['next_payment_due_date']?.toString() ?? '');
    return [
      _KpiData(
        title: 'Gastos Fijos Mensuales',
        value: _money(_payloadAmount(summary['total_mensual'])),
        caption: '${_payloadInt(summary['total_rows'])} compromisos recurrentes',
        color: _financeBlue,
        icon: Icons.receipt_long_rounded,
      ),
      _KpiData(
        title: 'Pagados',
        value: _money(_payloadAmount(summary['pagado_total'])),
        caption: '${_payloadInt(summary['pagado_count'])} pagos completados',
        color: _financePositive,
        icon: Icons.check_circle_rounded,
      ),
      _KpiData(
        title: 'Pendientes',
        value: _money(_payloadAmount(summary['pendiente_total'])),
        caption: '${_payloadInt(summary['pendiente_count'])} pagos pendientes',
        color: SaharaTheme.gold,
        icon: Icons.schedule_rounded,
      ),
      _KpiData(
        title: 'Vencidos',
        value: _money(_payloadAmount(summary['vencido_total'])),
        caption: '${_payloadInt(summary['vencido_count'])} gasto vencido',
        color: _financeNegative,
        icon: Icons.warning_rounded,
      ),
      _KpiData(
        title: 'Proximo Pago',
        value: _money(_payloadAmount(summary['next_payment_amount'])),
        caption: nextTitle.isEmpty || nextDate == null
            ? 'Sin pagos pendientes'
            : '$nextTitle - ${_daysUntilLabel(nextDate)}',
        color: _financeViolet,
        icon: Icons.event_rounded,
      ),
      _KpiData(
        title: 'Promedio Mensual',
        value: _money(_payloadAmount(summary['promedio_mensual'])),
        caption: 'Ultimos ${_payloadInt(summary['monthly_series_count'])} meses',
        color: _financePositive,
        icon: Icons.analytics_rounded,
      ),
    ];
  }

  List<_MonthlyPoint> get _fixedExpenseMonthlySeriesFromPayload => _listValue(
        _fixedExpensePayload?['monthly_series'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _MonthlyPoint(
          label: _payloadString(row['label'], fallback: '-'),
          value: _payloadAmount(row['value']),
        );
      }).toList();

  List<_CategoryAmount> get _fixedExpenseCategoryBreakdownFromPayload => _listValue(
        _fixedExpensePayload?['category_breakdown'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin categoria'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<_CategoryAmount> get _fixedExpenseStatusBreakdownFromPayload => _listValue(
        _fixedExpensePayload?['status_breakdown'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin estado'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<Map<String, dynamic>> get _fixedExpenseRowsFromPayload => _listValue(
        _fixedExpensePayload?['rows'],
      ).map((entry) {
        final row = _mapValue(entry);
        return <String, dynamic>{
          'id': row['id'],
          'name': _payloadString(row['name'], fallback: 'Sahara Club Spa'),
          'category': _payloadString(row['category'], fallback: 'Gasto fijo'),
          'description': _payloadString(row['title'], fallback: 'Gasto fijo'),
          'amount': _payloadAmount(row['amount']),
          'frequency': _payloadString(row['frequency'], fallback: 'mensual'),
          'status': _payloadString(row['status'], fallback: 'pendiente'),
          'due_day': _payloadInt(row['due_day']),
          'due_date': row['due_date'],
        };
      }).toList();

  List<_SummaryRow> get _fixedExpenseSummaryRowsFromPayload => _listValue(
        _fixedExpensePayload?['summary_rows'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _SummaryRow(
          _payloadString(row['label'], fallback: '-'),
          _payloadString(row['value'], fallback: 'Sin datos'),
        );
      }).toList();

  Map<String, dynamic> get _supplierSummaryPayload => _mapValue(_supplierPayload?['summary']);

  List<_KpiData> get _supplierCardsFromPayload {
    if (_supplierPayload == null) return const [];
    final summary = _supplierSummaryPayload;
    final paidThisMonth = _payloadAmount(summary['paid_this_month']);
    final paidPreviousMonth = _payloadAmount(summary['paid_previous_month']);
    return [
      _KpiData(
        title: 'Total Proveedores',
        value: '${_payloadInt(summary['total_suppliers'])}',
        caption: '+${_payloadInt(summary['new_this_month_count'])} nuevos',
        color: _financeBlue,
        icon: Icons.groups_rounded,
      ),
      _KpiData(
        title: 'Pagos Pendientes',
        value: _money(_payloadAmount(summary['pending_amount'])),
        caption: '${_payloadInt(summary['pending_entries'])} facturas',
        color: SaharaTheme.gold,
        icon: Icons.schedule_rounded,
      ),
      _KpiData(
        title: 'Pagos Vencidos',
        value: _money(_payloadAmount(summary['overdue_amount'])),
        caption: '${_payloadInt(summary['overdue_entries'])} vencidos',
        color: _financeNegative,
        icon: Icons.warning_rounded,
      ),
      _KpiData(
        title: 'Pagado Este Mes',
        value: _money(paidThisMonth),
        caption: paidPreviousMonth == 0
            ? 'Sin comparativo previo'
            : _percent(((paidThisMonth - paidPreviousMonth) / paidPreviousMonth) * 100),
        color: _financePositive,
        icon: Icons.check_circle_rounded,
      ),
      _KpiData(
        title: 'Proveedor Principal',
        value: _payloadString(summary['top_supplier_name'], fallback: 'Sin datos'),
        caption: _money(_payloadAmount(summary['top_supplier_total'])),
        color: _financeViolet,
        icon: Icons.local_shipping_rounded,
      ),
      _KpiData(
        title: 'Facturas Pendientes',
        value: '${_payloadInt(summary['pending_invoices_count'])}',
        caption: 'por revisar',
        color: _financePositive,
        icon: Icons.receipt_long_rounded,
      ),
    ];
  }

  List<_MonthlyPoint> get _supplierMonthlySeriesFromPayload => _listValue(
        _supplierPayload?['monthly_series'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _MonthlyPoint(
          label: _payloadString(row['label'], fallback: '-'),
          value: _payloadAmount(row['value']),
        );
      }).toList();

  List<_CategoryAmount> get _supplierCategoryBreakdownFromPayload => _listValue(
        _supplierPayload?['category_breakdown'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin categoria'),
          _payloadAmount(row['value']),
        );
      }).toList();

  _SupplierStatusSummary? get _supplierStatusFromPayload {
    if (_supplierPayload == null) return null;
    final summary = _supplierSummaryPayload;
    final total = _payloadInt(summary['total_suppliers']);
    return _SupplierStatusSummary(
      active: _payloadInt(summary['active_suppliers_count']),
      pending: _payloadInt(summary['pending_supplier_entity_count']),
      overdue: _payloadInt(summary['overdue_supplier_entity_count']),
      inactive: _payloadInt(summary['inactive_suppliers_count']),
      total: total == 0 ? 1 : total,
    );
  }

  List<Map<String, dynamic>> get _supplierRowsFromPayload => _listValue(
        _supplierPayload?['rows'],
      ).map((entry) {
        final row = _mapValue(entry);
        return <String, dynamic>{
          'id': row['id'],
          'supplier_name': _payloadString(row['supplier_name'], fallback: 'Proveedor'),
          'category': _payloadString(row['category'], fallback: 'Sin categoria'),
          'description': _payloadString(row['description'], fallback: ''),
          'invoice_number': _payloadString(row['invoice_number'], fallback: ''),
          'payment_method': _payloadString(row['payment_method'], fallback: 'sin definir'),
          'amount': _payloadAmount(row['amount']),
          'status': _payloadString(row['status'], fallback: 'pendiente'),
          'expense_date': row['movement_at'],
          'created_at': row['movement_at'],
        };
      }).toList();

  List<_SummaryRow> get _supplierSummaryRowsFromPayload => _listValue(
        _supplierPayload?['summary_rows'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _SummaryRow(
          _payloadString(row['label'], fallback: '-'),
          _payloadString(row['value'], fallback: 'Sin datos'),
        );
      }).toList();

  Map<String, dynamic> get _payrollSummaryPayload => _mapValue(_payrollPayload?['summary']);

  List<_KpiData> get _payrollCardsFromPayload {
    if (_payrollPayload == null) return const [];
    final summary = _payrollSummaryPayload;
    final previousMonth = _payloadAmount(summary['previous_month_total']);
    final currentMonth = _payloadAmount(summary['nomina_total']);
    final nextCutoff = DateTime.tryParse(summary['next_cutoff']?.toString() ?? '');
    return [
      _KpiData(
        title: 'Nomina Total',
        value: _money(currentMonth),
        caption: previousMonth == 0
            ? 'Operacion actual'
            : _percent(((currentMonth - previousMonth) / previousMonth) * 100),
        color: _financeBlue,
        icon: Icons.badge_rounded,
      ),
      _KpiData(
        title: 'Sueldos Base',
        value: _money(_payloadAmount(summary['sueldos_base'])),
        caption: '${_payloadInt(summary['empleados_count'])} empleados',
        color: _financePositive,
        icon: Icons.people_alt_rounded,
      ),
      _KpiData(
        title: 'Comisiones',
        value: _money(_payloadAmount(summary['comisiones_total'])),
        caption: 'Variable por rendimiento',
        color: _financeViolet,
        icon: Icons.trending_up_rounded,
      ),
      _KpiData(
        title: 'Bonos',
        value: _money(_payloadAmount(summary['bonos_total'])),
        caption: '${_payloadInt(summary['bonos_count'])} bonos',
        color: SaharaTheme.gold,
        icon: Icons.card_giftcard_rounded,
      ),
      _KpiData(
        title: 'Anticipos',
        value: _money(_payloadAmount(summary['deducciones_total'])),
        caption: '${_payloadInt(summary['deducciones_count'])} descuentos/anticipos',
        color: _financeNegative,
        icon: Icons.payments_rounded,
      ),
      _KpiData(
        title: 'Pendiente por Pagar',
        value: _money(_payloadAmount(summary['pendiente_total'])),
        caption: nextCutoff == null ? 'Sin corte pendiente' : 'Proximo corte ${DateFormat('d MMM', 'es_MX').format(nextCutoff)}',
        color: _financePositive,
        icon: Icons.schedule_rounded,
      ),
    ];
  }

  List<_MonthlyPoint> get _payrollMonthlySeriesFromPayload => _listValue(
        _payrollPayload?['monthly_series'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _MonthlyPoint(
          label: _payloadString(row['label'], fallback: '-'),
          value: _payloadAmount(row['value']),
        );
      }).toList();

  List<_CategoryAmount> get _payrollDistributionFromPayload => _listValue(
        _payrollPayload?['distribution'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin tipo'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<_CategoryAmount> get _payrollStatusFromPayload => _listValue(
        _payrollPayload?['status_breakdown'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin estado'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<Map<String, dynamic>> get _payrollRowsFromPayload => _listValue(
        _payrollPayload?['rows'],
      ).map((entry) {
        final row = _mapValue(entry);
        return <String, dynamic>{
          'id': row['id'],
          'employee_id': row['employee_id']?.toString(),
          'employee_name': _payloadString(row['employee_name'], fallback: 'Empleado'),
          'employee_role': _payloadString(row['employee_role'], fallback: 'Empleado'),
          'base_salary': _payloadAmount(row['base_salary']),
          'commissions': _payloadAmount(row['commissions']),
          'bonuses': _payloadAmount(row['bonuses']),
          'deductions': _payloadAmount(row['deductions']),
          'total_pay': _payloadAmount(row['total_pay']),
          'payment_status': _payloadString(row['payment_status'], fallback: 'pendiente'),
          'period_start': row['period_start'],
          'period_end': row['period_end'],
        };
      }).toList();

  List<Map<String, dynamic>> get _payrollStaffFromPayload => _payrollRowsFromPayload
      .map(
        (row) => {
          'id': row['employee_id'],
          'full_name': row['employee_name'],
          'role': row['employee_role'],
        },
      )
      .where((row) => (row['id']?.toString() ?? '').isNotEmpty)
      .toList();

  List<_SummaryRow> get _payrollSummaryRowsFromPayload => _listValue(
        _payrollPayload?['summary_rows'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _SummaryRow(
          _payloadString(row['label'], fallback: '-'),
          _payloadString(row['value'], fallback: 'Sin datos'),
        );
      }).toList();

  Map<String, dynamic> get _performanceSummaryPayload =>
      _mapValue(_performancePayload?['summary']);

  List<_KpiData> get _performanceCardsFromPayload {
    if (_performancePayload == null) return const [];
    final summary = _performanceSummaryPayload;
    return [
      _KpiData(
        title: 'Rendimiento General',
        value: _percent(_payloadAmount(summary['rendimiento_general'])),
        caption: 'Lectura operativa actual',
        color: _financePositive,
        icon: Icons.speed_rounded,
      ),
      _KpiData(
        title: 'Ticket Promedio',
        value: _money(_payloadAmount(summary['ticket_promedio'])),
        caption: 'Promedio por operacion',
        color: _financeBlue,
        icon: Icons.receipt_rounded,
      ),
      _KpiData(
        title: 'Margen Promedio',
        value: _percent(_payloadAmount(summary['margen_promedio'])),
        caption: 'Sobre ingresos netos',
        color: _financeViolet,
        icon: Icons.pie_chart_rounded,
      ),
      _KpiData(
        title: 'Servicios Realizados',
        value: '${_payloadInt(summary['servicios_realizados'])}',
        caption: 'Citas completadas o cobradas',
        color: SaharaTheme.gold,
        icon: Icons.spa_rounded,
      ),
      _KpiData(
        title: 'Empleado Top',
        value: _payloadString(summary['empleado_top_name'], fallback: 'Sin datos'),
        caption: _money(_payloadAmount(summary['empleado_top_total'])),
        color: _financeNegative,
        icon: Icons.emoji_events_rounded,
      ),
      _KpiData(
        title: 'Servicio Top',
        value: _payloadString(summary['servicio_top_name'], fallback: 'Sin datos'),
        caption: '${_payloadInt(summary['servicio_top_count'])} ventas',
        color: _financePositive,
        icon: Icons.star_rounded,
      ),
    ];
  }

  List<_TrendPoint> get _performanceTrendFromPayload => _listValue(
        _performancePayload?['trend'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _TrendPoint(
          label: _payloadString(row['label'], fallback: '-'),
          ingresos: _payloadAmount(row['ingresos']),
          egresos: _payloadAmount(row['egresos']),
        );
      }).toList();

  List<_CategoryAmount> get _performanceProfitableServicesFromPayload => _listValue(
        _performancePayload?['profitable_services'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: 'Sin servicio'),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<_CategoryAmount> get _performanceBranchBreakdownFromPayload => _listValue(
        _performancePayload?['branch_breakdown'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _CategoryAmount(
          _payloadString(row['label'], fallback: kDefaultBranchName),
          _payloadAmount(row['value']),
        );
      }).toList();

  List<_TherapistPerformance> get _performanceRowsFromPayload => _listValue(
        _performancePayload?['rows'],
      ).map((entry) {
        final row = _mapValue(entry);
        final therapist = _TherapistPerformance(
          id: _payloadString(row['id'], fallback: 'sin_terapeuta'),
          name: _payloadString(row['name'], fallback: 'Sin terapeuta'),
        );
        therapist.servicesCompleted = _payloadInt(row['services_completed']);
        therapist.cancelled = _payloadInt(row['cancelled']);
        therapist.noShows = _payloadInt(row['no_shows']);
        therapist.revenue = _payloadAmount(row['revenue']);
        return therapist;
      }).toList();

  List<_SummaryRow> get _performanceSummaryRowsFromPayload => _listValue(
        _performancePayload?['summary_rows'],
      ).map((entry) {
        final row = _mapValue(entry);
        return _SummaryRow(
          _payloadString(row['label'], fallback: '-'),
          _payloadString(row['value'], fallback: 'Sin datos'),
        );
      }).toList();

  bool _isPaidSale(Map<String, dynamic> sale) {
    final paymentStatus = (sale['payment_status'] as String?)?.toLowerCase();
    final legacyStatus = (sale['status'] as String?)?.toLowerCase();
    final saleStatus = (sale['sale_status'] as String?)?.toLowerCase();
    return _isPaidLikeStatus(paymentStatus) ||
        _isPaidLikeStatus(legacyStatus) ||
        _isPaidLikeStatus(saleStatus);
  }

  double _amount(dynamic value) => (value as num?)?.toDouble() ?? 0;

  bool _isPaidLikeStatus(String? status) {
    final normalized = (status ?? '').trim().toLowerCase();
    return normalized == 'paid' ||
        normalized == 'pagado' ||
        normalized == 'completed' ||
        normalized == 'completado' ||
        normalized == 'complete' ||
        normalized == 'settled';
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  double _saleTotal(Map<String, dynamic> sale) {
    final directTotal = _amount(sale['total']);
    if (directTotal > 0) return directTotal;

    final subtotal = _amount(sale['subtotal']);
    final discount = _amount(sale['discount']);
    final tax = _amount(sale['tax']);
    final computed = subtotal - discount + tax;
    if (computed > 0) return computed;

    final items = sale['sale_items'];
    if (items is List) {
      final sum = items.fold<double>(0, (acc, item) {
        if (item is! Map) return acc;
        final row = Map<String, dynamic>.from(item);
        final totalPrice = _amount(row['total_price']);
        if (totalPrice > 0) return acc + totalPrice;
        final unitPrice = _amount(row['unit_price']) > 0
            ? _amount(row['unit_price'])
            : _amount(row['price']);
        final quantity = (row['quantity'] as num?)?.toDouble() ?? 1;
        return acc + (unitPrice * quantity);
      });
      if (sum > 0) return sum;
    }

    return 0;
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

  DateTime get _previousMonthStart => DateTime(_monthStart.year, _monthStart.month - 1, 1);

  DateTime get _previousWeekStart => _weekStart.subtract(const Duration(days: 7));

  List<Map<String, dynamic>> get _paidSales => _sales.where(_isPaidSale).toList();

  Set<String> get _paidSaleBookingIds => _paidSales
      .map((sale) => sale['appointment_id']?.toString().trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();

  bool _isPaidBooking(Map<String, dynamic> booking) {
    final status = (booking['status'] as String?)?.toLowerCase();
    return _isPaidLikeStatus(status);
  }

  List<Map<String, dynamic>> get _paidBookingsWithoutSale => _bookings.where((booking) {
    final bookingId = booking['id']?.toString().trim() ?? '';
    if (bookingId.isEmpty) return false;
    return _isPaidBooking(booking) && !_paidSaleBookingIds.contains(bookingId);
  }).toList();

  double _bookingIncome(Map<String, dynamic> booking) {
    final service = booking['service'];
    if (service is Map) {
      return _amount(service['price']);
    }
    return 0;
  }

  double _salesTotalSince(DateTime from) {
    final paidSalesTotal = _paidSales.where((sale) {
      final date = _parseDate(sale['created_at']);
      return date != null && !date.isBefore(from);
    }).fold<double>(0, (sum, sale) => sum + _saleTotal(sale));

    final paidBookingsTotal = _paidBookingsWithoutSale.where((booking) {
      final date = _parseDate(booking['booking_date']);
      return date != null && !date.isBefore(from);
    }).fold<double>(0, (sum, booking) => sum + _bookingIncome(booking));

    return paidSalesTotal + paidBookingsTotal;
  }

  double _salesTotalBetween(DateTime from, DateTime toExclusive) {
    final paidSalesTotal = _paidSales.where((sale) {
      final date = _parseDate(sale['created_at']);
      return date != null && !date.isBefore(from) && date.isBefore(toExclusive);
    }).fold<double>(0, (sum, sale) => sum + _saleTotal(sale));

    final paidBookingsTotal = _paidBookingsWithoutSale.where((booking) {
      final date = _parseDate(booking['booking_date']);
      return date != null && !date.isBefore(from) && date.isBefore(toExclusive);
    }).fold<double>(0, (sum, booking) => sum + _bookingIncome(booking));

    return paidSalesTotal + paidBookingsTotal;
  }

  double _expensesTotalBetween(DateTime from, DateTime toExclusive) {
    return _allExpenseEntries.where((entry) {
      return !entry.date.isBefore(from) && entry.date.isBefore(toExclusive);
    }).fold<double>(0, (sum, entry) => sum + entry.amount);
  }

  int _salesCountSince(DateTime from) {
    final paidSalesCount = _paidSales.where((sale) {
      final date = _parseDate(sale['created_at']);
      return date != null && !date.isBefore(from);
    }).length;

    final paidBookingsCount = _paidBookingsWithoutSale.where((booking) {
      final date = _parseDate(booking['booking_date']);
      return date != null && !date.isBefore(from);
    }).length;

    return paidSalesCount + paidBookingsCount;
  }

  double get _ingresosTotales =>
      _paidSales.fold<double>(0, (sum, sale) => sum + _saleTotal(sale)) +
      _paidBookingsWithoutSale.fold<double>(
        0,
        (sum, booking) => sum + _bookingIncome(booking),
      );

  double get _egresosTotales => _allExpenseEntries.fold<double>(
        0,
        (sum, entry) => sum + entry.amount,
      );

  double get _ticketPromedio {
    final operationCount = _paidSales.length + _paidBookingsWithoutSale.length;
    if (operationCount == 0) return 0;
    return _ingresosTotales / operationCount;
  }

  int get _paidOperationsCount => _paidSales.length + _paidBookingsWithoutSale.length;

  double get _gananciaNeta => _ingresosTotales - _egresosTotales;

  double get _margenGanancia =>
      _ingresosTotales == 0 ? 0 : (_gananciaNeta / _ingresosTotales) * 100;

  int get _serviciosRealizados => _bookings.where((booking) {
        final status = (booking['status'] as String?)?.toLowerCase();
        return status == 'completed' || status == 'paid';
      }).length;

  int get _citasCompletadas => _bookings
      .where(
        (booking) => (booking['status'] as String?)?.toLowerCase() == 'completed',
      )
      .length;

  int get _citasPendientesCobro => _bookings
      .where(
        (booking) =>
            (booking['status'] as String?)?.toLowerCase() == 'awaiting_payment',
      )
      .length;

  double get _cuentasPorCobrarEstimadas => _ticketPromedio * _citasPendientesCobro;

  Map<String, double> get _ventasPorMetodo {
    final map = <String, double>{};
    for (final sale in _paidSales) {
      final method = (sale['payment_method'] as String?)?.trim();
      final key = method == null || method.isEmpty ? 'Pendiente' : _humanizeLabel(method);
      map[key] = (map[key] ?? 0) + _amount(sale['total']);
    }
    return map;
  }

  Map<String, double> get _ventasPorTipo {
    final map = <String, double>{
      'Servicios': 0,
      'Productos': 0,
      'Membresias': 0,
      'Gift Cards': 0,
    };
    for (final sale in _paidSales) {
      final items = _saleItems(sale);
      for (final item in items) {
        final label =
            ((item['description'] ?? item['name']) as String? ?? '').toLowerCase();
        final total = _saleItemAmount(item);
        if (label.contains('gift')) {
          map['Gift Cards'] = (map['Gift Cards'] ?? 0) + total;
        } else if (label.contains('membres')) {
          map['Membresias'] = (map['Membresias'] ?? 0) + total;
        } else if (item['service_id'] != null) {
          map['Servicios'] = (map['Servicios'] ?? 0) + total;
        } else {
          map['Productos'] = (map['Productos'] ?? 0) + total;
        }
      }
    }
    return map;
  }

  Map<String, double> get _servicioRevenue {
    final map = <String, double>{};
    for (final sale in _paidSales) {
      for (final item in _saleItems(sale)) {
        final label =
            ((item['description'] ?? item['name']) as String? ?? 'Sin concepto')
                .trim();
        map[label] = (map[label] ?? 0) + _saleItemAmount(item);
      }
    }
    return map;
  }

  Map<String, int> get _topServiciosCount {
    final map = <String, int>{};
    for (final sale in _paidSales) {
      for (final item in _saleItems(sale)) {
        final label =
            ((item['description'] ?? item['name']) as String? ?? 'Sin concepto')
                .trim();
        map[label] = (map[label] ?? 0) + ((item['quantity'] as num?)?.toInt() ?? 1);
      }
    }
    return map;
  }

  List<_TherapistPerformance> get _therapistPerformance {
    final byTherapist = <String, _TherapistPerformance>{};
    final saleByAppointment = <String, Map<String, dynamic>>{};

    for (final sale in _paidSales) {
      final appointmentId = sale['appointment_id']?.toString();
      if (appointmentId != null && appointmentId.isNotEmpty) {
        saleByAppointment[appointmentId] = sale;
      }
    }

    for (final booking in _bookings) {
      final therapistId = booking['therapist_id']?.toString() ?? 'sin_terapeuta';
      final therapistMap = booking['therapist'] as Map?;
      final therapistName = therapistMap?['full_name']?.toString() ??
          therapistMap?['name']?.toString() ??
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

  List<_ExpenseEntry> get _allExpenseEntries => _detailedExpenses
      .map(
        (entry) => _ExpenseEntry(
          category: entry.category,
          title: entry.title,
          subtitle: entry.subtitle,
          amount: entry.amount,
          status: entry.status,
          date: entry.date,
        ),
      )
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  List<_DetailedExpenseRow> get _detailedExpenses {
    final result = <_DetailedExpenseRow>[];

    for (final row in _fixedExpenses) {
      final title = row['description']?.toString().trim().isNotEmpty == true
          ? row['description'].toString()
          : (row['category']?.toString() ?? 'Gasto fijo');
      final category = 'Gastos Fijos';
      final rawCategory = row['category']?.toString() ?? category;
      final status = row['status']?.toString() ?? 'pendiente';
      result.add(
        _DetailedExpenseRow(
          category: category,
          rawCategory: rawCategory,
          title: title,
          subtitle: row['frequency']?.toString() ?? 'Sin frecuencia',
          amount: _amount(row['amount']),
          status: status,
          date: _expenseDate(row),
          paymentMethod: row['payment_method']?.toString() ?? 'Sin definir',
          responsible: row['name']?.toString().trim().isNotEmpty == true
              ? row['name'].toString()
              : 'Sahara Club Spa',
          hasReceipt: true,
          source: 'gasto_fijo',
        ),
      );
    }

    for (final row in _supplierExpenses) {
      final category = 'Proveedores';
      final rawCategory = row['category']?.toString() ?? category;
      final status = row['status']?.toString() ?? 'pendiente';
      final title = row['description']?.toString().trim().isNotEmpty == true
          ? row['description'].toString()
          : (row['supplier_name']?.toString() ?? 'Proveedor');
      result.add(
        _DetailedExpenseRow(
          category: category,
          rawCategory: rawCategory,
          title: title,
          subtitle: row['supplier_name']?.toString() ?? 'Proveedor',
          amount: _amount(row['amount']),
          status: status,
          date: _expenseDate(row),
          paymentMethod: row['payment_method']?.toString() ?? 'Sin definir',
          responsible: row['supplier_name']?.toString().trim().isNotEmpty == true
              ? row['supplier_name'].toString()
              : 'Proveedor',
          hasReceipt: row['invoice_number']?.toString().trim().isNotEmpty == true,
          source: 'proveedor',
        ),
      );
    }

    for (final row in _payrollEntries) {
      final title = 'Pago de nomina';
      final responsible = _staffNameById(row['employee_id']?.toString());
      result.add(
        _DetailedExpenseRow(
          category: 'Nomina',
          rawCategory: 'Nomina',
          title: title,
          subtitle: responsible,
          amount: _amount(row['total_pay']),
          status: row['payment_status']?.toString() ?? 'pendiente',
          date: _expenseDate(row, fallbackKey: 'paid_at'),
          paymentMethod: row['payment_method']?.toString() ?? 'Transferencia',
          responsible: responsible,
          hasReceipt: true,
          source: 'nomina',
        ),
      );
    }

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Map<String, double> get _expenseByCategory {
    final map = <String, double>{
      'Gastos Fijos': 0,
      'Nomina': 0,
      'Proveedores': 0,
    };

    for (final row in _fixedExpenses) {
      map['Gastos Fijos'] = (map['Gastos Fijos'] ?? 0) + _amount(row['amount']);
    }
    for (final row in _payrollEntries) {
      map['Nomina'] = (map['Nomina'] ?? 0) + _amount(row['total_pay']);
    }
    for (final row in _supplierExpenses) {
      map['Proveedores'] = (map['Proveedores'] ?? 0) + _amount(row['amount']);
    }
    return map;
  }

  List<_TrendPoint> get _monthlyTrend {
    final now = DateTime.now();
    final daysInView = math.min(now.day, 10);
    return List.generate(daysInView, (index) {
      final date = DateTime(now.year, now.month, index + 1);
      final next = date.add(const Duration(days: 1));
      return _TrendPoint(
        label: DateFormat('d MMM', 'es_MX').format(date),
        ingresos: _salesTotalBetween(date, next),
        egresos: _expensesTotalBetween(date, next),
      );
    });
  }

  List<_TrendPoint> get _incomeComparisonTrend {
    final now = DateTime.now();
    final daysInView = math.min(now.day, 10);
    return List.generate(daysInView, (index) {
      final current = DateTime(now.year, now.month, index + 1);
      final previous = DateTime(now.year, now.month - 1, index + 1);
      return _TrendPoint(
        label: DateFormat('d MMM', 'es_MX').format(current),
        ingresos: _salesTotalBetween(current, current.add(const Duration(days: 1))),
        egresos: _salesTotalBetween(previous, previous.add(const Duration(days: 1))),
      );
    });
  }

  List<_TrendPoint> get _expenseComparisonTrend {
    final now = DateTime.now();
    final daysInView = math.min(now.day, 10);
    return List.generate(daysInView, (index) {
      final current = DateTime(now.year, now.month, index + 1);
      final previous = DateTime(now.year, now.month - 1, index + 1);
      return _TrendPoint(
        label: DateFormat('d MMM', 'es_MX').format(current),
        ingresos: _expensesTotalBetween(
          current,
          current.add(const Duration(days: 1)),
        ),
        egresos: _expensesTotalBetween(
          previous,
          previous.add(const Duration(days: 1)),
        ),
      );
    });
  }

  Map<String, double> get _expenseStatusBreakdown {
    final map = <String, double>{};
    for (final row in _detailedExpenses) {
      final key = _normalizeExpenseStatusLabel(row.status);
      map[key] = (map[key] ?? 0) + row.amount;
    }
    return map;
  }

  List<Map<String, dynamic>> get _sortedFixedExpenses {
    final rows = [..._fixedExpenses];
    rows.sort((a, b) => _fixedDueDate(a).compareTo(_fixedDueDate(b)));
    return rows;
  }

  Map<String, double> get _fixedExpensesByCategory {
    final map = <String, double>{};
    for (final row in _fixedExpenses) {
      final key = _humanizeLabel(row['category']?.toString() ?? 'Sin categoria');
      map[key] = (map[key] ?? 0) + _amount(row['amount']);
    }
    return map;
  }

  Map<String, double> get _fixedExpensesByStatus {
    final map = <String, double>{};
    for (final row in _fixedExpenses) {
      final key = _normalizeExpenseStatusLabel(
        row['status']?.toString() ?? 'pendiente',
      );
      map[key] = (map[key] ?? 0) + _amount(row['amount']);
    }
    return map;
  }

  double get _fixedExpensesTotal =>
      _fixedExpenses.fold<double>(0, (sum, row) => sum + _amount(row['amount']));

  double get _fixedExpensesPaidTotal => _fixedExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'pagado')
      .fold<double>(0, (sum, row) => sum + _amount(row['amount']));

  double get _fixedExpensesPendingTotal => _fixedExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'pendiente')
      .fold<double>(0, (sum, row) => sum + _amount(row['amount']));

  double get _fixedExpensesOverdueTotal => _fixedExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'vencido')
      .fold<double>(0, (sum, row) => sum + _amount(row['amount']));

  int get _fixedExpensesPaidCount => _fixedExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'pagado')
      .length;

  int get _fixedExpensesPendingCount => _fixedExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'pendiente')
      .length;

  int get _fixedExpensesOverdueCount => _fixedExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'vencido')
      .length;

  _UpcomingFixedExpense? get _nextFixedExpense {
    final pending = _fixedExpenses
        .where((row) => (row['status']?.toString().toLowerCase() ?? '') != 'pagado')
        .toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => _fixedDueDate(a).compareTo(_fixedDueDate(b)));
    final row = pending.first;
    return _UpcomingFixedExpense(
      title: row['description']?.toString().trim().isNotEmpty == true
          ? row['description'].toString()
          : _humanizeLabel(row['category']?.toString() ?? 'Gasto fijo'),
      amount: _amount(row['amount']),
      dueDate: _fixedDueDate(row),
      status: row['status']?.toString() ?? 'pendiente',
    );
  }

  List<_MonthlyPoint> get _fixedExpenseMonthlySeries {
    final now = DateTime.now();
    final points = <_MonthlyPoint>[];
    for (var offset = 5; offset >= 0; offset--) {
      final monthStart = DateTime(now.year, now.month - offset, 1);
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
      final total = _fixedExpenses.where((row) {
        final createdAt = _expenseDate(row);
        return !createdAt.isBefore(monthStart) && createdAt.isBefore(nextMonth);
      }).fold<double>(0, (sum, row) => sum + _amount(row['amount']));
      points.add(
        _MonthlyPoint(
          label: DateFormat('MMM', 'es_MX').format(monthStart),
          value: total,
        ),
      );
    }
    return points;
  }

  double get _fixedExpenseMonthlyAverage {
    final populated = _fixedExpenseMonthlySeries.where((point) => point.value > 0).toList();
    if (populated.isEmpty) return _fixedExpensesTotal;
    final total = populated.fold<double>(0, (sum, point) => sum + point.value);
    return total / populated.length;
  }

  double get _ingresosHoy => _salesTotalBetween(
        _todayStart,
        _todayStart.add(const Duration(days: 1)),
      );

  double get _gastosHoy => _expensesTotalBetween(
        _todayStart,
        _todayStart.add(const Duration(days: 1)),
      );

  double get _cuentasPorPagarTotales =>
      _fixedExpenses
          .where((row) => (row['status']?.toString().toLowerCase() ?? '') != 'pagado')
          .fold<double>(0, (sum, row) => sum + _amount(row['amount'])) +
      _pendingSupplierAmount +
      _pendingPayrollAmount;

  double get _cajaChicaBaseEstimda => 5000;

  List<_DetailedExpenseRow> get _pettyCashMovements {
    final rows = _detailedExpenses.where((row) {
      final text =
          '${row.title} ${row.subtitle} ${row.rawCategory} ${row.paymentMethod}'.toLowerCase();
      return row.amount <= 1200 ||
          text.contains('caja chica') ||
          text.contains('efectivo') ||
          text.contains('operativ') ||
          text.contains('limpieza') ||
          text.contains('insumo');
    }).toList();
    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows.take(20).toList();
  }

  double get _cajaChicaSalidas =>
      _pettyCashMovements.fold<double>(0, (sum, row) => sum + row.amount);

  double get _cajaChicaDisponible =>
      math.max(_cajaChicaBaseEstimda - _cajaChicaSalidas, 0);

  double get _flujoEfectivoActual =>
      _salesTotalSince(_monthStart) -
      _expensesTotalBetween(
        _monthStart,
        DateTime.now().add(const Duration(days: 1)),
      );

  double get _crecimientoVsMesAnterior {
    final previous = _salesTotalBetween(_previousMonthStart, _monthStart);
    final current = _salesTotalSince(_monthStart);
    if (previous == 0) return current == 0 ? 0 : 100;
    return ((current - previous) / previous) * 100;
  }

  List<_MonthlyPoint> get _netProfitMonthlySeries {
    final now = DateTime.now();
    final points = <_MonthlyPoint>[];
    for (var offset = 5; offset >= 0; offset--) {
      final monthStart = DateTime(now.year, now.month - offset, 1);
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
      final ingresos = _salesTotalBetween(monthStart, nextMonth);
      final egresos = _expensesTotalBetween(monthStart, nextMonth);
      points.add(
        _MonthlyPoint(
          label: DateFormat('MMM', 'es_MX').format(monthStart),
          value: ingresos - egresos,
        ),
      );
    }
    return points;
  }

  List<_MonthlyPoint> get _cashFlowMonthlySeries {
    final now = DateTime.now();
    final points = <_MonthlyPoint>[];
    for (var offset = 5; offset >= 0; offset--) {
      final monthStart = DateTime(now.year, now.month - offset, 1);
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
      final ingresos = _salesTotalBetween(monthStart, nextMonth);
      final egresos = _expensesTotalBetween(monthStart, nextMonth);
      points.add(
        _MonthlyPoint(
          label: DateFormat('MMM', 'es_MX').format(monthStart),
          value: ingresos - egresos,
        ),
      );
    }
    return points;
  }

  List<_CategoryAmount> get _topProvidersBySpend {
    final totals = <String, double>{};
    for (final row in _supplierExpenses) {
      final name = _supplierName(row);
      totals[name] = (totals[name] ?? 0) + _amount(row['amount']);
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(5)
        .map((entry) => _CategoryAmount(entry.key, entry.value))
        .toList();
  }

  List<Map<String, dynamic>> get _payableRows {
    final rows = <Map<String, dynamic>>[];
    for (final row in _fixedExpenses) {
      final status = row['status']?.toString().toLowerCase() ?? 'pendiente';
      if (status == 'pagado') continue;
      rows.add({
        'origen': 'Gasto fijo',
        'concepto': row['description']?.toString().trim().isNotEmpty == true
            ? row['description'].toString()
            : _humanizeLabel(row['category']?.toString() ?? 'Gasto fijo'),
        'responsable': row['name']?.toString().trim().isNotEmpty == true
            ? row['name'].toString()
            : 'Sahara Club Spa',
        'fecha': _fixedDueDate(row),
        'monto': _amount(row['amount']),
        'estado': row['status']?.toString() ?? 'pendiente',
      });
    }
    for (final row in _supplierExpenses) {
      final status = row['status']?.toString().toLowerCase() ?? 'pendiente';
      if (status == 'pagado') continue;
      rows.add({
        'origen': 'Proveedor',
        'concepto': row['description']?.toString().trim().isNotEmpty == true
            ? row['description'].toString()
            : _supplierName(row),
        'responsable': _supplierName(row),
        'fecha': _expenseDate(row),
        'monto': _amount(row['amount']),
        'estado': row['status']?.toString() ?? 'pendiente',
      });
    }
    for (final row in _payrollEntries) {
      final status = row['payment_status']?.toString().toLowerCase() ?? 'pendiente';
      if (status == 'pagado') continue;
      rows.add({
        'origen': 'Nomina',
        'concepto': 'Pago de nomina',
        'responsable': _staffNameById(row['employee_id']?.toString()),
        'fecha': _payrollEntryDate(row),
        'monto': _amount(row['total_pay']),
        'estado': row['payment_status']?.toString() ?? 'pendiente',
      });
    }
    rows.sort(
      (a, b) => (a['fecha'] as DateTime).compareTo(b['fecha'] as DateTime),
    );
    return rows;
  }

  List<Map<String, dynamic>> get _receivableRows {
    final rows = <Map<String, dynamic>>[];
    for (final booking in _bookings) {
      final status = booking['status']?.toString().toLowerCase() ?? '';
      if (status != 'awaiting_payment') continue;
      final service = _mapValue(booking['service']);
      final therapist = _mapValue(booking['therapist']);
      final date = _parseDate(booking['booking_date']) ?? DateTime.now();
      rows.add({
        'cliente': 'Cliente agenda',
        'servicio': _payloadString(service['name'], fallback: 'Servicio'),
        'terapeuta': _payloadString(therapist['full_name'], fallback: 'Sin terapeuta'),
        'fecha': date,
        'monto': _payloadAmount(service['price']),
        'estado': date.isBefore(_todayStart) ? 'vencido' : 'pendiente',
      });
    }
    rows.sort(
      (a, b) => (a['fecha'] as DateTime).compareTo(b['fecha'] as DateTime),
    );
    return rows;
  }

  List<_MonthlyPoint> get _payablesMonthlySeries {
    final now = DateTime.now();
    final points = <_MonthlyPoint>[];
    for (var offset = 5; offset >= 0; offset--) {
      final monthStart = DateTime(now.year, now.month - offset, 1);
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
      final total = _payableRows.where((row) {
        final date = row['fecha'] as DateTime;
        return !date.isBefore(monthStart) && date.isBefore(nextMonth);
      }).fold<double>(0, (sum, row) => sum + (row['monto'] as double));
      points.add(
        _MonthlyPoint(
          label: DateFormat('MMM', 'es_MX').format(monthStart),
          value: total,
        ),
      );
    }
    return points;
  }

  List<_MonthlyPoint> get _receivablesMonthlySeries {
    final now = DateTime.now();
    final points = <_MonthlyPoint>[];
    for (var offset = 5; offset >= 0; offset--) {
      final monthStart = DateTime(now.year, now.month - offset, 1);
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
      final total = _receivableRows.where((row) {
        final date = row['fecha'] as DateTime;
        return !date.isBefore(monthStart) && date.isBefore(nextMonth);
      }).fold<double>(0, (sum, row) => sum + (row['monto'] as double));
      points.add(
        _MonthlyPoint(
          label: DateFormat('MMM', 'es_MX').format(monthStart),
          value: total,
        ),
      );
    }
    return points;
  }

  List<_MonthlyPoint> get _pettyCashMonthlySeries {
    final now = DateTime.now();
    final points = <_MonthlyPoint>[];
    for (var offset = 5; offset >= 0; offset--) {
      final monthStart = DateTime(now.year, now.month - offset, 1);
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
      final total = _pettyCashMovements.where((row) {
        final date = row.date;
        return !date.isBefore(monthStart) && date.isBefore(nextMonth);
      }).fold<double>(0, (sum, row) => sum + row.amount);
      points.add(
        _MonthlyPoint(
          label: DateFormat('MMM', 'es_MX').format(monthStart),
          value: total,
        ),
      );
    }
    return points;
  }

  List<_CategoryAmount> get _payablesByOrigin {
    final map = <String, double>{};
    for (final row in _payableRows) {
      final key = row['origen']?.toString() ?? 'Pendiente';
      map[key] = (map[key] ?? 0) + (row['monto'] as double);
    }
    return map.entries
        .map((entry) => _CategoryAmount(entry.key, entry.value))
        .toList();
  }

  List<_CategoryAmount> get _receivablesByStatus {
    final map = <String, double>{};
    for (final row in _receivableRows) {
      final key = _normalizeExpenseStatusLabel(row['estado']?.toString() ?? 'pendiente');
      map[key] = (map[key] ?? 0) + (row['monto'] as double);
    }
    return map.entries
        .map((entry) => _CategoryAmount(entry.key, entry.value))
        .toList();
  }

  List<_MetricAlert> get _alerts {
    final alerts = <_MetricAlert>[];
    final pendingPayroll = _pendingPayrollAmount;
    final pendingSuppliers = _pendingSupplierAmount;

    if (_citasPendientesCobro > 0) {
      alerts.add(
        _MetricAlert(
          title: 'Cobros pendientes',
          message:
              'Hay $_citasPendientesCobro citas esperando cobro estimado de ${_money(_cuentasPorCobrarEstimadas)}.',
          tone: _financeBlue,
          icon: Icons.receipt_long_outlined,
          stamp: 'Hoy',
        ),
      );
    }
    if (pendingPayroll > 0) {
      alerts.add(
        _MetricAlert(
          title: 'Nomina pendiente',
          message: 'Quedan ${_money(pendingPayroll)} pendientes por pagar al equipo.',
          tone: _financeNegative,
          icon: Icons.badge_outlined,
          stamp: 'Hoy',
        ),
      );
    }
    if (pendingSuppliers > 0) {
      alerts.add(
        _MetricAlert(
          title: 'Proveedores pendientes',
          message:
              'Se acumulan ${_money(pendingSuppliers)} en facturas de proveedores.',
          tone: SaharaTheme.gold,
          icon: Icons.local_shipping_outlined,
          stamp: 'Hoy',
        ),
      );
    }
    if (_cajaChicaDisponible < 1500) {
      alerts.add(
        _MetricAlert(
          title: 'Caja chica baja',
          message: 'La caja chica estimada esta en ${_money(_cajaChicaDisponible)} y requiere reposicion.',
          tone: SaharaTheme.gold,
          icon: Icons.account_balance_wallet_outlined,
          stamp: 'Caja',
        ),
      );
    }
    final unusualExpense = _detailedExpenses.firstWhere(
      (entry) => entry.amount > (_dailyExpenseAverage * 2.5) && entry.amount > 1500,
      orElse: () => _DetailedExpenseRow.empty(),
    );
    if (!unusualExpense.isEmpty) {
      alerts.add(
        _MetricAlert(
          title: 'Gasto inusual',
          message: 'Se detecto un egreso fuera de rango en ${unusualExpense.title} por ${_money(unusualExpense.amount)}.',
          tone: _financeNegative,
          icon: Icons.report_problem_rounded,
          stamp: 'Analitica',
        ),
      );
    }
    if (_margenGanancia < 20 && _ingresosTotales > 0) {
      alerts.add(
        _MetricAlert(
          title: 'Margen presionado',
          message: 'El margen actual es ${_percent(_margenGanancia)} y requiere revision.',
          tone: _financeViolet,
          icon: Icons.show_chart_rounded,
          stamp: 'Analitica',
        ),
      );
    }
    if (_salesTotalSince(_todayStart) == 0) {
      alerts.add(
        _MetricAlert(
          title: 'Sin ventas hoy',
          message: 'No hay ingresos cobrados registrados durante la jornada de hoy.',
          tone: _financeMuted,
          icon: Icons.event_busy_outlined,
          stamp: 'Hoy',
        ),
      );
    }
    final ingresosSemana = _salesTotalSince(_weekStart);
    final ingresosSemanaPrevia = _salesTotalBetween(_previousWeekStart, _weekStart);
    if (ingresosSemanaPrevia > 0 && ingresosSemana < (ingresosSemanaPrevia * 0.75)) {
      alerts.add(
        _MetricAlert(
          title: 'Caida de ingresos',
          message: 'La semana actual va ${_percent(((ingresosSemana - ingresosSemanaPrevia) / ingresosSemanaPrevia) * 100)} contra la anterior.',
          tone: _financeNegative,
          icon: Icons.trending_down_rounded,
          stamp: 'Semana',
        ),
      );
    }
    final overdueReceivables = _receivableRows.where(
      (row) => (row['estado']?.toString().toLowerCase() ?? '') == 'vencido',
    );
    if (overdueReceivables.isNotEmpty) {
      final total = overdueReceivables.fold<double>(
        0,
        (sum, row) => sum + (row['monto'] as double),
      );
      alerts.add(
        _MetricAlert(
          title: 'Cuenta por cobrar vencida',
          message: 'Hay ${overdueReceivables.length} cobros vencidos por ${_money(total)}.',
          tone: _financeBlue,
          icon: Icons.move_to_inbox_rounded,
          stamp: 'Cobranza',
        ),
      );
    }
    final overduePayables = _payableRows.where((row) {
      final status = row['estado']?.toString().toLowerCase() ?? '';
      return status == 'vencido';
    });
    if (overduePayables.isNotEmpty) {
      final total = overduePayables.fold<double>(
        0,
        (sum, row) => sum + (row['monto'] as double),
      );
      alerts.add(
        _MetricAlert(
          title: 'Cuenta por pagar vencida',
          message: 'Quedan ${overduePayables.length} pagos vencidos por ${_money(total)}.',
          tone: _financeNegative,
          icon: Icons.outbox_rounded,
          stamp: 'Pagos',
        ),
      );
    }
    if (alerts.isEmpty) {
      alerts.add(
        const _MetricAlert(
          title: 'Sin alertas criticas',
          message: 'La operacion financiera se ve estable con los datos actuales.',
          tone: _financePositive,
          icon: Icons.verified_outlined,
          stamp: 'Actual',
        ),
      );
    }
    return alerts;
  }

  double get _pendingPayrollAmount => _payrollEntries
      .where(
        (row) => (row['payment_status'] as String?)?.toLowerCase() != 'pagado',
      )
      .fold<double>(0, (sum, row) => sum + _amount(row['total_pay']));

  int get _pendingPayrollCount => _payrollEntries
      .where(
        (row) => (row['payment_status'] as String?)?.toLowerCase() != 'pagado',
      )
      .length;

  double get _pendingSupplierAmount => _supplierExpenses
      .where((row) => (row['status'] as String?)?.toLowerCase() != 'pagado')
      .fold<double>(0, (sum, row) => sum + _amount(row['amount']));

  int get _pendingSupplierCount => _supplierExpenses
      .where((row) => (row['status'] as String?)?.toLowerCase() != 'pagado')
      .length;

  List<Map<String, dynamic>> get _sortedPayrollEntries {
    final rows = [..._payrollEntries];
    rows.sort((a, b) => _payrollEntryDate(b).compareTo(_payrollEntryDate(a)));
    return rows;
  }

  double get _payrollTotal =>
      _payrollEntries.fold<double>(0, (sum, row) => sum + _amount(row['total_pay']));

  double get _payrollBaseTotal =>
      _payrollEntries.fold<double>(0, (sum, row) => sum + _amount(row['base_salary']));

  double get _payrollCommissionsTotal =>
      _payrollEntries.fold<double>(0, (sum, row) => sum + _amount(row['commissions']));

  double get _payrollBonusesTotal =>
      _payrollEntries.fold<double>(0, (sum, row) => sum + _amount(row['bonuses']));

  double get _payrollDeductionsTotal =>
      _payrollEntries.fold<double>(0, (sum, row) => sum + _amount(row['deductions']));

  int get _payrollEmployeeCount {
    final ids = _payrollEntries
        .map((row) => row['employee_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    return ids.length;
  }

  int get _payrollBonusesCount =>
      _payrollEntries.where((row) => _amount(row['bonuses']) > 0).length;

  int get _payrollDeductionsCount =>
      _payrollEntries.where((row) => _amount(row['deductions']) > 0).length;

  double get _payrollPaidTotal => _payrollEntries
      .where((row) => (row['payment_status']?.toString().toLowerCase() ?? '') == 'pagado')
      .fold<double>(0, (sum, row) => sum + _amount(row['total_pay']));

  double get _previousPayrollMonthValue {
    final series = _payrollMonthlySeries;
    if (series.length < 2) return 0;
    return series[series.length - 2].value;
  }

  List<_MonthlyPoint> get _payrollMonthlySeries {
    final now = DateTime.now();
    final points = <_MonthlyPoint>[];
    for (var offset = 5; offset >= 0; offset--) {
      final monthStart = DateTime(now.year, now.month - offset, 1);
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
      final total = _payrollEntries.where((row) {
        final date = _payrollEntryDate(row);
        return !date.isBefore(monthStart) && date.isBefore(nextMonth);
      }).fold<double>(0, (sum, row) => sum + _amount(row['total_pay']));
      points.add(
        _MonthlyPoint(
          label: DateFormat('MMM', 'es_MX').format(monthStart),
          value: total,
        ),
      );
    }
    return points;
  }

  String get _nextPayrollCutoffLabel {
    if (_payrollEntries.isEmpty) return 'Sin corte';
    final pending = _payrollEntries
        .where((row) => (row['payment_status']?.toString().toLowerCase() ?? '') != 'pagado')
        .toList();
    if (pending.isEmpty) return 'Sin pendiente';
    pending.sort((a, b) => _payrollEntryDate(a).compareTo(_payrollEntryDate(b)));
    final row = pending.first;
    final end = DateTime.tryParse(row['period_end']?.toString() ?? '');
    return end == null ? 'Sin fecha' : DateFormat('d MMM', 'es_MX').format(end);
  }

  double get _generalPerformanceScore {
    if (_bookings.isEmpty) return 0;
    return (_serviciosRealizados / _bookings.length) * 100;
  }

  List<_TrendPoint> get _performanceTrend {
    final now = DateTime.now();
    final daysInView = math.min(now.day, 10);
    return List.generate(daysInView, (index) {
      final current = DateTime(now.year, now.month, index + 1);
      final previous = DateTime(now.year, now.month - 1, index + 1);
      return _TrendPoint(
        label: DateFormat('d MMM', 'es_MX').format(current),
        ingresos: _performanceScoreForDay(current),
        egresos: _performanceScoreForDay(previous),
      );
    });
  }

  List<_CategoryAmount> get _serviceProfitability {
    final entries = _servicioRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(4)
        .map((entry) => _CategoryAmount(entry.key, entry.value))
        .toList();
  }

  List<_CategoryAmount> get _branchPerformanceBreakdown {
    return [
      _CategoryAmount(kDefaultBranchName, _ingresosTotales),
    ];
  }

  int get _lowPerformerCount {
    if (_therapistPerformance.isEmpty) return 0;
    final topRevenue = _therapistPerformance.first.revenue;
    return _therapistPerformance.where((entry) {
      if (entry.servicesCompleted == 0) return true;
      if (topRevenue <= 0) return false;
      return entry.revenue < (topRevenue * 0.35) || entry.noShows > 1;
    }).length;
  }

  double _performanceScoreForDay(DateTime day) {
    final dateKey = DateFormat('yyyy-MM-dd').format(day);
    final dayBookings = _bookings.where(
      (booking) => (booking['booking_date']?.toString() ?? '') == dateKey,
    );
    final total = dayBookings.length;
    if (total == 0) return 0;
    final completed = dayBookings.where((booking) {
      final status = (booking['status'] as String?)?.toLowerCase() ?? '';
      return status == 'completed' || status == 'paid';
    }).length;
    return (completed / total) * 100;
  }

  List<Map<String, dynamic>> get _sortedSupplierExpenses {
    final rows = [..._supplierExpenses];
    rows.sort((a, b) => _expenseDate(b).compareTo(_expenseDate(a)));
    return rows;
  }

  Map<String, double> get _supplierExpensesByCategory {
    final map = <String, double>{};
    for (final row in _supplierExpenses) {
      final key = _humanizeLabel(row['category']?.toString() ?? 'Sin categoria');
      map[key] = (map[key] ?? 0) + _amount(row['amount']);
    }
    return map;
  }

  List<_MonthlyPoint> get _supplierExpenseMonthlySeries {
    final now = DateTime.now();
    final points = <_MonthlyPoint>[];
    for (var offset = 5; offset >= 0; offset--) {
      final monthStart = DateTime(now.year, now.month - offset, 1);
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
      final total = _supplierExpenses.where((row) {
        final date = _expenseDate(row);
        return !date.isBefore(monthStart) && date.isBefore(nextMonth);
      }).fold<double>(0, (sum, row) => sum + _amount(row['amount']));
      points.add(
        _MonthlyPoint(
          label: DateFormat('MMM', 'es_MX').format(monthStart),
          value: total,
        ),
      );
    }
    return points;
  }

  Map<String, DateTime> get _supplierLatestMovement {
    final map = <String, DateTime>{};
    for (final row in _supplierExpenses) {
      final supplier = _supplierName(row);
      final date = _expenseDate(row);
      final current = map[supplier];
      if (current == null || date.isAfter(current)) {
        map[supplier] = date;
      }
    }
    return map;
  }

  int get _totalSuppliers => _supplierLatestMovement.length;

  int get _newSuppliersThisMonthCount {
    final firstMovement = <String, DateTime>{};
    for (final row in _supplierExpenses) {
      final supplier = _supplierName(row);
      final date = _expenseDate(row);
      final current = firstMovement[supplier];
      if (current == null || date.isBefore(current)) {
        firstMovement[supplier] = date;
      }
    }
    return firstMovement.values
        .where((date) => !date.isBefore(_monthStart))
        .length;
  }

  int get _activeSuppliersCount {
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    return _supplierLatestMovement.values.where((date) => !date.isBefore(cutoff)).length;
  }

  int get _inactiveSuppliersCount => math.max(_totalSuppliers - _activeSuppliersCount, 0);

  int get _pendingSupplierEntityCount {
    final names = _supplierExpenses
        .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'pendiente')
        .map(_supplierName)
        .toSet();
    return names.length;
  }

  int get _overdueSupplierEntityCount {
    final names = _supplierExpenses
        .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'vencido')
        .map(_supplierName)
        .toSet();
    return names.length;
  }

  double get _supplierPendingAmountOnly => _supplierExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'pendiente')
      .fold<double>(0, (sum, row) => sum + _amount(row['amount']));

  int get _supplierPendingEntriesOnly => _supplierExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'pendiente')
      .length;

  double get _supplierOverdueAmount => _supplierExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'vencido')
      .fold<double>(0, (sum, row) => sum + _amount(row['amount']));

  int get _supplierOverdueEntries => _supplierExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') == 'vencido')
      .length;

  double get _supplierPaidThisMonth => _supplierExpenses.where((row) {
        final status = row['status']?.toString().toLowerCase() ?? '';
        final date = _expenseDate(row);
        return status == 'pagado' && !date.isBefore(_monthStart);
      }).fold<double>(0, (sum, row) => sum + _amount(row['amount']));

  double get _supplierPaidPreviousMonth => _supplierExpenses.where((row) {
        final status = row['status']?.toString().toLowerCase() ?? '';
        final date = _expenseDate(row);
        return status == 'pagado' &&
            !date.isBefore(_previousMonthStart) &&
            date.isBefore(_monthStart);
      }).fold<double>(0, (sum, row) => sum + _amount(row['amount']));

  _SupplierLeader? get _topSupplier {
    final totals = <String, double>{};
    for (final row in _supplierExpenses) {
      final supplier = _supplierName(row);
      totals[supplier] = (totals[supplier] ?? 0) + _amount(row['amount']);
    }
    if (totals.isEmpty) return null;
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _SupplierLeader(name: entries.first.key, total: entries.first.value);
  }

  int get _pendingInvoicesCount => _supplierExpenses
      .where((row) => (row['status']?.toString().toLowerCase() ?? '') != 'pagado')
      .length;

  double get _operationalExpensesTotal => _detailedExpenses
      .where(
        (row) =>
            _isOperationalExpense(row.rawCategory) || _isOperationalExpense(row.title),
      )
      .fold<double>(0, (sum, row) => sum + row.amount);

  double get _expensesWithReceiptTotal => _detailedExpenses
      .where((row) => row.hasReceipt)
      .fold<double>(0, (sum, row) => sum + row.amount);

  double get _expensesWithoutReceiptTotal => _detailedExpenses
      .where((row) => !row.hasReceipt)
      .fold<double>(0, (sum, row) => sum + row.amount);

  double get _unexpectedExpensesTotal => _detailedExpenses
      .where(
        (row) =>
            _isUnexpectedExpense(row.rawCategory) || _isUnexpectedExpense(row.title),
      )
      .fold<double>(0, (sum, row) => sum + row.amount);

  double get _dailyExpenseAverage {
    final days = math.max(DateTime.now().day, 1);
    return _expensesTotalBetween(
          _monthStart,
          DateTime.now().add(const Duration(days: 1)),
        ) /
        days;
  }

  int get _missingReceiptsCount => _detailedExpenses.where((row) => !row.hasReceipt).length;

  String get _topExpenseCategoryLabel {
    final entries = _expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.isEmpty || entries.first.value <= 0 ? 'Sin datos' : entries.first.key;
  }

  String get _topSupplierLabel {
    final bySupplier = <String, double>{};
    for (final row in _supplierExpenses) {
      final supplier = row['supplier_name']?.toString().trim();
      final key = supplier == null || supplier.isEmpty ? 'Proveedor' : supplier;
      bySupplier[key] = (bySupplier[key] ?? 0) + _amount(row['amount']);
    }
    if (bySupplier.isEmpty) return 'Sin datos';
    final entries = bySupplier.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  String _staffNameById(String? id) {
    if (id == null || id.isEmpty) return 'Empleado';
    for (final item in _staff) {
      if (item['id']?.toString() == id) {
        return item['full_name']?.toString() ??
            item['name']?.toString() ??
            'Empleado';
      }
    }
    return 'Empleado';
  }

  String _supplierName(Map<String, dynamic> row) {
    final raw = row['supplier_name']?.toString().trim();
    return raw == null || raw.isEmpty ? 'Proveedor' : raw;
  }

  List<Map<String, dynamic>> _saleItems(Map<String, dynamic> sale) {
    final items = sale['sale_items'];
    if (items is List) {
      return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return const [];
  }

  double _saleItemAmount(Map<String, dynamic> item) {
    final quantity = ((item['quantity'] as num?)?.toDouble() ?? 1);
    final totalPrice = _amount(item['total_price']);
    if (totalPrice > 0) return totalPrice;
    final unitPrice = _amount(item['unit_price']);
    if (unitPrice > 0) return unitPrice * quantity;
    return _amount(item['price']) * quantity;
  }

  DateTime _expenseDate(Map<String, dynamic> row, {String fallbackKey = 'created_at'}) {
    return _parseDate(row['expense_date']) ??
        _parseDate(row[fallbackKey]) ??
        _parseDate(row['created_at']) ??
        DateTime.now();
  }

  DateTime _fixedDueDate(Map<String, dynamic> row) {
    final explicitDueDate = _parseDate(row['due_date']);
    if (explicitDueDate != null) return explicitDueDate;
    final now = DateTime.now();
    final dueDay = (row['due_day'] as num?)?.toInt() ?? 1;
    final safeDay = dueDay.clamp(1, DateUtils.getDaysInMonth(now.year, now.month));
    var candidate = DateTime(now.year, now.month, safeDay);
    final status = row['status']?.toString().toLowerCase() ?? '';
    if (candidate.isBefore(DateTime(now.year, now.month, now.day)) && status != 'vencido') {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final nextSafeDay = dueDay.clamp(
        1,
        DateUtils.getDaysInMonth(nextMonth.year, nextMonth.month),
      );
      candidate = DateTime(nextMonth.year, nextMonth.month, nextSafeDay);
    }
    return candidate;
  }

  DateTime _payrollEntryDate(Map<String, dynamic> row) {
    return _parseDate(row['paid_at']) ??
        _parseDate(row['period_end']) ??
        _parseDate(row['created_at']) ??
        DateTime.now();
  }

  bool _isOperationalExpense(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('operativ') ||
        normalized.contains('limpieza') ||
        normalized.contains('mantenimiento') ||
        normalized.contains('software') ||
        normalized.contains('suscrip') ||
        normalized.contains('publicidad') ||
        normalized.contains('marketing') ||
        normalized.contains('telefono') ||
        normalized.contains('gas') ||
        normalized.contains('agua') ||
        normalized.contains('internet');
  }

  bool _isUnexpectedExpense(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('imprev') ||
        normalized.contains('repar') ||
        normalized.contains('urgente') ||
        normalized.contains('mantenimiento') ||
        normalized.contains('otro');
  }

  String _topFixedExpenseLabel(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 'Sin datos';
    final sorted = [...rows]
      ..sort((a, b) => _amount(b['amount']).compareTo(_amount(a['amount'])));
    final top = sorted.first;
    return top['description']?.toString().trim().isNotEmpty == true
        ? top['description'].toString()
        : _humanizeLabel(top['category']?.toString() ?? 'Gasto fijo');
  }

  String _topFrequencyLabel(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 'Sin datos';
    final map = <String, int>{};
    for (final row in rows) {
      final key = _humanizeLabel(row['frequency']?.toString() ?? 'mensual');
      map[key] = (map[key] ?? 0) + 1;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  String _daysUntilLabel(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = target.difference(today).inDays;
    if (diff <= 0) return 'Hoy';
    if (diff == 1) return '1 dia';
    return '$diff dias';
  }

  Future<void> _openCreateDialog() async {
    if (_selectedSection == 3) {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => const _FixedExpenseDialog(),
      );
      if (created == true) _load();
      return;
    }
    if (_selectedSection == 4) {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => const _SupplierExpenseDialog(),
      );
      if (created == true) _load();
      return;
    }
    if (_selectedSection == 5) {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => _PayrollDialog(staff: _staff),
      );
      if (created == true) _load();
      return;
    }
    if (_selectedSection == 8) {
      _showFinanceSnack('Usa los movimientos detectados o integra el flujo de caja chica en la siguiente fase.');
      return;
    }
    if (_selectedSection == 9 || _selectedSection == 10) {
      _showFinanceSnack('Este atajo queda listo para conectarse al flujo de cobranza/pagos del negocio.');
      return;
    }
    if (_selectedSection == 13 || _selectedSection == 14 || _selectedSection == 15) {
      _showFinanceSnack('La captura guiada de esta seccion queda lista para la siguiente fase.');
    }
  }

  Future<void> _openExpenseEntryShortcut() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _financeBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registrar gasto',
                        style: GoogleFonts.playfairDisplay(
                          color: _financeInk,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Elige el tipo de movimiento que quieres capturar.',
                        style: GoogleFonts.inter(color: _financeMuted),
                      ),
                    ],
                  ),
                ),
                _QuickActionTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Gasto fijo',
                  subtitle: 'Renta, servicios, software y pagos recurrentes.',
                  onTap: () => Navigator.of(context).pop('fixed'),
                ),
                _QuickActionTile(
                  icon: Icons.local_shipping_rounded,
                  title: 'Proveedor',
                  subtitle: 'Compras, facturas y egresos con proveedores.',
                  onTap: () => Navigator.of(context).pop('supplier'),
                ),
                _QuickActionTile(
                  icon: Icons.badge_rounded,
                  title: 'Nomina',
                  subtitle: 'Pagos al personal, comisiones, bonos y ajustes.',
                  onTap: () => Navigator.of(context).pop('payroll'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;
    switch (selected) {
      case 'fixed':
        final created = await showDialog<bool>(
          context: context,
          builder: (_) => const _FixedExpenseDialog(),
        );
        if (created == true) _load();
        break;
      case 'supplier':
        final created = await showDialog<bool>(
          context: context,
          builder: (_) => const _SupplierExpenseDialog(),
        );
        if (created == true) _load();
        break;
      case 'payroll':
        final created = await showDialog<bool>(
          context: context,
          builder: (_) => _PayrollDialog(staff: _staff),
        );
        if (created == true) _load();
        break;
    }
  }

  void _showFinanceSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  Future<void> _copyCsvExport({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final buffer = StringBuffer()..writeln(headers.map(_csvCell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_csvCell).join(','));
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    _showFinanceSnack('$filename copiado al portapapeles en formato CSV.');
  }

  Future<void> _exportCurrentSection() async {
    switch (_selectedSection) {
      case 2:
        final rows = (_recentExpensesFromPayload.isNotEmpty
                ? _recentExpensesFromPayload
                : _detailedExpenses.take(50).toList())
            .map(
              (expense) => [
                DateFormat('yyyy-MM-dd HH:mm').format(expense.date),
                expense.title,
                expense.rawCategory,
                expense.responsible,
                _humanizeLabel(expense.paymentMethod),
                expense.amount.toStringAsFixed(2),
                expense.status,
              ],
            )
            .toList();
        await _copyCsvExport(
          filename: 'finanzas_gastos',
          headers: const [
            'fecha',
            'descripcion',
            'categoria',
            'responsable',
            'metodo_pago',
            'monto',
            'estado',
          ],
          rows: rows,
        );
        return;
      case 3:
        final rows = (_fixedExpenseRowsFromPayload.isNotEmpty
                ? _fixedExpenseRowsFromPayload
                : _sortedFixedExpenses)
            .map(
              (row) => [
                row['description']?.toString() ?? '',
                row['category']?.toString() ?? '',
                row['name']?.toString() ?? '',
                DateFormat('yyyy-MM-dd').format(_fixedDueDate(row)),
                row['frequency']?.toString() ?? '',
                _amount(row['amount']).toStringAsFixed(2),
                row['status']?.toString() ?? '',
              ],
            )
            .toList();
        await _copyCsvExport(
          filename: 'finanzas_gastos_fijos',
          headers: const [
            'descripcion',
            'categoria',
            'proveedor',
            'fecha_pago',
            'frecuencia',
            'monto',
            'estado',
          ],
          rows: rows,
        );
        return;
      case 4:
        final rows = (_supplierRowsFromPayload.isNotEmpty
                ? _supplierRowsFromPayload
                : _sortedSupplierExpenses)
            .map(
              (row) => [
                _safeSupplierName(row),
                row['category']?.toString() ?? '',
                row['invoice_number']?.toString() ?? '',
                row['description']?.toString() ?? '',
                row['payment_method']?.toString() ?? '',
                _amount(row['amount']).toStringAsFixed(2),
                row['status']?.toString() ?? '',
                DateFormat('yyyy-MM-dd').format(_rowExpenseDate(row)),
              ],
            )
            .toList();
        await _copyCsvExport(
          filename: 'finanzas_proveedores',
          headers: const [
            'proveedor',
            'categoria',
            'factura',
            'referencia',
            'metodo_pago',
            'monto',
            'estado',
            'movimiento',
          ],
          rows: rows,
        );
        return;
      case 5:
        final rows = (_payrollRowsFromPayload.isNotEmpty
                ? _payrollRowsFromPayload
                : _sortedPayrollEntries)
            .map(
              (row) => [
                row['employee_name']?.toString() ??
                    _staffNameById(row['employee_id']?.toString()),
                row['employee_role']?.toString() ??
                    _staffRoleById(row['employee_id']?.toString()),
                _amount(row['base_salary']).toStringAsFixed(2),
                _amount(row['commissions']).toStringAsFixed(2),
                _amount(row['bonuses']).toStringAsFixed(2),
                _amount(row['deductions']).toStringAsFixed(2),
                _amount(row['total_pay']).toStringAsFixed(2),
                row['payment_status']?.toString() ?? '',
              ],
            )
            .toList();
        await _copyCsvExport(
          filename: 'finanzas_nomina',
          headers: const [
            'empleado',
            'rol',
            'sueldo_base',
            'comisiones',
            'bonos',
            'anticipos',
            'total_pagar',
            'estado',
          ],
          rows: rows,
        );
        return;
      case 6:
        final rows = (_performanceRowsFromPayload.isNotEmpty
                ? _performanceRowsFromPayload
                : _therapistPerformance)
            .map(
              (row) => [
                row.name,
                _therapistRoleLabel(row.id),
                '${row.servicesCompleted}',
                row.revenue.toStringAsFixed(2),
                (row.servicesCompleted == 0 ? 0 : row.revenue / row.servicesCompleted)
                    .toStringAsFixed(2),
                '${row.cancelled}',
                '${row.noShows}',
              ],
            )
            .toList();
        await _copyCsvExport(
          filename: 'finanzas_rendimiento',
          headers: const [
            'empleado',
            'rol',
            'servicios',
            'ventas',
            'ticket_promedio',
            'canceladas',
            'no_show',
          ],
          rows: rows,
        );
        return;
      case 8:
        await _copyCsvExport(
          filename: 'finanzas_caja_chica',
          headers: const ['fecha', 'concepto', 'responsable', 'monto', 'estado'],
          rows: _pettyCashMovements
              .map(
                (row) => [
                  DateFormat('yyyy-MM-dd').format(row.date),
                  row.title,
                  row.responsible,
                  row.amount.toStringAsFixed(2),
                  row.status,
                ],
              )
              .toList(),
        );
        return;
      case 9:
        await _copyCsvExport(
          filename: 'finanzas_cuentas_por_pagar',
          headers: const ['origen', 'concepto', 'responsable', 'fecha', 'monto', 'estado'],
          rows: _payableRows
              .map(
                (row) => [
                  row['origen']?.toString() ?? '',
                  row['concepto']?.toString() ?? '',
                  row['responsable']?.toString() ?? '',
                  DateFormat('yyyy-MM-dd').format(row['fecha'] as DateTime),
                  (row['monto'] as double).toStringAsFixed(2),
                  row['estado']?.toString() ?? '',
                ],
              )
              .toList(),
        );
        return;
      case 10:
        await _copyCsvExport(
          filename: 'finanzas_cuentas_por_cobrar',
          headers: const ['cliente', 'servicio', 'terapeuta', 'fecha', 'monto', 'estado'],
          rows: _receivableRows
              .map(
                (row) => [
                  row['cliente']?.toString() ?? '',
                  row['servicio']?.toString() ?? '',
                  row['terapeuta']?.toString() ?? '',
                  DateFormat('yyyy-MM-dd').format(row['fecha'] as DateTime),
                  (row['monto'] as double).toStringAsFixed(2),
                  row['estado']?.toString() ?? '',
                ],
              )
              .toList(),
        );
        return;
      case 11:
        await _copyCsvExport(
          filename: 'finanzas_reportes',
          headers: const ['reporte', 'formato', 'estado'],
          rows: const [
            ['Ventas del dia', 'CSV/PDF', 'listo'],
            ['Corte de caja', 'CSV/PDF', 'listo'],
            ['Nomina', 'CSV/PDF', 'listo'],
            ['Gastos', 'CSV/PDF', 'listo'],
            ['Utilidad mensual', 'CSV', 'revision'],
            ['Rendimiento por terapeuta', 'CSV/PDF', 'listo'],
          ],
        );
        return;
      case 12:
        await _copyCsvExport(
          filename: 'finanzas_alertas',
          headers: const ['alerta', 'detalle', 'marca', 'estado'],
          rows: _alerts
              .map((alert) => [alert.title, alert.message, alert.stamp, _alertToneLabel(alert)])
              .toList(),
        );
        return;
      case 13:
        await _copyCsvExport(
          filename: 'finanzas_presupuestos',
          headers: const ['categoria', 'actual', 'presupuesto', 'desviacion', 'estado'],
          rows: [
            [
              'Ingresos',
              _salesTotalSince(_monthStart).toStringAsFixed(2),
              (_salesTotalSince(_monthStart) * 1.15).toStringAsFixed(2),
              ((_salesTotalSince(_monthStart) * 1.15) - _salesTotalSince(_monthStart)).toStringAsFixed(2),
              _salesTotalSince(_monthStart) >= (_salesTotalSince(_monthStart) * .9) ? 'en curso' : 'alerta',
            ],
            [
              'Gastos Fijos',
              _fixedExpensesTotal.toStringAsFixed(2),
              (_fixedExpensesTotal * 1.05).toStringAsFixed(2),
              ((_fixedExpensesTotal * 1.05) - _fixedExpensesTotal).toStringAsFixed(2),
              'controlado',
            ],
          ],
        );
        return;
      case 14:
        await _copyCsvExport(
          filename: 'finanzas_metas',
          headers: const ['meta', 'actual', 'objetivo', 'avance', 'estado'],
          rows: [
            [
              'Ingresos del mes',
              _salesTotalSince(_monthStart).toStringAsFixed(2),
              (_salesTotalSince(_monthStart) * 1.20).toStringAsFixed(2),
              '83.3%',
              'en curso',
            ],
            [
              'Margen',
              _margenGanancia.toStringAsFixed(2),
              '55.0',
              ((_margenGanancia / 55) * 100).toStringAsFixed(2),
              _margenGanancia >= 45 ? 'saludable' : 'riesgo',
            ],
          ],
        );
        return;
      case 15:
        await _copyCsvExport(
          filename: 'finanzas_configuracion',
          headers: const ['parametro', 'valor', 'tipo', 'estado'],
          rows: const [
            ['Metodos de pago activos', '4', 'catalogo', 'activo'],
            ['Alertas inteligentes', '8 reglas', 'automatizacion', 'activo'],
            ['Moneda base', 'MXN', 'general', 'activo'],
            ['Sucursal financiera', 'Matriz', 'alcance', 'activo'],
          ],
        );
        return;
      default:
        _showFinanceSnack('La exportacion de esta vista se conecta en la siguiente fase.');
    }
  }

  String _staffRoleById(String? employeeId) {
    if (employeeId == null || employeeId.isEmpty) return 'Empleado';
    for (final item in _staff) {
      if (item['id']?.toString() == employeeId) {
        return item['role']?.toString() ?? 'Empleado';
      }
    }
    return 'Empleado';
  }

  String _therapistRoleLabel(String therapistId) {
    for (final item in _staff) {
      if (item['id']?.toString() == therapistId) {
        return _humanizeLabel(item['role']?.toString() ?? 'Empleado');
      }
    }
    return 'Terapeuta';
  }

  String? get _createLabel {
    switch (_selectedSection) {
      case 3:
        return 'Nuevo gasto fijo';
      case 4:
        return 'Nuevo proveedor';
      case 5:
        return 'Nuevo pago de nomina';
      case 8:
        return 'Nuevo movimiento';
      case 9:
        return 'Nueva cuenta por pagar';
      case 10:
        return 'Nueva cuenta por cobrar';
      case 13:
        return 'Nuevo presupuesto';
      case 14:
        return 'Nueva meta';
      case 15:
        return 'Nuevo ajuste';
      default:
        return null;
    }
  }

  Widget _buildCurrentPage() {
    final topServices = _servicioRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topServiceCount = _topServiciosCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final therapistRanking = _therapistPerformance;
    final expenseBreakdown = _expenseByCategory.entries
        .map((entry) => _CategoryAmount(entry.key, entry.value))
        .where((entry) => entry.value > 0)
        .toList();
    final paymentBreakdown = _ventasPorMetodo.entries
        .map((entry) => _CategoryAmount(entry.key, entry.value))
        .toList();
    final typeBreakdown = _ventasPorTipo.entries
        .map((entry) => _CategoryAmount(entry.key, entry.value))
        .toList();
    final previousMonthSales = _salesTotalBetween(_previousMonthStart, _monthStart);
    final previousWeekSales = _salesTotalBetween(_previousWeekStart, _weekStart);
    final dashboardCards = _dashboardCardsFromPayload;
    final dashboardTrend = _dashboardTrendFromPayload;
    final dashboardExpenseBreakdown = _dashboardExpenseBreakdownFromPayload;
    final dashboardTopServices = _dashboardTopServicesFromPayload;
    final dashboardTopTherapists = _dashboardTopTherapistsFromPayload;
    final dashboardCashFlow = _dashboardCashFlowFromPayload;
    final dashboardAlerts = _dashboardAlertsFromPayload;
    final incomeCards = _incomeCardsFromPayload;
    final incomeTrend = _incomeTrendFromPayload;
    final incomePaymentBreakdown = _incomePaymentBreakdownFromPayload;
    final incomeTypeBreakdown = _incomeTypeBreakdownFromPayload;
    final incomeRecentSales = _incomeRecentSalesFromPayload;
    final incomeSummaryRows = _incomeSummaryRowsFromPayload;
    final expenseCards = _expenseCardsFromPayload;
    final expenseTrend = _expenseTrendFromPayload;
    final expenseBreakdownPayload = _expenseBreakdownFromPayload;
    final expenseStatusBreakdownPayload = _expenseStatusBreakdownFromPayload;
    final recentExpensesPayload = _recentExpensesFromPayload;
    final expenseSummaryRows = _expenseSummaryRowsFromPayload;
    final fixedExpenseCards = _fixedExpenseCardsFromPayload;
    final fixedExpenseMonthlySeries = _fixedExpenseMonthlySeriesFromPayload;
    final fixedExpenseCategoryBreakdown = _fixedExpenseCategoryBreakdownFromPayload;
    final fixedExpenseStatusBreakdown = _fixedExpenseStatusBreakdownFromPayload;
    final fixedExpenseRowsPayload = _fixedExpenseRowsFromPayload;
    final fixedExpenseSummaryRows = _fixedExpenseSummaryRowsFromPayload;
    final supplierCards = _supplierCardsFromPayload;
    final supplierMonthlySeries = _supplierMonthlySeriesFromPayload;
    final supplierCategoryBreakdown = _supplierCategoryBreakdownFromPayload;
    final supplierStatusPayload = _supplierStatusFromPayload;
    final supplierRowsPayload = _supplierRowsFromPayload;
    final supplierSummaryRows = _supplierSummaryRowsFromPayload;
    final payrollCards = _payrollCardsFromPayload;
    final payrollMonthlySeries = _payrollMonthlySeriesFromPayload;
    final payrollDistributionPayload = _payrollDistributionFromPayload;
    final payrollStatusPayload = _payrollStatusFromPayload;
    final payrollRowsPayload = _payrollRowsFromPayload;
    final payrollStaffPayload = _payrollStaffFromPayload;
    final payrollSummaryRows = _payrollSummaryRowsFromPayload;
    final performanceCards = _performanceCardsFromPayload;
    final performanceTrendPayload = _performanceTrendFromPayload;
    final performanceProfitableServicesPayload =
        _performanceProfitableServicesFromPayload;
    final performanceBranchBreakdownPayload =
        _performanceBranchBreakdownFromPayload;
    final performanceRowsPayload = _performanceRowsFromPayload;
    final performanceSummaryRows = _performanceSummaryRowsFromPayload;
    final currentMonthExpenses = _expensesTotalBetween(
      _monthStart,
      DateTime.now().add(const Duration(days: 1)),
    );
    final dashboardTopProviders = _topProvidersBySpend;
    final pettyCashBreakdown = [
      _CategoryAmount('Caja chica usada', _cajaChicaSalidas),
      _CategoryAmount('Caja chica disponible', _cajaChicaDisponible),
    ];
    final pettyCashRows = _pettyCashMovements
        .map(
          (row) => [
            DateFormat('d MMM', 'es_MX').format(row.date),
            row.title,
            row.responsible,
            _money(row.amount),
            row.status,
          ],
        )
        .toList();
    final payablesRows = _payableRows
        .map(
          (row) => [
            row['origen']?.toString() ?? 'Pendiente',
            row['concepto']?.toString() ?? 'Sin concepto',
            row['responsable']?.toString() ?? 'Responsable',
            _formattedDate(row['fecha'] as DateTime),
            _money(row['monto'] as double),
            row['estado']?.toString() ?? 'pendiente',
          ],
        )
        .toList();
    final receivablesRows = _receivableRows
        .map(
          (row) => [
            row['cliente']?.toString() ?? 'Cliente agenda',
            row['servicio']?.toString() ?? 'Servicio',
            row['terapeuta']?.toString() ?? 'Sin terapeuta',
            _formattedDate(row['fecha'] as DateTime),
            _money(row['monto'] as double),
            row['estado']?.toString() ?? 'pendiente',
          ],
        )
        .toList();
    final reportRows = const [
      ['Ventas del dia', 'CSV/PDF', 'listo'],
      ['Corte de caja', 'CSV/PDF', 'listo'],
      ['Nomina', 'CSV/PDF', 'listo'],
      ['Gastos', 'CSV/PDF', 'listo'],
      ['Utilidad mensual', 'CSV', 'revision'],
      ['Rendimiento por terapeuta', 'CSV/PDF', 'listo'],
      ['Cobranza pendiente', 'CSV', 'revision'],
    ];
    final budgetRows = [
      ['Ingresos', _money(_salesTotalSince(_monthStart)), _money(_salesTotalSince(_monthStart) * 1.15), _money((_salesTotalSince(_monthStart) * 1.15) - _salesTotalSince(_monthStart)), _salesTotalSince(_monthStart) >= (_salesTotalSince(_monthStart) * .9) ? 'en curso' : 'alerta'],
      ['Gastos Fijos', _money(_fixedExpensesTotal), _money(_fixedExpensesTotal * 1.05), _money((_fixedExpensesTotal * 1.05) - _fixedExpensesTotal), _fixedExpensesTotal <= (_fixedExpensesTotal * 1.05) ? 'controlado' : 'excedido'],
      ['Proveedores', _money(_supplierPaidThisMonth), _money(_supplierPaidThisMonth * 1.08), _money((_supplierPaidThisMonth * 1.08) - _supplierPaidThisMonth), 'controlado'],
      ['Nomina', _money(_payrollTotal), _money(_payrollTotal * 1.04), _money((_payrollTotal * 1.04) - _payrollTotal), 'controlado'],
    ];
    final goalRows = [
      ['Ingresos del mes', _money(_salesTotalSince(_monthStart)), _money(_salesTotalSince(_monthStart) * 1.20), _percent(83.3), _salesTotalSince(_monthStart) > 0 ? 'en curso' : 'sin avance'],
      ['Margen de ganancia', _percent(_margenGanancia), '55.0%', _percent((_margenGanancia / 55) * 100), _margenGanancia >= 45 ? 'saludable' : 'riesgo'],
      ['Cobranza pendiente', _money(_cuentasPorCobrarEstimadas), _money(_ticketPromedio * 2), _percent(_ticketPromedio == 0 ? 0 : ((_ticketPromedio * 2 - _cuentasPorCobrarEstimadas) / (_ticketPromedio * 2)) * 100), _cuentasPorCobrarEstimadas <= (_ticketPromedio * 2) ? 'en curso' : 'riesgo'],
      ['Control de gasto', _money(currentMonthExpenses), _money(currentMonthExpenses * 1.1), _percent(90), currentMonthExpenses <= (currentMonthExpenses * 1.1) ? 'controlado' : 'riesgo'],
    ];
    final settingsRows = const [
      ['Metodos de pago activos', '4', 'catalogo', 'activo'],
      ['Alertas inteligentes', '8 reglas', 'automatizacion', 'activo'],
      ['Moneda base', 'MXN', 'general', 'activo'],
      ['Sucursal financiera', 'Matriz', 'alcance', 'activo'],
      ['Politica de cobranzas', 'Seguimiento manual', 'regla', 'revision'],
      ['Control de caja chica', 'Estimado', 'operacion', 'activo'],
    ];
    final dashboardRecentIncomeRows = (incomeRecentSales.isNotEmpty
            ? incomeRecentSales.take(6).toList()
            : _paidSales.take(6).toList())
        .map((row) {
          final saleItems = _listValue(row['sale_items']);
          final firstItem = saleItems.isEmpty ? const {} : _mapValue(saleItems.first);
          return [
            DateFormat('d MMM', 'es_MX').format(
              _parseDate(row['created_at']) ?? DateTime.now(),
            ),
            _payloadString(firstItem['description'] ?? firstItem['name'], fallback: 'Venta'),
            _payloadString(row['client_name'], fallback: 'Cliente general'),
            _money(_payloadAmount(row['total'])),
            _humanizeLabel(_payloadString(row['payment_method'], fallback: 'sin metodo')),
          ];
        }).toList();
    final dashboardRecentExpenseRows = (recentExpensesPayload.isNotEmpty
            ? recentExpensesPayload.take(6).toList()
            : _detailedExpenses.take(6).toList().map((row) => {
                  'date': row.date,
                  'title': row.title,
                  'responsible': row.responsible,
                  'amount': row.amount,
                  'status': row.status,
                }).toList())
        .map((entry) {
          final row = _mapValue(entry);
          return [
              _formattedDate(_parseDate(row['date']) ?? DateTime.now()),
              _payloadString(row['title'], fallback: 'Gasto'),
              _payloadString(row['responsible'], fallback: 'Operacion'),
              _money(_payloadAmount(row['amount'])),
              _payloadString(row['status'], fallback: 'pendiente'),
            ];
        })
        .toList();

    switch (_selectedSection) {
      case 0:
        return _FinanceDashboardPage(
          cards: dashboardCards.isNotEmpty
              ? [
                  ...dashboardCards,
                  _KpiData(
                    title: 'Cuentas por Pagar',
                    value: _money(_cuentasPorPagarTotales),
                    caption: '${_payableRows.length} compromisos abiertos',
                    color: _financeNegative,
                    icon: Icons.outbox_rounded,
                  ),
                  _KpiData(
                    title: 'Caja Chica Disponible',
                    value: _money(_cajaChicaDisponible),
                    caption: 'Base estimada ${_money(_cajaChicaBaseEstimda)}',
                    color: SaharaTheme.gold,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _KpiData(
                    title: 'Ingresos del Dia',
                    value: _money(_ingresosHoy),
                    caption: '${_salesCountSince(_todayStart)} operaciones cobradas',
                    color: _financePositive,
                    icon: Icons.today_outlined,
                  ),
                  _KpiData(
                    title: 'Gastos del Dia',
                    value: _money(_gastosHoy),
                    caption: 'Salida diaria actual',
                    color: _financeNegative,
                    icon: Icons.calendar_today_outlined,
                  ),
                  _KpiData(
                    title: 'Flujo de Efectivo',
                    value: _money(_flujoEfectivoActual),
                    caption: 'Balance del mes en curso',
                    color: _financeViolet,
                    icon: Icons.waterfall_chart_rounded,
                  ),
                  _KpiData(
                    title: 'Crecimiento vs Mes Anterior',
                    value: _percent(_crecimientoVsMesAnterior),
                    caption: 'Comparativo del ingreso mensual',
                    color: _financeBlue,
                    icon: Icons.trending_up_rounded,
                  ),
                ]
              : [
                  _KpiData(
                    title: 'Ingresos Totales',
                    value: _money(_ingresosTotales),
                    caption: '$_paidOperationsCount operaciones cobradas',
                    color: _financePositive,
                    icon: Icons.attach_money_rounded,
                  ),
                  _KpiData(
                    title: 'Gastos Totales',
                    value: _money(_egresosTotales),
                    caption: '${_allExpenseEntries.length} egresos registrados',
                    color: _financeNegative,
                    icon: Icons.south_rounded,
                  ),
                  _KpiData(
                    title: 'Ganancia Neta',
                    value: _money(_gananciaNeta),
                    caption:
                        _gananciaNeta >= 0 ? 'Operacion positiva' : 'Operacion presionada',
                    color: SaharaTheme.gold,
                    icon: Icons.wallet_outlined,
                  ),
                  _KpiData(
                    title: 'Margen de Ganancia',
                    value: _percent(_margenGanancia),
                    caption: 'Sobre ingresos totales',
                    color: _financeViolet,
                    icon: Icons.pie_chart_outline_rounded,
                  ),
                  _KpiData(
                    title: 'Nomina Pendiente',
                    value: _money(_pendingPayrollAmount),
                    caption: '$_pendingPayrollCount pagos pendientes',
                    color: _financeNegative,
                    icon: Icons.badge_outlined,
                  ),
                  _KpiData(
                    title: 'Proveedores Pendientes',
                    value: _money(_pendingSupplierAmount),
                    caption: '$_pendingSupplierCount facturas pendientes',
                    color: _financeBlue,
                    icon: Icons.local_shipping_outlined,
                  ),
                  _KpiData(
                    title: 'Cuentas por Cobrar',
                    value: _money(_cuentasPorCobrarEstimadas),
                    caption: '$_citasPendientesCobro citas por cobrar',
                    color: SaharaTheme.bronceOscuro,
                    icon: Icons.receipt_long_outlined,
                  ),
                  _KpiData(
                    title: 'Ticket Promedio',
                    value: _money(_ticketPromedio),
                    caption: 'Promedio por operacion cobrada',
                    color: _financeInk,
                    icon: Icons.confirmation_number_outlined,
                  ),
                  _KpiData(
                    title: 'Cuentas por Pagar',
                    value: _money(_cuentasPorPagarTotales),
                    caption: '${_payableRows.length} compromisos abiertos',
                    color: _financeNegative,
                    icon: Icons.outbox_rounded,
                  ),
                  _KpiData(
                    title: 'Caja Chica Disponible',
                    value: _money(_cajaChicaDisponible),
                    caption: 'Base estimada ${_money(_cajaChicaBaseEstimda)}',
                    color: SaharaTheme.gold,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _KpiData(
                    title: 'Ingresos del Dia',
                    value: _money(_ingresosHoy),
                    caption: '${_salesCountSince(_todayStart)} operaciones cobradas',
                    color: _financePositive,
                    icon: Icons.today_outlined,
                  ),
                  _KpiData(
                    title: 'Gastos del Dia',
                    value: _money(_gastosHoy),
                    caption: 'Salida diaria actual',
                    color: _financeNegative,
                    icon: Icons.calendar_today_outlined,
                  ),
                  _KpiData(
                    title: 'Flujo de Efectivo',
                    value: _money(_flujoEfectivoActual),
                    caption: 'Balance del mes en curso',
                    color: _financeViolet,
                    icon: Icons.waterfall_chart_rounded,
                  ),
                  _KpiData(
                    title: 'Crecimiento vs Mes Anterior',
                    value: _percent(_crecimientoVsMesAnterior),
                    caption: 'Comparativo del ingreso mensual',
                    color: _financeBlue,
                    icon: Icons.trending_up_rounded,
                  ),
                ],
          trend: dashboardTrend.isNotEmpty ? dashboardTrend : _monthlyTrend,
          expenseBreakdown: dashboardExpenseBreakdown.isNotEmpty
              ? dashboardExpenseBreakdown
              : expenseBreakdown,
          topServices:
              dashboardTopServices.isNotEmpty ? dashboardTopServices : topServices.take(5).toList(),
          topTherapists: dashboardTopTherapists.isNotEmpty
              ? dashboardTopTherapists
              : therapistRanking.take(5).toList(),
          cashFlow: dashboardCashFlow.isNotEmpty
              ? dashboardCashFlow
              : [
                  _CategoryAmount('Saldo estimado', _gananciaNeta),
                  _CategoryAmount('Ingresos del mes', _salesTotalSince(_monthStart)),
                  _CategoryAmount(
                    'Egresos del mes',
                    _expensesTotalBetween(
                      _monthStart,
                      DateTime.now().add(const Duration(days: 1)),
                    ),
                  ),
                ],
          alerts: dashboardAlerts.isNotEmpty ? dashboardAlerts : _alerts,
          netProfitSeries: _netProfitMonthlySeries,
          cashFlowSeries: _cashFlowMonthlySeries,
          topProviders: dashboardTopProviders,
          recentIncomeRows: dashboardRecentIncomeRows,
          recentExpenseRows: dashboardRecentExpenseRows,
          payablesRows: payablesRows.take(6).toList(),
          receivablesRows: receivablesRows.take(6).toList(),
        );
      case 1:
        return _IngresosPage(
          cards: incomeCards.isNotEmpty
              ? incomeCards
              : [
                  _KpiData(
                    title: 'Ingresos de Hoy',
                    value: _money(_salesTotalSince(_todayStart)),
                    caption: '${_salesCountSince(_todayStart)} operaciones cobradas',
                    color: _financePositive,
                    icon: Icons.today_outlined,
                  ),
                  _KpiData(
                    title: 'Ingresos de la Semana',
                    value: _money(_salesTotalSince(_weekStart)),
                    caption: 'Comparado con ${_money(previousWeekSales)} semana previa',
                    color: SaharaTheme.gold,
                    icon: Icons.view_week_outlined,
                  ),
                  _KpiData(
                    title: 'Ingresos del Mes',
                    value: _money(_salesTotalSince(_monthStart)),
                    caption: 'Comparado con ${_money(previousMonthSales)} mes previo',
                    color: _financeInk,
                    icon: Icons.calendar_month_outlined,
                  ),
                  _KpiData(
                    title: 'Servicios Realizados',
                    value: '$_serviciosRealizados',
                    caption: '$_citasCompletadas citas completadas',
                    color: _financeBlue,
                    icon: Icons.spa_outlined,
                  ),
                  _KpiData(
                    title: 'Ticket Promedio',
                    value: _money(_ticketPromedio),
                    caption: 'Valor promedio por operacion',
                    color: _financeViolet,
                    icon: Icons.receipt_outlined,
                  ),
                  _KpiData(
                    title: 'Operaciones Cobradas',
                    value: '$_paidOperationsCount',
                    caption: 'Historial acumulado',
                    color: SaharaTheme.bronceOscuro,
                    icon: Icons.point_of_sale_outlined,
                  ),
                ],
          trend: incomeTrend.isNotEmpty ? incomeTrend : _incomeComparisonTrend,
          paymentBreakdown: incomePaymentBreakdown.isNotEmpty
              ? incomePaymentBreakdown
              : paymentBreakdown,
          typeBreakdown:
              incomeTypeBreakdown.isNotEmpty ? incomeTypeBreakdown : typeBreakdown,
          recentSales: incomeRecentSales.isNotEmpty ? incomeRecentSales : _paidSales.take(8).toList(),
          summary: incomeSummaryRows.isNotEmpty
              ? incomeSummaryRows
              : [
                  _SummaryRow('Ventas hoy', _money(_salesTotalSince(_todayStart))),
                  _SummaryRow('Ventas semana', _money(_salesTotalSince(_weekStart))),
                  _SummaryRow('Ventas mes', _money(_salesTotalSince(_monthStart))),
                  _SummaryRow(
                    'Mejor servicio',
                    topServices.isEmpty ? 'Sin datos' : topServices.first.key,
                  ),
                  _SummaryRow(
                    'Terapeuta top',
                    therapistRanking.isEmpty ? 'Sin datos' : therapistRanking.first.name,
                  ),
                ],
        );
      case 2:
        return _GastosOverviewPage(
          cards: expenseCards.isNotEmpty
              ? expenseCards
              : [
                  _KpiData(
                    title: 'Gastos Totales',
                    value: _money(_egresosTotales),
                    caption: '${_allExpenseEntries.length} movimientos',
                    color: _financeNegative,
                    icon: Icons.payments_outlined,
                  ),
                  _KpiData(
                    title: 'Gastos Operativos',
                    value: _money(_operationalExpensesTotal),
                    caption: 'Operacion del mes en curso',
                    color: SaharaTheme.bronceOscuro,
                    icon: Icons.business_center_rounded,
                  ),
                  _KpiData(
                    title: 'Gastos con Comprobante',
                    value: _money(_expensesWithReceiptTotal),
                    caption: _percent(
                      _egresosTotales == 0
                          ? 0
                          : (_expensesWithReceiptTotal / _egresosTotales) * 100,
                    ),
                    color: _financeBlue,
                    icon: Icons.receipt_long_rounded,
                  ),
                  _KpiData(
                    title: 'Gastos sin Comprobante',
                    value: _money(_expensesWithoutReceiptTotal),
                    caption: '$_missingReceiptsCount movimientos',
                    color: SaharaTheme.gold,
                    icon: Icons.warning_rounded,
                  ),
                  _KpiData(
                    title: 'Gastos Imprevistos',
                    value: _money(_unexpectedExpensesTotal),
                    caption: 'Incidencias o mantenimiento',
                    color: _financeViolet,
                    icon: Icons.report_problem_rounded,
                  ),
                  _KpiData(
                    title: 'Promedio Diario',
                    value: _money(_dailyExpenseAverage),
                    caption: '${DateTime.now().day} dias transcurridos',
                    color: _financePositive,
                    icon: Icons.calendar_month_rounded,
                  ),
                ],
          trend: expenseTrend.isNotEmpty ? expenseTrend : _expenseComparisonTrend,
          expenseBreakdown:
              expenseBreakdownPayload.isNotEmpty ? expenseBreakdownPayload : expenseBreakdown,
          statusBreakdown: expenseStatusBreakdownPayload.isNotEmpty
              ? expenseStatusBreakdownPayload
              : _expenseStatusBreakdown.entries
                    .map((entry) => _CategoryAmount(entry.key, entry.value))
                    .toList(),
          recentExpenses: recentExpensesPayload.isNotEmpty
              ? recentExpensesPayload
              : _detailedExpenses.take(12).toList(),
          summary: expenseSummaryRows.isNotEmpty
              ? expenseSummaryRows
              : [
                  _SummaryRow(
                    'Gastos del Dia',
                    _money(
                      _expensesTotalBetween(
                        _todayStart,
                        _todayStart.add(const Duration(days: 1)),
                      ),
                    ),
                  ),
                  _SummaryRow(
                    'Gastos del Mes',
                    _money(
                      _expensesTotalBetween(
                        _monthStart,
                        DateTime.now().add(const Duration(days: 1)),
                      ),
                    ),
                  ),
                  _SummaryRow('Categoria mayor', _topExpenseCategoryLabel),
                  _SummaryRow('Proveedor principal', _topSupplierLabel),
                  _SummaryRow(
                    'Gastos pendientes',
                    _money(_pendingSupplierAmount + _pendingPayrollAmount),
                  ),
                  _SummaryRow('Comprobantes faltantes', '$_missingReceiptsCount'),
                ],
          onAdd: _openExpenseEntryShortcut,
          onExport: _exportCurrentSection,
        );
      case 3:
        return _FixedExpensesOverviewPage(
          cards: fixedExpenseCards.isNotEmpty
              ? fixedExpenseCards
              : [
                  _KpiData(
                    title: 'Gastos Fijos Mensuales',
                    value: _money(_fixedExpensesTotal),
                    caption: '${_fixedExpenses.length} compromisos recurrentes',
                    color: _financeBlue,
                    icon: Icons.receipt_long_rounded,
                  ),
                  _KpiData(
                    title: 'Pagados',
                    value: _money(_fixedExpensesPaidTotal),
                    caption: '$_fixedExpensesPaidCount pagos completados',
                    color: _financePositive,
                    icon: Icons.check_circle_rounded,
                  ),
                  _KpiData(
                    title: 'Pendientes',
                    value: _money(_fixedExpensesPendingTotal),
                    caption: '$_fixedExpensesPendingCount pagos pendientes',
                    color: SaharaTheme.gold,
                    icon: Icons.schedule_rounded,
                  ),
                  _KpiData(
                    title: 'Vencidos',
                    value: _money(_fixedExpensesOverdueTotal),
                    caption: '$_fixedExpensesOverdueCount gasto vencido',
                    color: _financeNegative,
                    icon: Icons.warning_rounded,
                  ),
                  _KpiData(
                    title: 'Proximo Pago',
                    value: _money(_nextFixedExpense?.amount ?? 0),
                    caption: _nextFixedExpense == null
                        ? 'Sin pagos pendientes'
                        : '${_nextFixedExpense!.title} - ${_daysUntilLabel(_nextFixedExpense!.dueDate)}',
                    color: _financeViolet,
                    icon: Icons.event_rounded,
                  ),
                  _KpiData(
                    title: 'Promedio Mensual',
                    value: _money(_fixedExpenseMonthlyAverage),
                    caption: 'Ultimos ${_fixedExpenseMonthlySeries.length} meses',
                    color: _financePositive,
                    icon: Icons.analytics_rounded,
                  ),
                ],
          monthlySeries: fixedExpenseMonthlySeries.isNotEmpty
              ? fixedExpenseMonthlySeries
              : _fixedExpenseMonthlySeries,
          categoryBreakdown: fixedExpenseCategoryBreakdown.isNotEmpty
              ? fixedExpenseCategoryBreakdown
              : _fixedExpensesByCategory.entries
                    .map((entry) => _CategoryAmount(entry.key, entry.value))
                    .toList(),
          statusBreakdown: fixedExpenseStatusBreakdown.isNotEmpty
              ? fixedExpenseStatusBreakdown
              : _fixedExpensesByStatus.entries
                    .map((entry) => _CategoryAmount(entry.key, entry.value))
                    .toList(),
          rows: fixedExpenseRowsPayload.isNotEmpty
              ? fixedExpenseRowsPayload
              : _sortedFixedExpenses,
          summary: fixedExpenseSummaryRows.isNotEmpty
              ? fixedExpenseSummaryRows
              : [
                  _SummaryRow('Total mensual', _money(_fixedExpensesTotal)),
                  _SummaryRow('Pagado', _money(_fixedExpensesPaidTotal)),
                  _SummaryRow('Pendiente', _money(_fixedExpensesPendingTotal)),
                  _SummaryRow('Vencido', _money(_fixedExpensesOverdueTotal)),
                  _SummaryRow(
                    'Mayor gasto',
                    _topFixedExpenseLabel(_sortedFixedExpenses),
                  ),
                  _SummaryRow(
                    'Proximo pago',
                    _nextFixedExpense == null
                        ? 'Sin pendientes'
                        : '${_nextFixedExpense!.title} - ${_daysUntilLabel(_nextFixedExpense!.dueDate)}',
                  ),
                  _SummaryRow(
                    'Frecuencia principal',
                    _topFrequencyLabel(_sortedFixedExpenses),
                  ),
                ],
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
          dueDateBuilder: _fixedDueDate,
        );
      case 4:
        return _SuppliersOverviewPage(
          cards: supplierCards.isNotEmpty
              ? supplierCards
              : [
                  _KpiData(
                    title: 'Total Proveedores',
                    value: '$_totalSuppliers',
                    caption: '+$_newSuppliersThisMonthCount nuevos',
                    color: _financeBlue,
                    icon: Icons.groups_rounded,
                  ),
                  _KpiData(
                    title: 'Pagos Pendientes',
                    value: _money(_supplierPendingAmountOnly),
                    caption: '$_supplierPendingEntriesOnly facturas',
                    color: SaharaTheme.gold,
                    icon: Icons.schedule_rounded,
                  ),
                  _KpiData(
                    title: 'Pagos Vencidos',
                    value: _money(_supplierOverdueAmount),
                    caption: '$_supplierOverdueEntries vencidos',
                    color: _financeNegative,
                    icon: Icons.warning_rounded,
                  ),
                  _KpiData(
                    title: 'Pagado Este Mes',
                    value: _money(_supplierPaidThisMonth),
                    caption: _supplierPaidPreviousMonth == 0
                        ? 'Sin comparativo previo'
                        : _percent(
                            ((_supplierPaidThisMonth - _supplierPaidPreviousMonth) /
                                    _supplierPaidPreviousMonth) *
                                100,
                          ),
                    color: _financePositive,
                    icon: Icons.check_circle_rounded,
                  ),
                  _KpiData(
                    title: 'Proveedor Principal',
                    value: _topSupplier?.name ?? 'Sin datos',
                    caption: _money(_topSupplier?.total ?? 0),
                    color: _financeViolet,
                    icon: Icons.local_shipping_rounded,
                  ),
                  _KpiData(
                    title: 'Facturas Pendientes',
                    value: '$_pendingInvoicesCount',
                    caption: 'por revisar',
                    color: _financePositive,
                    icon: Icons.receipt_long_rounded,
                  ),
                ],
          monthlySeries: supplierMonthlySeries.isNotEmpty
              ? supplierMonthlySeries
              : _supplierExpenseMonthlySeries,
          categoryBreakdown: supplierCategoryBreakdown.isNotEmpty
              ? supplierCategoryBreakdown
              : _supplierExpensesByCategory.entries
                    .map((entry) => _CategoryAmount(entry.key, entry.value))
                    .toList(),
          status: supplierStatusPayload ??
              _SupplierStatusSummary(
                active: _activeSuppliersCount,
                pending: _pendingSupplierEntityCount,
                overdue: _overdueSupplierEntityCount,
                inactive: _inactiveSuppliersCount,
                total: _totalSuppliers == 0 ? 1 : _totalSuppliers,
              ),
          rows: supplierRowsPayload.isNotEmpty ? supplierRowsPayload : _sortedSupplierExpenses,
          summary: supplierSummaryRows.isNotEmpty
              ? supplierSummaryRows
              : [
                  _SummaryRow('Total proveedores', '$_totalSuppliers'),
                  _SummaryRow('Activos', '$_activeSuppliersCount'),
                  _SummaryRow('Pagos pendientes', _money(_supplierPendingAmountOnly)),
                  _SummaryRow('Pagos vencidos', _money(_supplierOverdueAmount)),
                  _SummaryRow('Pagado este mes', _money(_supplierPaidThisMonth)),
                  _SummaryRow('Proveedor mayor', _topSupplier?.name ?? 'Sin datos'),
                  _SummaryRow('Facturas por revisar', '$_pendingInvoicesCount'),
                ],
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
        );
      case 5:
        return _PayrollOverviewPage(
          cards: payrollCards.isNotEmpty
              ? payrollCards
              : [
                  _KpiData(
                    title: 'Nomina Total',
                    value: _money(_payrollTotal),
                    caption: _previousPayrollMonthValue == 0
                        ? 'Operacion actual'
                        : _percent(
                            ((_payrollTotal - _previousPayrollMonthValue) /
                                    _previousPayrollMonthValue) *
                                100,
                          ),
                    color: _financeBlue,
                    icon: Icons.badge_rounded,
                  ),
                  _KpiData(
                    title: 'Sueldos Base',
                    value: _money(_payrollBaseTotal),
                    caption: '$_payrollEmployeeCount empleados',
                    color: _financePositive,
                    icon: Icons.people_alt_rounded,
                  ),
                  _KpiData(
                    title: 'Comisiones',
                    value: _money(_payrollCommissionsTotal),
                    caption: 'Variable por rendimiento',
                    color: _financeViolet,
                    icon: Icons.trending_up_rounded,
                  ),
                  _KpiData(
                    title: 'Bonos',
                    value: _money(_payrollBonusesTotal),
                    caption: '$_payrollBonusesCount bonos',
                    color: SaharaTheme.gold,
                    icon: Icons.card_giftcard_rounded,
                  ),
                  _KpiData(
                    title: 'Anticipos',
                    value: _money(_payrollDeductionsTotal),
                    caption: '$_payrollDeductionsCount descuentos/anticipos',
                    color: _financeNegative,
                    icon: Icons.payments_rounded,
                  ),
                  _KpiData(
                    title: 'Pendiente por Pagar',
                    value: _money(_pendingPayrollAmount),
                    caption: _nextPayrollCutoffLabel == 'Sin pendiente'
                        ? 'Sin corte pendiente'
                        : 'Proximo corte $_nextPayrollCutoffLabel',
                    color: _financePositive,
                    icon: Icons.schedule_rounded,
                  ),
                ],
          monthlySeries:
              payrollMonthlySeries.isNotEmpty ? payrollMonthlySeries : _payrollMonthlySeries,
          distribution: payrollDistributionPayload.isNotEmpty
              ? payrollDistributionPayload
              : [
                  _CategoryAmount('Sueldos', _payrollBaseTotal),
                  _CategoryAmount('Comisiones', _payrollCommissionsTotal),
                  _CategoryAmount('Bonos', _payrollBonusesTotal),
                  _CategoryAmount('Anticipos', _payrollDeductionsTotal),
                ],
          status: payrollStatusPayload.isNotEmpty
              ? payrollStatusPayload
              : [
                  _CategoryAmount('Pagado', _payrollPaidTotal),
                  _CategoryAmount('Pendiente', _pendingPayrollAmount),
                  _CategoryAmount('Anticipos', _payrollDeductionsTotal),
                  _CategoryAmount('Bonos', _payrollBonusesTotal),
                ],
          rows: payrollRowsPayload.isNotEmpty ? payrollRowsPayload : _sortedPayrollEntries,
          staff: payrollRowsPayload.isNotEmpty ? payrollStaffPayload : _staff,
          summary: payrollSummaryRows.isNotEmpty
              ? payrollSummaryRows
              : [
                  _SummaryRow('Total nomina', _money(_payrollTotal)),
                  _SummaryRow('Empleados', '$_payrollEmployeeCount'),
                  _SummaryRow('Pagado', _money(_payrollPaidTotal)),
                  _SummaryRow('Pendiente', _money(_pendingPayrollAmount)),
                  _SummaryRow('Comisiones', _money(_payrollCommissionsTotal)),
                  _SummaryRow('Bonos', _money(_payrollBonusesTotal)),
                  _SummaryRow('Anticipos', _money(_payrollDeductionsTotal)),
                  _SummaryRow('Proximo corte', _nextPayrollCutoffLabel),
                ],
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
        );
      case 6:
        return _PerformanceOverviewPage(
          cards: performanceCards.isNotEmpty
              ? performanceCards
              : [
                  _KpiData(
                    title: 'Rendimiento General',
                    value: _percent(_generalPerformanceScore),
                    caption: '${_bookings.length} citas evaluadas',
                    color: _financePositive,
                    icon: Icons.speed_rounded,
                  ),
                  _KpiData(
                    title: 'Ticket Promedio',
                    value: _money(_ticketPromedio),
                    caption: 'Promedio por venta pagada',
                    color: _financeBlue,
                    icon: Icons.receipt_rounded,
                  ),
                  _KpiData(
                    title: 'Margen Promedio',
                    value: _percent(_margenGanancia),
                    caption: 'Rentabilidad sobre ingresos',
                    color: _financeViolet,
                    icon: Icons.pie_chart_rounded,
                  ),
                  _KpiData(
                    title: 'Servicios Realizados',
                    value: '$_serviciosRealizados',
                    caption:
                        '+${math.max(_serviciosRealizados - _citasCompletadas, 0)} adicionales',
                    color: SaharaTheme.gold,
                    icon: Icons.spa_rounded,
                  ),
                  _KpiData(
                    title: 'Empleado Top',
                    value: therapistRanking.isEmpty ? 'Sin datos' : therapistRanking.first.name,
                    caption: _money(therapistRanking.isEmpty ? 0 : therapistRanking.first.revenue),
                    color: _financeNegative,
                    icon: Icons.emoji_events_rounded,
                  ),
                  _KpiData(
                    title: 'Servicio Top',
                    value: topServices.isEmpty ? 'Sin datos' : topServices.first.key,
                    caption: topServiceCount.isEmpty
                        ? 'Sin ventas'
                        : '${topServiceCount.first.value} ventas',
                    color: _financePositive,
                    icon: Icons.star_rounded,
                  ),
                ],
          trend: performanceTrendPayload.isNotEmpty
              ? performanceTrendPayload
              : _performanceTrend,
          profitableServices: performanceProfitableServicesPayload.isNotEmpty
              ? performanceProfitableServicesPayload
              : _serviceProfitability,
          branchBreakdown: performanceBranchBreakdownPayload.isNotEmpty
              ? performanceBranchBreakdownPayload
              : _branchPerformanceBreakdown,
          rows: performanceRowsPayload.isNotEmpty ? performanceRowsPayload : therapistRanking,
          summary: performanceSummaryRows.isNotEmpty
              ? performanceSummaryRows
              : [
                  _SummaryRow('Rendimiento general', _percent(_generalPerformanceScore)),
                  _SummaryRow('Ticket promedio', _money(_ticketPromedio)),
                  _SummaryRow('Margen promedio', _percent(_margenGanancia)),
                  _SummaryRow('Servicios realizados', '$_serviciosRealizados'),
                  _SummaryRow(
                    'Empleado top',
                    therapistRanking.isEmpty ? 'Sin datos' : therapistRanking.first.name,
                  ),
                  _SummaryRow(
                    'Servicio top',
                    topServices.isEmpty ? 'Sin datos' : topServices.first.key,
                  ),
                  _SummaryRow('Sucursal top', kDefaultBranchName),
                  _SummaryRow(
                    'Alerta',
                    _lowPerformerCount == 0 ? 'Sin alertas' : '$_lowPerformerCount bajo',
                  ),
                ],
          onExport: _exportCurrentSection,
        );
      case 7:
        return _ComparativesHubPage(
          ventasHoy: _salesTotalSince(_todayStart),
          ventasAyer: _salesTotalBetween(
            _todayStart.subtract(const Duration(days: 1)),
            _todayStart,
          ),
          ventasSemana: _salesTotalSince(_weekStart),
          ventasSemanaPasada: _salesTotalBetween(_previousWeekStart, _weekStart),
          ventasMes: _salesTotalSince(_monthStart),
          ventasMesPasado: previousMonthSales,
          ingresosTotales: _ingresosTotales,
          egresosTotales: _egresosTotales,
          topServicio: topServices.isEmpty ? null : topServices.first,
          topTherapist: therapistRanking.isEmpty ? null : therapistRanking.first,
        );
      case 8:
        return _CashBoxPage(
          cards: [
            _KpiData(
              title: 'Caja Chica Disponible',
              value: _money(_cajaChicaDisponible),
              caption: 'Base estimada ${_money(_cajaChicaBaseEstimda)}',
              color: SaharaTheme.gold,
              icon: Icons.account_balance_wallet_outlined,
            ),
            _KpiData(
              title: 'Salidas del Mes',
              value: _money(_cajaChicaSalidas),
              caption: '${_pettyCashMovements.length} movimientos detectados',
              color: _financeNegative,
              icon: Icons.south_rounded,
            ),
            _KpiData(
              title: 'Movimientos de Hoy',
              value: '${_pettyCashMovements.where((row) => !row.date.isBefore(_todayStart)).length}',
              caption: _money(_pettyCashMovements.where((row) => !row.date.isBefore(_todayStart)).fold<double>(0, (sum, row) => sum + row.amount)),
              color: _financeBlue,
              icon: Icons.today_outlined,
            ),
            _KpiData(
              title: 'Ticket Caja Chica',
              value: _money(_pettyCashMovements.isEmpty ? 0 : _cajaChicaSalidas / _pettyCashMovements.length),
              caption: 'Promedio por movimiento',
              color: _financePositive,
              icon: Icons.receipt_long_rounded,
            ),
          ],
          monthlySeries: _pettyCashMonthlySeries,
          breakdown: pettyCashBreakdown,
          rows: pettyCashRows,
          summary: [
            _SummaryRow('Disponible', _money(_cajaChicaDisponible)),
            _SummaryRow('Salidas del mes', _money(_cajaChicaSalidas)),
            _SummaryRow('Movimientos', '${_pettyCashMovements.length}'),
            _SummaryRow('Ultimo movimiento', _pettyCashMovements.isEmpty ? 'Sin datos' : _formattedDate(_pettyCashMovements.first.date)),
          ],
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
        );
      case 9:
        return _PayablesPage(
          cards: [
            _KpiData(
              title: 'Cuentas por Pagar',
              value: _money(_cuentasPorPagarTotales),
              caption: '${_payableRows.length} compromisos abiertos',
              color: _financeNegative,
              icon: Icons.outbox_rounded,
            ),
            _KpiData(
              title: 'Vencidas',
              value: _money(_payableRows.where((row) => (row['estado']?.toString().toLowerCase() ?? '') == 'vencido').fold<double>(0, (sum, row) => sum + (row['monto'] as double))),
              caption: '${_payableRows.where((row) => (row['estado']?.toString().toLowerCase() ?? '') == 'vencido').length} pagos vencidos',
              color: _financeNegative,
              icon: Icons.warning_rounded,
            ),
            _KpiData(
              title: 'Pendientes',
              value: _money(_payableRows.where((row) => (row['estado']?.toString().toLowerCase() ?? '') == 'pendiente').fold<double>(0, (sum, row) => sum + (row['monto'] as double))),
              caption: '${_payableRows.where((row) => (row['estado']?.toString().toLowerCase() ?? '') == 'pendiente').length} por atender',
              color: SaharaTheme.gold,
              icon: Icons.schedule_rounded,
            ),
            _KpiData(
              title: 'Pago Proximo',
              value: _payableRows.isEmpty ? _money(0) : _money(_payableRows.first['monto'] as double),
              caption: _payableRows.isEmpty ? 'Sin pendientes' : _formattedDate(_payableRows.first['fecha'] as DateTime),
              color: _financeBlue,
              icon: Icons.event_rounded,
            ),
          ],
          monthlySeries: _payablesMonthlySeries,
          breakdown: _payablesByOrigin,
          statusItems: _payableRows
              .fold<Map<String, double>>({}, (map, row) {
                final key = _normalizeExpenseStatusLabel(row['estado']?.toString() ?? 'pendiente');
                map[key] = (map[key] ?? 0) + (row['monto'] as double);
                return map;
              })
              .entries
              .map((entry) => _CategoryAmount(entry.key, entry.value))
              .toList(),
          rows: payablesRows,
          summary: [
            _SummaryRow('Pendiente total', _money(_cuentasPorPagarTotales)),
            _SummaryRow('Fijos', _money(_fixedExpensesPendingTotal + _fixedExpensesOverdueTotal)),
            _SummaryRow('Proveedores', _money(_pendingSupplierAmount)),
            _SummaryRow('Nomina', _money(_pendingPayrollAmount)),
          ],
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
        );
      case 10:
        return _ReceivablesPage(
          cards: [
            _KpiData(
              title: 'Cuentas por Cobrar',
              value: _money(_cuentasPorCobrarEstimadas),
              caption: '${_receivableRows.length} cobros abiertos',
              color: _financeBlue,
              icon: Icons.move_to_inbox_rounded,
            ),
            _KpiData(
              title: 'Pendientes',
              value: '${_receivableRows.where((row) => row['estado'] == 'pendiente').length}',
              caption: 'En seguimiento',
              color: _financePositive,
              icon: Icons.schedule_rounded,
            ),
            _KpiData(
              title: 'Vencidas',
              value: '${_receivableRows.where((row) => row['estado'] == 'vencido').length}',
              caption: _money(_receivableRows.where((row) => row['estado'] == 'vencido').fold<double>(0, (sum, row) => sum + (row['monto'] as double))),
              color: _financeNegative,
              icon: Icons.warning_rounded,
            ),
            _KpiData(
              title: 'Ticket Estimado',
              value: _money(_ticketPromedio),
              caption: 'Valor medio por cobro',
              color: SaharaTheme.gold,
              icon: Icons.receipt_rounded,
            ),
          ],
          monthlySeries: _receivablesMonthlySeries,
          breakdown: _receivablesByStatus,
          rows: receivablesRows,
          summary: [
            _SummaryRow('Pendiente total', _money(_cuentasPorCobrarEstimadas)),
            _SummaryRow('Cobros pendientes', '${_receivableRows.where((row) => row['estado'] == 'pendiente').length}'),
            _SummaryRow('Cobros vencidos', '${_receivableRows.where((row) => row['estado'] == 'vencido').length}'),
            _SummaryRow('Ticket promedio', _money(_ticketPromedio)),
          ],
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
        );
      case 11:
        return _ReportsHubPage(
          rows: reportRows,
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
        );
      case 12:
        return _AlertsHubPage(
          alerts: _alerts,
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
        );
      case 13:
        return _BudgetsPage(
          cards: [
            _KpiData(title: 'Presupuesto Mensual', value: _money(currentMonthExpenses * 1.1), caption: 'Base estimada del mes', color: _financeViolet, icon: Icons.pie_chart_rounded),
            _KpiData(title: 'Ejecutado', value: _money(currentMonthExpenses), caption: 'Gasto real acumulado', color: _financeNegative, icon: Icons.payments_rounded),
            _KpiData(title: 'Desviacion', value: _money((currentMonthExpenses * 1.1) - currentMonthExpenses), caption: currentMonthExpenses <= (currentMonthExpenses * 1.1) ? 'Bajo control' : 'Sobre presupuesto', color: _financePositive, icon: Icons.compare_arrows_rounded),
            _KpiData(title: 'Categorias Activas', value: '${budgetRows.length}', caption: 'Con lectura operativa', color: SaharaTheme.gold, icon: Icons.category_outlined),
          ],
          monthlySeries: _cashFlowMonthlySeries,
          breakdown: _expenseByCategory.entries.map((entry) => _CategoryAmount(entry.key, entry.value)).toList(),
          rows: budgetRows,
          summary: [
            _SummaryRow('Presupuesto total', _money(currentMonthExpenses * 1.1)),
            _SummaryRow('Ejecutado', _money(currentMonthExpenses)),
            _SummaryRow('Desviacion', _money((currentMonthExpenses * 1.1) - currentMonthExpenses)),
            _SummaryRow('Categorias', '${budgetRows.length}'),
          ],
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
        );
      case 14:
        return _GoalsPage(
          cards: [
            _KpiData(title: 'Meta de Ingresos', value: _money(_salesTotalSince(_monthStart) * 1.2), caption: 'Objetivo de cierre mensual', color: _financeBlue, icon: Icons.flag_rounded),
            _KpiData(title: 'Avance Actual', value: _money(_salesTotalSince(_monthStart)), caption: 'Ingreso logrado hasta hoy', color: _financePositive, icon: Icons.trending_up_rounded),
            _KpiData(title: 'Margen Objetivo', value: '55.0%', caption: 'Meta de rentabilidad', color: _financeViolet, icon: Icons.pie_chart_rounded),
            _KpiData(title: 'Cobranza Objetivo', value: _money(_ticketPromedio * 2), caption: 'Nivel maximo de cartera abierta', color: SaharaTheme.gold, icon: Icons.move_to_inbox_rounded),
          ],
          breakdown: [
            _CategoryAmount('Ingresos', _salesTotalSince(_monthStart)),
            _CategoryAmount('Margen', _margenGanancia),
            _CategoryAmount('Cobranza', math.max((_ticketPromedio * 2) - _cuentasPorCobrarEstimadas, 0)),
            _CategoryAmount('Control de gasto', math.max((currentMonthExpenses * 1.1) - currentMonthExpenses, 0)),
          ],
          rows: goalRows,
          summary: [
            _SummaryRow('Ingreso actual', _money(_salesTotalSince(_monthStart))),
            _SummaryRow('Margen actual', _percent(_margenGanancia)),
            _SummaryRow('Cobranza abierta', _money(_cuentasPorCobrarEstimadas)),
            _SummaryRow('Gasto actual', _money(currentMonthExpenses)),
          ],
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
        );
      case 15:
        return _FinanceSettingsPage(
          cards: const [
            _KpiData(title: 'Parametros Activos', value: '6', caption: 'Configuracion base del modulo', color: _financeBlue, icon: Icons.settings_rounded),
            _KpiData(title: 'Metodos de Pago', value: '4', caption: 'Efectivo, tarjeta, transferencia y mixto', color: _financePositive, icon: Icons.payments_outlined),
            _KpiData(title: 'Reglas de Alerta', value: '8', caption: 'Monitor financiero automatizado', color: SaharaTheme.gold, icon: Icons.notifications_active_outlined),
            _KpiData(title: 'Salud de Config', value: '92%', caption: 'Lectura general del modulo', color: _financeViolet, icon: Icons.health_and_safety_outlined),
          ],
          rows: settingsRows,
          summary: const [
            _SummaryRow('Moneda base', 'MXN'),
            _SummaryRow('Sucursal', 'Matriz'),
            _SummaryRow('Alertas activas', '8 reglas'),
            _SummaryRow('Cierre automatico', 'Pendiente'),
          ],
          onAdd: _openCreateDialog,
          onExport: _exportCurrentSection,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = _sections[_selectedSection];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1180;

        return Scaffold(
          backgroundColor: SaharaTheme.background,
          drawer: isDesktop
              ? null
              : Drawer(
                  child: _FinanceSidebar(
                    sections: _sections,
                    selectedIndex: _selectedSection,
                    onTap: (index) {
                      Navigator.pop(context);
                      _handleSectionChange(index);
                    },
                  ),
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (isDesktop)
                  _FinanceSidebar(
                    sections: _sections,
                    selectedIndex: _selectedSection,
                    onTap: _handleSectionChange,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _FinanceTopBar(
                        title: section.title,
                        subtitle: section.subtitle,
                        alertCount: _currentAlertCount,
                        onRefresh: _load,
                        onCreate: _createLabel == null ? null : _openCreateDialog,
                        createLabel: _createLabel,
                        showMenuButton: !isDesktop,
                      ),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                            : _buildCurrentPage(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FinanceDashboardPage extends StatelessWidget {
  const _FinanceDashboardPage({
    required this.cards,
    required this.trend,
    required this.expenseBreakdown,
    required this.topServices,
    required this.topTherapists,
    required this.topProviders,
    required this.cashFlow,
    required this.alerts,
    required this.netProfitSeries,
    required this.cashFlowSeries,
    required this.recentIncomeRows,
    required this.recentExpenseRows,
    required this.payablesRows,
    required this.receivablesRows,
  });

  final List<_KpiData> cards;
  final List<_TrendPoint> trend;
  final List<_CategoryAmount> expenseBreakdown;
  final List<MapEntry<String, double>> topServices;
  final List<_TherapistPerformance> topTherapists;
  final List<_CategoryAmount> topProviders;
  final List<_CategoryAmount> cashFlow;
  final List<_MetricAlert> alerts;
  final List<_MonthlyPoint> netProfitSeries;
  final List<_MonthlyPoint> cashFlowSeries;
  final List<List<String>> recentIncomeRows;
  final List<List<String>> recentExpenseRows;
  final List<List<String>> payablesRows;
  final List<List<String>> receivablesRows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1180;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceResponsiveCardGrid(
                children: cards.map((card) => _FinanceKpiCard(data: card)).toList(),
              ),
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _TrendChartCard(points: trend)),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _DonutBreakdownCard(
                        title: 'Gastos por categoria',
                        subtitle: 'Como se distribuye la salida de dinero.',
                        items: expenseBreakdown,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _ValueLineChartCard(
                        title: 'Ganancia Neta Mensual',
                        subtitle: 'Lectura neta de ingreso menos egreso por mes.',
                        points: netProfitSeries,
                        color: _financePositive,
                      ),
                    ),
                  ],
                )
              else ...[
                _TrendChartCard(points: trend),
                const SizedBox(height: 20),
                _DonutBreakdownCard(
                  title: 'Gastos por categoria',
                  subtitle: 'Como se distribuye la salida de dinero.',
                  items: expenseBreakdown,
                ),
                const SizedBox(height: 20),
                _ValueLineChartCard(
                  title: 'Ganancia Neta Mensual',
                  subtitle: 'Lectura neta de ingreso menos egreso por mes.',
                  points: netProfitSeries,
                  color: _financePositive,
                ),
              ],
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _RankedListCard(
                        title: 'Top Servicios',
                        items: topServices
                            .map((entry) => _RankedItem(entry.key, _money(entry.value)))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _RankedListCard(
                        title: 'Top Terapeutas',
                        items: topTherapists
                            .map(
                              (entry) =>
                                  _RankedItem(entry.name, _money(entry.revenue)),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SummaryListCard(
                        title: 'Flujo de Efectivo',
                        rows: cashFlow
                            .map((entry) => _SummaryRow(entry.label, _money(entry.value)))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _RankedListCard(
                        title: 'Top Proveedores',
                        items: topProviders
                            .map((entry) => _RankedItem(entry.label, _money(entry.value)))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(child: _AlertsSummaryCard(alerts: alerts)),
                  ],
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 420,
                      child: _RankedListCard(
                        title: 'Top Servicios',
                        items: topServices
                            .map((entry) => _RankedItem(entry.key, _money(entry.value)))
                            .toList(),
                      ),
                    ),
                    SizedBox(
                      width: 420,
                      child: _RankedListCard(
                        title: 'Top Terapeutas',
                        items: topTherapists
                            .map(
                              (entry) =>
                                  _RankedItem(entry.name, _money(entry.revenue)),
                            )
                            .toList(),
                      ),
                    ),
                    SizedBox(
                      width: 420,
                      child: _SummaryListCard(
                        title: 'Flujo de Efectivo',
                        rows: cashFlow
                            .map((entry) => _SummaryRow(entry.label, _money(entry.value)))
                            .toList(),
                      ),
                    ),
                    SizedBox(
                      width: 420,
                      child: _RankedListCard(
                        title: 'Top Proveedores',
                        items: topProviders
                            .map((entry) => _RankedItem(entry.label, _money(entry.value)))
                            .toList(),
                      ),
                    ),
                    SizedBox(width: 420, child: _AlertsSummaryCard(alerts: alerts)),
                  ],
                ),
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _ValueLineChartCard(
                        title: 'Flujo de Efectivo',
                        subtitle: 'Balance neto mensual de la operacion financiera.',
                        points: cashFlowSeries,
                        color: _financeBlue,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: _SummaryListCard(
                        title: 'Comparativa Mes Actual vs Mes Anterior',
                        rows: [
                          _SummaryRow(
                            'Mes actual',
                            _money(cashFlowSeries.isEmpty ? 0 : cashFlowSeries.last.value),
                          ),
                          _SummaryRow(
                            'Mes anterior',
                            _money(cashFlowSeries.length < 2 ? 0 : cashFlowSeries[cashFlowSeries.length - 2].value),
                          ),
                          _SummaryRow(
                            'Variacion',
                            _percent(
                              cashFlowSeries.length < 2 || cashFlowSeries[cashFlowSeries.length - 2].value == 0
                                  ? 0
                                  : ((cashFlowSeries.last.value - cashFlowSeries[cashFlowSeries.length - 2].value) /
                                          cashFlowSeries[cashFlowSeries.length - 2].value) *
                                      100,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                _ValueLineChartCard(
                  title: 'Flujo de Efectivo',
                  subtitle: 'Balance neto mensual de la operacion financiera.',
                  points: cashFlowSeries,
                  color: _financeBlue,
                ),
                const SizedBox(height: 20),
                _SummaryListCard(
                  title: 'Comparativa Mes Actual vs Mes Anterior',
                  rows: [
                    _SummaryRow(
                      'Mes actual',
                      _money(cashFlowSeries.isEmpty ? 0 : cashFlowSeries.last.value),
                    ),
                    _SummaryRow(
                      'Mes anterior',
                      _money(cashFlowSeries.length < 2 ? 0 : cashFlowSeries[cashFlowSeries.length - 2].value),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: wide ? 560 : double.infinity,
                    child: _FinanceRecordsTableCard(
                      columns: const ['Fecha', 'Concepto', 'Cliente', 'Monto', 'Metodo'],
                      rows: recentIncomeRows,
                      searchHint: 'Buscar ingreso...',
                      filterPrimary: 'Ultimos ingresos',
                      filterSecondary: 'Todos',
                      addLabel: 'Nuevo ingreso',
                      onAdd: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('La captura de ingresos se conecta en la siguiente fase.')),
                      ),
                      onExport: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('La exportacion de ingresos se conecta en la siguiente fase.')),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: wide ? 560 : double.infinity,
                    child: _FinanceRecordsTableCard(
                      columns: const ['Fecha', 'Concepto', 'Responsable', 'Monto', 'Estado'],
                      rows: recentExpenseRows,
                      searchHint: 'Buscar gasto...',
                      filterPrimary: 'Ultimos gastos',
                      filterSecondary: 'Todos los estados',
                      addLabel: 'Nuevo gasto',
                      onAdd: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Usa el modulo de gastos para registrar nuevos egresos.')),
                      ),
                      onExport: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('La exportacion de gastos se conecta en la siguiente fase.')),
                      ),
                      statusColumnIndex: 4,
                    ),
                  ),
                  SizedBox(
                    width: wide ? 560 : double.infinity,
                    child: _FinanceRecordsTableCard(
                      columns: const ['Origen', 'Concepto', 'Responsable', 'Fecha', 'Monto', 'Estado'],
                      rows: payablesRows,
                      searchHint: 'Buscar pago pendiente...',
                      filterPrimary: 'Pagos pendientes',
                      filterSecondary: 'Todos los estados',
                      addLabel: 'Nueva cuenta',
                      onAdd: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Usa cuentas por pagar para gestionar nuevos compromisos.')),
                      ),
                      onExport: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('La exportacion de pagos pendientes se conecta en la siguiente fase.')),
                      ),
                      statusColumnIndex: 5,
                    ),
                  ),
                  SizedBox(
                    width: wide ? 560 : double.infinity,
                    child: _FinanceRecordsTableCard(
                      columns: const ['Cliente', 'Servicio', 'Terapeuta', 'Fecha', 'Monto', 'Estado'],
                      rows: receivablesRows,
                      searchHint: 'Buscar cobro pendiente...',
                      filterPrimary: 'Cuentas por cobrar',
                      filterSecondary: 'Todos los estados',
                      addLabel: 'Nueva cuenta',
                      onAdd: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Usa cuentas por cobrar para gestionar nuevos seguimientos.')),
                      ),
                      onExport: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('La exportacion de cobranza se conecta en la siguiente fase.')),
                      ),
                      statusColumnIndex: 5,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IngresosPage extends StatelessWidget {
  const _IngresosPage({
    required this.cards,
    required this.trend,
    required this.paymentBreakdown,
    required this.typeBreakdown,
    required this.recentSales,
    required this.summary,
  });

  final List<_KpiData> cards;
  final List<_TrendPoint> trend;
  final List<_CategoryAmount> paymentBreakdown;
  final List<_CategoryAmount> typeBreakdown;
  final List<Map<String, dynamic>> recentSales;
  final List<_SummaryRow> summary;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Resumen',
      'Servicios',
      'Metodos de pago',
      'Empleados',
      'Sucursal',
      'Cliente',
      'Membresias',
      'Gift Cards',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1240;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceResponsiveCardGrid(
                children: cards.map((card) => _FinanceKpiCard(data: card)).toList(),
              ),
              const SizedBox(height: 24),
              _FinanceSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: tabs
                      .map(
                        (tab) => _SectionChip(
                          label: tab,
                          selected: tab == 'Resumen',
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _ComparisonTrendCard(points: trend)),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _DonutBreakdownCard(
                        title: 'Metodo de Pago',
                        subtitle: 'Distribucion de ingresos cobrados.',
                        items: paymentBreakdown,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _ProgressBreakdownCard(
                        title: 'Ingresos por Tipo',
                        subtitle: 'Participacion dentro del total cobrado.',
                        items: typeBreakdown,
                      ),
                    ),
                  ],
                )
              else ...[
                _ComparisonTrendCard(points: trend),
                const SizedBox(height: 20),
                _DonutBreakdownCard(
                  title: 'Metodo de Pago',
                  subtitle: 'Distribucion de ingresos cobrados.',
                  items: paymentBreakdown,
                ),
                const SizedBox(height: 20),
                _ProgressBreakdownCard(
                  title: 'Ingresos por Tipo',
                  subtitle: 'Participacion dentro del total cobrado.',
                  items: typeBreakdown,
                ),
              ],
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _SalesTableCard(sales: recentSales),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SummaryListCard(
                        title: 'Resumen Operativo',
                        rows: summary,
                      ),
                    ),
                  ],
                )
              else ...[
                _SalesTableCard(sales: recentSales),
                const SizedBox(height: 20),
                _SummaryListCard(title: 'Resumen Operativo', rows: summary),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GastosOverviewPage extends StatelessWidget {
  const _GastosOverviewPage({
    required this.cards,
    required this.trend,
    required this.expenseBreakdown,
    required this.statusBreakdown,
    required this.recentExpenses,
    required this.summary,
    required this.onAdd,
    required this.onExport,
  });

  final List<_KpiData> cards;
  final List<_TrendPoint> trend;
  final List<_CategoryAmount> expenseBreakdown;
  final List<_CategoryAmount> statusBreakdown;
  final List<_DetailedExpenseRow> recentExpenses;
  final List<_SummaryRow> summary;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1240;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceResponsiveCardGrid(
                children: cards.map((card) => _FinanceKpiCard(data: card)).toList(),
              ),
              const SizedBox(height: 24),
              const _GastosTabsCard(),
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _ExpenseComparisonChartCard(points: trend),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _DonutBreakdownCard(
                        title: 'Gastos por Categoria',
                        subtitle: 'Distribucion por origen del egreso.',
                        items: expenseBreakdown,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _ExpenseStatusCard(items: statusBreakdown),
                    ),
                  ],
                )
              else ...[
                _ExpenseComparisonChartCard(points: trend),
                const SizedBox(height: 20),
                _DonutBreakdownCard(
                  title: 'Gastos por Categoria',
                  subtitle: 'Distribucion por origen del egreso.',
                  items: expenseBreakdown,
                ),
                const SizedBox(height: 20),
                _ExpenseStatusCard(items: statusBreakdown),
              ],
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _ExpensesTableCard(
                        expenses: recentExpenses,
                        onAdd: onAdd,
                        onExport: onExport,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SummaryListCard(
                        title: 'Resumen de Gastos',
                        rows: summary,
                      ),
                    ),
                  ],
                )
              else ...[
                _ExpensesTableCard(
                  expenses: recentExpenses,
                  onAdd: onAdd,
                  onExport: onExport,
                ),
                const SizedBox(height: 20),
                _SummaryListCard(title: 'Resumen de Gastos', rows: summary),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FixedExpensesOverviewPage extends StatelessWidget {
  const _FixedExpensesOverviewPage({
    required this.cards,
    required this.monthlySeries,
    required this.categoryBreakdown,
    required this.statusBreakdown,
    required this.rows,
    required this.summary,
    required this.onAdd,
    required this.onExport,
    required this.dueDateBuilder,
  });

  final List<_KpiData> cards;
  final List<_MonthlyPoint> monthlySeries;
  final List<_CategoryAmount> categoryBreakdown;
  final List<_CategoryAmount> statusBreakdown;
  final List<Map<String, dynamic>> rows;
  final List<_SummaryRow> summary;
  final VoidCallback onAdd;
  final VoidCallback onExport;
  final DateTime Function(Map<String, dynamic>) dueDateBuilder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1240;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceResponsiveCardGrid(
                children: cards.map((card) => _FinanceKpiCard(data: card)).toList(),
              ),
              const SizedBox(height: 24),
              const _FixedExpenseTabsCard(),
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _FixedExpenseMonthlyChartCard(points: monthlySeries),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _DonutBreakdownCard(
                        title: 'Distribucion de Gastos Fijos',
                        subtitle: 'Reparto por tipo de compromiso recurrente.',
                        items: categoryBreakdown,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _ExpenseStatusCard(items: statusBreakdown),
                    ),
                  ],
                )
              else ...[
                _FixedExpenseMonthlyChartCard(points: monthlySeries),
                const SizedBox(height: 20),
                _DonutBreakdownCard(
                  title: 'Distribucion de Gastos Fijos',
                  subtitle: 'Reparto por tipo de compromiso recurrente.',
                  items: categoryBreakdown,
                ),
                const SizedBox(height: 20),
                _ExpenseStatusCard(items: statusBreakdown),
              ],
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _FixedExpensesTableCard(
                        rows: rows,
                        onAdd: onAdd,
                        onExport: onExport,
                        dueDateBuilder: dueDateBuilder,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SummaryListCard(
                        title: 'Resumen de Gastos Fijos',
                        rows: summary,
                      ),
                    ),
                  ],
                )
              else ...[
                _FixedExpensesTableCard(
                  rows: rows,
                  onAdd: onAdd,
                  onExport: onExport,
                  dueDateBuilder: dueDateBuilder,
                ),
                const SizedBox(height: 20),
                _SummaryListCard(title: 'Resumen de Gastos Fijos', rows: summary),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SuppliersOverviewPage extends StatelessWidget {
  const _SuppliersOverviewPage({
    required this.cards,
    required this.monthlySeries,
    required this.categoryBreakdown,
    required this.status,
    required this.rows,
    required this.summary,
    required this.onAdd,
    required this.onExport,
  });

  final List<_KpiData> cards;
  final List<_MonthlyPoint> monthlySeries;
  final List<_CategoryAmount> categoryBreakdown;
  final _SupplierStatusSummary status;
  final List<Map<String, dynamic>> rows;
  final List<_SummaryRow> summary;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1240;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceResponsiveCardGrid(
                children: cards.map((card) => _FinanceKpiCard(data: card)).toList(),
              ),
              const SizedBox(height: 24),
              const _SuppliersTabsCard(),
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _SupplierMonthlyChartCard(points: monthlySeries),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _DonutBreakdownCard(
                        title: 'Proveedores por Categoria',
                        subtitle: 'Distribucion por tipo de compra o servicio.',
                        items: categoryBreakdown,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _SupplierStatusCard(summary: status),
                    ),
                  ],
                )
              else ...[
                _SupplierMonthlyChartCard(points: monthlySeries),
                const SizedBox(height: 20),
                _DonutBreakdownCard(
                  title: 'Proveedores por Categoria',
                  subtitle: 'Distribucion por tipo de compra o servicio.',
                  items: categoryBreakdown,
                ),
                const SizedBox(height: 20),
                _SupplierStatusCard(summary: status),
              ],
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _SuppliersTableCard(
                        rows: rows,
                        onAdd: onAdd,
                        onExport: onExport,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SummaryListCard(
                        title: 'Resumen de Proveedores',
                        rows: summary,
                      ),
                    ),
                  ],
                )
              else ...[
                _SuppliersTableCard(
                  rows: rows,
                  onAdd: onAdd,
                  onExport: onExport,
                ),
                const SizedBox(height: 20),
                _SummaryListCard(title: 'Resumen de Proveedores', rows: summary),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PayrollOverviewPage extends StatelessWidget {
  const _PayrollOverviewPage({
    required this.cards,
    required this.monthlySeries,
    required this.distribution,
    required this.status,
    required this.rows,
    required this.staff,
    required this.summary,
    required this.onAdd,
    required this.onExport,
  });

  final List<_KpiData> cards;
  final List<_MonthlyPoint> monthlySeries;
  final List<_CategoryAmount> distribution;
  final List<_CategoryAmount> status;
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> staff;
  final List<_SummaryRow> summary;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1240;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceResponsiveCardGrid(
                children: cards.map((card) => _FinanceKpiCard(data: card)).toList(),
              ),
              const SizedBox(height: 24),
              const _PayrollTabsCard(),
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _PayrollMonthlyChartCard(points: monthlySeries),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _DonutBreakdownCard(
                        title: 'Distribucion de Nomina',
                        subtitle: 'Peso de sueldos, comisiones y ajustes.',
                        items: distribution,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _PayrollStatusCard(items: status),
                    ),
                  ],
                )
              else ...[
                _PayrollMonthlyChartCard(points: monthlySeries),
                const SizedBox(height: 20),
                _DonutBreakdownCard(
                  title: 'Distribucion de Nomina',
                  subtitle: 'Peso de sueldos, comisiones y ajustes.',
                  items: distribution,
                ),
                const SizedBox(height: 20),
                _PayrollStatusCard(items: status),
              ],
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _PayrollTableCard(
                        rows: rows,
                        staff: staff,
                        onAdd: onAdd,
                        onExport: onExport,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SummaryListCard(
                        title: 'Resumen de Nomina',
                        rows: summary,
                      ),
                    ),
                  ],
                )
              else ...[
                _PayrollTableCard(
                  rows: rows,
                  staff: staff,
                  onAdd: onAdd,
                  onExport: onExport,
                ),
                const SizedBox(height: 20),
                _SummaryListCard(title: 'Resumen de Nomina', rows: summary),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PerformanceOverviewPage extends StatelessWidget {
  const _PerformanceOverviewPage({
    required this.cards,
    required this.trend,
    required this.profitableServices,
    required this.branchBreakdown,
    required this.rows,
    required this.summary,
    required this.onExport,
  });

  final List<_KpiData> cards;
  final List<_TrendPoint> trend;
  final List<_CategoryAmount> profitableServices;
  final List<_CategoryAmount> branchBreakdown;
  final List<_TherapistPerformance> rows;
  final List<_SummaryRow> summary;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1240;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceResponsiveCardGrid(
                children: cards.map((card) => _FinanceKpiCard(data: card)).toList(),
              ),
              const SizedBox(height: 24),
              const _PerformanceTabsCard(),
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _PerformanceTrendChartCard(points: trend),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _ServiceProfitabilityCard(items: profitableServices),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _PerformanceBranchCard(items: branchBreakdown),
                    ),
                  ],
                )
              else ...[
                _PerformanceTrendChartCard(points: trend),
                const SizedBox(height: 20),
                _ServiceProfitabilityCard(items: profitableServices),
                const SizedBox(height: 20),
                _PerformanceBranchCard(items: branchBreakdown),
              ],
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _PerformanceTableCard(rows: rows, onExport: onExport),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SummaryListCard(
                        title: 'Resumen de Rendimiento',
                        rows: summary,
                      ),
                    ),
                  ],
                )
              else ...[
                _PerformanceTableCard(rows: rows, onExport: onExport),
                const SizedBox(height: 20),
                _SummaryListCard(title: 'Resumen de Rendimiento', rows: summary),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _ComparativesPage extends StatelessWidget {
  const _ComparativesPage({
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
  final MapEntry<String, double>? topServicio;
  final _TherapistPerformance? topTherapist;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ComparisonData(
        title: 'Hoy vs ayer',
        primary: _money(ventasHoy),
        secondary: _money(ventasAyer),
      ),
      _ComparisonData(
        title: 'Semana actual vs pasada',
        primary: _money(ventasSemana),
        secondary: _money(ventasSemanaPasada),
      ),
      _ComparisonData(
        title: 'Mes actual vs pasado',
        primary: _money(ventasMes),
        secondary: _money(ventasMesPasado),
      ),
      _ComparisonData(
        title: 'Ingresos vs egresos',
        primary: _money(ingresosTotales),
        secondary: _money(egresosTotales),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FinanceResponsiveCardGrid(
            minItemWidth: 270,
            children: items.map((item) => _ComparisonCard(data: item)).toList(),
          ),
          const SizedBox(height: 20),
          _FinanceSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardHeader(
                  title: 'Hallazgos clave',
                  subtitle: 'Lectura rapida de lo mejor y lo mas rentable.',
                ),
                const SizedBox(height: 16),
                _RankRow(
                  label: 'Servicio mas vendido',
                  value: topServicio == null
                      ? 'Sin datos'
                      : '${topServicio!.key} • ${_money(topServicio!.value)}',
                ),
                _RankRow(
                  label: 'Terapeuta mas rentable',
                  value: topTherapist == null
                      ? 'Sin datos'
                      : '${topTherapist!.name} • ${_money(topTherapist!.revenue)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ReportsPage extends StatelessWidget {
  const _ReportsPage();

  @override
  Widget build(BuildContext context) {
    const reports = [
      'Ventas del dia',
      'Corte de caja',
      'Nomina',
      'Gastos',
      'Utilidad mensual',
      'Rendimiento por terapeuta',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _FinanceSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              title: 'Reportes Exportables',
              subtitle: 'Base lista para conectar CSV, PDF y cortes por fecha.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: reports
                  .map(
                    (report) => OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'La exportacion de "$report" se conecta en la siguiente fase.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(report),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _AlertsPage extends StatelessWidget {
  const _AlertsPage({required this.alerts});

  final List<_MetricAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _FinanceSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              title: 'Alertas',
              subtitle: 'Eventos que conviene atender para proteger margen y flujo.',
            ),
            const SizedBox(height: 16),
            ...alerts.map((alert) => _AlertTile(alert: alert)),
          ],
        ),
      ),
    );
  }
}

String _comparisonStatus(double current, double previous) {
  if (current == previous) return 'estable';
  return current > previous ? 'mejorando' : 'descendiendo';
}

String _alertToneLabel(_MetricAlert alert) {
  if (alert.tone == _financeNegative) return 'critica';
  if (alert.tone == SaharaTheme.gold) return 'seguimiento';
  if (alert.tone == _financePositive) return 'estable';
  return 'observacion';
}

class _FinanceTabsCard extends StatelessWidget {
  const _FinanceTabsCard({required this.tabs});

  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tabs
            .map(
              (tab) => _SectionChip(
                label: tab,
                selected: tab == tabs.first,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ValueLineChartCard extends StatelessWidget {
  const _ValueLineChartCard({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.color,
  });

  final String title;
  final String subtitle;
  final List<_MonthlyPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          SizedBox(
            height: 320,
            child: points.isEmpty
                ? const _EmptyFinanceState(message: 'Sin datos para graficar.')
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _monthlyInterval(points),
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: _financeBorder, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) => Text(
                              _compactMoney(value),
                              style: GoogleFonts.inter(
                                color: _financeMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[index].label,
                                  style: GoogleFonts.inter(
                                    color: _financeMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].value),
                          ],
                          isCurved: true,
                          color: color,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FinanceRecordsTableCard extends StatelessWidget {
  const _FinanceRecordsTableCard({
    required this.columns,
    required this.rows,
    required this.searchHint,
    required this.filterPrimary,
    required this.filterSecondary,
    required this.addLabel,
    required this.onAdd,
    required this.onExport,
    this.statusColumnIndex,
  });

  final List<String> columns;
  final List<List<String>> rows;
  final String searchHint;
  final String filterPrimary;
  final String filterSecondary;
  final String addLabel;
  final VoidCallback onAdd;
  final VoidCallback onExport;
  final int? statusColumnIndex;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SaharaTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _financeBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: _financeMuted),
                      const SizedBox(width: 10),
                      Text(
                        searchHint,
                        style: GoogleFonts.inter(color: _financeMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _TopBarChip(label: filterPrimary, icon: Icons.tune_rounded),
              const SizedBox(width: 12),
              _TopBarChip(label: filterSecondary, icon: Icons.flag_outlined),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exportar'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(addLabel),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            const _EmptyFinanceState(message: 'Todavia no hay registros para esta vista.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  SaharaTheme.background.withValues(alpha: 0.8),
                ),
                columns: [
                  for (final column in columns) DataColumn(label: Text(column)),
                  const DataColumn(label: Text('Acciones')),
                ],
                rows: rows.map((row) {
                  return DataRow(
                    cells: [
                      for (var i = 0; i < columns.length; i++)
                        DataCell(
                          statusColumnIndex == i
                              ? _StatusPill(status: row.length > i ? row[i] : '')
                              : Text(
                                  row.length > i ? row[i] : '',
                                  style: GoogleFonts.inter(
                                    fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                        ),
                      const DataCell(
                        Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.more_horiz_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Mostrando ${rows.isEmpty ? 0 : 1} a ${rows.length} de ${rows.length} registros',
            style: GoogleFonts.inter(color: _financeMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FinanceModuleWorkspacePage extends StatelessWidget {
  const _FinanceModuleWorkspacePage({
    required this.cards,
    required this.tabs,
    required this.primary,
    required this.secondary,
    required this.tableColumns,
    required this.tableRows,
    required this.tableSearchHint,
    required this.tableFilterPrimary,
    required this.tableFilterSecondary,
    required this.addLabel,
    required this.summaryTitle,
    required this.summaryRows,
    required this.onAdd,
    required this.onExport,
    this.statusColumnIndex,
    this.tertiary,
  });

  final List<_KpiData> cards;
  final List<String> tabs;
  final Widget primary;
  final Widget secondary;
  final Widget? tertiary;
  final List<String> tableColumns;
  final List<List<String>> tableRows;
  final String tableSearchHint;
  final String tableFilterPrimary;
  final String tableFilterSecondary;
  final String addLabel;
  final String summaryTitle;
  final List<_SummaryRow> summaryRows;
  final VoidCallback onAdd;
  final VoidCallback onExport;
  final int? statusColumnIndex;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1240;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceResponsiveCardGrid(
                children: cards.map((card) => _FinanceKpiCard(data: card)).toList(),
              ),
              const SizedBox(height: 24),
              _FinanceTabsCard(tabs: tabs),
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: primary),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: secondary),
                    if (tertiary != null) ...[
                      const SizedBox(width: 20),
                      Expanded(flex: 4, child: tertiary!),
                    ],
                  ],
                )
              else ...[
                primary,
                const SizedBox(height: 20),
                secondary,
                if (tertiary != null) ...[
                  const SizedBox(height: 20),
                  tertiary!,
                ],
              ],
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _FinanceRecordsTableCard(
                        columns: tableColumns,
                        rows: tableRows,
                        searchHint: tableSearchHint,
                        filterPrimary: tableFilterPrimary,
                        filterSecondary: tableFilterSecondary,
                        addLabel: addLabel,
                        onAdd: onAdd,
                        onExport: onExport,
                        statusColumnIndex: statusColumnIndex,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SummaryListCard(
                        title: summaryTitle,
                        rows: summaryRows,
                      ),
                    ),
                  ],
                )
              else ...[
                _FinanceRecordsTableCard(
                  columns: tableColumns,
                  rows: tableRows,
                  searchHint: tableSearchHint,
                  filterPrimary: tableFilterPrimary,
                  filterSecondary: tableFilterSecondary,
                  addLabel: addLabel,
                  onAdd: onAdd,
                  onExport: onExport,
                  statusColumnIndex: statusColumnIndex,
                ),
                const SizedBox(height: 20),
                _SummaryListCard(title: summaryTitle, rows: summaryRows),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ComparativesHubPage extends StatelessWidget {
  const _ComparativesHubPage({
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
  final MapEntry<String, double>? topServicio;
  final _TherapistPerformance? topTherapist;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['Hoy', _money(ventasHoy), _money(ventasAyer), _comparisonStatus(ventasHoy, ventasAyer)],
      ['Semana', _money(ventasSemana), _money(ventasSemanaPasada), _comparisonStatus(ventasSemana, ventasSemanaPasada)],
      ['Mes', _money(ventasMes), _money(ventasMesPasado), _comparisonStatus(ventasMes, ventasMesPasado)],
      ['Utilidad', _money(ingresosTotales), _money(egresosTotales), ingresosTotales >= egresosTotales ? 'saludable' : 'presionado'],
    ];

    return _FinanceModuleWorkspacePage(
      cards: [
        _KpiData(title: 'Hoy vs Ayer', value: _money(ventasHoy), caption: 'Ayer ${_money(ventasAyer)}', color: _financeBlue, icon: Icons.today_outlined),
        _KpiData(title: 'Semana vs Semana', value: _money(ventasSemana), caption: 'Previa ${_money(ventasSemanaPasada)}', color: _financePositive, icon: Icons.view_week_outlined),
        _KpiData(title: 'Mes vs Mes', value: _money(ventasMes), caption: 'Previo ${_money(ventasMesPasado)}', color: SaharaTheme.gold, icon: Icons.calendar_month_outlined),
        _KpiData(title: 'Balance', value: _money(ingresosTotales - egresosTotales), caption: '${_money(ingresosTotales)} vs ${_money(egresosTotales)}', color: _financeViolet, icon: Icons.compare_arrows_rounded),
        _KpiData(title: 'Servicio Top', value: topServicio?.key ?? 'Sin datos', caption: topServicio == null ? 'Sin comparativo' : _money(topServicio!.value), color: _financePositive, icon: Icons.star_rounded),
        _KpiData(title: 'Empleado Top', value: topTherapist?.name ?? 'Sin datos', caption: topTherapist == null ? 'Sin comparativo' : _money(topTherapist!.revenue), color: _financeNegative, icon: Icons.emoji_events_rounded),
      ],
      tabs: const ['Resumen', 'Diario', 'Semanal', 'Mensual', 'Utilidad', 'Servicios', 'Equipo'],
      primary: _FinanceSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Comparativa Operativa', subtitle: 'Lectura cruzada entre periodos y presion de utilidad.'),
            const SizedBox(height: 16),
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Expanded(child: Text(row[0])),
                      Text(row[1], style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      Text(row[2], style: GoogleFonts.inter(color: _financeMuted)),
                      const SizedBox(width: 12),
                      _StatusPill(status: row[3]),
                    ],
                  ),
                )),
          ],
        ),
      ),
      secondary: _SummaryListCard(
        title: 'Hallazgos Clave',
        rows: [
          _SummaryRow('Servicio mas vendido', topServicio == null ? 'Sin datos' : '${topServicio!.key} · ${_money(topServicio!.value)}'),
          _SummaryRow('Terapeuta mas rentable', topTherapist == null ? 'Sin datos' : '${topTherapist!.name} · ${_money(topTherapist!.revenue)}'),
          _SummaryRow('Balance', ingresosTotales >= egresosTotales ? 'Operacion positiva' : 'Operacion presionada'),
        ],
      ),
      tableColumns: const ['Periodo', 'Actual', 'Comparativo', 'Estado'],
      tableRows: rows,
      tableSearchHint: 'Buscar comparativa...',
      tableFilterPrimary: 'Todos los periodos',
      tableFilterSecondary: 'Todos los estados',
      addLabel: 'Nueva comparativa',
      summaryTitle: 'Resumen de Comparativas',
      summaryRows: [
        _SummaryRow('Ventas hoy', _money(ventasHoy)),
        _SummaryRow('Ventas semana', _money(ventasSemana)),
        _SummaryRow('Ventas mes', _money(ventasMes)),
        _SummaryRow('Ingresos totales', _money(ingresosTotales)),
        _SummaryRow('Egresos totales', _money(egresosTotales)),
      ],
      onAdd: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La comparativa guiada se conecta en la siguiente fase.'))),
      onExport: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La exportacion comparativa se conecta en la siguiente fase.'))),
      statusColumnIndex: 3,
    );
  }
}

class _ReportsHubPage extends StatelessWidget {
  const _ReportsHubPage({
    required this.rows,
    required this.onAdd,
    required this.onExport,
  });

  final List<List<String>> rows;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _FinanceModuleWorkspacePage(
      cards: [
        _KpiData(title: 'Reportes Disponibles', value: '${rows.length}', caption: 'Listos para corte y exportacion', color: _financeBlue, icon: Icons.insert_drive_file_outlined),
        _KpiData(title: 'Exportaciones Rapidas', value: '5', caption: 'Ingresos, gastos, nomina y mas', color: _financePositive, icon: Icons.download_rounded),
        _KpiData(title: 'Cortes del Mes', value: '3', caption: 'Base operativa consolidada', color: SaharaTheme.gold, icon: Icons.assignment_rounded),
        _KpiData(title: 'Pendientes de Revision', value: '${rows.where((row) => row[2] != 'listo').length}', caption: 'Cobranza y utilidad mensual', color: _financeNegative, icon: Icons.pending_actions_rounded),
      ],
      tabs: const ['Resumen', 'Ventas', 'Gastos', 'Nomina', 'Cobranza', 'Utilidad', 'Rendimiento'],
      primary: _FinanceSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Centro de Reportes', subtitle: 'Cortes operativos, historicos y exportables del negocio.'),
            const SizedBox(height: 16),
            ...rows.take(6).map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Expanded(child: Text(row[0])),
                      Text(row[1], style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      _StatusPill(status: row[2]),
                    ],
                  ),
                )),
          ],
        ),
      ),
      secondary: const _SummaryListCard(
        title: 'Resumen de Reportes',
        rows: [
          _SummaryRow('Ventas del dia', 'Disponible'),
          _SummaryRow('Corte de caja', 'Listo'),
          _SummaryRow('Nomina', 'Listo'),
          _SummaryRow('Gastos', 'Listo'),
          _SummaryRow('Rendimiento', 'Disponible'),
        ],
      ),
      tableColumns: const ['Reporte', 'Formato', 'Estado'],
      tableRows: rows,
      tableSearchHint: 'Buscar reporte...',
      tableFilterPrimary: 'Todas las areas',
      tableFilterSecondary: 'Todos los estados',
      addLabel: 'Nuevo reporte',
      summaryTitle: 'Resumen Operativo',
      summaryRows: [
        _SummaryRow('Reportes listos', '${rows.where((row) => row[2] == 'listo').length}'),
        _SummaryRow('Exportables', '${rows.where((row) => row[1] == 'CSV/PDF').length}'),
        _SummaryRow('Pendientes', '${rows.where((row) => row[2] != 'listo').length}'),
      ],
      onAdd: onAdd,
      onExport: onExport,
      statusColumnIndex: 2,
    );
  }
}

class _AlertsHubPage extends StatelessWidget {
  const _AlertsHubPage({
    required this.alerts,
    required this.onAdd,
    required this.onExport,
  });

  final List<_MetricAlert> alerts;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final rows = alerts.map((alert) => [alert.title, alert.message, alert.stamp, _alertToneLabel(alert)]).toList();
    final critical = alerts.where((alert) => alert.tone == _financeNegative).length;
    final watch = alerts.where((alert) => alert.tone == SaharaTheme.gold).length;
    final stable = alerts.where((alert) => alert.tone == _financePositive).length;

    return _FinanceModuleWorkspacePage(
      cards: [
        _KpiData(title: 'Alertas Activas', value: '${alerts.length}', caption: 'Lectura actual del negocio', color: _financeNegative, icon: Icons.notifications_active_outlined),
        _KpiData(title: 'Criticas', value: '$critical', caption: 'Requieren accion inmediata', color: _financeNegative, icon: Icons.priority_high_rounded),
        _KpiData(title: 'Seguimiento', value: '$watch', caption: 'Operacion bajo observacion', color: SaharaTheme.gold, icon: Icons.visibility_rounded),
        _KpiData(title: 'Estables', value: '$stable', caption: 'Sin riesgo inmediato', color: _financePositive, icon: Icons.verified_outlined),
      ],
      tabs: const ['Resumen', 'Criticas', 'Cobranza', 'Pagos', 'Caja', 'Margen', 'Operacion'],
      primary: _AlertsSummaryCard(alerts: alerts),
      secondary: _SummaryListCard(
        title: 'Semaforo de Riesgo',
        rows: [
          _SummaryRow('Criticas', '$critical'),
          _SummaryRow('Seguimiento', '$watch'),
          _SummaryRow('Estables', '$stable'),
        ],
      ),
      tableColumns: const ['Alerta', 'Detalle', 'Marca', 'Estado'],
      tableRows: rows,
      tableSearchHint: 'Buscar alerta...',
      tableFilterPrimary: 'Todos los tipos',
      tableFilterSecondary: 'Todos los estados',
      addLabel: 'Nueva alerta',
      summaryTitle: 'Resumen de Alertas',
      summaryRows: [
        _SummaryRow('Caja chica baja', '${alerts.where((a) => a.title.toLowerCase().contains('caja')).length}'),
        _SummaryRow('Cobros pendientes', '${alerts.where((a) => a.title.toLowerCase().contains('cobrar')).length}'),
        _SummaryRow('Pagos pendientes', '${alerts.where((a) => a.title.toLowerCase().contains('pagar') || a.title.toLowerCase().contains('proveedor') || a.title.toLowerCase().contains('nomina')).length}'),
      ],
      onAdd: onAdd,
      onExport: onExport,
      statusColumnIndex: 3,
    );
  }
}

class _CashBoxPage extends StatelessWidget {
  const _CashBoxPage({
    required this.cards,
    required this.monthlySeries,
    required this.breakdown,
    required this.rows,
    required this.summary,
    required this.onAdd,
    required this.onExport,
  });

  final List<_KpiData> cards;
  final List<_MonthlyPoint> monthlySeries;
  final List<_CategoryAmount> breakdown;
  final List<List<String>> rows;
  final List<_SummaryRow> summary;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _FinanceModuleWorkspacePage(
      cards: cards,
      tabs: const ['Resumen', 'Movimientos', 'Reposiciones', 'Salidas', 'Operativo'],
      primary: _ValueLineChartCard(
        title: 'Caja Chica por Mes',
        subtitle: 'Flujo estimado de salidas menores y reposiciones.',
        points: monthlySeries,
        color: SaharaTheme.gold,
      ),
      secondary: _DonutBreakdownCard(
        title: 'Movimientos de Caja',
        subtitle: 'Distribucion estimada por origen del movimiento.',
        items: breakdown,
      ),
      tableColumns: const ['Fecha', 'Concepto', 'Responsable', 'Monto', 'Estado'],
      tableRows: rows,
      tableSearchHint: 'Buscar movimiento...',
      tableFilterPrimary: 'Todos los movimientos',
      tableFilterSecondary: 'Todos los estados',
      addLabel: 'Nuevo movimiento',
      summaryTitle: 'Resumen de Caja Chica',
      summaryRows: summary,
      onAdd: onAdd,
      onExport: onExport,
      statusColumnIndex: 4,
    );
  }
}

class _PayablesPage extends StatelessWidget {
  const _PayablesPage({
    required this.cards,
    required this.monthlySeries,
    required this.breakdown,
    required this.statusItems,
    required this.rows,
    required this.summary,
    required this.onAdd,
    required this.onExport,
  });

  final List<_KpiData> cards;
  final List<_MonthlyPoint> monthlySeries;
  final List<_CategoryAmount> breakdown;
  final List<_CategoryAmount> statusItems;
  final List<List<String>> rows;
  final List<_SummaryRow> summary;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _FinanceModuleWorkspacePage(
      cards: cards,
      tabs: const ['Resumen', 'Proveedores', 'Nomina', 'Fijos', 'Vencidos', 'Historial'],
      primary: _ValueLineChartCard(
        title: 'Cuentas por Pagar',
        subtitle: 'Compromisos pendientes por periodo.',
        points: monthlySeries,
        color: _financeNegative,
      ),
      secondary: _DonutBreakdownCard(
        title: 'Pendientes por Origen',
        subtitle: 'Distribucion entre fijos, proveedores y nomina.',
        items: breakdown,
      ),
      tertiary: _ExpenseStatusCard(items: statusItems),
      tableColumns: const ['Origen', 'Concepto', 'Responsable', 'Fecha', 'Monto', 'Estado'],
      tableRows: rows,
      tableSearchHint: 'Buscar cuenta por pagar...',
      tableFilterPrimary: 'Todos los origenes',
      tableFilterSecondary: 'Todos los estados',
      addLabel: 'Nueva cuenta por pagar',
      summaryTitle: 'Resumen de Cuentas por Pagar',
      summaryRows: summary,
      onAdd: onAdd,
      onExport: onExport,
      statusColumnIndex: 5,
    );
  }
}

class _ReceivablesPage extends StatelessWidget {
  const _ReceivablesPage({
    required this.cards,
    required this.monthlySeries,
    required this.breakdown,
    required this.rows,
    required this.summary,
    required this.onAdd,
    required this.onExport,
  });

  final List<_KpiData> cards;
  final List<_MonthlyPoint> monthlySeries;
  final List<_CategoryAmount> breakdown;
  final List<List<String>> rows;
  final List<_SummaryRow> summary;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _FinanceModuleWorkspacePage(
      cards: cards,
      tabs: const ['Resumen', 'Pendientes', 'Vencidas', 'Agenda', 'Seguimiento'],
      primary: _ValueLineChartCard(
        title: 'Cuentas por Cobrar',
        subtitle: 'Evolucion estimada de cobros pendientes.',
        points: monthlySeries,
        color: _financeBlue,
      ),
      secondary: _DonutBreakdownCard(
        title: 'Estado de Cobranza',
        subtitle: 'Pendientes y vencidas por monto estimado.',
        items: breakdown,
      ),
      tableColumns: const ['Cliente', 'Servicio', 'Terapeuta', 'Fecha', 'Monto', 'Estado'],
      tableRows: rows,
      tableSearchHint: 'Buscar cuenta por cobrar...',
      tableFilterPrimary: 'Todas las cuentas',
      tableFilterSecondary: 'Todos los estados',
      addLabel: 'Nueva cuenta por cobrar',
      summaryTitle: 'Resumen de Cuentas por Cobrar',
      summaryRows: summary,
      onAdd: onAdd,
      onExport: onExport,
      statusColumnIndex: 5,
    );
  }
}

class _BudgetsPage extends StatelessWidget {
  const _BudgetsPage({
    required this.cards,
    required this.monthlySeries,
    required this.breakdown,
    required this.rows,
    required this.summary,
    required this.onAdd,
    required this.onExport,
  });

  final List<_KpiData> cards;
  final List<_MonthlyPoint> monthlySeries;
  final List<_CategoryAmount> breakdown;
  final List<List<String>> rows;
  final List<_SummaryRow> summary;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _FinanceModuleWorkspacePage(
      cards: cards,
      tabs: const ['Resumen', 'Categorias', 'Desviaciones', 'Mensual', 'Alertas'],
      primary: _ValueLineChartCard(
        title: 'Presupuesto vs Ejecucion',
        subtitle: 'Referencia mensual de gasto real contra el plan.',
        points: monthlySeries,
        color: _financeViolet,
      ),
      secondary: _DonutBreakdownCard(
        title: 'Presupuesto por Categoria',
        subtitle: 'Participacion estimada por rubro.',
        items: breakdown,
      ),
      tableColumns: const ['Categoria', 'Actual', 'Presupuesto', 'Desviacion', 'Estado'],
      tableRows: rows,
      tableSearchHint: 'Buscar presupuesto...',
      tableFilterPrimary: 'Todas las categorias',
      tableFilterSecondary: 'Todos los estados',
      addLabel: 'Nuevo presupuesto',
      summaryTitle: 'Resumen de Presupuestos',
      summaryRows: summary,
      onAdd: onAdd,
      onExport: onExport,
      statusColumnIndex: 4,
    );
  }
}

class _GoalsPage extends StatelessWidget {
  const _GoalsPage({
    required this.cards,
    required this.breakdown,
    required this.rows,
    required this.summary,
    required this.onAdd,
    required this.onExport,
  });

  final List<_KpiData> cards;
  final List<_CategoryAmount> breakdown;
  final List<List<String>> rows;
  final List<_SummaryRow> summary;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _FinanceModuleWorkspacePage(
      cards: cards,
      tabs: const ['Resumen', 'Ingresos', 'Cobranza', 'Margen', 'Productividad'],
      primary: _ProgressBreakdownCard(
        title: 'Avance de Metas',
        subtitle: 'Progreso actual frente a objetivos clave del negocio.',
        items: breakdown,
      ),
      secondary: _SummaryListCard(
        title: 'Lectura de Metas',
        rows: summary,
      ),
      tableColumns: const ['Meta', 'Actual', 'Objetivo', 'Avance', 'Estado'],
      tableRows: rows,
      tableSearchHint: 'Buscar meta...',
      tableFilterPrimary: 'Todas las metas',
      tableFilterSecondary: 'Todos los estados',
      addLabel: 'Nueva meta',
      summaryTitle: 'Resumen de Metas',
      summaryRows: summary,
      onAdd: onAdd,
      onExport: onExport,
      statusColumnIndex: 4,
    );
  }
}

class _FinanceSettingsPage extends StatelessWidget {
  const _FinanceSettingsPage({
    required this.cards,
    required this.rows,
    required this.summary,
    required this.onAdd,
    required this.onExport,
  });

  final List<_KpiData> cards;
  final List<List<String>> rows;
  final List<_SummaryRow> summary;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _FinanceModuleWorkspacePage(
      cards: cards,
      tabs: const ['Resumen', 'Metodos', 'Alertas', 'Reglas', 'Integridad'],
      primary: _FinanceSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              title: 'Salud del Modulo Financiero',
              subtitle: 'Revision de parametros, reglas y puntos de control.',
            ),
            const SizedBox(height: 16),
            ...summary.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Expanded(child: Text(row.label)),
                    Text(row.value, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      secondary: _SummaryListCard(
        title: 'Configuracion Activa',
        rows: summary,
      ),
      tableColumns: const ['Parametro', 'Valor', 'Tipo', 'Estado'],
      tableRows: rows,
      tableSearchHint: 'Buscar parametro...',
      tableFilterPrimary: 'Todos los parametros',
      tableFilterSecondary: 'Todos los estados',
      addLabel: 'Nuevo ajuste',
      summaryTitle: 'Resumen de Configuracion',
      summaryRows: summary,
      onAdd: onAdd,
      onExport: onExport,
      statusColumnIndex: 3,
    );
  }
}

class _FinanceSidebar extends StatelessWidget {
  const _FinanceSidebar({
    required this.sections,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_FinanceSectionMeta> sections;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_financeSidebarTop, _financeSidebarBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [SaharaTheme.gold, SaharaTheme.bronceOscuro],
                ),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
            ),
            title: Text(
              'FINANZAS',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            subtitle: Text(
              'Sahara Club Spa',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                final selected = index == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onTap(index),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: selected
                            ? SaharaTheme.gold.withValues(alpha: 0.16)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? SaharaTheme.gold.withValues(alpha: 0.34)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            section.icon,
                            size: 20,
                            color: selected ? SaharaTheme.gold : Colors.white70,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              section.title,
                              style: GoogleFonts.inter(
                                color: selected ? Colors.white : Colors.white70,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: SaharaTheme.gold,
                    child: Text(
                      'A',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administracion',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Sucursal Matriz',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceTopBar extends StatelessWidget {
  const _FinanceTopBar({
    required this.title,
    required this.subtitle,
    required this.alertCount,
    required this.onRefresh,
    required this.onCreate,
    required this.createLabel,
    required this.showMenuButton,
  });

  final String title;
  final String subtitle;
  final int alertCount;
  final VoidCallback onRefresh;
  final VoidCallback? onCreate;
  final String? createLabel;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rangeLabel =
        '${DateFormat('d MMM', 'es_MX').format(DateTime(now.year, now.month, 1))} - ${DateFormat('d MMM, yyyy', 'es_MX').format(now)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _financeBorder)),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    color: _financeInk,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(color: _financeMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              _TopBarChip(label: rangeLabel, icon: Icons.calendar_today_outlined),
              const _TopBarChip(label: 'Sucursal Matriz', icon: Icons.storefront_outlined),
              const _TopBarChip(label: 'Todos', icon: Icons.tune_rounded),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Actualizar'),
              ),
              if (onCreate != null && createLabel != null)
                ElevatedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(createLabel!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SaharaTheme.gold,
                    foregroundColor: Colors.white,
                  ),
                ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SaharaTheme.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _financeBorder),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: _financeInk),
                  ),
                  if (alertCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: _financeNegative,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          alertCount > 9 ? '9+' : '$alertCount',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _financeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _financeInk,
                      child: Text(
                        'A',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administrador',
                          style: GoogleFonts.inter(
                            color: _financeInk,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'admin@sahara.local',
                          style: GoogleFonts.inter(
                            color: _financeMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceKpiCard extends StatelessWidget {
  const _FinanceKpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 152,
      child: _FinanceSurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(data.icon, color: data.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: _financeMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 42,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          data.value,
                          maxLines: 1,
                          style: GoogleFonts.playfairDisplay(
                            color: _financeInk,
                            fontSize: 29,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        data.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: data.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Ingresos vs Gastos',
            subtitle: 'Comportamiento diario del mes en curso.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 320,
            child: points.isEmpty
                ? const _EmptyFinanceState(message: 'Sin datos para graficar.')
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _chartInterval(points),
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: _financeBorder, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) => Text(
                              _compactMoney(value),
                              style: GoogleFonts.inter(
                                color: _financeMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[index].label.split(' ').first,
                                  style: GoogleFonts.inter(
                                    color: _financeMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].ingresos),
                          ],
                          isCurved: true,
                          color: _financePositive,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _financePositive.withValues(alpha: 0.08),
                          ),
                        ),
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].egresos),
                          ],
                          isCurved: true,
                          color: _financeNegative,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTrendCard extends StatelessWidget {
  const _ComparisonTrendCard({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Ingresos vs Mes Anterior',
            subtitle: 'Lectura diaria para validar aceleracion comercial.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 320,
            child: points.isEmpty
                ? const _EmptyFinanceState(message: 'Sin datos para graficar.')
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _chartInterval(points),
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: _financeBorder, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) => Text(
                              _compactMoney(value),
                              style: GoogleFonts.inter(
                                color: _financeMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[index].label.split(' ').first,
                                  style: GoogleFonts.inter(
                                    color: _financeMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].ingresos),
                          ],
                          isCurved: true,
                          color: SaharaTheme.gold,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: SaharaTheme.gold.withValues(alpha: 0.08),
                          ),
                        ),
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].egresos),
                          ],
                          isCurved: true,
                          color: _financeBlue,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DonutBreakdownCard extends StatelessWidget {
  const _DonutBreakdownCard({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<_CategoryAmount> items;

  @override
  Widget build(BuildContext context) {
    final palette = [
      SaharaTheme.gold,
      _financePositive,
      _financeBlue,
      _financeViolet,
      _financeNegative,
    ];
    final total = items.fold<double>(0, (sum, item) => sum + item.value);

    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          if (items.isEmpty || total == 0)
            const SizedBox(
              height: 260,
              child: _EmptyFinanceState(message: 'Sin datos para graficar.'),
            )
          else
            SizedBox(
              height: 260,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 56,
                        sections: [
                          for (var i = 0; i < items.length; i++)
                            PieChartSectionData(
                              value: items[i].value,
                              color: palette[i % palette.length],
                              radius: 46,
                              title: '${((items[i].value / total) * 100).round()}%',
                              titleStyle: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 5),
                                  decoration: BoxDecoration(
                                    color: palette[i % palette.length],
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        items[i].label,
                                        style: GoogleFonts.inter(
                                          color: _financeInk,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _money(items[i].value),
                                        style: GoogleFonts.inter(
                                          color: _financeMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressBreakdownCard extends StatelessWidget {
  const _ProgressBreakdownCard({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<_CategoryAmount> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.value);

    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          if (items.isEmpty || total == 0)
            const SizedBox(
              height: 220,
              child: _EmptyFinanceState(message: 'Sin datos suficientes.'),
            )
          else
            ...items.map((item) {
              final progress = total == 0 ? 0.0 : item.value / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: GoogleFonts.inter(
                              color: _financeInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _money(item.value),
                          style: GoogleFonts.inter(
                            color: _financeInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        color: SaharaTheme.gold,
                        backgroundColor: SaharaTheme.background,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _GastosTabsCard extends StatelessWidget {
  const _GastosTabsCard();

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Resumen',
      'Por Categoria',
      'Por Metodo de Pago',
      'Por Empleado',
      'Por Sucursal',
      'Con Comprobante',
      'Sin Comprobante',
    ];

    return _FinanceSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tabs
            .map(
              (tab) => _SectionChip(
                label: tab,
                selected: tab == 'Resumen',
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FixedExpenseTabsCard extends StatelessWidget {
  const _FixedExpenseTabsCard();

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Resumen',
      'Renta',
      'Servicios',
      'Software',
      'Seguros',
      'Internet',
      'Mantenimiento',
      'Vencimientos',
    ];

    return _FinanceSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tabs
            .map(
              (tab) => _SectionChip(
                label: tab,
                selected: tab == 'Resumen',
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SuppliersTabsCard extends StatelessWidget {
  const _SuppliersTabsCard();

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Resumen',
      'Activos',
      'Pendientes',
      'Vencidos',
      'Pagados',
      'Insumos',
      'Servicios',
      'Historial',
    ];

    return _FinanceSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tabs
            .map(
              (tab) => _SectionChip(
                label: tab,
                selected: tab == 'Resumen',
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PayrollTabsCard extends StatelessWidget {
  const _PayrollTabsCard();

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Resumen',
      'Empleados',
      'Sueldos',
      'Comisiones',
      'Bonos',
      'Anticipos',
      'Descuentos',
      'Historial',
    ];

    return _FinanceSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tabs
            .map(
              (tab) => _SectionChip(
                label: tab,
                selected: tab == 'Resumen',
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PerformanceTabsCard extends StatelessWidget {
  const _PerformanceTabsCard();

  @override
  Widget build(BuildContext context) {
    const tabs = [
      'Resumen',
      'Empleados',
      'Servicios',
      'Sucursales',
      'Ventas',
      'Margen',
      'Comparativas',
      'Alertas',
    ];

    return _FinanceSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tabs
            .map(
              (tab) => _SectionChip(
                label: tab,
                selected: tab == 'Resumen',
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ExpenseComparisonChartCard extends StatelessWidget {
  const _ExpenseComparisonChartCard({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Gastos vs Mes Anterior',
            subtitle: 'Comparativa diaria de salida de dinero.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 320,
            child: points.isEmpty
                ? const _EmptyFinanceState(message: 'Sin datos para graficar.')
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _chartInterval(points),
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: _financeBorder, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) => Text(
                              _compactMoney(value),
                              style: GoogleFonts.inter(
                                color: _financeMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[index].label.split(' ').first,
                                  style: GoogleFonts.inter(
                                    color: _financeMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].ingresos),
                          ],
                          isCurved: true,
                          color: _financeNegative,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _financeNegative.withValues(alpha: 0.08),
                          ),
                        ),
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].egresos),
                          ],
                          isCurved: true,
                          color: _financeMuted,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FixedExpenseMonthlyChartCard extends StatelessWidget {
  const _FixedExpenseMonthlyChartCard({required this.points});

  final List<_MonthlyPoint> points;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Gastos Fijos por Mes',
            subtitle: 'Evolucion de compromisos recurrentes en los ultimos meses.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 320,
            child: points.isEmpty
                ? const _EmptyFinanceState(message: 'Sin datos para graficar.')
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _monthlyInterval(points),
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: _financeBorder, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) => Text(
                              _compactMoney(value),
                              style: GoogleFonts.inter(
                                color: _financeMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[index].label,
                                  style: GoogleFonts.inter(
                                    color: _financeMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].value),
                          ],
                          isCurved: true,
                          color: _financeBlue,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _financeBlue.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupplierMonthlyChartCard extends StatelessWidget {
  const _SupplierMonthlyChartCard({required this.points});

  final List<_MonthlyPoint> points;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Pagos a Proveedores por Mes',
            subtitle: 'Evolucion de compras y pagos a proveedores.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 320,
            child: points.isEmpty
                ? const _EmptyFinanceState(message: 'Sin datos para graficar.')
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _monthlyInterval(points),
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: _financeBorder, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) => Text(
                              _compactMoney(value),
                              style: GoogleFonts.inter(
                                color: _financeMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[index].label,
                                  style: GoogleFonts.inter(
                                    color: _financeMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].value),
                          ],
                          isCurved: true,
                          color: _financeViolet,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _financeViolet.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PayrollMonthlyChartCard extends StatelessWidget {
  const _PayrollMonthlyChartCard({required this.points});

  final List<_MonthlyPoint> points;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Nomina por Mes',
            subtitle: 'Evolucion mensual de pagos al personal.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 320,
            child: points.isEmpty
                ? const _EmptyFinanceState(message: 'Sin datos para graficar.')
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _monthlyInterval(points),
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: _financeBorder, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) => Text(
                              _compactMoney(value),
                              style: GoogleFonts.inter(
                                color: _financeMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[index].label,
                                  style: GoogleFonts.inter(
                                    color: _financeMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].value),
                          ],
                          isCurved: true,
                          color: _financeBlue,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _financeBlue.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceTrendChartCard extends StatelessWidget {
  const _PerformanceTrendChartCard({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Rendimiento vs Mes Anterior',
            subtitle: 'Eficiencia operativa diaria contra el mes previo.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 320,
            child: points.isEmpty
                ? const _EmptyFinanceState(message: 'Sin datos para graficar.')
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 20,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: _financeBorder, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}%',
                              style: GoogleFonts.inter(
                                color: _financeMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[index].label.split(' ').first,
                                  style: GoogleFonts.inter(
                                    color: _financeMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].ingresos),
                          ],
                          isCurved: true,
                          color: _financePositive,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _financePositive.withValues(alpha: 0.08),
                          ),
                        ),
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].egresos),
                          ],
                          isCurved: true,
                          color: _financeMuted,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseStatusCard extends StatelessWidget {
  const _ExpenseStatusCard({required this.items});

  final List<_CategoryAmount> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.value);
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Estado de Gastos',
            subtitle: 'Distribucion por estatus de pago y revision.',
          ),
          const SizedBox(height: 18),
          if (items.isEmpty || total == 0)
            const SizedBox(
              height: 220,
              child: _EmptyFinanceState(message: 'Sin datos suficientes.'),
            )
          else
            ...items.map((item) {
              final progress = item.value / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: GoogleFonts.inter(
                              color: _financeInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _money(item.value),
                          style: GoogleFonts.inter(
                            color: _financeInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        color: _statusColor(item.label),
                        backgroundColor: SaharaTheme.background,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SupplierStatusCard extends StatelessWidget {
  const _SupplierStatusCard({required this.summary});

  final _SupplierStatusSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.total <= 0 ? 1 : summary.total;
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Estado de Proveedores',
            subtitle: 'Lectura por relacion activa y presion de pago.',
          ),
          const SizedBox(height: 18),
          _SupplierCountRow(
            label: 'Activos',
            value: '${summary.active}',
            progress: summary.active / total,
            color: _financePositive,
          ),
          _SupplierCountRow(
            label: 'Pendientes de Pago',
            value: '${summary.pending}',
            progress: summary.pending / total,
            color: SaharaTheme.gold,
          ),
          _SupplierCountRow(
            label: 'Vencidos',
            value: '${summary.overdue}',
            progress: summary.overdue / total,
            color: _financeNegative,
          ),
          _SupplierCountRow(
            label: 'Inactivos',
            value: '${summary.inactive}',
            progress: summary.inactive / total,
            color: _financeBlue,
          ),
        ],
      ),
    );
  }
}

class _SupplierCountRow extends StatelessWidget {
  const _SupplierCountRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _financeInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: _financeInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 10,
              color: color,
              backgroundColor: SaharaTheme.background,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollStatusCard extends StatelessWidget {
  const _PayrollStatusCard({required this.items});

  final List<_CategoryAmount> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.value);
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Estado de Pagos',
            subtitle: 'Pagado, pendiente y ajustes aplicados.',
          ),
          const SizedBox(height: 18),
          if (items.isEmpty || total == 0)
            const SizedBox(
              height: 220,
              child: _EmptyFinanceState(message: 'Sin datos suficientes.'),
            )
          else
            ...items.map((item) {
              final color = item.label == 'Pagado'
                  ? _financePositive
                  : item.label == 'Pendiente'
                      ? SaharaTheme.gold
                      : item.label == 'Bonos'
                          ? _financeViolet
                          : _financeNegative;
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: GoogleFonts.inter(
                              color: _financeInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _money(item.value),
                          style: GoogleFonts.inter(
                            color: _financeInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : (item.value / total).clamp(0, 1),
                        minHeight: 10,
                        color: color,
                        backgroundColor: SaharaTheme.background,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ServiceProfitabilityCard extends StatelessWidget {
  const _ServiceProfitabilityCard({required this.items});

  final List<_CategoryAmount> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.value);
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Servicios mas Rentables',
            subtitle: 'Ingresos generados por servicio destacado.',
          ),
          const SizedBox(height: 18),
          if (items.isEmpty || total == 0)
            const SizedBox(
              height: 220,
              child: _EmptyFinanceState(message: 'Sin datos suficientes.'),
            )
          else
            ...items.map((item) {
              final progress = total == 0 ? 0.0 : (item.value / total).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: GoogleFonts.inter(
                              color: _financeInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _money(item.value),
                          style: GoogleFonts.inter(
                            color: _financeInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        color: SaharaTheme.gold,
                        backgroundColor: SaharaTheme.background,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PerformanceBranchCard extends StatelessWidget {
  const _PerformanceBranchCard({required this.items});

  final List<_CategoryAmount> items;

  @override
  Widget build(BuildContext context) {
    return _DonutBreakdownCard(
      title: 'Rendimiento por Sucursal',
      subtitle: kEnableMultiBranch
          ? 'Distribucion de ingresos por sucursal disponible.'
          : 'Operacion concentrada en la sucursal principal.',
      items: items,
    );
  }
}

class _ExpensesTableCard extends StatelessWidget {
  const _ExpensesTableCard({
    required this.expenses,
    required this.onAdd,
    required this.onExport,
  });

  final List<_DetailedExpenseRow> expenses;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SaharaTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _financeBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: _financeMuted),
                      const SizedBox(width: 10),
                      Text(
                        'Buscar gasto...',
                        style: GoogleFonts.inter(color: _financeMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const _TopBarChip(
                label: 'Todas las categorias',
                icon: Icons.tune_rounded,
              ),
              const SizedBox(width: 12),
              const _TopBarChip(label: 'Todos los metodos', icon: Icons.payments_outlined),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exportar'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Registrar Gasto'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (expenses.isEmpty)
            const _EmptyFinanceState(message: 'Todavia no hay gastos registrados.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  SaharaTheme.background.withValues(alpha: 0.8),
                ),
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Descripcion')),
                  DataColumn(label: Text('Categoria')),
                  DataColumn(label: Text('Proveedor / Responsable')),
                  DataColumn(label: Text('Metodo de Pago')),
                  DataColumn(label: Text('Monto')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: expenses.map((expense) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(DateFormat('d MMM • h:mm a', 'es_MX').format(expense.date)),
                      ),
                      DataCell(Text(expense.title)),
                      DataCell(
                        Text(
                          expense.rawCategory,
                          style: GoogleFonts.inter(
                            color: SaharaTheme.bronceOscuro,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(Text(expense.responsible)),
                      DataCell(Text(_humanizeLabel(expense.paymentMethod))),
                      DataCell(
                        Text(
                          _money(expense.amount),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(_StatusPill(status: expense.status)),
                      const DataCell(
                        Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.more_horiz_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Mostrando ${expenses.isEmpty ? 0 : 1} a ${expenses.length} de ${expenses.length} gastos',
            style: GoogleFonts.inter(color: _financeMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FixedExpensesTableCard extends StatelessWidget {
  const _FixedExpensesTableCard({
    required this.rows,
    required this.onAdd,
    required this.onExport,
    required this.dueDateBuilder,
  });

  final List<Map<String, dynamic>> rows;
  final VoidCallback onAdd;
  final VoidCallback onExport;
  final DateTime Function(Map<String, dynamic>) dueDateBuilder;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SaharaTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _financeBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: _financeMuted),
                      const SizedBox(width: 10),
                      Text(
                        'Buscar gasto fijo...',
                        style: GoogleFonts.inter(color: _financeMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const _TopBarChip(
                label: 'Todas las categorias',
                icon: Icons.tune_rounded,
              ),
              const SizedBox(width: 12),
              const _TopBarChip(label: 'Todos los estados', icon: Icons.flag_outlined),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exportar'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Agregar Gasto Fijo'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            const _EmptyFinanceState(message: 'Todavia no hay gastos fijos registrados.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  SaharaTheme.background.withValues(alpha: 0.8),
                ),
                columns: const [
                  DataColumn(label: Text('Nombre')),
                  DataColumn(label: Text('Categoria')),
                  DataColumn(label: Text('Proveedor')),
                  DataColumn(label: Text('Fecha de Pago')),
                  DataColumn(label: Text('Frecuencia')),
                  DataColumn(label: Text('Monto')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: rows.map((row) {
                  final name = row['description']?.toString().trim().isNotEmpty == true
                      ? row['description'].toString()
                      : _humanizeLabel(row['category']?.toString() ?? 'Gasto fijo');
                  final category = _humanizeLabel(row['category']?.toString() ?? 'Sin categoria');
                  final provider = row['name']?.toString().trim().isNotEmpty == true
                      ? row['name'].toString()
                      : 'Sahara Club Spa';
                  final dueDate = _formattedDate(dueDateBuilder(row));
                  final frequency = _humanizeLabel(row['frequency']?.toString() ?? 'mensual');
                  final amount = _money((row['amount'] as num?)?.toDouble() ?? 0);
                  final status = row['status']?.toString() ?? 'pendiente';
                  return DataRow(
                    cells: [
                      DataCell(Text(name)),
                      DataCell(
                        Text(
                          category,
                          style: GoogleFonts.inter(
                            color: SaharaTheme.bronceOscuro,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(Text(provider)),
                      DataCell(Text(dueDate)),
                      DataCell(Text(frequency)),
                      DataCell(
                        Text(
                          amount,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(_StatusPill(status: status)),
                      const DataCell(
                        Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.more_horiz_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Mostrando ${rows.isEmpty ? 0 : 1} a ${rows.length} de ${rows.length} gastos fijos',
            style: GoogleFonts.inter(color: _financeMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SuppliersTableCard extends StatelessWidget {
  const _SuppliersTableCard({
    required this.rows,
    required this.onAdd,
    required this.onExport,
  });

  final List<Map<String, dynamic>> rows;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SaharaTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _financeBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: _financeMuted),
                      const SizedBox(width: 10),
                      Text(
                        'Buscar proveedor...',
                        style: GoogleFonts.inter(color: _financeMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const _TopBarChip(
                label: 'Todas las categorias',
                icon: Icons.tune_rounded,
              ),
              const SizedBox(width: 12),
              const _TopBarChip(label: 'Todos los estados', icon: Icons.flag_outlined),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exportar'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Agregar Proveedor'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            const _EmptyFinanceState(message: 'Todavia no hay proveedores registrados.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  SaharaTheme.background.withValues(alpha: 0.8),
                ),
                columns: const [
                  DataColumn(label: Text('Proveedor')),
                  DataColumn(label: Text('Categoria')),
                  DataColumn(label: Text('Referencia')),
                  DataColumn(label: Text('Metodo')),
                  DataColumn(label: Text('Monto')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Ultimo Movimiento')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: rows.map((row) {
                  final supplier = _safeSupplierName(row);
                  final category = _humanizeLabel(row['category']?.toString() ?? 'Sin categoria');
                  final reference = row['invoice_number']?.toString().trim().isNotEmpty == true
                      ? row['invoice_number'].toString()
                      : (row['description']?.toString().trim().isNotEmpty == true
                            ? row['description'].toString()
                            : 'Sin referencia');
                  final method = _humanizeLabel(
                    row['payment_method']?.toString() ?? 'sin definir',
                  );
                  final amount = _money((row['amount'] as num?)?.toDouble() ?? 0);
                  final status = row['status']?.toString() ?? 'pendiente';
                  final movement = _formattedDate(_rowExpenseDate(row));
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: SaharaTheme.gold.withValues(alpha: 0.12),
                              child: const Icon(
                                Icons.storefront_rounded,
                                size: 16,
                                color: SaharaTheme.bronceOscuro,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              supplier,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          category,
                          style: GoogleFonts.inter(
                            color: SaharaTheme.bronceOscuro,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(Text(reference)),
                      DataCell(Text(method)),
                      DataCell(
                        Text(
                          amount,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(_StatusPill(status: status)),
                      DataCell(Text(movement)),
                      const DataCell(
                        Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.payment_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.more_horiz_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Mostrando ${rows.isEmpty ? 0 : 1} a ${rows.length} de ${rows.length} proveedores',
            style: GoogleFonts.inter(color: _financeMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PayrollTableCard extends StatelessWidget {
  const _PayrollTableCard({
    required this.rows,
    required this.staff,
    required this.onAdd,
    required this.onExport,
  });

  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> staff;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final staffNames = <String, String>{
      for (final item in staff)
        item['id']?.toString() ?? '':
            item['full_name']?.toString() ?? item['name']?.toString() ?? 'Empleado',
    };
    final staffRoles = <String, String>{
      for (final item in staff)
        item['id']?.toString() ?? '': item['role']?.toString() ?? 'Empleado',
    };

    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SaharaTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _financeBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: _financeMuted),
                      const SizedBox(width: 10),
                      Text(
                        'Buscar empleado...',
                        style: GoogleFonts.inter(color: _financeMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const _TopBarChip(label: 'Todos los roles', icon: Icons.tune_rounded),
              const SizedBox(width: 12),
              const _TopBarChip(label: 'Todos los estados', icon: Icons.flag_outlined),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exportar'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Registrar Pago'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            const _EmptyFinanceState(message: 'Todavia no hay registros de nomina.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  SaharaTheme.background.withValues(alpha: 0.8),
                ),
                columns: const [
                  DataColumn(label: Text('Empleado')),
                  DataColumn(label: Text('Rol')),
                  DataColumn(label: Text('Sueldo Base')),
                  DataColumn(label: Text('Comisiones')),
                  DataColumn(label: Text('Bonos')),
                  DataColumn(label: Text('Anticipos')),
                  DataColumn(label: Text('Total a Pagar')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: rows.map((row) {
                  final employeeId = row['employee_id']?.toString() ?? '';
                  final name = staffNames[employeeId] ??
                      row['employee_name']?.toString() ??
                      'Empleado';
                  final role = _humanizeLabel(
                    staffRoles[employeeId] ??
                        row['employee_role']?.toString() ??
                        'Empleado',
                  );
                  final base = _money((row['base_salary'] as num?)?.toDouble() ?? 0);
                  final commissions = _money((row['commissions'] as num?)?.toDouble() ?? 0);
                  final bonuses = _money((row['bonuses'] as num?)?.toDouble() ?? 0);
                  final deductions = _money((row['deductions'] as num?)?.toDouble() ?? 0);
                  final total = _money((row['total_pay'] as num?)?.toDouble() ?? 0);
                  final status = row['payment_status']?.toString() ?? 'pendiente';

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: SaharaTheme.gold.withValues(alpha: 0.12),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: SaharaTheme.bronceOscuro,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              name,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(role)),
                      DataCell(Text(base)),
                      DataCell(
                        Text(
                          commissions,
                          style: GoogleFonts.inter(color: _financePositive),
                        ),
                      ),
                      DataCell(Text(bonuses)),
                      DataCell(
                        Text(
                          deductions,
                          style: GoogleFonts.inter(color: _financeNegative),
                        ),
                      ),
                      DataCell(
                        Text(
                          total,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(_StatusPill(status: status)),
                      const DataCell(
                        Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.payment_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.more_horiz_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Mostrando ${rows.isEmpty ? 0 : 1} a ${rows.length} de ${rows.length} empleados',
            style: GoogleFonts.inter(color: _financeMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PerformanceTableCard extends StatelessWidget {
  const _PerformanceTableCard({
    required this.rows,
    required this.onExport,
  });

  final List<_TherapistPerformance> rows;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final topRevenue = rows.isEmpty ? 0.0 : rows.first.revenue;
    final totalRevenue = rows.fold<double>(0, (sum, row) => sum + row.revenue);
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SaharaTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _financeBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: _financeMuted),
                      const SizedBox(width: 10),
                      Text(
                        'Buscar empleado...',
                        style: GoogleFonts.inter(color: _financeMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const _TopBarChip(
                label: 'Todos los empleados',
                icon: Icons.tune_rounded,
              ),
              const SizedBox(width: 12),
              const _TopBarChip(
                label: 'Sucursal principal',
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exportar'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            const _EmptyFinanceState(message: 'Todavia no hay datos de rendimiento.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  SaharaTheme.background.withValues(alpha: 0.8),
                ),
                columns: const [
                  DataColumn(label: Text('Empleado')),
                  DataColumn(label: Text('Rol')),
                  DataColumn(label: Text('Servicios')),
                  DataColumn(label: Text('Ventas')),
                  DataColumn(label: Text('Ticket Promedio')),
                  DataColumn(label: Text('Margen')),
                  DataColumn(label: Text('Rendimiento')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: rows.map((row) {
                  final avgTicket = row.servicesCompleted == 0
                      ? 0.0
                      : row.revenue / row.servicesCompleted;
                  final margin = totalRevenue == 0 ? 0.0 : (row.revenue / totalRevenue) * 100;
                  final label = _performanceLabel(row, topRevenue);
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: SaharaTheme.gold.withValues(alpha: 0.12),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: SaharaTheme.bronceOscuro,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              row.name,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const DataCell(Text('Terapeuta')),
                      DataCell(Text('${row.servicesCompleted}')),
                      DataCell(
                        Text(
                          _money(row.revenue),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(Text(_money(avgTicket))),
                      DataCell(Text(_percent(margin))),
                      DataCell(_PerformancePill(label: label)),
                      const DataCell(
                        Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.bar_chart_rounded, size: 18),
                            SizedBox(width: 10),
                            Icon(Icons.more_horiz_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Mostrando ${rows.isEmpty ? 0 : 1} a ${rows.length} de ${rows.length} empleados',
            style: GoogleFonts.inter(color: _financeMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SalesTableCard extends StatelessWidget {
  const _SalesTableCard({required this.sales});

  final List<Map<String, dynamic>> sales;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Ventas Recientes',
            subtitle: 'Ultimos movimientos cobrados registrados en el sistema.',
          ),
          const SizedBox(height: 18),
          if (sales.isEmpty)
            const _EmptyFinanceState(message: 'Todavia no hay ingresos cobrados.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  SaharaTheme.background.withValues(alpha: 0.8),
                ),
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Descripcion')),
                  DataColumn(label: Text('Cliente')),
                  DataColumn(label: Text('Metodo')),
                  DataColumn(label: Text('Monto')),
                ],
                rows: sales.map((sale) {
                  final createdAt = DateTime.tryParse(sale['created_at']?.toString() ?? '');
                  final itemLabel = _saleDescription(sale);
                  final clientName = sale['client_name']?.toString().trim().isNotEmpty == true
                      ? sale['client_name'].toString()
                      : 'Cliente general';
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          createdAt == null
                              ? 'Sin fecha'
                              : DateFormat('d MMM • h:mm a', 'es_MX').format(createdAt),
                        ),
                      ),
                      DataCell(Text(itemLabel)),
                      DataCell(Text(clientName)),
                      DataCell(
                        Text(_humanizeLabel(sale['payment_method']?.toString() ?? 'pendiente')),
                      ),
                      DataCell(
                        Text(
                          _money((sale['total'] as num?)?.toDouble() ?? 0),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryListCard extends StatelessWidget {
  const _SummaryListCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: title, subtitle: 'Resumen rapido para lectura ejecutiva.'),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const _EmptyFinanceState(message: 'Sin informacion disponible.')
          else
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: GoogleFonts.inter(color: _financeMuted),
                      ),
                    ),
                    Text(
                      row.value,
                      style: GoogleFonts.inter(
                        color: _financeInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertsSummaryCard extends StatelessWidget {
  const _AlertsSummaryCard({required this.alerts});

  final List<_MetricAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Alertas Recientes',
            subtitle: 'Lo que mas conviene revisar hoy.',
          ),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            const _EmptyFinanceState(message: 'Sin alertas recientes.')
          else
            ...alerts.take(4).map((alert) => _AlertTile(alert: alert, compact: true)),
        ],
      ),
    );
  }
}

class _RankedListCard extends StatelessWidget {
  const _RankedListCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_RankedItem> items;

  @override
  Widget build(BuildContext context) {
    return _FinanceSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: title, subtitle: 'Ranking basado en la data disponible.'),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const _EmptyFinanceState(message: 'Sin datos suficientes.')
          else
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: SaharaTheme.background,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.inter(
                          color: _financeInk,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        items[i].label,
                        style: GoogleFonts.inter(
                          color: _financeInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      items[i].value,
                      style: GoogleFonts.inter(
                        color: _financeMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.data});

  final _ComparisonData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 146,
      child: _FinanceSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              data.title,
              style: GoogleFonts.inter(
                color: _financeMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.primary,
                    maxLines: 1,
                    style: GoogleFonts.playfairDisplay(
                      color: _financeInk,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Comparativo: ${data.secondary}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: _financeMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceSurfaceCard extends StatelessWidget {
  const _FinanceSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _financeBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FinanceResponsiveCardGrid extends StatelessWidget {
  const _FinanceResponsiveCardGrid({
    required this.children,
    this.minItemWidth = 245,
  });

  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        const runSpacing = 16.0;
        final maxWidth = constraints.maxWidth;
        var columns = ((maxWidth + spacing) / (minItemWidth + spacing)).floor();
        if (columns < 1) columns = 1;
        final itemWidth = (maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _TopBarChip extends StatelessWidget {
  const _TopBarChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _financeBorder),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _financeMuted),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _financeInk,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SaharaTheme.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _financeBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SaharaTheme.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: SaharaTheme.bronceOscuro),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: _financeInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: _financeMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _financeMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? SaharaTheme.gold : SaharaTheme.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? SaharaTheme.gold : _financeBorder,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: selected ? Colors.white : _financeInk,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: _financeInk,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: _financeMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    this.compact = false,
  });

  final _MetricAlert alert;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 12 : 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: alert.tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: alert.tone.withValues(alpha: 0.16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(alert.icon, color: alert.tone, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: GoogleFonts.inter(
                            color: _financeInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        alert.stamp,
                        style: GoogleFonts.inter(
                          color: _financeMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: GoogleFonts.inter(
                      color: _financeMuted,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    late final Color tone;
    late final String label;
    if (normalized == 'pagado' || normalized == 'paid' || normalized == 'completed') {
      tone = _financePositive;
      label = 'Pagado';
    } else if (normalized == 'parcial') {
      tone = SaharaTheme.gold;
      label = 'Parcial';
    } else if (normalized == 'vencido' || normalized == 'cancelled') {
      tone = _financeNegative;
      label = 'Vencido';
    } else {
      tone = _financeBlue;
      label = _humanizeLabel(status);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: tone,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PerformancePill extends StatelessWidget {
  const _PerformancePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    late final Color tone;
    switch (label) {
      case 'Excelente':
        tone = _financePositive;
        break;
      case 'Muy bueno':
      case 'Bueno':
        tone = _financeBlue;
        break;
      default:
        tone = SaharaTheme.gold;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: tone,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: _financeInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _financeMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFinanceState extends StatelessWidget {
  const _EmptyFinanceState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SaharaTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _financeBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: _financeMuted, size: 28),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _financeMuted),
          ),
        ],
      ),
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
            if (descripcion.isNotEmpty) 'Descripcion: $descripcion',
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
          _LabeledField(controller: _categoryCtrl, label: 'Categoria'),
          _LabeledField(controller: _descriptionCtrl, label: 'Descripcion', lines: 2),
          _LabeledField(controller: _amountCtrl, label: 'Monto', number: true),
          _LabeledField(controller: _invoiceCtrl, label: 'Factura / referencia'),
          Row(
            children: [
              Expanded(
                child: _LabeledDropdown(
                  label: 'Metodo de pago',
                  value: _paymentMethod,
                  items: const ['efectivo', 'tarjeta', 'transferencia', 'stripe'],
                  onChanged: (value) =>
                      setState(() => _paymentMethod = value ?? _paymentMethod),
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
      title: 'Nuevo registro de nomina',
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
                    item['full_name']?.toString() ??
                        item['name']?.toString() ??
                        'Empleado',
            },
            onChanged: (value) => setState(() => _employeeId = value),
          ),
          Row(
            children: [
              Expanded(
                child: _DatePickerField(
                  controller: _periodStartCtrl,
                  label: 'Periodo inicio',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DatePickerField(
                  controller: _periodEndCtrl,
                  label: 'Periodo fin',
                ),
              ),
            ],
          ),
          _LabeledField(controller: _baseCtrl, label: 'Sueldo base', number: true),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  controller: _commissionsCtrl,
                  label: 'Comisiones',
                  number: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  controller: _bonusesCtrl,
                  label: 'Bonos',
                  number: true,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  controller: _tipsCtrl,
                  label: 'Propinas',
                  number: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  controller: _deductionsCtrl,
                  label: 'Descuentos',
                  number: true,
                ),
              ),
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
      backgroundColor: SaharaTheme.background,
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
                    color: _financeInk,
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
                    ElevatedButton(
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

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  Future<void> _pick(BuildContext context) async {
    final initial = DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('es', 'MX'),
    );
    if (picked != null) {
      controller.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: () => _pick(context),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
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
        decoration: InputDecoration(labelText: label),
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
        decoration: InputDecoration(labelText: label),
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

class _FinanceSectionMeta {
  const _FinanceSectionMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _KpiData {
  const _KpiData({
    required this.title,
    required this.value,
    required this.caption,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;
}

class _TrendPoint {
  const _TrendPoint({
    required this.label,
    required this.ingresos,
    required this.egresos,
  });

  final String label;
  final double ingresos;
  final double egresos;
}

class _CategoryAmount {
  const _CategoryAmount(this.label, this.value);

  final String label;
  final double value;
}

class _RankedItem {
  const _RankedItem(this.label, this.value);

  final String label;
  final String value;
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;
}

class _MetricAlert {
  const _MetricAlert({
    required this.title,
    required this.message,
    required this.tone,
    required this.icon,
    required this.stamp,
  });

  final String title;
  final String message;
  final Color tone;
  final IconData icon;
  final String stamp;
}

class _ExpenseEntry {
  const _ExpenseEntry({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.date,
  });

  final String category;
  final String title;
  final String subtitle;
  final double amount;
  final String status;
  final DateTime date;
}

class _DetailedExpenseRow {
  const _DetailedExpenseRow({
    required this.category,
    required this.rawCategory,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.date,
    required this.paymentMethod,
    required this.responsible,
    required this.hasReceipt,
    required this.source,
  });

  _DetailedExpenseRow.empty()
      : category = '',
        rawCategory = '',
        title = '',
        subtitle = '',
        amount = 0,
        status = '',
        date = DateTime.fromMillisecondsSinceEpoch(0),
        paymentMethod = '',
        responsible = '',
        hasReceipt = false,
        source = '';

  final String category;
  final String rawCategory;
  final String title;
  final String subtitle;
  final double amount;
  final String status;
  final DateTime date;
  final String paymentMethod;
  final String responsible;
  final bool hasReceipt;
  final String source;

  bool get isEmpty => title.isEmpty && amount == 0;
}

class _ComparisonData {
  const _ComparisonData({
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final String primary;
  final String secondary;
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

class _MonthlyPoint {
  const _MonthlyPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class _UpcomingFixedExpense {
  const _UpcomingFixedExpense({
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.status,
  });

  final String title;
  final double amount;
  final DateTime dueDate;
  final String status;
}

class _SupplierLeader {
  const _SupplierLeader({
    required this.name,
    required this.total,
  });

  final String name;
  final double total;
}

class _SupplierStatusSummary {
  const _SupplierStatusSummary({
    required this.active,
    required this.pending,
    required this.overdue,
    required this.inactive,
    required this.total,
  });

  final int active;
  final int pending;
  final int overdue;
  final int inactive;
  final int total;
}

double _chartInterval(List<_TrendPoint> points) {
  final all = [
    for (final point in points) point.ingresos,
    for (final point in points) point.egresos,
  ];
  final maxValue = all.fold<double>(0, math.max);
  if (maxValue <= 1000) return 250;
  if (maxValue <= 5000) return 1000;
  if (maxValue <= 20000) return 5000;
  return maxValue / 4;
}

double _monthlyInterval(List<_MonthlyPoint> points) {
  final maxValue = points.fold<double>(0, (current, point) => math.max(current, point.value));
  if (maxValue <= 1000) return 250;
  if (maxValue <= 5000) return 1000;
  if (maxValue <= 20000) return 5000;
  return maxValue / 4;
}

String _money(double value) =>
    NumberFormat.currency(locale: 'en_US', symbol: r'$').format(value);

String _formattedDate(DateTime value) => DateFormat('d MMM. yyyy', 'es_MX').format(value);

String _safeSupplierName(Map<String, dynamic> row) {
  final raw = row['supplier_name']?.toString().trim();
  return raw == null || raw.isEmpty ? 'Proveedor' : raw;
}

DateTime _rowExpenseDate(Map<String, dynamic> row) {
  final primary = DateTime.tryParse(row['expense_date']?.toString() ?? '');
  if (primary != null) return primary;
  final secondary = DateTime.tryParse(row['created_at']?.toString() ?? '');
  if (secondary != null) return secondary;
  return DateTime.now();
}

String _compactMoney(num value) {
  if (value >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(0)}k';
  }
  return '\$${value.toStringAsFixed(0)}';
}

String _percent(double value) => '${value.toStringAsFixed(1)}%';

String _humanizeLabel(String input) {
  final normalized = input.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return 'Sin definir';
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String _normalizeExpenseStatusLabel(String input) {
  final normalized = input.toLowerCase().trim();
  if (normalized == 'paid' || normalized == 'pagado' || normalized == 'completed') {
    return 'Pagados';
  }
  if (normalized == 'parcial' || normalized == 'pending' || normalized == 'pendiente') {
    return 'Pendientes';
  }
  if (normalized == 'vencido' || normalized == 'cancelled') {
    return 'Vencidos';
  }
  return 'En Revision';
}

Color _statusColor(String statusLabel) {
  switch (statusLabel.toLowerCase()) {
    case 'pagados':
      return _financePositive;
    case 'pendientes':
      return SaharaTheme.gold;
    case 'vencidos':
      return _financeNegative;
    default:
      return _financeBlue;
  }
}

String _performanceLabel(_TherapistPerformance row, double topRevenue) {
  if (row.servicesCompleted == 0) return 'Regular';
  if (topRevenue <= 0) return 'Bueno';
  final score = row.revenue / topRevenue;
  if (score >= 0.9 && row.noShows == 0) return 'Excelente';
  if (score >= 0.7) return 'Muy bueno';
  if (score >= 0.45) return 'Bueno';
  return 'Regular';
}

String _saleDescription(Map<String, dynamic> sale) {
  final items = sale['sale_items'];
  if (items is List && items.isNotEmpty) {
    final first = Map<String, dynamic>.from(items.first as Map);
    return ((first['description'] ?? first['name']) as String?)?.trim().isNotEmpty == true
        ? ((first['description'] ?? first['name']) as String).trim()
        : 'Venta';
  }
  return 'Venta';
}
