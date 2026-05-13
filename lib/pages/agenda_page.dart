import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_mode.dart';
import '../theme/sahara_theme.dart';
import '../features/clients/clients_module.dart';
import '../features/sales/sales_module.dart';
import '../features/mensajes/mensajes_module.dart';
import '../features/productos/productos_module.dart';
import '../features/reportes/reportes_module.dart';
import '../features/admin/admin_module.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const _kStartHour = 9;
const _kEndHour = 19;
const _kHourHeight = 64.0;
const _kTimeColWidth = 64.0;
const _kSidebarWidth = 224.0;

// ── Spanish month/day names ───────────────────────────────────────────────────
const _kMonths = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];
const _kMonthsShort = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
const _kDaysShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _kDaysLetter = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

// ── Models ────────────────────────────────────────────────────────────────────
class _Therapist {
  final String id;
  final String name;
  const _Therapist({required this.id, required this.name});
}

class _Booking {
  final String id;
  final String clientId;
  final String clientName;
  final String serviceId;
  final String serviceName;
  final String therapistId;
  final String therapistName;
  final DateTime date;
  final int startMinute;
  final int durationMinutes;
  final String status;
  final String notes;
  final String? clientPhone;

  const _Booking({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.serviceId,
    required this.serviceName,
    required this.therapistId,
    required this.therapistName,
    required this.date,
    required this.startMinute,
    required this.durationMinutes,
    required this.status,
    required this.notes,
    this.clientPhone,
    this.sucursalId,
    this.branchName,
    this.branchAddress,
    this.branchMaps,
  });

  final String? sucursalId;
  final String? branchName;
  final String? branchAddress;
  final String? branchMaps;


  factory _Booking.fromMap(Map<String, dynamic> m) {
    try {
      final t = (m['booking_time'] as String? ?? '09:00:00').split(':');
      final dateStr = m['booking_date'] as String? ?? DateTime.now().toIso8601String().split('T')[0];
      
      return _Booking(
        id: m['id'] as String? ?? '',
        clientId:
            m['client_record_id'] as String? ?? m['client_id'] as String? ?? '',
        clientName:
            (m['client_record'] as Map?)?['full_name'] as String? ??
            (m['client'] as Map?)?['full_name'] as String? ??
            'Cliente',
        serviceId: m['service_id'] as String? ?? '',
        serviceName: (m['services'] as Map?)?['name'] as String? ?? 'Servicio',
        therapistId: m['therapist_id'] as String? ?? '',
        therapistName:
            (m['therapist'] as Map?)?['full_name'] as String? ??
            'Sin asignar',
        date: DateTime.tryParse(dateStr) ?? DateTime.now(),
        startMinute: t.length >= 2 ? (int.tryParse(t[0]) ?? 9) * 60 + (int.tryParse(t[1]) ?? 0) : 540,
        durationMinutes: (m['duration_min'] as int?) ?? 60,
        status: m['status'] as String? ?? 'pending',
        notes: m['client_notes'] as String? ?? '',
        clientPhone: (m['client_record'] as Map?)?['phone'] as String? ??
                     (m['client'] as Map?)?['phone'] as String?,
        sucursalId: (m['sucursal_id'] as String?) ??
            (kEnableMultiBranch ? null : kDefaultBranchId),
        branchName: (m['sucursales'] as Map?)?['nombre'] as String? ??
            (kEnableMultiBranch ? null : kDefaultBranchName),
        branchAddress:
            (m['sucursales'] as Map?)?['direccion_completa'] as String? ??
            (kEnableMultiBranch ? null : kDefaultBranchAddress),
        branchMaps: (m['sucursales'] as Map?)?['link_maps'] as String? ??
            (kEnableMultiBranch ? null : kDefaultBranchMaps),
      );
    } catch (e) {
      debugPrint('Error parsing booking ${m['id']}: $e');
      // Return a minimal valid booking to avoid crashing the entire list
      return _Booking(
        id: m['id'] as String? ?? 'error',
        clientId: '', clientName: 'Error de datos',
        serviceId: '', serviceName: 'Error',
        therapistId: '', therapistName: '',
        date: DateTime.now(), startMinute: 0, durationMinutes: 30,
        status: 'error', notes: '',
      );
    }
  }

  Color get cardBg {
    switch (status) {
      case 'confirmed':
        return Colors.green.withValues(alpha: 0.4);
      case 'cancelled':
        return Colors.red.withValues(alpha: 0.4);
      case 'pending':
      case 'scheduled':
        return Colors.amber.withValues(alpha: 0.4);
      case 'rescheduled':
        return Colors.lightBlue.withValues(alpha: 0.4);
      default:
        return const Color(0xFFEDF4FD); // Default blueish for other states
    }
  }

