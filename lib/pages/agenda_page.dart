import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_mode.dart';
import '../features/auth/role_permissions.dart';
import '../features/bookings/booking_sync_service.dart';
import '../features/mensajes/chat_service.dart';
import '../theme/sahara_theme.dart';
import '../features/clients/clients_module.dart';
import '../features/sales/sales_module.dart';
import '../features/sales/services/agenda_sales_service.dart';
import '../features/mensajes/mensajes_module.dart';
import '../features/admin/admin_module.dart';
import '../features/admin/finanzas_module.dart';
import '../features/productos/productos_module.dart';
import '../features/reportes/reportes_module.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const _kHourHeight = 64.0;
const _kTimeColWidth = 64.0;
const _kSidebarWidth = 224.0;
const _kDefaultCalendarStartMinute = 0;
const _kDefaultCalendarEndMinute = (24 * 60) - 1;

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
  final String? profileClientId;
  final String? clientRecordId;
  final String clientName;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
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
    this.profileClientId,
    this.clientRecordId,
    required this.clientName,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
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
    this.paymentRequirement,
    this.waiverReason,
    this.giftCardId,
    this.membershipId,
    this.depositRequiredCents,
    this.depositPaidCents,
  });

  final String? sucursalId;
  final String? branchName;
  final String? branchAddress;
  final String? branchMaps;
  final String? paymentRequirement;  // deposit_required | waived | paid
  final String? waiverReason;        // gift_card | membership | admin_override
  final String? giftCardId;
  final String? membershipId;
  final int?    depositRequiredCents;
  final int?    depositPaidCents;


  factory _Booking.fromMap(Map<String, dynamic> m) {
    try {
      final t = (m['booking_time'] as String? ?? '09:00:00').split(':');
      final dateStr = m['booking_date'] as String? ?? DateTime.now().toIso8601String().split('T')[0];
      
      return _Booking(
        id: m['id'] as String? ?? '',
        clientId:
            m['client_record_id'] as String? ?? m['client_id'] as String? ?? '',
        profileClientId: m['client_id'] as String?,
        clientRecordId: m['client_record_id'] as String?,
        clientName:
            (m['client_record'] as Map?)?['full_name'] as String? ??
            (m['client'] as Map?)?['full_name'] as String? ??
            'Cliente',
        serviceId: m['service_id'] as String? ?? '',
        serviceName: (m['services'] as Map?)?['name'] as String? ?? 'Servicio',
        servicePrice: ((m['services'] as Map?)?['price'] as num?)?.toDouble() ?? 0,
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
        paymentRequirement: m['payment_requirement'] as String?,
        waiverReason: m['waiver_reason'] as String?,
        giftCardId: m['gift_card_id'] as String?,
        membershipId: m['membership_id'] as String?,
        depositRequiredCents: (m['deposit_required_cents'] as num?)?.toInt(),
        depositPaidCents: (m['deposit_paid_cents'] as num?)?.toInt(),
      );
    } catch (e) {
      debugPrint('Error parsing booking ${m['id']}: $e');
      // Return a minimal valid booking to avoid crashing the entire list
      return _Booking(
        id: m['id'] as String? ?? 'error',
        clientId: '', clientName: 'Error de datos',
        serviceId: '', serviceName: 'Error', servicePrice: 0,
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

class _AgendaCalendarHours {
  const _AgendaCalendarHours({
    required this.startMinute,
    required this.endMinuteInclusive,
  });

  const _AgendaCalendarHours.fullDay()
    : startMinute = _kDefaultCalendarStartMinute,
      endMinuteInclusive = _kDefaultCalendarEndMinute;

  final int startMinute;
  final int endMinuteInclusive;

  int get lastSlotMinute {
    final normalizedEnd = endMinuteInclusive.clamp(0, _kDefaultCalendarEndMinute);
    final snapped = (normalizedEnd ~/ 15) * 15;
    return snapped.clamp(startMinute, _kDefaultCalendarEndMinute);
  }

  int get displayEndMinuteExclusive {
    final slotEnd = (lastSlotMinute + 15).clamp(startMinute + 15, 24 * 60);
    return max(slotEnd, startMinute + 60);
  }

  double get gridHeight =>
      (displayEndMinuteExclusive - startMinute) * (_kHourHeight / 60);

  int get totalDisplayMinutes => displayEndMinuteExclusive - startMinute;

  List<int> get hourLabelMinutes {
    final totalHours = max(1, (totalDisplayMinutes / 60).ceil());
    return List<int>.generate(
      totalHours,
      (index) => startMinute + (index * 60),
    );
  }

  List<int> get selectableHours {
    final firstHour = startMinute ~/ 60;
    final lastHour = lastSlotMinute ~/ 60;
    return List<int>.generate(
      max(1, (lastHour - firstHour) + 1),
      (index) => firstHour + index,
    );
  }

  List<int> selectableMinutesForHour(int hour) {
    final baseMinute = hour * 60;
    final values = [0, 15, 30, 45]
        .where((minute) => containsMinute(baseMinute + minute))
        .toList();
    return values.isEmpty ? const [0] : values;
  }

  bool containsMinute(int minute) =>
      minute >= startMinute && minute <= lastSlotMinute;

  _AgendaCalendarHours expandToFit(List<_Booking> bookings) {
    if (bookings.isEmpty) return this;

    var expandedStart = startMinute;
    var expandedEnd = endMinuteInclusive;

    for (final booking in bookings) {
      final bookingStart = booking.startMinute.clamp(0, _kDefaultCalendarEndMinute);
      final bookingEnd = booking.endMinute.clamp(0, 24 * 60);
      if (bookingStart < expandedStart) {
        expandedStart = max(0, (bookingStart ~/ 60) * 60);
      }
      if (bookingEnd > expandedEnd) {
        expandedEnd = min(
          _kDefaultCalendarEndMinute,
          (((bookingEnd + 14) ~/ 15) * 15) - 1,
        );
      }
    }

    return _AgendaCalendarHours(
      startMinute: expandedStart,
      endMinuteInclusive: max(expandedStart, expandedEnd),
    );
  }

  _AgendaCalendarHours normalized() {
    final normalizedStart = startMinute.clamp(0, _kDefaultCalendarEndMinute);
    final normalizedEnd = endMinuteInclusive.clamp(
      normalizedStart,
      _kDefaultCalendarEndMinute,
    );
    return _AgendaCalendarHours(
      startMinute: normalizedStart,
      endMinuteInclusive: normalizedEnd,
    );
  }

  static _AgendaCalendarHours fromMap(Map<String, dynamic>? row) {
    if (row == null) {
      return const _AgendaCalendarHours.fullDay();
    }

    final startMinute = _parseCalendarMinute(
      row['calendar_start_hour'],
      fallbackMinute: _kDefaultCalendarStartMinute,
    );
    final endMinute = _parseCalendarMinute(
      row['calendar_end_hour'],
      fallbackMinute: _kDefaultCalendarEndMinute,
    );

    if (endMinute < startMinute) {
      return const _AgendaCalendarHours.fullDay();
    }

    return _AgendaCalendarHours(
      startMinute: startMinute,
      endMinuteInclusive: endMinute,
    ).normalized();
  }
}

class _ScheduleBlock {
  const _ScheduleBlock({
    required this.id,
    required this.blockDate,
    required this.startMinute,
    required this.endMinute,
    required this.scope,
    required this.title,
    required this.notes,
    this.branchId,
    this.createdAt,
  });

  final String id;
  final String? branchId;
  final DateTime blockDate;
  final int startMinute;
  final int endMinute;
  final String scope;
  final String title;
  final String notes;
  final DateTime? createdAt;

  factory _ScheduleBlock.fromMap(Map<String, dynamic> map) {
    final parsedDate =
        DateTime.tryParse(map['block_date'] as String? ?? '') ?? DateTime.now();
    final start = (map['start_minute'] as num?)?.toInt() ?? 0;
    final rawEnd = (map['end_minute'] as num?)?.toInt() ?? start + 60;
    return _ScheduleBlock(
      id: map['id'] as String? ?? '',
      branchId: map['branch_id'] as String?,
      blockDate: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      startMinute: start.clamp(0, _kDefaultCalendarEndMinute),
      endMinute: rawEnd.clamp(start + 15, 24 * 60),
      scope: (map['scope'] as String? ?? 'day').toLowerCase(),
      title:
          (map['title'] as String?)?.trim().isNotEmpty == true
          ? (map['title'] as String).trim()
          : 'Horario bloqueado',
      notes: (map['notes'] as String? ?? '').trim(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }

  bool get appliesWholeWeek => scope == 'week';
  int get durationMinutes => max(15, endMinute - startMinute);

  String get scopeLabel => appliesWholeWeek ? 'Toda la semana' : 'Solo este día';

  String get timeLabel =>
      '${_minuteLabel24(startMinute)} - ${_minuteLabel24(endMinute)}';

  bool appliesToDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    if (!appliesWholeWeek) {
      return _sameDay(normalizedDay, blockDate);
    }
    final weekStart = _mondayOf(blockDate);
    final weekEnd = weekStart.add(const Duration(days: 6));
    return !normalizedDay.isBefore(weekStart) && !normalizedDay.isAfter(weekEnd);
  }

  bool overlaps(DateTime day, int slotStartMinute, int slotEndMinute) {
    if (!appliesToDay(day)) return false;
    return slotStartMinute < endMinute && slotEndMinute > startMinute;
  }

  bool intersectsRange(DateTime start, DateTime end) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    if (!appliesWholeWeek) {
      return !blockDate.isBefore(normalizedStart) &&
          !blockDate.isAfter(normalizedEnd);
    }
    final weekStart = _mondayOf(blockDate);
    final weekEnd = weekStart.add(const Duration(days: 6));
    return !weekEnd.isBefore(normalizedStart) && !weekStart.isAfter(normalizedEnd);
  }
}

int _parseCalendarMinute(dynamic raw, {required int fallbackMinute}) {
  if (raw == null) return fallbackMinute;
  if (raw is num) {
    final value = raw.toInt();
    if (value >= 0 && value <= 24) return (value * 60).clamp(0, 24 * 60 - 1);
    return value.clamp(0, 24 * 60 - 1);
  }

  final text = raw.toString().trim();
  if (text.isEmpty) return fallbackMinute;

  final number = int.tryParse(text);
  if (number != null) {
    if (number >= 0 && number <= 24) return (number * 60).clamp(0, 24 * 60 - 1);
    return number.clamp(0, 24 * 60 - 1);
  }

  final parts = text.split(':');
  if (parts.length >= 2) {
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return ((hour * 60) + minute).clamp(0, 24 * 60 - 1);
  }

  return fallbackMinute;
}

String _minuteLabel24(int minute) {
  final normalized = minute % (24 * 60);
  final hour = normalized ~/ 60;
  final mins = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
}

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
  final AgendaSalesService _agendaSalesService = const AgendaSalesService();
  final BookingSyncService _bookingSyncService = const BookingSyncService();
  final ChatService _chatService = const ChatService();
  late DateTime _weekStart;
  String? _therapistId;
  String _statusFilter = 'active';
  bool _loading = true;
  List<_Booking> _bookings = [];
  List<_ScheduleBlock> _scheduleBlocks = [];
  List<_Therapist> _therapists = [];
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  _AgendaCalendarHours _calendarHours = const _AgendaCalendarHours.fullDay();

  DateTime _now = DateTime.now();
  late Timer _timer;
  String _activeModule = 'agenda';
  String _viewMode = 'day_therapist';
  late DateTime _selectedDay;
  late DateTime _monthStart;
  bool _hasLoadedOnce = false;
  RealtimeChannel? _bookingsChannel;
  RealtimeChannel? _scheduleBlocksChannel;
  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _messagesChannel;
  Timer? _bookingsReloadDebounce;
  Timer? _messagesReloadDebounce;
  Timer? _messagesPollingTimer;
  String? _salesFocusId;
  String? _messagesFocusConversationId;
  String? _agendaChatConversationId;
  _Booking? _agendaChatBooking;
  String _userRole = 'reception';
  String _userDisplayName = '';
  int _messagesUnreadCount = 0;
  int _pendingConfirmCount = 0;
  RealtimeChannel? _paymentsChannel;
  Timer? _pendingConfirmPollTimer;
  final Set<String> _seenPaymentReceivedIds = {};

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/recepcion', (_) => false);
  }

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    _selectedDay = DateTime.now();
    _monthStart = DateTime(DateTime.now().year, DateTime.now().month);
    _loadCurrentRole();
    _loadTherapists();
    _loadBranches().then((_) async {
      await _loadCalendarSettings();
      await _loadBookings();
    });
    _subscribeToBookingsRealtime();
    _subscribeToScheduleBlocksRealtime();
    _subscribeToMessagesRealtime();
    _startMessagesPolling();
    _loadPendingConfirmCount();
    _subscribeToPaymentReceivedRealtime();
    _startPendingConfirmPolling();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _bookingsReloadDebounce?.cancel();
    _messagesReloadDebounce?.cancel();
    _messagesPollingTimer?.cancel();
    if (_bookingsChannel != null) {
      Supabase.instance.client.removeChannel(_bookingsChannel!);
    }
    if (_scheduleBlocksChannel != null) {
      Supabase.instance.client.removeChannel(_scheduleBlocksChannel!);
    }
    if (_conversationsChannel != null) {
      Supabase.instance.client.removeChannel(_conversationsChannel!);
    }
    if (_messagesChannel != null) {
      Supabase.instance.client.removeChannel(_messagesChannel!);
    }
    if (_paymentsChannel != null) {
      Supabase.instance.client.removeChannel(_paymentsChannel!);
    }
    _pendingConfirmPollTimer?.cancel();
    super.dispose();
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));
  _AgendaCalendarHours get _visibleCalendarHours {
    final expandedForBookings = _calendarHours.expandToFit(_bookings);
    if (_scheduleBlocks.isEmpty) {
      return expandedForBookings;
    }

    var expandedStart = expandedForBookings.startMinute;
    var expandedEnd = expandedForBookings.endMinuteInclusive;

    for (final block in _scheduleBlocks) {
      final blockStart = block.startMinute.clamp(0, _kDefaultCalendarEndMinute);
      final blockEnd = block.endMinute.clamp(0, 24 * 60);
      if (blockStart < expandedStart) {
        expandedStart = max(0, (blockStart ~/ 60) * 60);
      }
      if (blockEnd > expandedEnd) {
        expandedEnd = min(
          _kDefaultCalendarEndMinute,
          (((blockEnd + 14) ~/ 15) * 15) - 1,
        );
      }
    }

    return _AgendaCalendarHours(
      startMinute: expandedStart,
      endMinuteInclusive: max(expandedStart, expandedEnd),
    );
  }

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
    _bookingsChannel = _bookingSyncService.subscribeToBookings(
      channelName: 'agenda-bookings-realtime',
      onChanged: () {
        _bookingsReloadDebounce?.cancel();
        _bookingsReloadDebounce = Timer(
          const Duration(milliseconds: 350),
          () {
            if (mounted) {
              _loadBookings();
            }
          },
        );
      },
    );
  }

  Future<void> _loadPendingConfirmCount() async {
    try {
      final rows = await Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('status', 'payment_received');
      if (!mounted) return;
      final list = rows as List;
      setState(() {
        _pendingConfirmCount = list.length;
        for (final r in list) {
          final id = (r as Map)['id']?.toString();
          if (id != null) _seenPaymentReceivedIds.add(id);
        }
      });
    } catch (_) {}
  }

  void _subscribeToPaymentReceivedRealtime() {
    _paymentsChannel = Supabase.instance.client
        .channel('agenda-payments-received-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (payload) async {
            final newRow = payload.newRecord;
            final status = newRow['status']?.toString();
            final id = newRow['id']?.toString();
            if (status == 'payment_received' &&
                id != null &&
                !_seenPaymentReceivedIds.contains(id)) {
              _seenPaymentReceivedIds.add(id);
              if (!mounted) return;
              setState(() {
                _pendingConfirmCount += 1;
              });
              _showNewPaymentToast(id);
            } else if (status != 'payment_received' &&
                id != null &&
                _seenPaymentReceivedIds.contains(id)) {
              // El booking pasó a confirmed o cancelled: descuenta
              _seenPaymentReceivedIds.remove(id);
              if (!mounted) return;
              setState(() {
                _pendingConfirmCount = (_pendingConfirmCount - 1).clamp(0, 99);
              });
            }
          },
        )
        .subscribe();
  }

  void _startPendingConfirmPolling() {
    _pendingConfirmPollTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) _loadPendingConfirmCount();
      },
    );
  }

  void _showNewPaymentToast(String bookingId) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A9E65),
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            const Icon(Icons.payments_outlined, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Nuevo pago de anticipo recibido. Revisa la agenda y confirma la cita.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () {
                _loadBookings();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Refrescar'),
            ),
          ],
        ),
      ),
    );
  }

  void _subscribeToScheduleBlocksRealtime() {
    _scheduleBlocksChannel = Supabase.instance.client
        .channel('agenda-schedule-blocks-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'schedule_blocks',
          callback: (_) {
            _bookingsReloadDebounce?.cancel();
            _bookingsReloadDebounce = Timer(
              const Duration(milliseconds: 350),
              () {
                if (mounted) {
                  _loadBookings();
                }
              },
            );
          },
        )
        .subscribe();
  }

  void _subscribeToMessagesRealtime() {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    _conversationsChannel = _chatService.subscribeToConversations(
      channelName: 'agenda-conversations-$userId',
      onChanged: _scheduleUnreadMessagesRefresh,
    );
    _messagesChannel = _chatService.subscribeToMessages(
      channelName: 'agenda-messages-$userId',
      onChanged: _scheduleUnreadMessagesRefresh,
    );
  }

  void _scheduleUnreadMessagesRefresh() {
    _messagesReloadDebounce?.cancel();
    _messagesReloadDebounce = Timer(
      const Duration(milliseconds: 250),
      () {
        if (mounted) {
          _loadUnreadMessagesCount();
        }
      },
    );
  }

  void _startMessagesPolling() {
    _messagesPollingTimer ??= Timer.periodic(
      Duration(seconds: kIsWeb ? 5 : 12),
      (_) {
        if (mounted) {
          _loadUnreadMessagesCount();
        }
      },
    );
  }

  Future<void> _loadCurrentRole() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final supa = Supabase.instance.client;
      final profile = await supa
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      // staff.full_name es la fuente de verdad del nombre del usuario logueado.
      Map<String, dynamic>? staffRow;
      try {
        staffRow = await supa
            .from('staff')
            .select('full_name')
            .eq('auth_user_id', userId)
            .maybeSingle();
      } catch (_) {}
      if (!mounted) return;
      final role = RolePermissions.normalize(profile?['role'] as String?);
      await RolePermissions.warmup(role, forceRefresh: true);
      await _loadUnreadMessagesCount();
      if (!mounted) return;
      final fullName = (staffRow?['full_name'] as String?)?.trim() ?? '';
      final firstName = fullName.isEmpty
          ? ''
          : fullName.split(RegExp(r'\s+')).first;
      setState(() {
        final visibleModules = RolePermissions.visibleModulesFor(role);
        _userRole = role;
        _userDisplayName = firstName;
        if (visibleModules.isEmpty) {
          _activeModule = '';
        } else if (!visibleModules.contains(_activeModule)) {
          _activeModule = visibleModules.first;
        }
      });
    } catch (_) {}
  }

  String get _sourcePlatform => kIsWeb ? 'web' : 'mobile';

  Future<void> _loadUnreadMessagesCount() async {
    try {
      final count = await _chatService.unreadCount();
      if (!mounted) {
        return;
      }
      setState(() => _messagesUnreadCount = count);
    } catch (_) {}
  }

  void _closeAgendaChat() {
    if (!mounted) return;
    setState(() {
      _agendaChatConversationId = null;
      _agendaChatBooking = null;
    });
  }

  List<_Booking> _bookingsForDay(DateTime day) {
    final list = _bookings.where((b) => _sameDay(b.date, day)).toList();
    list.sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return list;
  }

  List<_ScheduleBlock> _scheduleBlocksForDay(DateTime day) {
    final list = _scheduleBlocks.where((b) => b.appliesToDay(day)).toList();
    list.sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return list;
  }

  bool _isSlotBlocked(DateTime day, int startMinute, int durationMinutes) {
    final slotEnd = startMinute + max(15, durationMinutes).toInt();
    return _scheduleBlocks.any((block) => block.overlaps(day, startMinute, slotEnd));
  }

  List<_Booking> get _upcomingBookings {
    final nowMinute = _now.hour * 60 + _now.minute;
    final list = _bookings
        .where(
          (b) =>
              b.status != 'cancelled' &&
              b.status != 'paid' &&
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
      case 'pending_reception':
        return 'Solicitud IA';
      case 'pending_payment':
        return 'Esperando anticipo';
      case 'payment_received':
        return 'Pago recibido · pdte confirmar';
      case 'confirmed':
        return 'Confirmada';
      case 'checked_in':
        return 'Check-in';
      case 'in_progress':
        return 'En proceso';
      case 'completed':
        return 'Completada';
      case 'awaiting_payment':
        return 'Pendiente de cobro';
      case 'paid':
        return 'Pagada';
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
      case 'pending_reception':
        return const Color(0xFFFF8C00);
      case 'pending_payment':
        return const Color(0xFFC68A17);
      case 'payment_received':
        return const Color(0xFF1A9E65);
      case 'confirmed':
        return const Color(0xFF1A9E65);
      case 'checked_in':
        return const Color(0xFF2088D8);
      case 'in_progress':
        return const Color(0xFF6A54E0);
      case 'completed':
        return const Color(0xFF666666);
      case 'awaiting_payment':
        return const Color(0xFFB06A1F);
      case 'paid':
        return const Color(0xFF0E8F55);
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
      final finalStatus = await _persistBookingStatusFlow(booking, newStatus);

      await _loadBookings();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cita actualizada a ${_statusLabel(finalStatus)}'),
          backgroundColor: _statusColor(finalStatus),
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

  Future<String> _persistBookingStatusFlow(_Booking booking, String newStatus) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    Future<void> updateStatus(String status) {
      return Supabase.instance.client
          .from('bookings')
          .update({
            'status': status,
            'updated_by': currentUserId,
            'source_platform': _sourcePlatform,
          })
          .eq('id', booking.id);
    }

    if (newStatus != 'completed') {
      await updateStatus(newStatus);
      if (newStatus == 'confirmed') {
        await _emitReservationSystemMessage(
          booking,
          'Tu cita fue confirmada por recepcion. Te esperamos en Sahara Club Spa.',
        );
      }
      return newStatus;
    }

    await updateStatus('completed');

    final sale = await _agendaSalesService.ensureSaleForBooking(
      AgendaSaleDraft(
        bookingId: booking.id,
        branchId: booking.sucursalId,
        customerId: booking.clientRecordId ?? booking.profileClientId,
        profileClientId: booking.profileClientId,
        customerName: booking.clientName,
        professionalId: booking.therapistId,
        serviceId: booking.serviceId,
        serviceName: booking.serviceName,
        subtotal: booking.servicePrice,
        total: booking.servicePrice,
        notes: booking.notes,
        durationMinutes: booking.durationMinutes,
      ),
    );

    try {
      await updateStatus('awaiting_payment');
      _salesFocusId = sale.id;
      return 'awaiting_payment';
    } catch (_) {
      _salesFocusId = sale.id;
      return 'completed';
    }
  }

  Future<void> _emitReservationSystemMessage(
    _Booking booking,
    String message,
  ) async {
    try {
      final conversation = await _chatService.createConversation(
        NewConversationDraft(
          subject: booking.serviceName.isNotEmpty
              ? 'Reserva: ${booking.serviceName}'
              : 'Seguimiento de reserva',
          customerId: booking.profileClientId,
          professionalId: booking.therapistId.isEmpty ? null : booking.therapistId,
          reservationId: booking.id,
        ),
      );
      await _chatService.sendMessage(
        conversationId: conversation.id,
        text: message,
        messageType: 'reservation_update',
      );
      await _loadUnreadMessagesCount();
    } catch (error) {
      debugPrint('reservation system message error: $error');
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
      final data = await _bookingSyncService.fetchBookings(
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
        therapistId: _therapistId,
        branchId: kEnableMultiBranch ? _selectedBranchId : null,
        statusFilter: _statusFilter,
      );
      final parsed = <_Booking>[];
      for (final row in data) {
        try {
          parsed.add(_Booking.fromMap(row));
        } catch (e) {
          debugPrint('Skipping malformed booking row: $e');
        }
      }
      var parsedBlocks = _scheduleBlocks;
      try {
        parsedBlocks = await _loadScheduleBlocksForVisibleRange();
      } catch (e) {
        debugPrint('loadScheduleBlocks: $e');
      }
      if (!mounted) return;
      setState(() {
        _bookings = parsed;
        _scheduleBlocks = parsedBlocks;
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
    final visibleModules = RolePermissions.visibleModulesFor(_userRole);
    final effectiveModule = visibleModules.isEmpty
        ? ''
        : visibleModules.contains(_activeModule)
        ? _activeModule
        : visibleModules.first;
    return Scaffold(
      backgroundColor: SaharaTheme.blancoAlmendra,
      body: Column(
        children: [
          _ModuleNav(
            activeModule: effectiveModule,
            userRole: _userRole,
            messagesUnreadCount: _messagesUnreadCount,
            pendingConfirmCount: _pendingConfirmCount,
            onModuleTap: (m) => setState(() => _activeModule = m),
            onLogout: _logout,
          ),
          Expanded(
            child: visibleModules.isEmpty
                ? _PlaceholderModule(module: 'sin_acceso')
                : effectiveModule == 'clientes'
                ? const ClientsModule()
                : effectiveModule == 'ventas'
                ? SalesModule(initialSaleId: _salesFocusId)
                : effectiveModule == 'mensajes'
                ? MensajesModule(
                    initialConversationId: _messagesFocusConversationId,
                  )
                : effectiveModule == 'productos'
                ? const ProductosModule()
                : effectiveModule == 'finanzas'
                ? const FinanzasModule()
                : effectiveModule == 'reportes'
                ? const ReportesModule()
                : effectiveModule == 'admin'
                ? AdminModule(currentRole: _userRole)
                : effectiveModule != 'agenda'
                ? _PlaceholderModule(module: effectiveModule)
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

                      return Stack(
                        children: [
                          Row(
                            children: [
                              _Sidebar(
                                therapists: _therapists,
                                therapistId: _therapistId,
                                branches: _branches,
                                selectedBranchId: _selectedBranchId,
                                statusFilter: _statusFilter,
                                weekStart: _weekStart,
                                userDisplayName: _userDisplayName,
                                onBranch: (v) async {
                                  setState(() => _selectedBranchId = v);
                                  await _loadCalendarSettings();
                                  await _loadBookings();
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
                                onLogout: _logout,
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
                                              calendarHours:
                                                  _visibleCalendarHours,
                                              weekStart: _weekStart,
                                              bookings: _bookings,
                                              scheduleBlocks: _scheduleBlocks,
                                              now: _now,
                                              onBookingTap: _showBookingDetail,
                                              onScheduleBlockTap:
                                                  _showScheduleBlockDetail,
                                              onReschedule: _rescheduleBooking,
                                              isSlotBlocked: _isSlotBlocked,
                                              onSlotTap: _onSlotTap,
                                            )
                                          : _viewMode == 'day'
                                          ? _DayGrid(
                                              calendarHours:
                                                  _visibleCalendarHours,
                                              day: _selectedDay,
                                              bookings: _bookings,
                                              scheduleBlocks: _scheduleBlocksForDay(
                                                _selectedDay,
                                              ),
                                              now: _now,
                                              onBookingTap: _showBookingDetail,
                                              onScheduleBlockTap:
                                                  _showScheduleBlockDetail,
                                              onReschedule: _rescheduleBooking,
                                              isSlotBlocked: _isSlotBlocked,
                                              onSlotTap: _onSlotTap,
                                            )
                                          : _viewMode == 'day_therapist'
                                          ? _DayByTherapistGrid(
                                              calendarHours:
                                                  _visibleCalendarHours,
                                              day: _selectedDay,
                                              bookings: _bookings.where((b) {
                                                return _sameDay(b.date, _selectedDay);
                                              }).toList(),
                                              therapists: _therapists,
                                              now: _now,
                                              onBookingTap: _showBookingDetail,
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
                          ),
                          if (_agendaChatConversationId != null &&
                              _agendaChatBooking != null) ...[
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: _closeAgendaChat,
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _AgendaReservationChatDrawer(
                                booking: _agendaChatBooking!,
                                conversationId: _agendaChatConversationId!,
                                onClose: _closeAgendaChat,
                                onViewReservation: () {
                                  final booking = _agendaChatBooking;
                                  _closeAgendaChat();
                                  if (booking != null) {
                                    Future.microtask(
                                      () => _showBookingDetail(context, booking),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
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
        calendarHours: _visibleCalendarHours,
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
        calendarHours: _visibleCalendarHours,
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

  void _showScheduleBlockDialog(
    BuildContext ctx, {
    required DateTime date,
    required TimeOfDay time,
    _ScheduleBlock? initialBlock,
  }) {
    showDialog(
      context: ctx,
      builder: (_) => _ScheduleBlockDialog(
        calendarHours: _visibleCalendarHours,
        selectedDate: date,
        initialStartMinute: (time.hour * 60) + time.minute,
        initialBlock: initialBlock,
        onSave: ({
          required DateTime blockDate,
          required int startMinute,
          required int endMinute,
          required String scope,
          required String title,
          required String notes,
        }) async {
          final saved = await _saveScheduleBlock(
            existing: initialBlock,
            blockDate: blockDate,
            startMinute: startMinute,
            endMinute: endMinute,
            scope: scope,
            title: title,
            notes: notes,
          );
          if (!saved || !mounted) return false;
          Navigator.pop(ctx);
          return true;
        },
        onDelete: initialBlock == null
            ? null
            : () async {
                final deleted = await _deleteScheduleBlock(initialBlock);
                if (!deleted || !mounted) return false;
                Navigator.pop(ctx);
                return true;
              },
      ),
    );
  }

  void _showScheduleBlockDetail(BuildContext ctx, _ScheduleBlock block) {
    showDialog(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            const Icon(Icons.block_outlined, color: SaharaTheme.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                block.title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F1A17),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_kDaysShort[block.blockDate.weekday - 1]}, ${block.blockDate.day}/${block.blockDate.month}/${block.blockDate.year}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              block.timeLabel,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              block.scopeLabel,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
            ),
            if (block.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                block.notes,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cerrar',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showScheduleBlockDialog(
                context,
                date: block.blockDate,
                time: TimeOfDay(
                  hour: block.startMinute ~/ 60,
                  minute: block.startMinute % 60,
                ),
                initialBlock: block,
              );
            },
            child: Text(
              'Editar',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
      if (!mounted || value == null) return;
      if (value == 'reserva') {
        _showNewDialog(context, date: date, time: time);
        return;
      }
      if (value == 'bloquear') {
        _showScheduleBlockDialog(context, date: date, time: time);
      }
    });
  }

  Future<bool> _saveScheduleBlock({
    _ScheduleBlock? existing,
    required DateTime blockDate,
    required int startMinute,
    required int endMinute,
    required String scope,
    required String title,
    required String notes,
  }) async {
    final payload = <String, dynamic>{
      'branch_id': kEnableMultiBranch ? _selectedBranchId : kDefaultBranchId,
      'block_date': _isoDateOnly(
        DateTime(blockDate.year, blockDate.month, blockDate.day),
      ),
      'start_minute': startMinute,
      'end_minute': endMinute,
      'scope': scope,
      'title': title.trim().isEmpty ? 'Horario bloqueado' : title.trim(),
      'notes': notes.trim(),
    };
    try {
      final table = Supabase.instance.client.from('schedule_blocks');
      if (existing == null) {
        await table.insert(payload);
      } else {
        await table.update(payload).eq('id', existing.id);
      }
      if (!mounted) return true;
      await _loadBookings();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Bloqueo de horario guardado.'
                : 'Bloqueo de horario actualizado.',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: Text(
            'No se pudo guardar el bloqueo. Si la tabla no existe aún, corre el SQL de schedule_blocks. Error: $error',
          ),
        ),
      );
      return false;
    }
  }

  Future<bool> _deleteScheduleBlock(_ScheduleBlock block) async {
    try {
      await Supabase.instance.client
          .from('schedule_blocks')
          .delete()
          .eq('id', block.id);
      if (!mounted) return true;
      await _loadBookings();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bloqueo eliminado.')),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: Text('No se pudo eliminar el bloqueo: $error'),
        ),
      );
      return false;
    }
  }

  String _isoDateOnly(DateTime value) => value.toIso8601String().split('T').first;

  String _isoTimeOnly(int minute) {
    final h = minute ~/ 60;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
  }

  String _statusAfterReschedule(String currentStatus) {
    switch (currentStatus) {
      case 'confirmed':
      case 'checked_in':
      case 'in_progress':
      case 'rescheduled':
        return 'confirmed';
      case 'completed':
      case 'awaiting_payment':
      case 'paid':
      case 'cancelled':
      case 'no_show':
        return currentStatus;
      case 'scheduled':
      case 'pending':
      default:
        return 'pending';
    }
  }

  Future<void> _loadCalendarSettings() async {
    try {
      dynamic query = Supabase.instance.client
          .from('business_settings')
          .select('calendar_start_hour, calendar_end_hour');

      final branchId = kEnableMultiBranch ? _selectedBranchId : kDefaultBranchId;
      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('branch_id', branchId);
      }

      final rows = await query.limit(1);

      Map<String, dynamic>? row;
      if (rows is List && rows.isNotEmpty) {
        row = Map<String, dynamic>.from(rows.first as Map);
      }

      if (mounted) {
        setState(() {
          _calendarHours = _AgendaCalendarHours.fromMap(row);
        });
      } else {
        _calendarHours = _AgendaCalendarHours.fromMap(row);
      }
    } catch (error) {
      debugPrint('loadCalendarSettings fallback: $error');
      if (mounted) {
        setState(() {
          _calendarHours = const _AgendaCalendarHours.fullDay();
        });
      } else {
        _calendarHours = const _AgendaCalendarHours.fullDay();
      }
    }
  }

  Future<List<_ScheduleBlock>> _loadScheduleBlocksForVisibleRange() async {
    final bufferStart = _rangeStart.subtract(const Duration(days: 6));
    dynamic query = Supabase.instance.client
        .from('schedule_blocks')
        .select(
          'id, branch_id, block_date, start_minute, end_minute, scope, title, notes, created_at',
        )
        .gte('block_date', _isoDateOnly(bufferStart))
        .lte('block_date', _isoDateOnly(_rangeEnd))
        .order('block_date')
        .order('start_minute');

    if (kEnableMultiBranch && _selectedBranchId != null) {
      query = query.eq('branch_id', _selectedBranchId!);
    }

    final response = await query;
    final parsed = (response as List)
        .cast<Map<String, dynamic>>()
        .map(_ScheduleBlock.fromMap)
        .where((block) => block.intersectsRange(_rangeStart, _rangeEnd))
        .toList();
    parsed.sort((a, b) {
      final byDate = a.blockDate.compareTo(b.blockDate);
      if (byDate != 0) return byDate;
      return a.startMinute.compareTo(b.startMinute);
    });
    return parsed;
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
            'status': _statusAfterReschedule(b.status),
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
        onCharge: () => _showChargeDialog(context, b),
        onViewTicket: () => _openSaleFromBooking(context, b),
        onOpenChat: () => _openChatFromBooking(context, b),
      ),
    );
  }

  AgendaSaleDraft _saleDraftFromBooking(_Booking booking) {
    return AgendaSaleDraft(
      bookingId: booking.id,
      branchId: booking.sucursalId,
      customerId: booking.clientRecordId ?? booking.profileClientId,
      profileClientId: booking.profileClientId,
      customerName: booking.clientName,
      professionalId: booking.therapistId,
      serviceId: booking.serviceId,
      serviceName: booking.serviceName,
      subtotal: booking.servicePrice,
      total: booking.servicePrice,
      notes: booking.notes,
      durationMinutes: booking.durationMinutes,
    );
  }

  Future<void> _openSaleFromBooking(BuildContext context, _Booking booking) async {
    var sale = await _agendaSalesService.findSaleForBooking(booking.id);
    if (!mounted) return;

    if (sale == null &&
        const ['completed', 'awaiting_payment', 'paid'].contains(booking.status)) {
      try {
        sale = await _agendaSalesService.ensureSaleForBooking(
          _saleDraftFromBooking(booking),
        );
      } catch (_) {}
    }

    if (sale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todavia no existe un ticket para esta cita.')),
      );
      return;
    }

    final resolvedSale = sale;

    Navigator.pop(context);
    setState(() {
      _salesFocusId = resolvedSale.id;
      _activeModule = 'ventas';
    });
  }

  Future<void> _showChargeDialog(BuildContext context, _Booking booking) async {
    var sale = await _agendaSalesService.findSaleForBooking(booking.id);
    if (!mounted) return;

    if (sale == null &&
        const ['completed', 'awaiting_payment'].contains(booking.status)) {
      try {
        sale = await _agendaSalesService.ensureSaleForBooking(
          _saleDraftFromBooking(booking),
        );
        await _updateBookingStatus(booking, 'completed');
      } catch (_) {}
    }

    if (sale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo generar el ticket de esta cita para cobrarla.'),
        ),
      );
      return;
    }

    final resolvedSale = sale;

    final paid = await showDialog<bool>(
      context: context,
      builder: (_) => _ChargeBookingDialog(
        booking: booking,
        sale: resolvedSale,
        salesService: _agendaSalesService,
      ),
    );

    if (paid == true && mounted) {
      await _loadBookings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cobro registrado correctamente.')),
      );
    }
  }

  Future<void> _openChatFromBooking(BuildContext context, _Booking booking) async {
    try {
      if ((booking.profileClientId ?? '').isEmpty) {
        throw const ChatException(
          'La reserva no tiene un cliente enlazado para abrir el chat.',
        );
      }
      final conversation = await _chatService.createConversation(
        NewConversationDraft(
          subject: booking.serviceName.isNotEmpty
              ? 'Reserva: ${booking.serviceName}'
              : 'Seguimiento de reserva',
          customerId: booking.profileClientId,
          reservationId: booking.id,
        ),
      );
      if (!mounted) {
        return;
      }
      final isCompact = MediaQuery.of(context).size.width < 960;
      if (isCompact) {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(20),
            backgroundColor: Colors.transparent,
            child: SizedBox(
              width: 760,
              height: 720,
              child: _AgendaReservationChatDrawer(
                booking: booking,
                conversationId: conversation.id,
                onClose: () => Navigator.of(context).pop(),
                onViewReservation: () {
                  Navigator.of(context).pop();
                  Future.microtask(() => _showBookingDetail(context, booking));
                },
                compact: true,
              ),
            ),
          ),
        );
        return;
      }
      setState(() {
        _agendaChatConversationId = conversation.id;
        _agendaChatBooking = booking;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo abrir el chat de esta reserva.'),
          backgroundColor: const Color(0xFFB32D2D),
        ),
      );
      debugPrint('openReservationChat error: $error');
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Top Bar
// ═════════════════════════════════════════════════════════════════════════════
class _AgendaReservationChatDrawer extends StatelessWidget {
  const _AgendaReservationChatDrawer({
    required this.booking,
    required this.conversationId,
    required this.onClose,
    required this.onViewReservation,
    this.compact = false,
  });

  final _Booking booking;
  final String conversationId;
  final VoidCallback onClose;
  final VoidCallback onViewReservation;
  final bool compact;

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
      case 'scheduled':
        return 'Pendiente';
      case 'pending_reception':
        return 'Solicitud IA';
      case 'pending_payment':
        return 'Esperando anticipo';
      case 'payment_received':
        return 'Pago recibido · pdte confirmar';
      case 'confirmed':
        return 'Confirmada';
      case 'checked_in':
        return 'Check-in';
      case 'in_progress':
        return 'En proceso';
      case 'completed':
        return 'Completada';
      case 'awaiting_payment':
        return 'Pendiente de cobro';
      case 'paid':
        return 'Pagada';
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
      case 'confirmed':
        return const Color(0xFF1A9E65);
      case 'checked_in':
        return const Color(0xFF2088D8);
      case 'in_progress':
        return const Color(0xFF6A54E0);
      case 'completed':
        return const Color(0xFF666666);
      case 'awaiting_payment':
        return const Color(0xFFB06A1F);
      case 'paid':
        return const Color(0xFF0E8F55);
      case 'cancelled':
        return const Color(0xFFB32D2D);
      case 'rescheduled':
        return const Color(0xFF0A9AA4);
      default:
        return SaharaTheme.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth = compact ? 760.0 : 560.0;
    final statusColor = _statusColor(booking.status);
    final dateLabel =
        '${booking.date.day.toString().padLeft(2, '0')}/${booking.date.month.toString().padLeft(2, '0')}/${booking.date.year}';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: panelWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(-8, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFEAE6DF))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.clientName,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF201A16),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking.serviceName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: SaharaTheme.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close, color: Color(0xFF6D655C)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ReservationMetaChip(
                        icon: Icons.event_outlined,
                        label: dateLabel,
                      ),
                      _ReservationMetaChip(
                        icon: Icons.schedule_outlined,
                        label: '${booking.timeLabel} - ${booking.endTimeLabel}',
                      ),
                      _ReservationMetaChip(
                        icon: Icons.spa_outlined,
                        label: booking.serviceName,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          _statusLabel(booking.status),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: onViewReservation,
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Ver reserva'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF52463C),
                          side: const BorderSide(color: Color(0xFFD8C9B5)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: onClose,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Volver a agenda'),
                        style: FilledButton.styleFrom(
                          backgroundColor: SaharaTheme.gold,
                          foregroundColor: const Color(0xFF22170D),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: MensajesModule(
                initialConversationId: conversationId,
                embedded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationMetaChip extends StatelessWidget {
  const _ReservationMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F2E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7F6441)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4D4034),
            ),
          ),
        ],
      ),
    );
  }
}

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
            label: 'DÍA · TERAPEUTAS',
            active: viewMode == 'day_therapist',
            onTap: () => onViewMode('day_therapist'),
          ),
          const SizedBox(width: 6),
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
                          DropdownMenuItem(value: 'awaiting_payment', child: Text('Pendientes de cobro')),
                          DropdownMenuItem(value: 'paid', child: Text('Pagadas')),
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
                      onCancel: !const ['completed', 'awaiting_payment', 'paid', 'cancelled']
                              .contains(booking.status)
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
                      onCancel: !const ['completed', 'awaiting_payment', 'paid', 'cancelled']
                              .contains(booking.status)
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
    required this.onLogout,
    this.userDisplayName = '',
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
  final Future<void> Function() onLogout;
  final String userDisplayName;

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
                  widget.userDisplayName.isEmpty
                      ? 'RECEPCIÓN'
                      : 'HOLA, ${widget.userDisplayName.toUpperCase()}',
                  style: GoogleFonts.inter(
                    color: widget.userDisplayName.isEmpty
                        ? Colors.black26
                        : SaharaTheme.gold,
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
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
                        value: 'awaiting_payment',
                        child: Text('Pendientes de cobro'),
                      ),
                      DropdownMenuItem(
                        value: 'paid',
                        child: Text('Pagadas'),
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
            onTap: widget.onLogout,
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
    required this.calendarHours,
    required this.weekStart,
    required this.bookings,
    required this.scheduleBlocks,
    required this.now,
    required this.onBookingTap,
    required this.onScheduleBlockTap,
    required this.onReschedule,
    required this.isSlotBlocked,
    required this.onSlotTap,
  });

  final _AgendaCalendarHours calendarHours;
  final DateTime weekStart;
  final List<_Booking> bookings;
  final List<_ScheduleBlock> scheduleBlocks;
  final DateTime now;
  final void Function(BuildContext, _Booking) onBookingTap;
  final void Function(BuildContext, _ScheduleBlock) onScheduleBlockTap;
  final Future<bool> Function(_Booking, DateTime, int) onReschedule;
  final bool Function(DateTime, int, int) isSlotBlocked;
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
  final ScrollController _scrollController = ScrollController();
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToPreferredHour());
  }

  @override
  void didUpdateWidget(covariant _WeekGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hoursChanged =
        oldWidget.calendarHours.startMinute != widget.calendarHours.startMinute ||
        oldWidget.calendarHours.endMinuteInclusive !=
            widget.calendarHours.endMinuteInclusive;
    final weekChanged = !_sameDay(oldWidget.weekStart, widget.weekStart);
    if (hoursChanged || weekChanged) {
      _didInitialScroll = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToPreferredHour());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  (int, int)? _slotFromLocal(Offset local) {
    if (_dayWidth <= 0 || local.dx < 0 || local.dy < 0) return null;
    final dayIdx = (local.dx / _dayWidth).floor().clamp(0, 6);
    final rawMin =
        (local.dy / _kHourHeight * 60).round() + widget.calendarHours.startMinute;
    final snapped = (rawMin / 15).round() * 15;
    if (!widget.calendarHours.containsMinute(snapped)) return null;
    return (dayIdx, snapped);
  }

  Offset? _localFromGrid(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  String _minuteLabel(int minute) {
    return _minuteLabel24(minute);
  }

  double _topForMinute(int minute) =>
      (minute - widget.calendarHours.startMinute) * (_kHourHeight / 60);

  void _jumpToPreferredHour() {
    if (_didInitialScroll || !_scrollController.hasClients) return;
    final nowMinute = widget.now.hour * 60 + widget.now.minute;
    final todayIdx = DateTime(
      widget.now.year,
      widget.now.month,
      widget.now.day,
    ).difference(widget.weekStart).inDays;
    final focusMinute = (todayIdx >= 0 && todayIdx < 7)
        ? nowMinute
        : max(widget.calendarHours.startMinute, 8 * 60);
    final clampedMinute = focusMinute.clamp(
      widget.calendarHours.startMinute,
      widget.calendarHours.lastSlotMinute,
    ).toInt();
    final target = max(
      0.0,
      _topForMinute(clampedMinute) - (_kHourHeight * 1.5),
    );
    final maxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(target.clamp(0.0, maxExtent).toDouble());
    _didInitialScroll = true;
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
              controller: _scrollController,
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  _dayWidth = (constraints.maxWidth - _kTimeColWidth) / 7;
                  final gridHeight = widget.calendarHours.gridHeight;
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
        children: widget.calendarHours.hourLabelMinutes.map((minute) {
          return SizedBox(
            height: _kHourHeight,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 4),
                child: Text(
                  _minuteLabel(minute),
                  style: GoogleFonts.inter(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
              startMinute: widget.calendarHours.startMinute,
              endMinuteExclusive: widget.calendarHours.displayEndMinuteExclusive,
              dayWidth: _dayWidth,
              hourHeight: _kHourHeight,
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
              if (widget.isSlotBlocked(
                newDate,
                minute,
                details.data.durationMinutes,
              )) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Ese horario está bloqueado. Edita o elimina el bloqueo para mover la cita.',
                    ),
                  ),
                );
                setState(() {
                  _dragging = null;
                  _dragLocal = null;
                });
                return;
              }
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

          // 8. Schedule blocks
          ..._buildScheduleBlocks(ctx),

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
    final top = _topForMinute(minute);
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
    final top = _topForMinute(minute);
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
    final topOffset = _topForMinute(minutes);
    if (topOffset < 0 || topOffset > widget.calendarHours.gridHeight) {
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
      final top = _topForMinute(b.startMinute);
      final height = (b.durationMinutes * _kHourHeight / 60).clamp(
        22.0,
        double.infinity,
      );
      if (top < 0 || top > widget.calendarHours.gridHeight) {
        return const SizedBox.shrink();
      }

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

  List<Widget> _buildScheduleBlocks(BuildContext ctx) {
    final widgets = <Widget>[];
    for (final block in widget.scheduleBlocks) {
      for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
        final day = widget.weekStart.add(Duration(days: dayOffset));
        if (!block.appliesToDay(day)) continue;
        final top = _topForMinute(block.startMinute);
        final height = (block.durationMinutes * _kHourHeight / 60).clamp(
          22.0,
          double.infinity,
        );
        widgets.add(
          Positioned(
            top: top + 1,
            left: dayOffset * _dayWidth + 1,
            width: _dayWidth - 2,
            height: height,
            child: _ScheduleBlockCard(
              block: block,
              onTap: () => widget.onScheduleBlockTap(ctx, block),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Day Grid  (vista de un solo día)
// ═════════════════════════════════════════════════════════════════════════════
class _DayGrid extends StatefulWidget {
  const _DayGrid({
    required this.calendarHours,
    required this.day,
    required this.bookings,
    required this.scheduleBlocks,
    required this.now,
    required this.onBookingTap,
    required this.onScheduleBlockTap,
    required this.onReschedule,
    required this.isSlotBlocked,
    required this.onSlotTap,
  });
  final _AgendaCalendarHours calendarHours;
  final DateTime day;
  final List<_Booking> bookings;
  final List<_ScheduleBlock> scheduleBlocks;
  final DateTime now;
  final void Function(BuildContext, _Booking) onBookingTap;
  final void Function(BuildContext, _ScheduleBlock) onScheduleBlockTap;
  final Future<bool> Function(_Booking, DateTime, int) onReschedule;
  final bool Function(DateTime, int, int) isSlotBlocked;
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
  final ScrollController _scrollController = ScrollController();
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToPreferredHour());
  }

  @override
  void didUpdateWidget(covariant _DayGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hoursChanged =
        oldWidget.calendarHours.startMinute != widget.calendarHours.startMinute ||
        oldWidget.calendarHours.endMinuteInclusive !=
            widget.calendarHours.endMinuteInclusive;
    final dayChanged = !_sameDay(oldWidget.day, widget.day);
    if (hoursChanged || dayChanged) {
      _didInitialScroll = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToPreferredHour());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int? _slotMinute(Offset local) {
    if (_colWidth <= 0 || local.dy < 0) return null;
    final rawMin =
        (local.dy / _kHourHeight * 60).round() + widget.calendarHours.startMinute;
    final snapped = (rawMin / 15).round() * 15;
    if (!widget.calendarHours.containsMinute(snapped)) return null;
    return snapped;
  }

  Offset? _localFromGrid(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  String _minuteLabel(int m) => _minuteLabel24(m);

  double _topForMinute(int minute) =>
      (minute - widget.calendarHours.startMinute) * (_kHourHeight / 60);

  void _jumpToPreferredHour() {
    if (_didInitialScroll || !_scrollController.hasClients) return;
    final nowMinute = widget.now.hour * 60 + widget.now.minute;
    final focusMinute = _sameDay(widget.day, widget.now)
        ? nowMinute
        : max(widget.calendarHours.startMinute, 8 * 60);
    final clampedMinute = focusMinute.clamp(
      widget.calendarHours.startMinute,
      widget.calendarHours.lastSlotMinute,
    ).toInt();
    final target = max(
      0.0,
      _topForMinute(clampedMinute) - (_kHourHeight * 1.5),
    );
    final maxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(target.clamp(0.0, maxExtent).toDouble());
    _didInitialScroll = true;
  }

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
              controller: _scrollController,
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  _colWidth = constraints.maxWidth - _kTimeColWidth;
                  final gridHeight = widget.calendarHours.gridHeight;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time column
                      SizedBox(
                        width: _kTimeColWidth,
                        height: gridHeight,
                        child: Column(
                          children: [
                            for (final minute
                                in widget.calendarHours.hourLabelMinutes)
                              SizedBox(
                                height: _kHourHeight,
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      right: 10,
                                      top: 4,
                                    ),
                                    child: Text(
                                      _minuteLabel(minute),
                                      style: GoogleFonts.inter(
                                        color: Colors.grey,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                                startMinute: widget.calendarHours.startMinute,
                                endMinuteExclusive:
                                    widget.calendarHours.displayEndMinuteExclusive,
                                hourHeight: _kHourHeight,
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
                                if (widget.isSlotBlocked(
                                  widget.day,
                                  m,
                                  d.data.durationMinutes,
                                )) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Ese horario está bloqueado. Edita o elimina el bloqueo para mover la cita.',
                                      ),
                                    ),
                                  );
                                  setState(() {
                                    _dragging = null;
                                    _dragLocal = null;
                                  });
                                  return;
                                }
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
                            ..._buildScheduleBlocks(ctx),
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
    final top = _topForMinute(m);
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
    final top = _topForMinute(m);
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
    final top = _topForMinute(mins);
    if (top < 0 || top > widget.calendarHours.gridHeight)
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
      final top = _topForMinute(b.startMinute);
      final height = (b.durationMinutes * _kHourHeight / 60).clamp(
        22.0,
        double.infinity,
      );
      if (top < 0 || top > widget.calendarHours.gridHeight) {
        return const SizedBox.shrink();
      }
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

  List<Widget> _buildScheduleBlocks(BuildContext ctx) {
    return widget.scheduleBlocks.map((block) {
      final top = _topForMinute(block.startMinute);
      final height = (block.durationMinutes * _kHourHeight / 60).clamp(
        22.0,
        double.infinity,
      );
      return Positioned(
        top: top + 1,
        left: 1,
        right: 1,
        height: height,
        child: _ScheduleBlockCard(
          block: block,
          onTap: () => widget.onScheduleBlockTap(ctx, block),
        ),
      );
    }).toList();
  }
}

class _DayPainter extends CustomPainter {
  const _DayPainter({
    required this.startMinute,
    required this.endMinuteExclusive,
    required this.hourHeight,
    required this.isToday,
  });
  final int startMinute;
  final int endMinuteExclusive;
  final double hourHeight;
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
    final totalHours = max(1, ((endMinuteExclusive - startMinute) / 60).ceil());
    for (int h = 0; h <= totalHours; h++) {
      canvas.drawLine(
        Offset(0, h * hourHeight),
        Offset(size.width, h * hourHeight),
        hLine,
      );
    }
  }

  @override
  bool shouldRepaint(_DayPainter old) =>
      old.isToday != isToday ||
      old.startMinute != startMinute ||
      old.endMinuteExclusive != endMinuteExclusive;
}

// ═════════════════════════════════════════════════════════════════════════════
// Month Grid  (vista mensual)
// ═════════════════════════════════════════════════════════════════════════════
class _ScheduleBlockCard extends StatelessWidget {
  const _ScheduleBlockCard({required this.block, required this.onTap});

  final _ScheduleBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFFF8EEE7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE0C2AC)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFC07A4A),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.block_outlined,
                          size: 12,
                          color: Color(0xFFA96535),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            block.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5E3921),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      block.timeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9A6B46),
                      ),
                    ),
                    if (block.notes.isNotEmpty)
                      Text(
                        block.notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF7C5A42),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

// ───────────────────────────────────────────────────────────────────────────
// Vista: DÍA POR TERAPEUTA
// Una columna por cada terapeuta activo + columna "Sin asignar". Resuelve el
// solape de citas a la misma hora cuando se atienden con distintos terapeutas.
// ───────────────────────────────────────────────────────────────────────────
class _DayByTherapistGrid extends StatefulWidget {
  const _DayByTherapistGrid({
    required this.calendarHours,
    required this.day,
    required this.bookings,
    required this.therapists,
    required this.now,
    required this.onBookingTap,
  });
  final _AgendaCalendarHours calendarHours;
  final DateTime day;
  final List<_Booking> bookings;
  final List<_Therapist> therapists;
  final DateTime now;
  final void Function(BuildContext, _Booking) onBookingTap;

  @override
  State<_DayByTherapistGrid> createState() => _DayByTherapistGridState();
}

class _DayByTherapistGridState extends State<_DayByTherapistGrid> {
  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();
  bool _didInitialScroll = false;

  static const double _kHourLabelWidth = 56;
  static const double _kColMinWidth = 180;
  static const double _kHeaderHeight = 56;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToPreferredHour());
  }

  @override
  void didUpdateWidget(covariant _DayByTherapistGrid old) {
    super.didUpdateWidget(old);
    final hoursChanged =
        old.calendarHours.startMinute != widget.calendarHours.startMinute ||
        old.calendarHours.endMinuteInclusive !=
            widget.calendarHours.endMinuteInclusive;
    final dayChanged = !_sameDay(old.day, widget.day);
    if (hoursChanged || dayChanged) {
      _didInitialScroll = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToPreferredHour());
    }
  }

  @override
  void dispose() {
    _vScroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  double _topForMinute(int minute) =>
      (minute - widget.calendarHours.startMinute) * (_kHourHeight / 60);

  void _jumpToPreferredHour() {
    if (_didInitialScroll || !_vScroll.hasClients) return;
    final nowMinute = widget.now.hour * 60 + widget.now.minute;
    final focusMinute = _sameDay(widget.day, widget.now)
        ? nowMinute
        : max(widget.calendarHours.startMinute, 8 * 60);
    final clampedMinute = focusMinute.clamp(
      widget.calendarHours.startMinute,
      widget.calendarHours.lastSlotMinute,
    ).toInt();
    final target =
        max(0.0, _topForMinute(clampedMinute) - (_kHourHeight * 1.5));
    _vScroll.jumpTo(target);
    _didInitialScroll = true;
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar terapeutas activos (los recibidos ya están filtrados por activo,
    // pero por si acaso reforzamos).
    final therapists = widget.therapists.where((t) => t.id.isNotEmpty).toList();
    // ¿Hay bookings sin terapeuta? Mostrar columna "Sin asignar".
    final hasUnassigned = widget.bookings.any(
      (b) => b.therapistId.isEmpty,
    );
    final columnIds = <String>[
      ...therapists.map((t) => t.id),
      if (hasUnassigned) '__unassigned__',
    ];
    final columnLabels = <String>[
      ...therapists.map((t) => t.name),
      if (hasUnassigned) 'Sin asignar',
    ];

    if (columnIds.isEmpty) {
      return Center(
        child: Text(
          'No hay terapeutas activos. Agrégalos en Administración → Personal.',
          style: GoogleFonts.inter(color: Colors.black54, fontSize: 13),
        ),
      );
    }

    final totalMinutes = widget.calendarHours.endMinuteInclusive -
        widget.calendarHours.startMinute +
        30;
    final gridHeight = (totalMinutes / 60) * _kHourHeight;

    return LayoutBuilder(builder: (context, constraints) {
      final available =
          constraints.maxWidth - _kHourLabelWidth;
      final naturalColWidth =
          available / columnIds.length;
      final colWidth = naturalColWidth < _kColMinWidth
          ? _kColMinWidth
          : naturalColWidth;
      final totalWidth = _kHourLabelWidth + colWidth * columnIds.length;

      return Column(
        children: [
          // Header: nombres de terapeutas
          SizedBox(
            height: _kHeaderHeight,
            child: Row(
              children: [
                Container(
                  width: _kHourLabelWidth,
                  height: _kHeaderHeight,
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFE0DDD8)),
                      bottom: BorderSide(color: Color(0xFFE0DDD8)),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _hScroll,
                    child: SizedBox(
                      width: colWidth * columnIds.length,
                      child: Row(
                        children: List.generate(columnIds.length, (i) {
                          final isUnassigned =
                              columnIds[i] == '__unassigned__';
                          return Container(
                            width: colWidth,
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Color(0xFFE0DDD8)),
                                bottom: BorderSide(color: Color(0xFFE0DDD8)),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isUnassigned
                                    ? const Color(0xFFFFE5C2)
                                    : SaharaTheme.gold.withValues(alpha: 0.18),
                                child: Icon(
                                  isUnassigned
                                      ? Icons.help_outline
                                      : Icons.person_outline,
                                  size: 15,
                                  color: isUnassigned
                                      ? const Color(0xFFC68A17)
                                      : SaharaTheme.gold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  columnLabels[i],
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isUnassigned
                                        ? const Color(0xFFC68A17)
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body: scroll vertical compartido + horas a la izq + columnas con cards
          Expanded(
            child: SingleChildScrollView(
              controller: _vScroll,
              scrollDirection: Axis.vertical,
              child: SizedBox(
                height: gridHeight,
                width: totalWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna de horas
                    SizedBox(
                      width: _kHourLabelWidth,
                      child: Column(
                        children: List.generate(
                          (totalMinutes / 30).ceil(),
                          (i) {
                            final m =
                                widget.calendarHours.startMinute + i * 30;
                            return Container(
                              height: _kHourHeight / 2,
                              padding: const EdgeInsets.only(
                                  right: 6, top: 2),
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Color(0xFFE0DDD8)),
                                ),
                              ),
                              alignment: Alignment.topRight,
                              child: Text(
                                _minuteLabel24(m),
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: Colors.black54),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Columnas por terapeuta (con scroll horizontal sincronizado)
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _hScroll,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: colWidth * columnIds.length,
                          height: gridHeight,
                          child: Row(
                            children: List.generate(columnIds.length, (i) {
                              final tId = columnIds[i];
                              final colBookings = widget.bookings.where((b) {
                                if (tId == '__unassigned__') {
                                  return b.therapistId.isEmpty;
                                }
                                return b.therapistId == tId;
                              }).toList();
                              return _TherapistColumn(
                                width: colWidth,
                                gridHeight: gridHeight,
                                calendarHours: widget.calendarHours,
                                bookings: colBookings,
                                onBookingTap: widget.onBookingTap,
                                now: widget.now,
                                day: widget.day,
                                isUnassigned: tId == '__unassigned__',
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _TherapistColumn extends StatelessWidget {
  const _TherapistColumn({
    required this.width,
    required this.gridHeight,
    required this.calendarHours,
    required this.bookings,
    required this.onBookingTap,
    required this.now,
    required this.day,
    required this.isUnassigned,
  });
  final double width;
  final double gridHeight;
  final _AgendaCalendarHours calendarHours;
  final List<_Booking> bookings;
  final void Function(BuildContext, _Booking) onBookingTap;
  final DateTime now;
  final DateTime day;
  final bool isUnassigned;

  double _topForMinute(int minute) =>
      (minute - calendarHours.startMinute) * (_kHourHeight / 60);

  @override
  Widget build(BuildContext context) {
    final isToday = _sameDay(now, day);
    final nowMinute = now.hour * 60 + now.minute;
    final showNowLine = isToday &&
        nowMinute >= calendarHours.startMinute &&
        nowMinute <= calendarHours.endMinuteInclusive;

    return Container(
      width: width,
      height: gridHeight,
      decoration: BoxDecoration(
        color: isUnassigned ? const Color(0xFFFFF8EC) : Colors.white,
        border: const Border(
          right: BorderSide(color: Color(0xFFE0DDD8)),
        ),
      ),
      child: Stack(
        children: [
          // Líneas horizontales cada 30 minutos
          ...List.generate(
            ((calendarHours.endMinuteInclusive +
                        30 -
                        calendarHours.startMinute) /
                    30)
                .ceil(),
            (i) {
              final m = calendarHours.startMinute + i * 30;
              final isHour = m % 60 == 0;
              return Positioned(
                top: _topForMinute(m),
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: Color(isHour ? 0xFFE0DDD8 : 0xFFF1EEE9),
                ),
              );
            },
          ),
          // Citas posicionadas
          ...bookings.map((b) {
            final top = _topForMinute(b.startMinute).clamp(0.0, gridHeight);
            final h = max(
              28.0,
              b.durationMinutes * (_kHourHeight / 60) - 4,
            );
            return Positioned(
              top: top,
              left: 4,
              right: 4,
              height: h,
              child: _BookingCard(
                booking: b,
                onTap: () => onBookingTap(context, b),
              ),
            );
          }),
          // Línea de "ahora"
          if (showNowLine)
            Positioned(
              top: _topForMinute(nowMinute),
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                color: const Color(0xFFFF5252),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Grid painter ──────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.startMinute,
    required this.endMinuteExclusive,
    required this.dayWidth,
    required this.hourHeight,
    required this.today,
    required this.weekStart,
  });

  final int startMinute;
  final int endMinuteExclusive;
  final double dayWidth;
  final double hourHeight;
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
    final totalHours = max(1, ((endMinuteExclusive - startMinute) / 60).ceil());
    for (int h = 0; h <= totalHours; h++) {
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
      old.today != today ||
      old.weekStart != weekStart ||
      old.startMinute != startMinute ||
      old.endMinuteExclusive != endMinuteExclusive;
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
              // Chip de waiver / anticipo, solo si la cita tiene esa data
              if (b.paymentRequirement == 'waived' && b.durationMinutes >= 30) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _paymentLineColor(b).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: _paymentLineColor(b).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _paymentLineLabel(b),
                    style: GoogleFonts.inter(
                      color: _paymentLineColor(b),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
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
String _paymentLineLabel(_Booking b) {
  if (b.paymentRequirement == 'waived') {
    switch (b.waiverReason) {
      case 'gift_card':
        return 'Gift Card · sin anticipo';
      case 'membership':
        return 'Membresía · sin anticipo';
      case 'admin_override':
        return 'Sin anticipo · autorizado';
      default:
        return 'Sin anticipo';
    }
  }
  if (b.paymentRequirement == 'paid') return 'Anticipo pagado';
  return 'Anticipo requerido';
}

Color _paymentLineColor(_Booking b) {
  if (b.paymentRequirement == 'waived') {
    switch (b.waiverReason) {
      case 'gift_card':
        return const Color(0xFFE07B00);
      case 'membership':
        return const Color(0xFF6A54E0);
      default:
        return const Color(0xFF2D8A4F);
    }
  }
  if (b.paymentRequirement == 'paid') return const Color(0xFF1A9E65);
  return const Color(0xFFB32D2D);
}

class _BookingDetailDialog extends StatelessWidget {
  const _BookingDetailDialog({
    required this.booking,
    required this.onRefresh,
    required this.onEdit,
    required this.onUpdateStatus,
    required this.statusLabel,
    required this.onCharge,
    required this.onViewTicket,
    required this.onOpenChat,
  });
  final _Booking booking;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final Future<bool> Function(String) onUpdateStatus;
  final String Function(String) statusLabel;
  final VoidCallback onCharge;
  final VoidCallback onViewTicket;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final hasAssignedTherapist =
        b.therapistId.trim().isNotEmpty &&
        b.therapistName.trim().toLowerCase() != 'sin asignar';
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
              _DetailRow(
                icon: Icons.person,
                text: hasAssignedTherapist ? b.therapistName : 'Sin asignar',
                color: hasAssignedTherapist ? null : const Color(0xFFC68A17),
              ),
              if ((b.clientPhone ?? '').isNotEmpty)
                _DetailRow(icon: Icons.phone_outlined, text: b.clientPhone!),
              if (b.notes.trim().isNotEmpty)
                _DetailRow(icon: Icons.sticky_note_2_outlined, text: b.notes),
              _DetailRow(
                icon: Icons.circle,
                text: statusLabel(b.status),
                color: b.cardAccent,
              ),
              // Bloque de anticipo / waiver
              if (b.paymentRequirement != null) ...[
                const SizedBox(height: 4),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  text: _paymentLineLabel(b),
                  color: _paymentLineColor(b),
                ),
                if (b.depositRequiredCents != null && b.depositRequiredCents! > 0)
                  _DetailRow(
                    icon: Icons.attach_money_rounded,
                    text:
                        'Anticipo: \$${(b.depositRequiredCents! / 100).toStringAsFixed(0)} MXN'
                        '${(b.depositPaidCents ?? 0) > 0 ? ' · pagado \$${((b.depositPaidCents ?? 0) / 100).toStringAsFixed(0)}' : ''}',
                  ),
                if (b.giftCardId != null)
                  _DetailRow(
                    icon: Icons.redeem_outlined,
                    text: 'Gift card: ${b.giftCardId!.substring(0, 8)}…',
                    color: const Color(0xFFE07B00),
                  ),
                if (b.membershipId != null)
                  _DetailRow(
                    icon: Icons.workspace_premium_outlined,
                    text: 'Membresía: ${b.membershipId!.substring(0, 8)}…',
                    color: const Color(0xFF6A54E0),
                  ),
              ],
              const SizedBox(height: 20),
              // Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (b.status == 'scheduled' ||
                      b.status == 'pending' ||
                      b.status == 'pending_reception' ||
                      b.status == 'payment_received')
                    _DialogBtn(
                      label: 'Confirmar',
                      color: const Color(0xFF1A9E65),
                      onTap: () => _updateStatus(context, 'confirmed'),
                    ),
                  if (!const ['completed', 'awaiting_payment', 'paid', 'cancelled']
                      .contains(b.status))
                    _DialogBtn(
                      label: 'Cancelar',
                      color: const Color(0xFFB32D2D),
                      onTap: () => _updateStatus(context, 'cancelled'),
                    ),
                  if (b.status == 'confirmed' || b.status == 'rescheduled')
                    _DialogBtn(
                      label: 'Check-in',
                      color: const Color(0xFF2088D8),
                      onTap: () => _updateStatus(context, 'checked_in'),
                    ),
                  if (b.status == 'confirmed' || b.status == 'rescheduled')
                    _DialogBtn(
                      label: 'Reenviar WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () => _resendWhatsAppConfirmation(context, b),
                    ),
                  if (b.status == 'checked_in')
                    _DialogBtn(
                      label: 'Iniciar servicio',
                      color: const Color(0xFF6A54E0),
                      onTap: () => _updateStatus(context, 'in_progress'),
                    ),
                  if (b.status == 'in_progress')
                    _DialogBtn(
                      label: 'Finalizar servicio',
                      color: const Color(0xFF666666),
                      onTap: () => _updateStatus(context, 'completed'),
                    ),
                  if (b.status == 'awaiting_payment' || b.status == 'completed')
                    _DialogBtn(
                      label: 'Cobrar',
                      color: const Color(0xFF0E8F55),
                      onTap: () {
                        Navigator.pop(context);
                        onCharge();
                      },
                    ),
                  if (b.status == 'awaiting_payment' ||
                      b.status == 'completed' ||
                      b.status == 'paid')
                    _DialogBtn(
                      label: 'Ver ticket',
                      color: const Color(0xFF4A4A4A),
                      onTap: onViewTicket,
                    ),
                  _DialogBtn(
                    label: 'Reagendar',
                    color: SaharaTheme.gold,
                    onTap: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                  ),
                  if (!hasAssignedTherapist)
                    _DialogBtn(
                      label: 'Asignar terapeuta',
                      color: const Color(0xFF6A54E0),
                      onTap: () {
                        Navigator.pop(context);
                        onEdit();
                      },
                    ),
                  _DialogBtn(
                    label: 'Historial',
                    color: const Color(0xFF4A4A4A),
                    onTap: () => _showClientHistory(context, b),
                  ),
                  _DialogBtn(
                    label: 'Abrir chat',
                    color: const Color(0xFF2088D8),
                    onTap: () {
                      Navigator.pop(context);
                      onOpenChat();
                    },
                  ),
                  if (b.status == 'paid')
                    _DialogBtn(
                      label: 'Pagada',
                      color: const Color(0xFF0E8F55),
                      onTap: () {},
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
      case 'checked_in':
        return 'Check-in';
      case 'in_progress':
        return 'En proceso';
      case 'awaiting_payment':
        return 'Pendiente de cobro';
      case 'paid':
        return 'Pagada';
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

  Future<void> _resendWhatsAppConfirmation(BuildContext ctx, _Booking booking) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'whatsapp_resend_booking_confirmation',
        params: {'p_booking_id': booking.id},
      );
      final map = Map<String, dynamic>.from(res as Map);
      final ok = map['ok'] == true;
      final pendingTemplate = map['pending_template'] == true;
      final msg = (map['message'] ?? map['error'] ?? 'Acción ejecutada').toString();
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok
              ? const Color(0xFF1A9E65)
              : pendingTemplate
                  ? const Color(0xFFC68A17)
                  : const Color(0xFFB32D2D),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Error al reenviar WhatsApp: $e'),
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

class _ChargeBookingDialog extends StatefulWidget {
  const _ChargeBookingDialog({
    required this.booking,
    required this.sale,
    required this.salesService,
  });

  final _Booking booking;
  final AgendaSaleRecord sale;
  final AgendaSalesService salesService;

  @override
  State<_ChargeBookingDialog> createState() => _ChargeBookingDialogState();
}

class _ChargeBookingDialogState extends State<_ChargeBookingDialog> {
  final TextEditingController _tipController = TextEditingController(text: '0');
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'efectivo';
  bool _saving = false;

  @override
  void dispose() {
    _tipController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _tip => double.tryParse(_tipController.text.trim()) ?? 0;
  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0;
  double get _total => max(0.0, widget.sale.total - _discount + _tip).toDouble();

  InputDecoration _paymentDeco(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 18),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE7E0D7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE7E0D7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: SaharaTheme.gold, width: 1.2),
      ),
      labelStyle: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cobrar servicio',
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.black87,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black38),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(icon: Icons.person, text: booking.clientName),
              _DetailRow(icon: Icons.spa_outlined, text: booking.serviceName),
              _DetailRow(icon: Icons.badge_outlined, text: booking.therapistName),
              _DetailRow(icon: Icons.timer_outlined, text: '${booking.durationMinutes} min'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SimpleAmountField(
                      label: 'Propina opcional',
                      controller: _tipController,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SimpleAmountField(
                      label: 'Descuento',
                      controller: _discountController,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Metodo de pago',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: _paymentDeco('Metodo de pago', null),
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                  DropdownMenuItem(value: 'stripe', child: Text('Stripe')),
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                  DropdownMenuItem(value: 'gift_card', child: Text('Gift card')),
                  DropdownMenuItem(value: 'membresia', child: Text('Membresia')),
                  DropdownMenuItem(value: 'saldo_cliente', child: Text('Saldo cliente')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _paymentMethod = value);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 3,
                decoration: _paymentDeco('Notas de cobro', Icons.notes_outlined),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F3EC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8DDCA)),
                ),
                child: Column(
                  children: [
                    _SummaryLine(label: 'Servicio', value: '\$${widget.sale.total.toStringAsFixed(2)}'),
                    _SummaryLine(label: 'Propina', value: '\$${_tip.toStringAsFixed(2)}'),
                    _SummaryLine(label: 'Descuento', value: '-\$${_discount.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Total a cobrar',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            color: SaharaTheme.gold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _collectPayment,
                  style: FilledButton.styleFrom(
                    backgroundColor: SaharaTheme.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.point_of_sale_outlined),
                  label: Text(
                    'Registrar cobro',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _collectPayment() async {
    setState(() => _saving = true);
    try {
      await widget.salesService.collectPayment(
        saleId: widget.sale.id,
        paymentMethod: _paymentMethod,
        baseTotal: widget.sale.total,
        bookingId: widget.booking.id,
        tip: _tip,
        discount: _discount,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el cobro: $e')),
      );
      setState(() => _saving = false);
    }
  }
}

class _SimpleAmountField extends StatelessWidget {
  const _SimpleAmountField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.attach_money_outlined, size: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE7E0D7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE7E0D7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: SaharaTheme.gold, width: 1.2),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontSize: 12, color: Colors.black87)),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: color ?? Colors.black38, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: color ?? Colors.black54,
              fontSize: 13,
              height: 1.35,
            ),
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
class _ScheduleBlockDialog extends StatefulWidget {
  const _ScheduleBlockDialog({
    required this.calendarHours,
    required this.selectedDate,
    required this.initialStartMinute,
    required this.onSave,
    this.initialBlock,
    this.onDelete,
  });

  final _AgendaCalendarHours calendarHours;
  final DateTime selectedDate;
  final int initialStartMinute;
  final _ScheduleBlock? initialBlock;
  final Future<bool> Function({
    required DateTime blockDate,
    required int startMinute,
    required int endMinute,
    required String scope,
    required String title,
    required String notes,
  })
  onSave;
  final Future<bool> Function()? onDelete;

  @override
  State<_ScheduleBlockDialog> createState() => _ScheduleBlockDialogState();
}

class _ScheduleBlockDialogState extends State<_ScheduleBlockDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _selectedDate;
  late int _startMinute;
  late int _endMinute;
  late String _scope;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialBlock;
    _selectedDate = initial?.blockDate ?? widget.selectedDate;
    _startMinute = initial?.startMinute ?? widget.initialStartMinute;
    _endMinute = initial?.endMinute ?? (_startMinute + 60).clamp(15, 24 * 60);
    _scope = initial?.scope ?? 'day';
    _titleCtrl = TextEditingController(
      text: initial?.title ?? 'Horario bloqueado',
    );
    _notesCtrl = TextEditingController(text: initial?.notes ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  List<int> get _availableHours => widget.calendarHours.selectableHours;

  List<int> _minutesForHour(int hour) =>
      widget.calendarHours.selectableMinutesForHour(hour);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_endMinute <= _startMinute) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: const Text('La hora final debe ser mayor a la inicial.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onSave(
      blockDate: _selectedDate,
      startMinute: _startMinute,
      endMinute: _endMinute,
      scope: _scope,
      title: _titleCtrl.text,
      notes: _notesCtrl.text,
    );
    if (mounted && !saved) {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving || widget.onDelete == null) return;
    setState(() => _saving = true);
    final deleted = await widget.onDelete!.call();
    if (mounted && !deleted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialBlock == null
        ? 'Bloquear horario'
        : 'Editar bloqueo';

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.block_outlined, color: SaharaTheme.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F1A17),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Ingresa un título'
                      : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _scope,
                        decoration: const InputDecoration(labelText: 'Aplicar a'),
                        items: const [
                          DropdownMenuItem(
                            value: 'day',
                            child: Text('Solo este día'),
                          ),
                          DropdownMenuItem(
                            value: 'week',
                            child: Text('Toda la semana'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _scope = value);
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _startMinute ~/ 60,
                        decoration: const InputDecoration(
                          labelText: 'Hora inicial',
                        ),
                        items: _availableHours
                            .map(
                              (hour) => DropdownMenuItem(
                                value: hour,
                                child: Text(hour.toString().padLeft(2, '0')),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (hour) {
                                if (hour == null) return;
                                final minutes = _minutesForHour(hour);
                                setState(() {
                                  final selectedMinute = _startMinute % 60;
                                  _startMinute = (hour * 60) +
                                      (minutes.contains(selectedMinute)
                                          ? selectedMinute
                                          : minutes.first);
                                  if (_endMinute <= _startMinute) {
                                    _endMinute = min(_startMinute + 60, 24 * 60);
                                  }
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _startMinute % 60,
                        decoration: const InputDecoration(
                          labelText: 'Minuto inicial',
                        ),
                        items: _minutesForHour(_startMinute ~/ 60)
                            .map(
                              (minute) => DropdownMenuItem(
                                value: minute,
                                child: Text(minute.toString().padLeft(2, '0')),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (minute) {
                                if (minute == null) return;
                                setState(() {
                                  _startMinute =
                                      ((_startMinute ~/ 60) * 60) + minute;
                                  if (_endMinute <= _startMinute) {
                                    _endMinute = min(_startMinute + 60, 24 * 60);
                                  }
                                });
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: (_endMinute >= 24 * 60
                                ? 23
                                : _endMinute ~/ 60)
                            .clamp(_availableHours.first, _availableHours.last),
                        decoration: const InputDecoration(labelText: 'Hora final'),
                        items: _availableHours
                            .map(
                              (hour) => DropdownMenuItem(
                                value: hour,
                                child: Text(hour.toString().padLeft(2, '0')),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (hour) {
                                if (hour == null) return;
                                final minutes = _minutesForHour(hour);
                                setState(() {
                                  final selectedMinute = _endMinute % 60;
                                  _endMinute = (hour * 60) +
                                      (minutes.contains(selectedMinute)
                                          ? selectedMinute
                                          : minutes.last);
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _endMinute % 60,
                        decoration: const InputDecoration(
                          labelText: 'Minuto final',
                        ),
                        items: _minutesForHour(
                          (_endMinute >= 24 * 60 ? 23 : _endMinute ~/ 60).clamp(
                            _availableHours.first,
                            _availableHours.last,
                          ),
                        )
                            .map(
                              (minute) => DropdownMenuItem(
                                value: minute,
                                child: Text(minute.toString().padLeft(2, '0')),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (minute) {
                                if (minute == null) return;
                                setState(() {
                                  _endMinute = ((_endMinute ~/ 60) * 60) + minute;
                                });
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    hintText: 'Motivo del bloqueo o indicaciones internas',
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (widget.onDelete != null)
                      TextButton.icon(
                        onPressed: _saving ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          'Eliminar',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        widget.initialBlock == null ? 'Guardar bloqueo' : 'Guardar cambios',
                      ),
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

class _NewBookingDialog extends StatefulWidget {
  const _NewBookingDialog({
    required this.calendarHours,
    required this.therapists,
    required this.branches,
    required this.onSaved,
    this.initialTherapistId,
    this.initialBranchId,
    this.initialDate,
    this.initialTime,
    this.editBooking,
  });
  final _AgendaCalendarHours calendarHours;
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
  final BookingSyncService _bookingSyncService = const BookingSyncService();
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
  // Default 'confirmed': recepción/admin creando cita en persona o por teléfono
  // SIEMPRE agenda ya confirmada (dispara WhatsApp inmediato vía trigger
  // handle_booking_whatsapp_events). El status pending solo aplica a citas
  // que nacen desde landing/app/IA/externo, donde recepción luego valida.
  String _status = 'confirmed';
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

  List<int> get _availableHours => widget.calendarHours.selectableHours;

  List<int> get _availableMinutes =>
      widget.calendarHours.selectableMinutesForHour(_hour);

  static const _statusMeta = {
    'scheduled': ('Reservado', Color(0xFF5B8FF9)),
    'checked_in': ('Check-in', Color(0xFF2088D8)),
    'in_progress': ('En proceso', Color(0xFF6A54E0)),
    'confirmed': ('Confirmado', Color(0xFFFFB347)),
    'attended': ('Asiste', Color(0xFFFF9899)),
    'no_show': ('No asistió', Color(0xFFFFB3B3)),
    'pending': ('Pendiente', Color(0xFFFF4444)),
    'pending_reception': ('Solicitud IA', Color(0xFFFF8C00)),
    'pending_payment': ('Esperando anticipo', Color(0xFFC68A17)),
    'payment_received': ('Pago recibido · pdte confirmar', Color(0xFF52C41A)),
    'waiting': ('En espera', Color(0xFF52C41A)),
    'cancelled': ('Cancelado', Color(0xFFB32D2D)),
    'rescheduled': ('Reagendado', Color(0xFF0A9AA4)),
    'completed': ('Completado', Color(0xFF888888)),
    'awaiting_payment': ('Pendiente de cobro', Color(0xFFC6922B)),
    'paid': ('Pagada', Color(0xFF52C41A)),
  };

  @override
  void initState() {
    super.initState();
    _date = widget.editBooking?.date ?? widget.initialDate ?? DateTime.now();
    _hour = widget.editBooking?.startMinute != null ? (widget.editBooking!.startMinute ~/ 60) : (widget.initialTime?.hour ?? 10);
    _minute = widget.editBooking?.startMinute != null ? (widget.editBooking!.startMinute % 60) : (widget.initialTime?.minute ?? 0);
    final initialTherapistId =
        widget.editBooking?.therapistId ?? widget.initialTherapistId;
    _therapistId =
        (initialTherapistId == null || initialTherapistId.trim().isEmpty)
        ? null
        : initialTherapistId;
    _sucursalId = kEnableMultiBranch
        ? (widget.editBooking?.sucursalId ?? widget.initialBranchId)
        : kDefaultBranchId;
    _serviceId = widget.editBooking?.serviceId;
    _status = widget.editBooking?.status ?? 'confirmed';
    
    if (widget.editBooking != null) {
      _clientCtrl.text = widget.editBooking!.clientName;
      _clientId        = widget.editBooking!.clientRecordId;
      _notesCtrl.text  = widget.editBooking!.notes;
    }
    _normalizeSelectedTime();
    _loadServices();
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _clientFocus.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _normalizeSelectedTime() {
    final hours = _availableHours;
    if (hours.isEmpty) {
      _hour = 0;
      _minute = 0;
      return;
    }
    if (!hours.contains(_hour)) {
      _hour = hours.first;
    }
    final minutes = _availableMinutes;
    if (!minutes.contains(_minute)) {
      _minute = minutes.first;
    }
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
      final profileClientId =
          widget.editBooking?.profileClientId?.trim().isNotEmpty == true
          ? widget.editBooking!.profileClientId!.trim()
          : null;
      String? finalClientId = _clientId?.trim();
      if (finalClientId == null || finalClientId.isEmpty) {
        finalClientId = await _bookingSyncService.findClientRecordIdByName(
          _clientCtrl.text.trim(),
        );
        if ((finalClientId == null || finalClientId.isEmpty) &&
            (profileClientId == null || profileClientId.isEmpty)) {
          throw Exception('Cliente no encontrado. Verifica el nombre.');
        }
      }

      final timeStr =
          '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}:00';
      final draft = BookingUpsertData(
        bookingId: widget.editBooking?.id,
        clientProfileId: profileClientId,
        clientRecordId: finalClientId,
        clientName: _clientCtrl.text.trim(),
        therapistId: _therapistId ?? '',
        serviceId: _serviceId ?? '',
        serviceName: _selectedServiceName,
        bookingDate: _date,
        bookingTime: timeStr,
        durationMinutes: _selectedServiceDuration,
        status: _status,
        notes: _notesCtrl.text.trim(),
        sourcePlatform: kIsWeb ? 'web' : 'mobile',
        branchId: _sucursalId,
      );
      final validation = await _bookingSyncService.validateBookingDraft(draft);
      if (!validation.isValid) {
        throw Exception(validation.errorMessage ?? 'No se pudo validar la reserva.');
      }
      final result = await _bookingSyncService.upsertBooking(draft);
      if (validation.warningMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation.warningMessage!),
            backgroundColor: const Color(0xFFC68A17),
          ),
        );
      }

      // Aviso operativo sobre WhatsApp automático.
      // Las citas creadas desde recepción (esta pantalla) tienen booking_source='reception'
      // y disparan confirmacion_cita al cliente si nacen confirmed.
      // Las citas que vienen de landing/app/IA llegan como pending — recepción debe
      // confirmarlas manualmente para que se envíe el WhatsApp.
      if (mounted && result != null && widget.editBooking == null) {
        final isConfirmed = _status == 'confirmed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isConfirmed
                  ? '✓ Cita agendada. WhatsApp de notificación enviado al cliente.'
                  : 'ℹ Cita guardada como pendiente. Agéndala para notificar al cliente por WhatsApp.',
            ),
            backgroundColor: isConfirmed
                ? const Color(0xFF1A9E65)
                : const Color(0xFF2D6DB3),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return result;
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
      _status = 'confirmed';
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
                                        items: _availableHours,
                                        onChanged: (v) => setState(() {
                                          _hour = v;
                                          final validMinutes =
                                              widget.calendarHours
                                                  .selectableMinutesForHour(v);
                                          if (!validMinutes.contains(_minute)) {
                                            _minute = validMinutes.first;
                                          }
                                        }),
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
                                        items: _availableMinutes,
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
  const _ModuleNav({
    required this.activeModule,
    required this.userRole,
    required this.messagesUnreadCount,
    required this.pendingConfirmCount,
    required this.onModuleTap,
    required this.onLogout,
  });

  final String activeModule;
  final String userRole;
  final int messagesUnreadCount;
  final int pendingConfirmCount;
  final ValueChanged<String> onModuleTap;
  final Future<void> Function() onLogout;

  static const _mods = [
    ('agenda', 'Agenda', Icons.calendar_today_outlined),
    ('clientes', 'Clientes', Icons.people_outline),
    ('ventas', 'Ventas', Icons.point_of_sale_outlined),
    ('mensajes', 'Mensajes', Icons.chat_bubble_outline),
    ('productos', 'Productos', Icons.inventory_2_outlined),
    ('finanzas', 'Finanzas', Icons.account_balance_wallet_outlined),
    ('reportes', 'Reportes', Icons.bar_chart_outlined),
    ('admin', 'Administración', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 960;
    final visibleIds = RolePermissions.visibleModulesFor(userRole);
    final visibleMods =
        _mods.where((module) => visibleIds.contains(module.$1)).toList();
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
                children: visibleMods
                    .map(
                      (m) => _ModuleTab(
                        id: m.$1,
                        label: m.$1 == 'admin' ? 'Administracion' : m.$2,
                        icon: m.$3,
                        badgeCount: m.$1 == 'mensajes'
                            ? messagesUnreadCount
                            : (m.$1 == 'agenda' ? pendingConfirmCount : null),
                        active: activeModule == m.$1,
                        onTap: () => onModuleTap(m.$1),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => onLogout(),
            icon: const Icon(Icons.logout_outlined, size: 18, color: Colors.black87),
            label: Text(
              'Cerrar sesion',
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
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
    this.badgeCount,
    required this.active,
    required this.onTap,
  });

  final String id;
  final String label;
  final IconData icon;
  final int? badgeCount;
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
              if ((widget.badgeCount ?? 0) > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.active
                        ? Colors.white.withValues(alpha: 0.24)
                        : const Color(0xFF1A9E65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${widget.badgeCount}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
    'finanzas': ('Finanzas', Icons.account_balance_wallet_outlined),
    'reportes': ('Reportes', Icons.bar_chart_outlined),
    'sin_acceso': ('Sin acceso', Icons.lock_outline),
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