  Color get cardAccent {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      case 'scheduled':
        return Colors.amber;
      case 'rescheduled':
        return Colors.lightBlue;
      default:
        return SaharaTheme.gold;
    }
  }

  String get timeLabel {
    final h = startMinute ~/ 60;
    final m = startMinute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int get endMinute => startMinute + durationMinutes;

  String get endTimeLabel {
    final h = endMinute ~/ 60;
    final m = endMinute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────
DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _yyyyMMdd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ═════════════════════════════════════════════════════════════════════════════
// AgendaPage
// ═════════════════════════════════════════════════════════════════════════════
class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late DateTime _weekStart;
  String? _therapistId;
  String _statusFilter = 'active';
  bool _loading = true;
  List<_Booking> _bookings = [];
  List<_Therapist> _therapists = [];
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;

  DateTime _now = DateTime.now();
  late Timer _timer;
  String _activeModule = 'agenda';
  String _viewMode = 'week';
  late DateTime _selectedDay;
  late DateTime _monthStart;
  bool _hasLoadedOnce = false;
  RealtimeChannel? _bookingsChannel;
  Timer? _bookingsReloadDebounce;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    _selectedDay = DateTime.now();
    _monthStart = DateTime(DateTime.now().year, DateTime.now().month);
    _loadTherapists();
    _loadBranches().then((_) => _loadBookings());
    _subscribeToBookingsRealtime();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _bookingsReloadDebounce?.cancel();
    if (_bookingsChannel != null) {
      Supabase.instance.client.removeChannel(_bookingsChannel!);
    }
    super.dispose();
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  DateTime get _rangeStart {
    if (_viewMode == 'day')
      return DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    if (_viewMode == 'month') return _monthStart;
    return _weekStart;
  }

  DateTime get _rangeEnd {
    if (_viewMode == 'day') return _rangeStart;
    if (_viewMode == 'month')
      return DateTime(_monthStart.year, _monthStart.month + 1, 0);
    return _weekEnd;
  }

  String get _topBarTitle {
    if (_viewMode == 'day') {
      const days = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
      final d = _selectedDay;
      return '${days[d.weekday - 1]}, ${d.day} de ${_kMonths[d.month - 1].toLowerCase()} de ${d.year}';
    }
    if (_viewMode == 'month') {
      return '${_kMonths[_monthStart.month - 1]} ${_monthStart.year}';
    }
    String fmt(DateTime d) =>
        '${_kDaysShort[d.weekday - 1]}, ${d.day} ${_kMonthsShort[d.month - 1]}';
    return '${fmt(_weekStart)} — ${fmt(_weekEnd)}';
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  void _subscribeToBookingsRealtime() {
    _bookingsChannel = Supabase.instance.client
        .channel('agenda-bookings-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (_) {
            _bookingsReloadDebounce?.cancel();
            _bookingsReloadDebounce = Timer(
              const Duration(milliseconds: 350),
              () {
                if (mounted) _loadBookings();
              },
            );
          },
        )
        .subscribe();
  }

  String get _sourcePlatform => kIsWeb ? 'web' : 'mobile';

  List<_Booking> _bookingsForDay(DateTime day) {
    final list = _bookings.where((b) => _sameDay(b.date, day)).toList();
    list.sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return list;
  }

  List<_Booking> get _upcomingBookings {
    final nowMinute = _now.hour * 60 + _now.minute;
    final list = _bookings
        .where(
          (b) =>
              b.status != 'cancelled' &&
              b.status != 'completed' &&
              (b.date.isAfter(DateTime(_now.year, _now.month, _now.day)) ||
                  (_sameDay(b.date, _now) && b.endMinute >= nowMinute)),
        )
        .toList();
    list.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.startMinute.compareTo(b.startMinute);
    });
    return list.take(5).toList();
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
      case 'scheduled':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmada';
      case 'checked_in':
        return 'Check-in';
      case 'in_progress':
        return 'En proceso';
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      case 'no_show':
        return 'No asistio';
      case 'rescheduled':
        return 'Reagendada';
      default:
        return 'Reservada';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
      case 'scheduled':
        return const Color(0xFFC68A17);
      case 'confirmed':
        return const Color(0xFF1A9E65);
      case 'checked_in':
        return const Color(0xFF2088D8);
      case 'in_progress':
        return const Color(0xFF6A54E0);
      case 'completed':
        return const Color(0xFF666666);
      case 'cancelled':
        return const Color(0xFFB32D2D);
      case 'no_show':
        return const Color(0xFF8B4D4D);
      case 'rescheduled':
        return const Color(0xFF0A9AA4);
      default:
        return SaharaTheme.gold;
    }
  }

  Future<bool> _updateBookingStatus(_Booking booking, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({
            'status': newStatus,
            'updated_by': Supabase.instance.client.auth.currentUser?.id,
            'source_platform': _sourcePlatform,
          })
          .eq('id', booking.id);

      await _loadBookings();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cita actualizada a ${_statusLabel(newStatus)}'),
          backgroundColor: _statusColor(newStatus),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar la cita: $e'),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
      return false;
    }
  }

  Future<void> _loadTherapists() async {
    try {
      final data = await Supabase.instance.client
          .from('staff')
          .select('id, full_name')
          .eq('role', 'therapist')
          .order('full_name');
      if (!mounted) return;
      setState(() {
        _therapists = (data as List)
            .map(
              (m) => _Therapist(
                id: m['id'] as String,
                name: m['full_name'] as String,
              ),
            )
            .toList();
      });
    } catch (e) {
      debugPrint('loadTherapists: $e');
    }
  }

  Future<void> _loadBranches() async {
    try {
      final res = await Supabase.instance.client
          .from('sucursales')
          .select('id, nombre')
          .order('nombre');
      if (mounted) {
        var branches = (res as List).cast<Map<String, dynamic>>();
        if (!kEnableMultiBranch) {
          branches = branches.isEmpty ? [defaultBranchMap()] : branches;
        }
        final hasSelectedBranch = _selectedBranchId != null &&
            branches.any((b) => b['id'] == _selectedBranchId);
        setState(() {
          _branches = branches;
          if (!kEnableMultiBranch) {
            _selectedBranchId = branches.first['id'] as String?;
          } else if (branches.isEmpty || !hasSelectedBranch) {
            _selectedBranchId = null;
          }
        });
      }
    } catch (e) {
      debugPrint('loadBranches: $e');
      if (mounted && !kEnableMultiBranch) {
        setState(() {
          _branches = [defaultBranchMap()];
          _selectedBranchId = kDefaultBranchId;
        });
      }
    }
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    try {
      dynamic q = Supabase.instance.client
          .from('bookings')
          .select('''
        id, client_id, client_record_id, service_id, sucursal_id, booking_date, booking_time, duration_min, status, therapist_id, client_notes,
        client:profiles!bookings_client_id_fkey(full_name),
        client_record:clients!bookings_client_record_id_fkey(full_name, phone),
        therapist:staff(full_name),
        services(name, price),
        sucursales(nombre, direccion_completa, link_maps)
      ''')
          .gte('booking_date', _yyyyMMdd(_rangeStart))
          .lte('booking_date', _yyyyMMdd(_rangeEnd));

      if (kEnableMultiBranch && _selectedBranchId != null) {
        q = q.eq('sucursal_id', _selectedBranchId!);
      }
      if (_therapistId != null) q = q.eq('therapist_id', _therapistId!);

      if (_statusFilter == 'active') {
        q = q.or(
          'status.eq.scheduled,status.eq.pending,status.eq.confirmed,'
          'status.eq.checked_in,status.eq.in_progress,status.eq.rescheduled',
        );
      } else if (_statusFilter != 'all') {
        q = q.eq('status', _statusFilter);
      }

      final data = await q.order('booking_date').order('booking_time') as List;
      final parsed = <_Booking>[];
      for (final row in data) {
        if (row is! Map) {
          debugPrint('Skipping booking row with invalid type: ${row.runtimeType}');
          continue;
        }
        try {
          parsed.add(_Booking.fromMap(Map<String, dynamic>.from(row)));
        } catch (e) {
          debugPrint('Skipping malformed booking row: $e');
        }
      }
      if (!mounted) return;
      setState(() {
        _bookings = parsed;
        _loading = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      debugPrint('loadBookings: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar citas: $e'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _loadBookings();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _loadBookings();
  }

  void _prevDay() {
    setState(
      () => _selectedDay = _selectedDay.subtract(const Duration(days: 1)),
    );
    _loadBookings();
  }

  void _nextDay() {
    setState(() => _selectedDay = _selectedDay.add(const Duration(days: 1)));
    _loadBookings();
  }

  void _prevMonth() {
    setState(
      () => _monthStart = DateTime(_monthStart.year, _monthStart.month - 1),
    );
    _loadBookings();
  }

  void _nextMonth() {
    setState(
      () => _monthStart = DateTime(_monthStart.year, _monthStart.month + 1),
    );
    _loadBookings();
  }

  void _goToToday() {
    setState(() {
      _weekStart = _mondayOf(DateTime.now());
      _selectedDay = DateTime.now();
      _monthStart = DateTime(DateTime.now().year, DateTime.now().month);
    });
    _loadBookings();
  }

  void _goToDate(DateTime d) {
    setState(() {
      _weekStart = _mondayOf(d);
      _selectedDay = d;
    });
    _loadBookings();
  }

  void _onMonthDayTap(DateTime day) {
    setState(() {
      _selectedDay = day;
      _viewMode = 'day';
    });
    _loadBookings();
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaharaTheme.blancoAlmendra,
      body: Column(
        children: [
          _ModuleNav(
            activeModule: _activeModule,
            onModuleTap: (m) => setState(() => _activeModule = m),
          ),
          Expanded(
            child: _activeModule == 'clientes'
                ? const ClientsModule()
                : _activeModule == 'ventas'
                ? const SalesModule()
                : _activeModule == 'mensajes'
                ? const MensajesModule()
                : _activeModule == 'productos'
                ? const ProductosModule()
                : _activeModule == 'reportes'
                ? const ReportesModule()
                : _activeModule == 'admin'
                ? const AdminModule()
                : _activeModule != 'agenda'
                ? _PlaceholderModule(module: _activeModule)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 960;
                      if (isCompact) {
                        return _MobileAgendaView(
                          title: _topBarTitle,
                          selectedDay: _selectedDay,
                          therapists: _therapists,
                          therapistId: _therapistId,
                          statusFilter: _statusFilter,
                          dayBookings: _bookingsForDay(_selectedDay),
                          upcomingBookings: _upcomingBookings,
                          onPrevDay: _prevDay,
                          onNextDay: _nextDay,
                          onPickDate: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDay,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) _goToDate(picked);
                          },
                          onToday: _goToToday,
                          onTherapist: (v) {
                            setState(() => _therapistId = v);
                            _loadBookings();
                          },
                          onStatus: (v) {
                            setState(() => _statusFilter = v);
                            _loadBookings();
                          },
                          onNew: () => _showNewDialog(context, date: _selectedDay),
                          onBookingTap: (booking) =>
                              _showBookingDetail(context, booking),
                          onConfirm: (booking) =>
                              _updateBookingStatus(booking, 'confirmed'),
                          onCancel: (booking) =>
                              _updateBookingStatus(booking, 'cancelled'),
                          onReschedule: (booking) =>
                              _showEditDialog(context, booking),
                          statusLabel: _statusLabel,
                          statusColor: _statusColor,
                        );
                      }

                      return Row(
                        children: [
                          _Sidebar(
                            therapists: _therapists,
                            therapistId: _therapistId,
                            branches: _branches,
                            selectedBranchId: _selectedBranchId,
                            statusFilter: _statusFilter,
                            weekStart: _weekStart,
                            onBranch: (v) {
                              setState(() => _selectedBranchId = v);
                              _loadBookings();
                            },
                            onTherapist: (v) {
                              setState(() => _therapistId = v);
                              _loadBookings();
                            },
                            onStatus: (v) {
                              setState(() => _statusFilter = v!);
                              _loadBookings();
                            },
                            onDateTap: _goToDate,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                _TopBar(
                                  title: _topBarTitle,
                                  viewMode: _viewMode,
                                  onPrev: _viewMode == 'day'
                                      ? _prevDay
                                      : _viewMode == 'month'
                                      ? _prevMonth
                                      : _prevWeek,
                                  onNext: _viewMode == 'day'
                                      ? _nextDay
                                      : _viewMode == 'month'
                                      ? _nextMonth
                                      : _nextWeek,
                                  onToday: _goToToday,
                                  onNew: () => _showNewDialog(
                                    context,
                                    date: _viewMode == 'day'
                                        ? _selectedDay
                                        : _weekStart,
                                  ),
                                  onViewMode: (v) {
                                    setState(() => _viewMode = v);
                                    _loadBookings();
                                  },
                                ),
                                Expanded(
                                  child: _loading && !_hasLoadedOnce
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: SaharaTheme.gold,
                                          ),
                                        )
                                      : _viewMode == 'week'
                                      ? _WeekGrid(
                                          weekStart: _weekStart,
                                          bookings: _bookings,
                                          now: _now,
                                          onBookingTap: _showBookingDetail,
                                          onReschedule: _rescheduleBooking,
                                          onSlotTap: _onSlotTap,
                                        )
                                      : _viewMode == 'day'
                                      ? _DayGrid(
                                          day: _selectedDay,
                                          bookings: _bookings,
                                          now: _now,
                                          onBookingTap: _showBookingDetail,
                                          onReschedule: _rescheduleBooking,
                                          onSlotTap: _onSlotTap,
                                        )
                                      : _MonthGrid(
                                          monthStart: _monthStart,
                                          bookings: _bookings,
                                          onDayTap: _onMonthDayTap,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showNewDialog(BuildContext ctx, {DateTime? date, TimeOfDay? time}) {
    showDialog(
      context: ctx,
      builder: (_) => _NewBookingDialog(
        therapists: _therapists,
        branches: _branches,
        initialTherapistId: _therapistId,
        initialBranchId: _selectedBranchId,
        initialDate: date,
        initialTime: time,
        onSaved: () {
          Navigator.pop(ctx);
          _loadBookings();
        },
      ),
    );
  }

  void _showEditDialog(BuildContext ctx, _Booking b) {
    showDialog(
      context: ctx,
      builder: (_) => _NewBookingDialog(
        therapists: _therapists,
        branches: _branches,
        initialTherapistId: _therapistId,
        initialBranchId: b.sucursalId,
        editBooking: b,
        onSaved: () {
          Navigator.pop(ctx);
          _loadBookings();
        },
      ),
    );
  }

  void _onSlotTap(DateTime date, TimeOfDay time, Offset globalPos) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE8E5E0)),
      ),
      position: RelativeRect.fromRect(
        globalPos & const Size(4, 4),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.add, size: 14, color: Colors.black45),
              const SizedBox(width: 6),
              Text(
                'Agregar',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(Icons.close, size: 13, color: Colors.black26),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'reserva',
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 15,
                color: Colors.black45,
              ),
              const SizedBox(width: 10),
              Text(
                'Reserva',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'bloquear',
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.block_outlined, size: 15, color: Colors.black45),
              const SizedBox(width: 10),
              Text(
                'Bloquear horario',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!mounted || value != 'reserva') return;
      _showNewDialog(context, date: date, time: time);
    });
  }

  String _isoDateOnly(DateTime value) => value.toIso8601String().split('T').first;

  String _isoTimeOnly(int minute) {
    final h = minute ~/ 60;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
  }

  Future<bool> _rescheduleBooking(
    _Booking b,
    DateTime newDate,
    int newMinute,
  ) async {
    final bookingDate = _isoDateOnly(newDate);
    final bookingTime = _isoTimeOnly(newMinute);
    try {
      debugPrint(
        'reschedule start id=${b.id} branch=${b.sucursalId} '
        'from=${_yyyyMMdd(b.date)} ${_isoTimeOnly(b.startMinute)} '
        'to=$bookingDate $bookingTime '
        'range=${_yyyyMMdd(_rangeStart)}..${_yyyyMMdd(_rangeEnd)}',
      );

      final updatedRow = await Supabase.instance.client
          .from('bookings')
          .update({
            'booking_date': bookingDate,
            'booking_time': bookingTime,
            'status': (b.status == 'completed' || b.status == 'cancelled')
                ? b.status
                : 'rescheduled',
            'updated_by': Supabase.instance.client.auth.currentUser?.id,
            'source_platform': _sourcePlatform,
          })
          .eq('id', b.id)
          .select('id, booking_date, booking_time, sucursal_id')
          .maybeSingle();

      if (updatedRow == null) {
        throw PostgrestException(
          message:
              'La actualización no devolvió filas. Posible rechazo por RLS o ID inexistente.',
          code: 'RLS_NO_ROW',
        );
      }

      debugPrint(
        'reschedule success id=${updatedRow['id']} '
        'date=${updatedRow['booking_date']} time=${updatedRow['booking_time']} '
        'branch=${updatedRow['sucursal_id']}',
      );

      await _loadBookings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita movida con éxito'),
            backgroundColor: SaharaTheme.gold,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    } on PostgrestException catch (e) {
      debugPrint('reschedule postgres error: code=${e.code} message=${e.message}');
      if (mounted) {
        var errorMsg = e.message.isNotEmpty ? e.message : e.toString();
        if (e.code == '42501' || e.code == 'RLS_NO_ROW') {
          errorMsg =
              'No tienes permisos para mover esta cita o la política RLS la rechazó';
        }
        await _loadBookings();
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al mover cita: $errorMsg'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    } catch (e) {
      debugPrint('reschedule error: $e');
      if (mounted) {
        final errorMsg = e.toString();
        await _loadBookings();
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al mover cita: $errorMsg'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }

  void _showBookingDetail(BuildContext ctx, _Booking b) {
    showDialog(
      context: ctx,
      builder: (_) => _BookingDetailDialog(
        booking: b,
        onRefresh: _loadBookings,
        onEdit: () => _showEditDialog(context, b),
        onUpdateStatus: (status) => _updateBookingStatus(b, status),
        statusLabel: _statusLabel,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Top Bar
// ═════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.viewMode,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onNew,
    required this.onViewMode,
  });

  final String title;
  final String viewMode;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onNew;
  final ValueChanged<String> onViewMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0DDD8))),
      ),
      child: Row(
        children: [
          // View mode chips
          _OutlineChip(
            label: 'DÍA',
            active: viewMode == 'day',
            onTap: () => onViewMode('day'),
          ),
          const SizedBox(width: 6),
          _OutlineChip(
            label: 'SEMANA',
            active: viewMode == 'week',
            onTap: () => onViewMode('week'),
          ),
          const SizedBox(width: 6),
          _OutlineChip(
            label: 'MES',
            active: viewMode == 'month',
            onTap: () => onViewMode('month'),
          ),
          const SizedBox(width: 12),
          // Prev / Next
          _IconBtn(icon: Icons.chevron_left, onTap: onPrev),
          _IconBtn(icon: Icons.chevron_right, onTap: onNext),
          const SizedBox(width: 8),
          // Period label
          Text(
            title,
            style: GoogleFonts.inter(color: Colors.black54, fontSize: 13),
          ),
          const Spacer(),
          // Today
          _OutlineChip(label: 'HOY', active: false, onTap: onToday),
          const SizedBox(width: 12),
          // Nueva Reserva
          FilledButton.icon(
            onPressed: onNew,
            style: FilledButton.styleFrom(
              backgroundColor: SaharaTheme.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              'Nueva Reserva',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineChip extends StatelessWidget {
  const _OutlineChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? SaharaTheme.gold.withValues(alpha: 0.15)
            : Colors.transparent,
        border: Border.all(color: active ? SaharaTheme.gold : Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: active ? SaharaTheme.gold : Colors.black54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Icon(icon, color: Colors.black54, size: 20),
    ),
  );
}

class _MobileAgendaView extends StatelessWidget {
  const _MobileAgendaView({
    required this.title,
    required this.selectedDay,
    required this.therapists,
    required this.therapistId,
    required this.statusFilter,
    required this.dayBookings,
    required this.upcomingBookings,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onPickDate,
    required this.onToday,
    required this.onTherapist,
    required this.onStatus,
    required this.onNew,
    required this.onBookingTap,
    required this.onConfirm,
    required this.onCancel,
    required this.onReschedule,
    required this.statusLabel,
    required this.statusColor,
  });

  final String title;
  final DateTime selectedDay;
  final List<_Therapist> therapists;
  final String? therapistId;
  final String statusFilter;
  final List<_Booking> dayBookings;
  final List<_Booking> upcomingBookings;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickDate;
  final VoidCallback onToday;
  final ValueChanged<String?> onTherapist;
  final ValueChanged<String> onStatus;
  final VoidCallback onNew;
  final ValueChanged<_Booking> onBookingTap;
  final Future<bool> Function(_Booking) onConfirm;
  final Future<bool> Function(_Booking) onCancel;
  final ValueChanged<_Booking> onReschedule;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 960;
    return Container(
      color: SaharaTheme.blancoAlmendra,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE0DDD8))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.black87,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: onNew,
                      style: FilledButton.styleFrom(
                        backgroundColor: SaharaTheme.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      child: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _IconBtn(icon: Icons.chevron_left, onTap: onPrevDay),
                    _IconBtn(icon: Icons.chevron_right, onTap: onNextDay),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPickDate,
                        icon: const Icon(Icons.calendar_today_outlined, size: 16),
                        label: Text(
                          '${selectedDay.day}/${selectedDay.month}/${selectedDay.year}',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(onPressed: onToday, child: const Text('Hoy')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SideDropdown<String?>(
                        value: therapistId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos los terapeutas')),
                          ...therapists.map(
                            (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
                          ),
                        ],
                        onChanged: onTherapist,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SideDropdown<String>(
                        value: statusFilter,
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Activas')),
                          DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
                          DropdownMenuItem(value: 'confirmed', child: Text('Confirmadas')),
                          DropdownMenuItem(value: 'completed', child: Text('Completadas')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Canceladas')),
                          DropdownMenuItem(value: 'all', child: Text('Todas')),
                        ],
                        onChanged: (value) {
                          if (value != null) onStatus(value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MobileSectionTitle(
                  title: 'Agenda del dia',
                  subtitle: '${dayBookings.length} citas',
                ),
                const SizedBox(height: 10),
                if (dayBookings.isEmpty)
                  _MobileEmptyState(
                    message: 'No hay citas para este dia con los filtros actuales.',
                  )
                else
                  ...dayBookings.map(
                    (booking) => _MobileBookingCard(
                      booking: booking,
                      statusLabel: statusLabel,
                      statusColor: statusColor,
                      onTap: () => onBookingTap(booking),
                      onConfirm: booking.status == 'pending' || booking.status == 'scheduled'
                          ? () => onConfirm(booking)
                          : null,
                      onCancel: booking.status != 'completed' && booking.status != 'cancelled'
                          ? () => onCancel(booking)
                          : null,
                      onReschedule: () => onReschedule(booking),
                    ),
                  ),
                const SizedBox(height: 18),
                _MobileSectionTitle(
                  title: 'Proximas citas',
                  subtitle: '${upcomingBookings.length} proximas',
                ),
                const SizedBox(height: 10),
                if (upcomingBookings.isEmpty)
                  _MobileEmptyState(
                    message: 'No hay proximas citas activas en el rango cargado.',
                  )
                else
                  ...upcomingBookings.map(
                    (booking) => _MobileBookingCard(
                      booking: booking,
                      compact: true,
                      statusLabel: statusLabel,
                      statusColor: statusColor,
                      onTap: () => onBookingTap(booking),
                      onConfirm: booking.status == 'pending' || booking.status == 'scheduled'
                          ? () => onConfirm(booking)
                          : null,
                      onCancel: booking.status != 'completed' && booking.status != 'cancelled'
                          ? () => onCancel(booking)
                          : null,
                      onReschedule: () => onReschedule(booking),
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

class _MobileSectionTitle extends StatelessWidget {
  const _MobileSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
        ),
      ],
    );
  }
}

class _MobileEmptyState extends StatelessWidget {
  const _MobileEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 960;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
      ),
    );
  }
}

class _MobileBookingCard extends StatelessWidget {
  const _MobileBookingCard({
    required this.booking,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
    required this.onReschedule,
    this.onConfirm,
    this.onCancel,
    this.compact = false,
  });

  final _Booking booking;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final VoidCallback onTap;
  final VoidCallback onReschedule;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badgeColor = statusColor(booking.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${booking.timeLabel} - ${booking.endTimeLabel}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel(booking.status),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            booking.clientName,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.serviceName} • ${booking.therapistName}',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
          ),
          if (!compact && (booking.clientPhone ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              booking.clientPhone!,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
            ),
          ],
          if (!compact && booking.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              booking.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onConfirm != null)
                _DialogBtn(
                  label: 'Confirmar',
                  color: const Color(0xFF1A9E65),
                  onTap: onConfirm!,
                ),
              if (onCancel != null)
                _DialogBtn(
                  label: 'Cancelar',
                  color: const Color(0xFFB32D2D),
                  onTap: onCancel!,
                ),
              _DialogBtn(
                label: 'Reagendar',
                color: const Color(0xFF0A9AA4),
                onTap: onReschedule,
              ),
              _DialogBtn(
                label: 'Detalle',
                color: SaharaTheme.gold,
                onTap: onTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sidebar
// ═════════════════════════════════════════════════════════════════════════════
class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.therapists,
    required this.therapistId,
    required this.branches,
    required this.selectedBranchId,
    required this.statusFilter,
    required this.weekStart,
    required this.onBranch,
    required this.onTherapist,
    required this.onStatus,
    required this.onDateTap,
  });

  final List<_Therapist> therapists;
  final String? therapistId;
  final List<Map<String, dynamic>> branches;
  final String? selectedBranchId;
  final String statusFilter;
  final DateTime weekStart;
  final ValueChanged<String?> onBranch;
  final ValueChanged<String?> onTherapist;
  final ValueChanged<String?> onStatus;
  final ValueChanged<DateTime> onDateTap;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  late DateTime _miniMonth;

  @override
  void initState() {
    super.initState();
    _miniMonth = DateTime(widget.weekStart.year, widget.weekStart.month);
  }

  @override
  void didUpdateWidget(_Sidebar old) {
    super.didUpdateWidget(old);
    if (!_sameDay(old.weekStart, widget.weekStart)) {
      _miniMonth = DateTime(widget.weekStart.year, widget.weekStart.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSidebarWidth,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE0DDD8))),
      ),
      child: Column(
        children: [
          // Brand
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE0DDD8))),
            ),
            child: Row(
              children: [
                Text(
                  'SAHARA',
                  style: GoogleFonts.playfairDisplay(
                    color: SaharaTheme.gold,
                    fontSize: 17,
                    letterSpacing: 4,
                  ),
                ),
                const Spacer(),
                Text(
                  'RECEPCIÓN',
                  style: GoogleFonts.inter(
                    color: Colors.black26,
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          // Filters + mini-calendar
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (kEnableMultiBranch) ...[
                    _SideLabel('SUCURSAL'),
                    const SizedBox(height: 6),
                    _SideDropdown<String?>(
                      value: widget.selectedBranchId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas')),
                        ...widget.branches.map(
                          (b) => DropdownMenuItem(
                            value: b['id'],
                            child: Text(b['nombre']),
                          ),
                        ),
                      ],
                      onChanged: (v) => widget.onBranch(v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _SideLabel('PROFESIONAL'),
                  const SizedBox(height: 6),
                  _SideDropdown<String?>(
                    value: widget.therapistId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...widget.therapists.map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      ),
                    ],
                    onChanged: widget.onTherapist,
                  ),
                  const SizedBox(height: 16),
                  _SideLabel('ESTADO'),
                  const SizedBox(height: 6),
                  _SideDropdown<String>(
                    value: widget.statusFilter,
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Reservas activas'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pendientes'),
                      ),
                      DropdownMenuItem(
                        value: 'confirmed',
                        child: Text('Confirmadas'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completadas'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Canceladas'),
                      ),
                      DropdownMenuItem(value: 'no_show', child: Text('No show')),
                      DropdownMenuItem(value: 'all', child: Text('Todas')),
                    ],
                    onChanged: widget.onStatus,
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE0DDD8)),
                  const SizedBox(height: 16),
                  // Mini calendar
                  _MiniCalendar(
                    month: _miniMonth,
                    weekStart: widget.weekStart,
                    onDayTap: widget.onDateTap,
                    onPrevMonth: () => setState(
                      () => _miniMonth = DateTime(
                        _miniMonth.year,
                        _miniMonth.month - 1,
                      ),
                    ),
                    onNextMonth: () => setState(
                      () => _miniMonth = DateTime(
                        _miniMonth.year,
                        _miniMonth.month + 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Logout
          InkWell(
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/recepcion');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE0DDD8))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Colors.black38, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    'Cerrar sesión',
                    style: GoogleFonts.inter(
                      color: Colors.black38,
                      fontSize: 12,
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

class _SideLabel extends StatelessWidget {
  const _SideLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(
      color: Colors.black45,
      fontSize: 10,
      letterSpacing: 1.5,
    ),
  );
}

class _SideDropdown<T> extends StatelessWidget {
  const _SideDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F6F2),
      border: Border.all(color: const Color(0xFFE0DDD8)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        dropdownColor: Colors.white,
        style: GoogleFonts.inter(color: Colors.black87, fontSize: 12),
        iconEnabledColor: Colors.black45,
        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Mini Calendar
// ═════════════════════════════════════════════════════════════════════════════
class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar({
    required this.month,
    required this.weekStart,
    required this.onDayTap,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final DateTime weekStart;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final weekEnd = weekStart.add(const Duration(days: 6));
    final firstDay = DateTime(month.year, month.month, 1);
    final offset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              '${_kMonths[month.month - 1]} ${month.year}',
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _MiniNavBtn(icon: Icons.chevron_left, onTap: onPrevMonth),
            _MiniNavBtn(icon: Icons.chevron_right, onTap: onNextMonth),
          ],
        ),
        const SizedBox(height: 8),
        // Day-of-week headers
        Row(
          children: _kDaysLetter
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: GoogleFonts.inter(
                        color: Colors.black38,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        // Date grid
        ...List.generate(
          6,
          (row) => Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col - offset + 1;
              if (idx < 1 || idx > daysInMonth) {
                return const Expanded(child: SizedBox(height: 26));
              }
              final day = DateTime(month.year, month.month, idx);
              final isToday = _sameDay(day, today);
              final inWeek = !day.isBefore(weekStart) && !day.isAfter(weekEnd);

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDayTap(day),
                  child: Container(
                    height: 26,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isToday
                          ? SaharaTheme.gold
                          : inWeek
                          ? SaharaTheme.gold.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$idx',
                      style: GoogleFonts.inter(
                        color: isToday
                            ? Colors.black
                            : inWeek
                            ? SaharaTheme.gold
                            : Colors.black54,
                        fontSize: 11,
                        fontWeight: isToday || inWeek
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MiniNavBtn extends StatelessWidget {
  const _MiniNavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(3),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Icon(icon, color: Colors.black38, size: 16),
    ),
  );
}

// ── Reschedule confirm dialog ─────────────────────────────────────────────────
Future<bool?> _confirmReschedule(
  BuildContext context,
  _Booking booking,
  DateTime newDate,
  int newMinute,
) {
  final h = newMinute ~/ 60;
  final m = newMinute % 60;
  final time =
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  final date = '${newDate.day} ${_kMonthsShort[newDate.month - 1]}';
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Mover reserva',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      content: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.black87,
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'Se moverá la reserva de '),
            TextSpan(
              text: booking.clientName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: ' — '),
            TextSpan(
              text: booking.serviceName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: '\nal $date a las $time.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Cancelar',
            style: GoogleFonts.inter(color: Colors.black54),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC6A76A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Mover reserva',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Weekly Grid
// ═════════════════════════════════════════════════════════════════════════════
class _WeekGrid extends StatefulWidget {
  const _WeekGrid({
    required this.weekStart,
    required this.bookings,
    required this.now,
    required this.onBookingTap,
    required this.onReschedule,
    required this.onSlotTap,
  });

  final DateTime weekStart;
  final List<_Booking> bookings;
  final DateTime now;
  final void Function(BuildContext, _Booking) onBookingTap;
  final Future<bool> Function(_Booking, DateTime, int) onReschedule;
  final void Function(DateTime, TimeOfDay, Offset) onSlotTap;

  @override
  State<_WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<_WeekGrid> {
  _Booking? _dragging;
  Offset? _dragLocal;
  Offset? _hoverLocal;
  double _dayWidth = 0;
  final _gridKey = GlobalKey();

  // ── Helpers ────────────────────────────────────────────────────────────────
  (int, int)? _slotFromLocal(Offset local) {
    if (_dayWidth <= 0 || local.dx < 0 || local.dy < 0) return null;
    final dayIdx = (local.dx / _dayWidth).floor().clamp(0, 6);
    final rawMin = (local.dy / _kHourHeight * 60).round() + _kStartHour * 60;
    final snapped = (rawMin / 15).round() * 15;
    if (snapped < _kStartHour * 60 || snapped > _kEndHour * 60 - 15)
      return null;
    return (dayIdx, snapped);
  }

  Offset? _localFromGrid(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  String _minuteLabel(int minute) {
    final h = minute ~/ 60;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final today = DateTime(widget.now.year, widget.now.month, widget.now.day);

    return Column(
      children: [
        _buildDayHeader(today),
        Expanded(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  _dayWidth = (constraints.maxWidth - _kTimeColWidth) / 7;
                  final gridHeight = (_kEndHour - _kStartHour) * _kHourHeight;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeColumn(gridHeight),
                      _buildGrid(ctx, gridHeight, today),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Day header ─────────────────────────────────────────────────────────────
  Widget _buildDayHeader(DateTime today) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0DDD8))),
      ),
      child: Row(
        children: [
          SizedBox(width: _kTimeColWidth),
          ...List.generate(7, (i) {
            final d = widget.weekStart.add(Duration(days: i));
            final isToday = _sameDay(d, today);
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isToday
                      ? SaharaTheme.gold.withValues(alpha: 0.08)
                      : null,
                  border: i > 0
                      ? Border(
                          left: BorderSide(
                            color: SaharaTheme.gold.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        )
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      _kDaysShort[i],
                      style: GoogleFonts.inter(
                        color: isToday ? SaharaTheme.gold : Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.day}/${d.month}',
                      style: GoogleFonts.inter(
                        color: isToday ? SaharaTheme.gold : Colors.black87,
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Time column ────────────────────────────────────────────────────────────
  Widget _buildTimeColumn(double gridHeight) {
    return SizedBox(
      width: _kTimeColWidth,
      height: gridHeight,
      child: Column(
        children: List.generate(_kEndHour - _kStartHour, (i) {
          return SizedBox(
            height: _kHourHeight,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 4),
                child: Text(
                  '${(_kStartHour + i).toString().padLeft(2, '0')}:00',
                  style: GoogleFonts.inter(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Main grid area ─────────────────────────────────────────────────────────
  Widget _buildGrid(BuildContext ctx, double gridHeight, DateTime today) {
    return SizedBox(
      key: _gridKey,
      width: _dayWidth * 7,
      height: gridHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 1. Grid lines
          CustomPaint(
            size: Size(_dayWidth * 7, gridHeight),
            painter: _GridPainter(
              dayWidth: _dayWidth,
              hourHeight: _kHourHeight,
              hours: _kEndHour - _kStartHour,
              today: today,
              weekStart: widget.weekStart,
            ),
          ),

          // 2. Empty-slot hover highlight
          if (_dragging == null && _hoverLocal != null) _buildHoverHighlight(),

          // 3. Ghost card during drag
          if (_dragging != null && _dragLocal != null) _buildGhostCard(),

          // 5. Current time indicator
          _buildTimeIndicator(today),

          // 6. Interaction layer — hover + click on empty slots
          MouseRegion(
            onHover: (e) {
              final local = _localFromGrid(e.position);
              if (local != null) setState(() => _hoverLocal = local);
            },
            onExit: (_) => setState(() => _hoverLocal = null),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) {
                final local = _localFromGrid(details.globalPosition);
                if (local == null) return;
                final slot = _slotFromLocal(local);
                if (slot == null) return;
                final (dayIdx, minute) = slot;
                final date = widget.weekStart.add(Duration(days: dayIdx));
                widget.onSlotTap(
                  date,
                  TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
                  details.globalPosition,
                );
              },
              child: const SizedBox.expand(),
            ),
          ),

          // 7. DragTarget — full grid drop zone
          DragTarget<_Booking>(
            onMove: (details) {
              final local = _localFromGrid(details.offset);
              if (local != null) setState(() => _dragLocal = local);
            },
            onLeave: (_) => setState(() => _dragLocal = null),
            onAcceptWithDetails: (details) async {
              final local = _localFromGrid(details.offset);
              if (local == null) return;
              final slot = _slotFromLocal(local);
              if (slot == null) return;
              final (dayIdx, minute) = slot;
              final newDate = widget.weekStart.add(Duration(days: dayIdx));
              final confirmed = await _confirmReschedule(
                context,
                details.data,
                newDate,
                minute,
              );
              if (confirmed != true) {
                if (!mounted) return;
                setState(() {
                  _dragging = null;
                  _dragLocal = null;
                });
                return;
              }
              final persisted = await widget.onReschedule(
                details.data,
                newDate,
                minute,
              );
              if (!mounted) return;
              setState(() {
                _dragging = null;
                _dragLocal = null;
              });
              if (!persisted) return;
            },
            builder: (context, candidateData, rejectedData) =>
                const SizedBox.expand(),
          ),

          // 8. Booking cards (Draggable) - MOVED TO TOP OF STACK Z-INDEX
          ..._buildCards(ctx),
        ],
      ),
    );
  }

  // ── Hover highlight ────────────────────────────────────────────────────────
  Widget _buildHoverHighlight() {
    final slot = _slotFromLocal(_hoverLocal!);
    if (slot == null) return const SizedBox.shrink();
    final (dayIdx, minute) = slot;
    final top = (minute - _kStartHour * 60) * (_kHourHeight / 60);
    return Positioned(
      top: top,
      left: dayIdx * _dayWidth,
      width: _dayWidth,
      height: _kHourHeight / 2,
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: SaharaTheme.gold.withValues(alpha: 0.10),
            border: Border.all(
              color: SaharaTheme.gold.withValues(alpha: 0.45),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            _minuteLabel(minute),
            style: GoogleFonts.inter(
              color: SaharaTheme.gold,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ── Ghost card ─────────────────────────────────────────────────────────────
  Widget _buildGhostCard() {
    final slot = _slotFromLocal(_dragLocal!);
    if (slot == null) return const SizedBox.shrink();
    final (dayIdx, minute) = slot;
    final top = (minute - _kStartHour * 60) * (_kHourHeight / 60);
    final height = (_dragging!.durationMinutes * _kHourHeight / 60).clamp(
      22.0,
      double.infinity,
    );
    return Positioned(
      top: top,
      left: dayIdx * _dayWidth,
      width: _dayWidth,
      height: height,
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: SaharaTheme.gold.withValues(alpha: 0.18),
            border: Border.all(color: SaharaTheme.gold, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _minuteLabel(minute),
                style: GoogleFonts.inter(
                  color: SaharaTheme.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _dragging!.clientName,
                style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Time indicator ─────────────────────────────────────────────────────────
  Widget _buildTimeIndicator(DateTime today) {
    final dayIdx = today.difference(widget.weekStart).inDays;
    if (dayIdx < 0 || dayIdx > 6) return const SizedBox.shrink();
    final minutes = widget.now.hour * 60 + widget.now.minute;
    final topOffset = (minutes - _kStartHour * 60) * (_kHourHeight / 60);
    if (topOffset < 0 || topOffset > (_kEndHour - _kStartHour) * _kHourHeight) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: topOffset - 1,
      left: dayIdx * _dayWidth,
      width: _dayWidth,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Container(
                height: 1.5,
                color: Colors.red.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────────────
  List<Widget> _buildCards(BuildContext ctx) {
    return widget.bookings.map((b) {
      final dayIdx = b.date.difference(widget.weekStart).inDays;
      if (dayIdx < 0 || dayIdx > 6) return const SizedBox.shrink();
      final top = (b.startMinute - _kStartHour * 60) * (_kHourHeight / 60);
      final height = (b.durationMinutes * _kHourHeight / 60).clamp(
        22.0,
        double.infinity,
      );
      if (top < 0) return const SizedBox.shrink();

      return Positioned(
        top: top + 1,
        left: dayIdx * _dayWidth + 1,
        width: _dayWidth - 2,
        height: height,
        child: Draggable<_Booking>(
          data: b,
          onDragStarted: () => setState(() => _dragging = b),
          onDraggableCanceled: (velocity, offset) => setState(() {
            _dragging = null;
            _dragLocal = null;
          }),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: _dayWidth - 2,
              height: height,
              child: Opacity(
                opacity: 0.85,
                child: _BookingCard(booking: b, onTap: () {}),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: _BookingCard(booking: b, onTap: () {}),
          ),
          child: _BookingCard(
            booking: b,
            onTap: () => widget.onBookingTap(ctx, b),
          ),
        ),
      );
    }).toList();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Day Grid  (vista de un solo día)
// ═════════════════════════════════════════════════════════════════════════════
class _DayGrid extends StatefulWidget {
  const _DayGrid({
    required this.day,
    required this.bookings,
    required this.now,
    required this.onBookingTap,
    required this.onReschedule,
    required this.onSlotTap,
  });
  final DateTime day;
  final List<_Booking> bookings;
  final DateTime now;
  final void Function(BuildContext, _Booking) onBookingTap;
  final Future<bool> Function(_Booking, DateTime, int) onReschedule;
  final void Function(DateTime, TimeOfDay, Offset) onSlotTap;

  @override
  State<_DayGrid> createState() => _DayGridState();
}

class _DayGridState extends State<_DayGrid> {
  _Booking? _dragging;
  Offset? _dragLocal;
  Offset? _hoverLocal;
  double _colWidth = 0;
  final _gridKey = GlobalKey();

  int? _slotMinute(Offset local) {
    if (_colWidth <= 0 || local.dy < 0) return null;
    final rawMin = (local.dy / _kHourHeight * 60).round() + _kStartHour * 60;
    final snapped = (rawMin / 15).round() * 15;
    if (snapped < _kStartHour * 60 || snapped > _kEndHour * 60 - 15)
      return null;
    return snapped;
  }

  Offset? _localFromGrid(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  String _minuteLabel(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final isToday = _sameDay(widget.day, today);

    return Column(
      children: [
        // Day header
        Container(
          height: 56,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE0DDD8))),
          ),
          child: Row(
            children: [
              SizedBox(width: _kTimeColWidth),
              Expanded(
                child: Container(
                  color: isToday
                      ? SaharaTheme.gold.withValues(alpha: 0.05)
                      : null,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _kDaysShort[widget.day.weekday - 1].toUpperCase(),
                        style: GoogleFonts.inter(
                          color: isToday ? SaharaTheme.gold : Colors.black45,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.day.day} de ${_kMonths[widget.day.month - 1].toLowerCase()}',
                        style: GoogleFonts.inter(
                          color: isToday ? SaharaTheme.gold : Colors.black87,
                          fontSize: 14,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scrollable grid
        Expanded(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  _colWidth = constraints.maxWidth - _kTimeColWidth;
                  final gridHeight = (_kEndHour - _kStartHour) * _kHourHeight;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time column
                      SizedBox(
                        width: _kTimeColWidth,
                        height: gridHeight,
                        child: Column(
                          children: List.generate(
                            _kEndHour - _kStartHour,
                            (i) => SizedBox(
                              height: _kHourHeight,
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    right: 10,
                                    top: 4,
                                  ),
                                  child: Text(
                                    '${(_kStartHour + i).toString().padLeft(2, '0')}:00',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Grid area
                      SizedBox(
                        key: _gridKey,
                        width: _colWidth,
                        height: gridHeight,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            // Grid lines
                            CustomPaint(
                              size: Size(_colWidth, gridHeight),
                              painter: _DayPainter(
                                hourHeight: _kHourHeight,
                                hours: _kEndHour - _kStartHour,
                                isToday: isToday,
                              ),
                            ),
                            // Hover highlight
                            if (_dragging == null && _hoverLocal != null)
                              _buildHover(),
                            // Ghost card
                            if (_dragging != null && _dragLocal != null)
                              _buildGhost(),
                            // Time indicator
                            if (isToday) _buildIndicator(),
                            // Interaction layer
                            MouseRegion(
                              onHover: (e) {
                                final l = _localFromGrid(e.position);
                                if (l != null) setState(() => _hoverLocal = l);
                              },
                              onExit: (_) => setState(() => _hoverLocal = null),
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapDown: (d) {
                                  final l = _localFromGrid(d.globalPosition);
                                  if (l == null) return;
                                  final m = _slotMinute(l);
                                  if (m == null) return;
                                  widget.onSlotTap(
                                    widget.day,
                                    TimeOfDay(hour: m ~/ 60, minute: m % 60),
                                    d.globalPosition,
                                  );
                                },
                                child: const SizedBox.expand(),
                              ),
                            ),
                            // Drop target
                            DragTarget<_Booking>(
                              onMove: (d) {
                                final l = _localFromGrid(d.offset);
                                if (l != null) setState(() => _dragLocal = l);
                              },
                              onLeave: (_) => setState(() => _dragLocal = null),
                              onAcceptWithDetails: (d) async {
                                final l = _localFromGrid(d.offset);
                                if (l == null) return;
                                final m = _slotMinute(l);
                                if (m == null) return;
                                final confirmed = await _confirmReschedule(
                                  context,
                                  d.data,
                                  widget.day,
                                  m,
                                );
                                if (confirmed != true) {
                                  if (!mounted) return;
                                  setState(() {
                                    _dragging = null;
                                    _dragLocal = null;
                                  });
                                  return;
                                }
                                final persisted = await widget.onReschedule(
                                  d.data,
                                  widget.day,
                                  m,
                                );
                                if (!mounted) return;
                                setState(() {
                                  _dragging = null;
                                  _dragLocal = null;
                                });
                                if (!persisted) return;
                              },
                              builder: (ctx2, cd, rd) =>
                                  const SizedBox.expand(),
                            ),
                            // Booking cards - MOVED TO TOP OF STACK
                            ..._buildCards(ctx),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHover() {
    final m = _slotMinute(_hoverLocal!);
    if (m == null) return const SizedBox.shrink();
    final top = (m - _kStartHour * 60) * (_kHourHeight / 60);
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: _kHourHeight / 2,
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: SaharaTheme.gold.withValues(alpha: 0.10),
            border: Border.all(
              color: SaharaTheme.gold.withValues(alpha: 0.45),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            _minuteLabel(m),
            style: GoogleFonts.inter(
              color: SaharaTheme.gold,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGhost() {
    final m = _slotMinute(_dragLocal!);
    if (m == null) return const SizedBox.shrink();
    final top = (m - _kStartHour * 60) * (_kHourHeight / 60);
    final height = (_dragging!.durationMinutes * _kHourHeight / 60).clamp(
      22.0,
      double.infinity,
    );
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: SaharaTheme.gold.withValues(alpha: 0.18),
            border: Border.all(color: SaharaTheme.gold, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _minuteLabel(m),
                style: GoogleFonts.inter(
                  color: SaharaTheme.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _dragging!.clientName,
                style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    final mins = widget.now.hour * 60 + widget.now.minute;
    final top = (mins - _kStartHour * 60) * (_kHourHeight / 60);
    if (top < 0 || top > (_kEndHour - _kStartHour) * _kHourHeight)
      return const SizedBox.shrink();
    return Positioned(
      top: top - 1,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Container(
                height: 1.5,
                color: Colors.red.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCards(BuildContext ctx) {
    return widget.bookings.where((b) => _sameDay(b.date, widget.day)).map((b) {
      final top = (b.startMinute - _kStartHour * 60) * (_kHourHeight / 60);
      final height = (b.durationMinutes * _kHourHeight / 60).clamp(
        22.0,
        double.infinity,
      );
      if (top < 0) return const SizedBox.shrink();
      return Positioned(
        top: top + 1,
        left: 1,
        right: 1,
        height: height,
        child: Draggable<_Booking>(
          data: b,
          onDragStarted: () => setState(() => _dragging = b),
          onDraggableCanceled: (velocity, offset) => setState(() {
            _dragging = null;
            _dragLocal = null;
          }),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: _colWidth - 2,
              height: height,
              child: Opacity(
                opacity: 0.85,
                child: _BookingCard(booking: b, onTap: () {}),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: _BookingCard(booking: b, onTap: () {}),
          ),
          child: _BookingCard(
            booking: b,
            onTap: () => widget.onBookingTap(ctx, b),
          ),
        ),
      );
    }).toList();
  }
}

class _DayPainter extends CustomPainter {
  const _DayPainter({
    required this.hourHeight,
    required this.hours,
    required this.isToday,
  });
  final double hourHeight;
  final int hours;
  final bool isToday;

  @override
  void paint(Canvas canvas, Size size) {
    if (isToday) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = SaharaTheme.gold.withValues(alpha: 0.03),
      );
    }
    final hLine = Paint()
      ..color = SaharaTheme.gold.withValues(alpha: 0.37)
      ..strokeWidth = 0.5;
    for (int h = 0; h <= hours; h++) {
      canvas.drawLine(
        Offset(0, h * hourHeight),
        Offset(size.width, h * hourHeight),
        hLine,
      );
    }
  }

  @override
  bool shouldRepaint(_DayPainter old) => old.isToday != isToday;
}

// ═════════════════════════════════════════════════════════════════════════════
// Month Grid  (vista mensual)
// ═════════════════════════════════════════════════════════════════════════════
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.monthStart,
    required this.bookings,
    required this.onDayTap,
  });
  final DateTime monthStart;
  final List<_Booking> bookings;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(monthStart.year, monthStart.month, 1);
    final offset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;

    final Map<int, List<_Booking>> byDay = {};
    for (final b in bookings) {
      if (b.date.year == monthStart.year && b.date.month == monthStart.month) {
        byDay.putIfAbsent(b.date.day, () => []).add(b);
      }
    }

    return Column(
      children: [
        // DOW header
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE0DDD8))),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: _kDaysShort
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.inter(
                          color: Colors.black45,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        // Day cells
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              color: Colors.white,
              child: Column(
                children: List.generate(6, (row) {
                  // Skip empty rows at the end
                  final firstIdx = row * 7 - offset + 1;
                  if (firstIdx > daysInMonth) return const SizedBox.shrink();
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(7, (col) {
                        final idx = row * 7 + col - offset + 1;
                        if (idx < 1 || idx > daysInMonth) {
                          return Expanded(
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 88),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F6F2),
                                border: Border(
                                  right: col < 6
                                      ? const BorderSide(
                                          color: Color(0xFFE8E5E0),
                                        )
                                      : BorderSide.none,
                                  bottom: const BorderSide(
                                    color: Color(0xFFE8E5E0),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        final day = DateTime(
                          monthStart.year,
                          monthStart.month,
                          idx,
                        );
                        final isToday = _sameDay(day, today);
                        final dayBkgs = byDay[idx] ?? [];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onDayTap(day),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 88,
                                ),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? SaharaTheme.gold.withValues(alpha: 0.05)
                                      : Colors.white,
                                  border: Border(
                                    right: col < 6
                                        ? const BorderSide(
                                            color: Color(0xFFE8E5E0),
                                          )
                                        : BorderSide.none,
                                    bottom: const BorderSide(
                                      color: Color(0xFFE8E5E0),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? SaharaTheme.gold
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$idx',
                                        style: GoogleFonts.inter(
                                          color: isToday
                                              ? Colors.black
                                              : Colors.black87,
                                          fontSize: 12,
                                          fontWeight: isToday
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...dayBkgs
                                        .take(3)
                                        .map(
                                          (b) => Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 2,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: b.cardBg,
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              border: Border(
                                                left: BorderSide(
                                                  color: b.cardAccent,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              '${b.timeLabel} ${b.clientName}',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                    if (dayBkgs.length > 3)
                                      Text(
                                        '+${dayBkgs.length - 3} más',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          color: SaharaTheme.gold,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Grid painter ──────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.dayWidth,
    required this.hourHeight,
    required this.hours,
    required this.today,
    required this.weekStart,
  });

  final double dayWidth;
  final double hourHeight;
  final int hours;
  final DateTime today;
  final DateTime weekStart;

  @override
  void paint(Canvas canvas, Size size) {
    final hLine = Paint()
      ..color = SaharaTheme.gold.withValues(alpha: 0.37)
      ..strokeWidth = 0.5;
    final vLine = Paint()
      ..color = SaharaTheme.gold.withValues(alpha: 0.30)
      ..strokeWidth = 0.5;
    final weekend = Paint()..color = SaharaTheme.gold.withValues(alpha: 0.04);
    final todayBg = Paint()..color = SaharaTheme.gold.withValues(alpha: 0.08);

    // Weekend shading (Sat=5, Sun=6)
    for (final d in [5, 6]) {
      canvas.drawRect(
        Rect.fromLTWH(d * dayWidth, 0, dayWidth, size.height),
        weekend,
      );
    }

    // Today column highlight
    final todayIdx = today.difference(weekStart).inDays;
    if (todayIdx >= 0 && todayIdx < 7) {
      canvas.drawRect(
        Rect.fromLTWH(todayIdx * dayWidth, 0, dayWidth, size.height),
        todayBg,
      );
    }

    // Horizontal hour lines
    for (int h = 0; h <= hours; h++) {
      final y = h * hourHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hLine);
    }

    // Vertical day separators
    for (int d = 1; d < 7; d++) {
      canvas.drawLine(
        Offset(d * dayWidth, 0),
        Offset(d * dayWidth, size.height),
        vLine,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.today != today || old.weekStart != weekStart;
}

// ═════════════════════════════════════════════════════════════════════════════
// Booking Card
// ═════════════════════════════════════════════════════════════════════════════
class _BookingCard extends StatefulWidget {
  const _BookingCard({required this.booking, required this.onTap});
  final _Booking booking;
  final VoidCallback onTap;

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered
                ? Color.lerp(b.cardBg, Colors.black, 0.05)!
                : b.cardBg,
            border: Border(left: BorderSide(color: b.cardAccent, width: 3)),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: b.cardAccent.withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                b.clientName,
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w700, // Slightly bolder for premium look
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (b.durationMinutes >= 30) ...[
                const SizedBox(height: 1),
                Text(
                  b.serviceName,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Booking Detail Dialog
// ═════════════════════════════════════════════════════════════════════════════
class _BookingDetailDialog extends StatelessWidget {
  const _BookingDetailDialog({
    required this.booking,
    required this.onRefresh,
    required this.onEdit,
    required this.onUpdateStatus,
    required this.statusLabel,
  });
  final _Booking booking;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final Future<bool> Function(String) onUpdateStatus;
  final String Function(String) statusLabel;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: b.cardAccent.withValues(alpha: 0.3)),
      ),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: b.cardAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.clientName,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.black87,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          b.serviceName,
                          style: GoogleFonts.inter(
                            color: SaharaTheme.gold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black38),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFECECEC)),
              const SizedBox(height: 16),
              // Details
              _DetailRow(icon: Icons.schedule, text: '${b.timeLabel} - ${b.endTimeLabel}'),
              _DetailRow(icon: Icons.timer, text: '${b.durationMinutes} min'),
              _DetailRow(icon: Icons.person, text: b.therapistName),
              if ((b.clientPhone ?? '').isNotEmpty)
                _DetailRow(icon: Icons.phone_outlined, text: b.clientPhone!),
              if (b.notes.trim().isNotEmpty)
                _DetailRow(icon: Icons.sticky_note_2_outlined, text: b.notes),
              _DetailRow(
                icon: Icons.circle,
                text: statusLabel(b.status),
                color: b.cardAccent,
              ),
              const SizedBox(height: 20),
              // Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (b.status == 'scheduled' || b.status == 'pending')
                    _DialogBtn(
                      label: 'Confirmar',
                      color: const Color(0xFF1A9E65),
                      onTap: () => _updateStatus(context, 'confirmed'),
                    ),
                  if (b.status != 'completed' && b.status != 'cancelled')
                    _DialogBtn(
                      label: 'Cancelar',
                      color: const Color(0xFFB32D2D),
                      onTap: () => _updateStatus(context, 'cancelled'),
                    ),
                  if (b.status == 'confirmed')
                    _DialogBtn(
                      label: 'Completada',
                      color: const Color(0xFF666666),
                      onTap: () => _updateStatus(context, 'completed'),
                    ),
                  _DialogBtn(
                    label: 'Historial',
                    color: const Color(0xFF4A4A4A),
                    onTap: () => _showClientHistory(context, b),
                  ),
                  _WhatsAppBtn(booking: b),
                  _DialogBtn(
                    label: 'Editar',
                    color: SaharaTheme.gold,
                    onTap: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmed':
        return 'Confirmada';
      case 'attended':
        return 'Asistió';
      case 'no_show':
        return 'No asistió';
      case 'pending':
        return 'Pendiente';
      case 'waiting':
        return 'En espera';
      case 'cancelled':
        return 'Cancelada';
      case 'completed':
        return 'Completada';
      default:
        return 'Reservada';
    }
  }

  Future<void> _updateStatus(BuildContext ctx, String newStatus) async {
    try {
      final updated = await onUpdateStatus(newStatus);
      if (updated && ctx.mounted) {
        Navigator.pop(ctx);
        onRefresh();
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFF2A1010),
          ),
        );
      }
    }
  }

  void _showClientHistory(BuildContext context, _Booking booking) {
    showDialog(
      context: context,
      builder: (_) => _ClientHistoryDialog(
        booking: booking,
        statusLabel: statusLabel,
      ),
    );
  }
}

class _ClientHistoryDialog extends StatefulWidget {
  const _ClientHistoryDialog({
    required this.booking,
    required this.statusLabel,
  });

  final _Booking booking;
  final String Function(String) statusLabel;

  @override
  State<_ClientHistoryDialog> createState() => _ClientHistoryDialogState();
}

class _ClientHistoryDialogState extends State<_ClientHistoryDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client
          .from('bookings')
          .select('''
            id, booking_date, booking_time, duration_min, status, client_notes,
            services(name),
            therapist:staff(full_name)
          ''')
          .eq('client_record_id', widget.booking.clientId)
          .order('booking_date', ascending: false)
          .order('booking_time', ascending: false)
          .limit(12);

      if (!mounted) return;
      setState(() {
        _history = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Historial de ${widget.booking.clientName}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No hay historial registrado para este cliente.',
                    style: GoogleFonts.inter(color: Colors.black54),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = _history[index];
                      final time = (item['booking_time'] as String? ?? '').substring(0, 5);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (item['services'] as Map?)?['name'] as String? ?? 'Servicio',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${item['booking_date']} • $time • ${(item['therapist'] as Map?)?['full_name'] as String? ?? 'Terapeuta'}',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        trailing: Text(
                          widget.statusLabel(item['status'] as String? ?? 'scheduled'),
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, color: color ?? Colors.black38, size: 15),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            color: color ?? Colors.black54,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

class _DialogBtn extends StatelessWidget {
  const _DialogBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      backgroundColor: color.withValues(alpha: 0.15),
      foregroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// New Booking Dialog
// ═════════════════════════════════════════════════════════════════════════════
class _NewBookingDialog extends StatefulWidget {
  const _NewBookingDialog({
    required this.therapists,
    required this.branches,
    required this.onSaved,
    this.initialTherapistId,
    this.initialBranchId,
    this.initialDate,
    this.initialTime,
    this.editBooking,
  });
  final List<_Therapist> therapists;
  final List<Map<String, dynamic>> branches;
  final VoidCallback onSaved;
  final String? initialTherapistId;
  final String? initialBranchId;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final _Booking? editBooking;

  @override
  State<_NewBookingDialog> createState() => _NewBookingDialogState();
}

class _NewBookingDialogState extends State<_NewBookingDialog> {
  final _clientCtrl = TextEditingController();
  final _clientFocus = FocusNode();
  final _notesCtrl = TextEditingController();

  late DateTime _date;
  late int _hour;
  late int _minute;
  String? _clientId;
  String? _therapistId;
  String? _sucursalId;
  String? _serviceId;
  String _status = 'pending';
  bool _saving = false;
  bool _showInfo = false;
  bool _serviceOpen = false;
  String _serviceSearch = '';
  String? _serviceLoadError;

  List<Map<String, dynamic>> _services = [];

  List<Map<String, dynamic>> get _filteredServices {
    if (_serviceSearch.isEmpty) return _services;
    final q = _serviceSearch.toLowerCase();
    return _services
        .where((s) => (s['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  String get _serviceLabel {
    if (_serviceId == null) return '';
    try {
      final s = _services.firstWhere((s) => s['id'] == _serviceId);
      return '${s['name']}  ·  ${s['duration'] ?? 60} min';
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic>? get _selectedService {
    if (_serviceId == null) return null;
    try {
      return _services.firstWhere((s) => s['id'] == _serviceId);
    } catch (_) {
      return null;
    }
  }

  int get _selectedServiceDuration =>
      (_selectedService?['duration'] as num?)?.toInt() ?? 60;

  String get _selectedServiceName => _selectedService?['name'] as String? ?? '';

  static const _statusMeta = {
    'scheduled': ('Reservado', Color(0xFF5B8FF9)),
    'checked_in': ('Check-in', Color(0xFF2088D8)),
    'in_progress': ('En proceso', Color(0xFF6A54E0)),
    'confirmed': ('Confirmado', Color(0xFFFFB347)),
    'attended': ('Asiste', Color(0xFFFF9899)),
    'no_show': ('No asistió', Color(0xFFFFB3B3)),
    'pending': ('Pendiente', Color(0xFFFF4444)),
    'waiting': ('En espera', Color(0xFF52C41A)),
    'cancelled': ('Cancelado', Color(0xFFB32D2D)),
    'rescheduled': ('Reagendado', Color(0xFF0A9AA4)),
    'completed': ('Completado', Color(0xFF888888)),
  };

  @override
  void initState() {
    super.initState();
    _date = widget.editBooking?.date ?? widget.initialDate ?? DateTime.now();
    _hour = widget.editBooking?.startMinute != null ? (widget.editBooking!.startMinute ~/ 60) : (widget.initialTime?.hour ?? 10);
    _minute = widget.editBooking?.startMinute != null ? (widget.editBooking!.startMinute % 60) : (widget.initialTime?.minute ?? 0);
    _therapistId = widget.editBooking?.therapistId ?? widget.initialTherapistId;
    _sucursalId = kEnableMultiBranch
        ? (widget.editBooking?.sucursalId ?? widget.initialBranchId)
        : kDefaultBranchId;
    _serviceId = widget.editBooking?.serviceId;
    _status = widget.editBooking?.status ?? 'pending';
    
    if (widget.editBooking != null) {
      _clientCtrl.text = widget.editBooking!.clientName;
      _clientId        = widget.editBooking!.clientId;
      _notesCtrl.text  = widget.editBooking!.notes;
    }
    _loadServices();
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
          .select('id, name, price, duration')
          .order('name');
      if (mounted) {
        setState(() {
          _services = (data as List).cast<Map<String, dynamic>>();
          _serviceLoadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _serviceLoadError = '$e');
      }
    }
  }

  void _showRepeatDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Repetir reserva',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black38,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...[
                  ('Ninguna', Icons.block_outlined),
                  ('Diaria', Icons.today_outlined),
                  ('Semanal', Icons.view_week_outlined),
                  ('Mensual', Icons.calendar_month_outlined),
                ].map(
                  (opt) => ListTile(
                    dense: true,
                    leading: Icon(opt.$2, size: 18, color: Colors.black45),
                    title: Text(
                      opt.$1,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: SaharaTheme.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: SaharaTheme.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: SaharaTheme.gold,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Reservas recurrentes disponibles en la próxima versión.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: SaharaTheme.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Iterable<Map<String, dynamic>>> _searchClients(
    TextEditingValue v,
  ) async {
    final q = v.text.trim();
    if (q.length < 2) return const [];
    try {
      final data = await Supabase.instance.client
          .from('clients')
          .select('id, full_name, email')
          .ilike('full_name', '%$q%')
          .order('full_name')
          .limit(8);
      return (data as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST204' || !e.message.contains("'email'")) {
        return const [];
      }
      try {
        final data = await Supabase.instance.client
            .from('clients')
            .select('id, full_name')
            .ilike('full_name', '%$q%')
            .order('full_name')
            .limit(8);
        return (data as List).cast<Map<String, dynamic>>();
      } catch (_) {
        return const [];
      }
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> _doSave() async {
    if (_clientCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona o crea un cliente.')),
      );
      return null;
    }
    if (_therapistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un profesional.')),
      );
      return null;
    }
    if (_serviceId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un servicio.')));
      return null;
    }
    setState(() => _saving = true);
    try {
      // Resolve client ID: use cached selection, else lookup by name
      String? finalClientId = _clientId;
      if (finalClientId == null || finalClientId.isEmpty) {
        final nameQ = await Supabase.instance.client
            .from('clients')
            .select('id')
            .eq('full_name', _clientCtrl.text.trim())
            .maybeSingle();
        finalClientId = nameQ?['id'] as String?;
        if (finalClientId == null)
          throw Exception('Cliente no encontrado. Verifica el nombre.');
      }

      final timeStr =
          '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}:00';
      final payload = {
        'client_record_id': finalClientId,
        'therapist_id': _therapistId,
        'sucursal_id': _sucursalId,
        'service_id': _serviceId,
        'booking_date': _yyyyMMdd(_date),
        'booking_time': timeStr,
        'duration_min': _selectedServiceDuration,
        'status': _status,
        'client_notes': _notesCtrl.text.trim(),
        'service_name': _selectedServiceName,
        'source_platform': kIsWeb ? 'web' : 'mobile',
        'updated_by': Supabase.instance.client.auth.currentUser?.id,
      };

      Map<String, dynamic>? res;
      if (widget.editBooking != null) {
        final data = await Supabase.instance.client
            .from('bookings')
            .update(payload)
            .eq('id', widget.editBooking!.id)
            .select('*, client_record:client_record_id(full_name, phone)')
            .maybeSingle();
        res = data;
      } else {
        final data = await Supabase.instance.client
            .from('bookings')
            .insert({
              ...payload,
              'created_by': Supabase.instance.client.auth.currentUser?.id,
            })
            .select('*, client_record:client_record_id(full_name, phone)')
            .maybeSingle();
        res = data;
      }
      return res;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade100,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final bData = await _doSave();
    if (bData != null) {
      widget.onSaved();
    }
  }

  Future<void> _saveAndAddAnother() async {
    final messenger = ScaffoldMessenger.of(context);
    final bData = await _doSave();
    if (bData == null) return;

    setState(() {
      _clientCtrl.clear();
      _notesCtrl.clear();
      _clientId = null;
      _therapistId = null;
      _serviceId = null;
      _status = 'pending';
    });
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Reserva guardada. Agrega otra.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Date/time helpers ───────────────────────────────────────────────────────
  String get _dateLabel {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return '${days[_date.weekday - 1]}, ${_date.day} de ${_kMonths[_date.month - 1].toLowerCase()} de ${_date.year}';
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta[_status]!;
    final sColor = meta.$2;

    return Dialog(
      backgroundColor: SaharaTheme.blancoAlmendra,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: Color(0xFFECE9E4))),
              ),
              child: Row(
                children: [
                  Text(
                    widget.editBooking != null
                        ? 'Editar reserva'
                        : 'Nueva reserva',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Status badge dropdown
                  _StatusBadge(
                    label: meta.$1,
                    color: sColor,
                    onChanged: (v) => setState(() => _status = v),
                    statuses: _statusMeta.entries
                        .map((e) => (e.key, e.value.$1, e.value.$2))
                        .toList(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.black38,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card: Fecha + Hora
                    _NbCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Fecha
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _NbLabel('Fecha'),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () async {
                                        final d = await showDatePicker(
                                          context: context,
                                          initialDate: _date,
                                          firstDate: DateTime(2024),
                                          lastDate: DateTime(2030),
                                          builder: (_, child) => Theme(
                                            data: ThemeData.light().copyWith(
                                              colorScheme: ColorScheme.light(
                                                primary: SaharaTheme.gold,
                                                onPrimary: Colors.black,
                                              ),
                                            ),
                                            child: child!,
                                          ),
                                        );
                                        if (d != null)
                                          setState(() => _date = d);
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFFDDD9D3),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          color: Colors.white,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 14,
                                              color: Colors.black45,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _dateLabel,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.keyboard_arrow_down,
                                              size: 16,
                                              color: Colors.black38,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Hora
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _NbLabel('Hora'),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _TimeDropdown(
                                        value: _hour,
                                        items: List.generate(
                                          _kEndHour - _kStartHour + 1,
                                          (i) => _kStartHour + i,
                                        ),
                                        onChanged: (v) =>
                                            setState(() => _hour = v),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          ':',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      _TimeDropdown(
                                        value: _minute,
                                        items: const [0, 15, 30, 45],
                                        label: (v) =>
                                            v.toString().padLeft(2, '0'),
                                        onChanged: (v) =>
                                            setState(() => _minute = v),
                                      ),
                                      const SizedBox(width: 10),
                                      InkWell(
                                        onTap: () => _showRepeatDialog(context),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFFDDD9D3),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            color: Colors.white,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.repeat,
                                                size: 14,
                                                color: Colors.black45,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Repetir',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Card: Cliente
                    _NbCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NbLabel('Cliente'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: RawAutocomplete<Map<String, dynamic>>(
                                  textEditingController: _clientCtrl,
                                  focusNode: _clientFocus,
                                  optionsBuilder: _searchClients,
                                  displayStringForOption: (o) =>
                                      o['full_name'] as String? ?? '',
                                  onSelected: (o) => setState(
                                    () => _clientId = o['id'] as String,
                                  ),
                                  fieldViewBuilder:
                                      (ctx, ctrl, focus, onSubmitted) =>
                                          TextField(
                                            controller: ctrl,
                                            focusNode: focus,
                                            onChanged: (_) {
                                              if (_clientId != null)
                                                setState(
                                                  () => _clientId = null,
                                                );
                                            },
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            decoration: _lightDeco(
                                              hint: 'Busca por nombre…',
                                              prefix: const Icon(
                                                Icons.search,
                                                size: 15,
                                                color: Colors.black38,
                                              ),
                                            ),
                                          ),
                                  optionsViewBuilder: (ctx, onSel, options) => Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 6,
                                      borderRadius: BorderRadius.circular(8),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 220,
                                        ),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (ctx2, i) {
                                            final o = options.elementAt(i);
                                            final name =
                                                o['full_name'] as String? ?? '';
                                            final email =
                                                o['email'] as String? ?? '';
                                            return InkWell(
                                              onTap: () => onSel(o),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: i < options.length - 1
                                                      ? const Border(
                                                          bottom: BorderSide(
                                                            color: Color(
                                                              0xFFECE9E4,
                                                            ),
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        color: Colors.black87,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    if (email.isNotEmpty)
                                                      Text(
                                                        email,
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .black38,
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final client = await showClientFormDialog(
                                    context,
                                  );
                                  if (client == null || !mounted) return;
                                  setState(() {
                                    _clientId = client['id'] as String?;
                                    _clientCtrl.text =
                                        client['full_name'] as String? ?? '';
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: SaharaTheme.gold,
                                  side: BorderSide(
                                    color: SaharaTheme.gold.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.person_add_outlined,
                                  size: 15,
                                ),
                                label: Text(
                                  'Nuevo cliente',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Card: Profesional
                    _NbCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NbLabel('Profesional'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _NbDropdown<String?>(
                                  value: _therapistId,
                                  hint: 'Seleccionar profesional',
                                  items: widget.therapists
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t.id,
                                          child: Text(t.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _therapistId = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFDDD9D3),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                                child: const Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Card: Servicios (searchable expandable picker)
                    _NbCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          // Trigger row
                          InkWell(
                            onTap: () => setState(() {
                              _serviceOpen = !_serviceOpen;
                              _serviceSearch = '';
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _NbLabel('Servicios'),
                                        if (_serviceId != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            _serviceLabel,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    _serviceOpen
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 18,
                                    color: Colors.black38,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Expanded panel
                          if (_serviceOpen) ...[
                            const Divider(height: 1, color: Color(0xFFECE9E4)),
                            // + Crear nuevo servicio
                            InkWell(
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 14,
                                      color: SaharaTheme.gold,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Crear un nuevo servicio',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: SaharaTheme.gold,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Search field
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: TextField(
                                autofocus: true,
                                onChanged: (v) =>
                                    setState(() => _serviceSearch = v),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                decoration: _lightDeco(
                                  hint: 'Buscar',
                                  prefix: const Icon(
                                    Icons.search,
                                    size: 15,
                                    color: Colors.black38,
                                  ),
                                ),
                              ),
                            ),
                            // Services list
                            if (_serviceLoadError != null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Text(
                                  'No se pudieron cargar servicios: $_serviceLoadError',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ] else if (_filteredServices.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: Text(
                                  'Servicios',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.black38,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _filteredServices.length,
                                  itemBuilder: (ctx, i) {
                                    final s = _filteredServices[i];
                                    final selected = _serviceId == s['id'];
                                    return InkWell(
                                      onTap: () => setState(() {
                                        _serviceId = s['id'] as String;
                                        _serviceOpen = false;
                                        _serviceSearch = '';
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        color: selected
                                            ? SaharaTheme.gold.withValues(
                                                alpha: 0.08,
                                              )
                                            : null,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                s['name'] as String? ?? '',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: selected
                                                      ? SaharaTheme.gold
                                                      : Colors.black87,
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${s['duration'] ?? 60} min',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ] else ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Text(
                                  'No hay servicios disponibles.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Información adicional (collapsible)
                    _NbCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _showInfo = !_showInfo),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Información adicional',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    _showInfo
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 18,
                                    color: Colors.black38,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showInfo) ...[
                            const Divider(height: 1, color: Color(0xFFECE9E4)),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: TextField(
                                controller: _notesCtrl,
                                maxLines: 3,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                decoration: _lightDeco(
                                  hint: 'Notas internas...',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: Color(0xFFECE9E4))),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black54,
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  if (widget.editBooking == null)
                    TextButton(
                      onPressed: _saving ? null : _saveAndAddAnother,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black45,
                      ),
                      child: Text(
                        'Agregar otra reserva',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: SaharaTheme.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.calendar_month_outlined, size: 15),
                    label: Text(
                      'Guardar reserva',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

  InputDecoration _lightDeco({required String hint, Widget? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.black38, fontSize: 13),
        isDense: true,
        prefixIcon: prefix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFDDD9D3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: SaharaTheme.gold, width: 1.5),
        ),
      );
}

// ── New-booking helper widgets ────────────────────────────────────────────────
class _NbCard extends StatelessWidget {
  const _NbCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFECE9E4)),
    ),
    child: child,
  );
}

class _NbLabel extends StatelessWidget {
  const _NbLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  );
}

class _NbDropdown<T> extends StatelessWidget {
  const _NbDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFDDD9D3)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: Text(
          hint,
          style: GoogleFonts.inter(color: Colors.black38, fontSize: 13),
        ),
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        dropdownColor: Colors.white,
        style: GoogleFonts.inter(color: Colors.black87, fontSize: 13),
        iconEnabledColor: Colors.black38,
        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
      ),
    ),
  );
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
  });
  final int value;
  final List<int> items;
  final ValueChanged<int> onChanged;
  final String Function(int)? label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFDDD9D3)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        dropdownColor: Colors.white,
        style: GoogleFonts.inter(
          color: Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        iconEnabledColor: Colors.black38,
        icon: const Icon(Icons.keyboard_arrow_down, size: 14),
        items: items
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(
                  label != null ? label!(v) : v.toString().padLeft(2, '0'),
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.onChanged,
    required this.statuses,
  });
  final String label;
  final Color color;
  final ValueChanged<String> onChanged;
  final List<(String, String, Color)> statuses;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE8E5E0)),
      ),
      onSelected: onChanged,
      itemBuilder: (_) => statuses
          .map(
            (s) => PopupMenuItem(
              value: s.$1,
              height: 36,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: s.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.$2,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Module Navigation Bar
// ═════════════════════════════════════════════════════════════════════════════
class _ModuleNav extends StatelessWidget {
  const _ModuleNav({required this.activeModule, required this.onModuleTap});

  final String activeModule;
  final ValueChanged<String> onModuleTap;

  static const _mods = [
    ('agenda', 'Agenda', Icons.calendar_today_outlined),
    ('clientes', 'Clientes', Icons.people_outline),
    ('ventas', 'Ventas', Icons.point_of_sale_outlined),
    ('mensajes', 'Mensajes', Icons.chat_bubble_outline),
    ('productos', 'Productos', Icons.inventory_2_outlined),
    ('reportes', 'Reportes', Icons.bar_chart_outlined),
    ('admin', 'Administración', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 960;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: SaharaTheme.gold.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: SaharaTheme.gold.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Brand mark
          SizedBox(
            width: compact ? 128 : _kSidebarWidth,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
              child: Row(
                children: [
                  Text(
                    'SAHARA',
                    style: GoogleFonts.playfairDisplay(
                      color: SaharaTheme.gold,
                      fontSize: compact ? 13 : 15,
                      letterSpacing: compact ? 2.8 : 4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SaharaTheme.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'PRO',
                      style: GoogleFonts.inter(
                        color: SaharaTheme.gold,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Thin gold divider
          Container(
            width: 1,
            height: 28,
            color: SaharaTheme.gold.withValues(alpha: 0.2),
          ),
          // Module tabs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: _mods
                    .map(
                      (m) => _ModuleTab(
                        id: m.$1,
                        label: m.$2,
                        icon: m.$3,
                        active: activeModule == m.$1,
                        onTap: () => onModuleTap(m.$1),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 20, color: Colors.black45),
            onPressed: () => Supabase.instance.client.auth.signOut(),
            tooltip: 'Cerrar sesión',
          ),
          SizedBox(width: compact ? 8 : 16),
        ],
      ),
    );
  }
}

class _ModuleTab extends StatefulWidget {
  const _ModuleTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ModuleTab> createState() => _ModuleTabState();
}

class _ModuleTabState extends State<_ModuleTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? SaharaTheme.gold
        : _hovered
        ? Colors.black87
        : Colors.black45;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.active ? SaharaTheme.gold : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Placeholder — módulos próximamente
// ═════════════════════════════════════════════════════════════════════════════
class _PlaceholderModule extends StatelessWidget {
  const _PlaceholderModule({required this.module});

  final String module;

  static const _labels = {
    'clientes': ('Clientes', Icons.people_outline),
    'ventas': ('Ventas', Icons.point_of_sale_outlined),
    'mensajes': ('Mensajes', Icons.chat_bubble_outline),
    'productos': ('Productos', Icons.inventory_2_outlined),
    'reportes': ('Reportes', Icons.bar_chart_outlined),
    'admin': ('Administración', Icons.settings_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final info = _labels[module] ?? ('Módulo', Icons.widgets_outlined);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: SaharaTheme.gold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: SaharaTheme.gold.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(info.$2, color: SaharaTheme.gold, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            info.$1.toUpperCase(),
            style: GoogleFonts.playfairDisplay(
              color: const Color(0xFF1A1A1A),
              fontSize: 22,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Módulo en construcción',
            style: GoogleFonts.inter(color: Colors.black38, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Fase 1 — Shell activo',
            style: GoogleFonts.inter(
              color: SaharaTheme.gold,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// WhatsApp Integration
// ─────────────────────────────────────────────────────────────────────────────
class _WhatsAppBtn extends StatefulWidget {
  const _WhatsAppBtn({required this.booking});
  final _Booking booking;

  @override
  State<_WhatsAppBtn> createState() => _WhatsAppBtnState();
}

class _WhatsAppBtnState extends State<_WhatsAppBtn> {
  List<WhatsAppTemplate> _templates = [];
  bool _loading = false;

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('whatsapp_templates')
          .select()
          .eq('active', true)
          .order('title');
      if (mounted) {
        setState(() {
          _templates = (data as List)
              .map((m) => WhatsAppTemplate.fromMap(m as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sendTemplate(WhatsAppTemplate t) async {
    final b = widget.booking;
    String msg = t.message;

    // Format date
    final dateStr = '${b.date.day} de ${_kMonths[b.date.month - 1]}';
    
    // Replace tags
    msg = msg.replaceAll('[CLIENTE]', b.clientName);
    msg = msg.replaceAll('[SERVICIO]', b.serviceName);
    msg = msg.replaceAll('[FECHA]', dateStr);
    msg = msg.replaceAll('[HORA]', b.timeLabel);
    msg = msg.replaceAll('[PRECIO]', ''); 
    msg = msg.replaceAll('[LOCAL]', b.branchName ?? kDefaultBranchName);
    msg = msg.replaceAll('[DIRECCION]', b.branchAddress ?? kDefaultBranchAddress);
    msg = msg.replaceAll('[MAPS]', b.branchMaps ?? kDefaultBranchMaps);

    final phone = b.clientPhone ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cliente no tiene teléfono registrado')));
      return;
    }

    // Clean phone number (remove non-digits, add country code if missing)
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 10) cleanPhone = '52$cleanPhone'; // Default to MX

    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogBtn(
      label: 'WhatsApp',
      color: const Color(0xFF25D366),
      onTap: () async {
        await _loadTemplates();
        if (!mounted) return;
        if (_templates.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay plantillas de WhatsApp activas')));
          return;
        }

        final RenderBox button = context.findRenderObject() as RenderBox;
        final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
        final RelativeRect position = RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(Offset.zero, ancestor: overlay),
            button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
          ),
          Offset.zero & overlay.size,
        );

        final selected = await showMenu<WhatsAppTemplate>(
          context: context,
          position: position,
          items: _templates.map((t) => PopupMenuItem(
            value: t,
            child: Text(t.title, style: GoogleFonts.inter(fontSize: 13)),
          )).toList(),
        );

        if (selected != null) {
          _sendTemplate(selected);
        }
      },
    );
  }
}
