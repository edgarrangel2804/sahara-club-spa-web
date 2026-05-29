import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_mode.dart';
import '../auth/role_permissions.dart';
import '../productos/productos_module.dart';
import '../../theme/sahara_theme.dart';
import 'finanzas_module.dart';
import 'reception_permissions_module.dart';
import 'whatsapp_meta_templates_panel.dart';
import 'whatsapp_queue_dashboard.dart';
import 'knowledge_base_panel.dart';
import 'ai_control_panel.dart';
import 'faqs_panel.dart';
import 'business_hours_panel.dart';
import 'services_ai_fields_panel.dart';
import 'staff_ai_profile_panel.dart';
import 'ai_monitor_tab.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Models
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _Staff {
  final String id;
  final String name;
  final String role;
  final bool active;
  final String? photoUrl;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? city;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final List<String> workDays;
  final String? workStartTime;
  final String? workEndTime;
  final String? breakTime;
  final bool showInCalendar;
  final double? fixedSalary;
  final double? commissionPercentage;
  final String? paymentNotes;
  final bool canAccessMobile;
  final bool canAccessWeb;
  final String? accessEmail;
  // Si true, permite agendar este terapeuta aunque sea fuera de su jornada,
  // en comida o día de descanso. Pensado para staff con horarios flexibles
  // cuando no hay recepcionista fija.
  final bool allowOffHoursBooking;

  _Staff({
    required this.id,
    required this.name,
    required this.role,
    this.active = true,
    this.photoUrl,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.city,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.workDays = const [],
    this.workStartTime,
    this.workEndTime,
    this.breakTime,
    this.showInCalendar = false,
    this.fixedSalary,
    this.commissionPercentage,
    this.paymentNotes,
    this.canAccessMobile = false,
    this.canAccessWeb = false,
    this.accessEmail,
    this.allowOffHoursBooking = false,
  });

  factory _Staff.fromMap(Map<String, dynamic> m) {
    List<String> parseDays(dynamic data) {
      if (data == null) return [];
      if (data is List) return data.map((e) => e.toString()).toList();
      return [];
    }

    return _Staff(
      id: m['id'] ?? '',
      name: m['full_name'] ?? m['name'] ?? '',
      role: m['role'] ?? 'other',
      active: m['is_active'] as bool? ?? m['active'] as bool? ?? true,
      photoUrl: m['photo_url'],
      phone: m['phone'],
      whatsapp: m['whatsapp'],
      email: m['email'],
      address: m['address'],
      city: m['city'],
      emergencyContactName: m['emergency_contact_name'],
      emergencyContactPhone: m['emergency_contact_phone'],
      workDays: parseDays(m['work_days']),
      workStartTime: m['work_start_time'],
      workEndTime: m['work_end_time'],
      breakTime: m['break_time'],
      showInCalendar: m['show_in_calendar'] ?? false,
      fixedSalary: (m['fixed_salary'] as num?)?.toDouble(),
      commissionPercentage: (m['commission_percentage'] as num?)?.toDouble(),
      paymentNotes: m['payment_notes'],
      canAccessMobile: m['can_access_mobile'] ?? false,
      canAccessWeb: m['can_access_web'] ?? false,
      accessEmail: m['access_email'] ?? m['email'],
      allowOffHoursBooking: m['allow_off_hours_booking'] ?? false,
    );
  }
}

class _StaffWorkingDay {
  _StaffWorkingDay({
    required this.weekday,
    required this.label,
    this.isWorking = false,
    this.startsAt = '',
    this.endsAt = '',
  });

  final int weekday;
  final String label;
  bool isWorking;
  String startsAt;
  String endsAt;
  String breakStartsAt = '';
  String breakEndsAt = '';

  Map<String, dynamic> toPayload(String staffId) => {
        'staff_id': staffId,
        'weekday': weekday,
        'is_working': isWorking,
        'starts_at': isWorking ? _normalizeTimeValue(startsAt) : null,
        'ends_at': isWorking ? _normalizeTimeValue(endsAt) : null,
        'break_starts_at':
            isWorking && breakStartsAt.trim().isNotEmpty
                ? _normalizeTimeValue(breakStartsAt)
                : null,
        'break_ends_at':
            isWorking && breakEndsAt.trim().isNotEmpty
                ? _normalizeTimeValue(breakEndsAt)
                : null,
      };

  static String? _normalizeTimeValue(String value) {
    final minute = _timeToMinute(value);
    if (minute == null) return null;
    return '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}:00';
  }

  static int? _timeToMinute(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }
}

class _StaffWorkingHoursRow {
  const _StaffWorkingHoursRow({
    required this.staffId,
    required this.weekday,
    required this.isWorking,
    this.startsAt,
    this.endsAt,
    this.breakStartsAt,
    this.breakEndsAt,
  });

  final String staffId;
  final int weekday;
  final bool isWorking;
  final int? startsAt;
  final int? endsAt;
  final int? breakStartsAt;
  final int? breakEndsAt;

  factory _StaffWorkingHoursRow.fromMap(Map<String, dynamic> map) {
    return _StaffWorkingHoursRow(
      staffId: map['staff_id']?.toString() ?? '',
      weekday: (map['weekday'] as num?)?.toInt() ?? 0,
      isWorking: map['is_working'] == true,
      startsAt: _StaffWorkingDay._timeToMinute(map['starts_at']?.toString() ?? ''),
      endsAt: _StaffWorkingDay._timeToMinute(map['ends_at']?.toString() ?? ''),
      breakStartsAt:
          _StaffWorkingDay._timeToMinute(map['break_starts_at']?.toString() ?? ''),
      breakEndsAt:
          _StaffWorkingDay._timeToMinute(map['break_ends_at']?.toString() ?? ''),
    );
  }
}

class _StaffTimeOffRow {
  const _StaffTimeOffRow({
    required this.staffId,
    required this.startsAt,
    required this.endsAt,
  });

  final String staffId;
  final DateTime startsAt;
  final DateTime endsAt;

  factory _StaffTimeOffRow.fromMap(Map<String, dynamic> map) {
    return _StaffTimeOffRow(
      staffId: map['staff_id']?.toString() ?? '',
      startsAt: DateTime.tryParse(map['starts_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: DateTime.tryParse(map['ends_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _StaffScheduleBlockRow {
  const _StaffScheduleBlockRow({
    required this.blockDate,
    required this.startMinute,
    required this.endMinute,
    this.staffId,
  });

  final DateTime blockDate;
  final int startMinute;
  final int endMinute;
  final String? staffId;

  factory _StaffScheduleBlockRow.fromMap(Map<String, dynamic> map) {
    final parsedDate = DateTime.tryParse(map['block_date']?.toString() ?? '') ??
        DateTime.now();
    final start = (map['start_minute'] as num?)?.toInt() ?? 0;
    final end = (map['end_minute'] as num?)?.toInt() ?? start + 60;
    return _StaffScheduleBlockRow(
      blockDate: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      startMinute: start,
      endMinute: end,
      staffId: map['staff_id']?.toString(),
    );
  }
}

enum _StaffAvailabilityStatus {
  available,
  unavailable,
  lunch,
  busy,
}

class _ServiceItem {
  final String id;
  String name;
  String category;
  int duration;
  double price;
  bool active;

  _ServiceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.duration,
    required this.price,
    required this.active,
  });

  factory _ServiceItem.fromMap(Map<String, dynamic> m) => _ServiceItem(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    category: m['category'] as String? ?? '',
    duration: (m['duration'] as num?)?.toInt() ?? 60,
    price: (m['price'] as num?)?.toDouble() ?? 0,
    active: m['active'] as bool? ?? true,
  );
}

class WhatsAppTemplate {
  final String id;
  String? branchId;
  String templateKey;
  String triggerEvent;
  String languageCode;
  String category;
  bool emojiEnabled;
  bool markdownEnabled;
  String title;
  String message;
  String type;
  bool active;

  WhatsAppTemplate({
    required this.id,
    this.branchId,
    required this.templateKey,
    required this.triggerEvent,
    required this.languageCode,
    required this.category,
    required this.emojiEnabled,
    required this.markdownEnabled,
    required this.title,
    required this.message,
    required this.type,
    required this.active,
  });

  static String _normalizeEvent(String? raw) {
    switch (raw) {
      case 'confirmation':
        return 'reservation_confirmed';
      case 'welcome':
        return 'first_visit';
      default:
        return raw ?? 'custom';
    }
  }

  factory WhatsAppTemplate.fromMap(Map<String, dynamic> m) => WhatsAppTemplate(
    id: m['id'] as String,
    branchId: m['branch_id'] as String?,
    templateKey: _normalizeEvent(
      m['template_key'] as String? ?? m['type'] as String? ?? 'custom',
    ),
    triggerEvent: _normalizeEvent(
      m['trigger_event'] as String? ?? m['type'] as String? ?? 'custom',
    ),
    languageCode: m['language_code'] as String? ?? 'es_MX',
    category: m['category'] as String? ?? 'general',
    emojiEnabled: m['emoji_enabled'] as bool? ?? true,
    markdownEnabled: m['markdown_enabled'] as bool? ?? true,
    title: m['template_name'] as String? ?? m['title'] as String? ?? '',
    message: m['message_body'] as String? ?? m['message'] as String? ?? '',
    type: _normalizeEvent(
      m['template_key'] as String? ?? m['type'] as String? ?? 'custom',
    ),
    active: m['is_active'] as bool? ?? m['active'] as bool? ?? true,
  );
}

class _BusinessWhatsAppSettings {
  final String? id;
  final String branchId;
  final String businessName;
  final String metaBusinessId;
  final String whatsappBusinessAccountId;
  final String phoneNumberId;
  final String whatsappPhoneNumber;
  final String accessTokenMasked;
  final String appId;
  final String appSecretMasked;
  final String webhookVerifyToken;
  final String connectionStatus;
  final DateTime? lastValidatedAt;
  final bool hasAccessToken;
  final bool hasAppSecret;
  final String environment;
  final bool isSandbox;
  final String webhookStatus;
  final DateTime? webhookLastEventAt;
  final DateTime? webhookLastVerifiedAt;
  final String webhookLastError;
  final String graphApiVersion;

  const _BusinessWhatsAppSettings({
    required this.id,
    required this.branchId,
    required this.businessName,
    required this.metaBusinessId,
    required this.whatsappBusinessAccountId,
    required this.phoneNumberId,
    required this.whatsappPhoneNumber,
    required this.accessTokenMasked,
    required this.appId,
    required this.appSecretMasked,
    required this.webhookVerifyToken,
    required this.connectionStatus,
    required this.lastValidatedAt,
    required this.hasAccessToken,
    required this.hasAppSecret,
    required this.environment,
    required this.isSandbox,
    required this.webhookStatus,
    required this.webhookLastEventAt,
    required this.webhookLastVerifiedAt,
    required this.webhookLastError,
    required this.graphApiVersion,
  });

  factory _BusinessWhatsAppSettings.empty() => const _BusinessWhatsAppSettings(
    id: null,
    branchId: kDefaultBranchId,
    businessName: '',
    metaBusinessId: '',
    whatsappBusinessAccountId: '',
    phoneNumberId: '',
    whatsappPhoneNumber: '',
    accessTokenMasked: '',
    appId: '',
    appSecretMasked: '',
    webhookVerifyToken: '',
    connectionStatus: 'not_configured',
    lastValidatedAt: null,
    hasAccessToken: false,
    hasAppSecret: false,
    environment: 'sandbox',
    isSandbox: true,
    webhookStatus: 'not_verified',
    webhookLastEventAt: null,
    webhookLastVerifiedAt: null,
    webhookLastError: '',
    graphApiVersion: 'v21.0',
  );

  factory _BusinessWhatsAppSettings.fromMap(Map<String, dynamic> m) =>
      _BusinessWhatsAppSettings(
        id: m['id'] as String?,
        branchId: m['branch_id'] as String? ?? kDefaultBranchId,
        businessName: m['business_name'] as String? ?? '',
        metaBusinessId: m['meta_business_id'] as String? ?? '',
        whatsappBusinessAccountId:
            m['whatsapp_business_account_id'] as String? ?? '',
        phoneNumberId: m['phone_number_id'] as String? ?? '',
        whatsappPhoneNumber: m['whatsapp_phone_number'] as String? ?? '',
        accessTokenMasked: m['access_token_masked'] as String? ?? '',
        appId: m['app_id'] as String? ?? '',
        appSecretMasked: m['app_secret_masked'] as String? ?? '',
        webhookVerifyToken: m['webhook_verify_token'] as String? ?? '',
        connectionStatus: m['connection_status'] as String? ?? 'not_configured',
        lastValidatedAt: m['last_validated_at'] == null
            ? null
            : DateTime.tryParse(m['last_validated_at'] as String),
        hasAccessToken: m['has_access_token'] as bool? ?? false,
        hasAppSecret: m['has_app_secret'] as bool? ?? false,
        environment: m['environment'] as String? ?? 'sandbox',
        isSandbox: m['is_sandbox'] as bool? ?? true,
        webhookStatus: m['webhook_status'] as String? ?? 'not_verified',
        webhookLastEventAt: m['webhook_last_event_at'] == null
            ? null
            : DateTime.tryParse(m['webhook_last_event_at'] as String),
        webhookLastVerifiedAt: m['webhook_last_verified_at'] == null
            ? null
            : DateTime.tryParse(m['webhook_last_verified_at'] as String),
        webhookLastError: m['webhook_last_error'] as String? ?? '',
        graphApiVersion: m['graph_api_version'] as String? ?? 'v21.0',
      );
}

class _Branch {
  final String id;
  String name;
  String address;
  String phone;
  String whatsapp;
  String email;
  String mapsLink;

  _Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.mapsLink,
  });

  factory _Branch.fromMap(Map<String, dynamic> m) => _Branch(
    id: m['id'] as String,
    name: m['nombre'] as String? ?? '',
    address: m['direccion_completa'] as String? ?? '',
    phone: m['telefono_contacto'] as String? ?? '',
    whatsapp: m['whatsapp'] as String? ?? '',
    email: m['email'] as String? ?? '',
    mapsLink: m['link_maps'] as String? ?? '',
  );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Main widget
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class AdminModule extends StatefulWidget {
  const AdminModule({super.key, required this.currentRole});

  final String currentRole;

  @override
  State<AdminModule> createState() => _AdminModuleState();
}

class _AdminModuleState extends State<AdminModule>
    with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 9, vsync: this);
  bool _loading = true;
  List<_Staff> _staff = [];
  List<Map<String, dynamic>> _todayBookings = [];
  List<_StaffWorkingHoursRow> _staffWorkingHours = [];
  List<_StaffTimeOffRow> _staffTimeOff = [];
  List<_StaffScheduleBlockRow> _scheduleBlocks = [];
  List<_ServiceItem> _services = [];
  List<WhatsAppTemplate> _templates = [];
  List<_Branch> _branches = [];
  bool _canAccessAdministration = false;
  String _role = 'reception';

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowStart = todayStart.add(const Duration(days: 1));
      final todayKey = todayStart.toIso8601String().split('T').first;
      _role = RolePermissions.normalize(widget.currentRole);
      if (userId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .maybeSingle();
        _role = RolePermissions.normalize(profile?['role'] as String? ?? _role);
      }

      _canAccessAdministration = RolePermissions.isAdminLevel(_role);
      if (!_canAccessAdministration) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final tomorrowKey = tomorrowStart.toIso8601String().split('T').first;
      final sb = Supabase.instance.client;

      final results = await Future.wait<dynamic>([
        sb.from('staff').select(),
        sb.from('services').select(),
        sb.from('whatsapp_templates').select(),
        sb
            .from('bookings')
            .select('''
              id,
              therapist_id,
              booking_date,
              booking_time,
              duration_min,
              status,
              service:services(name, price)
            ''')
            .gte('booking_date', todayKey)
            .lt('booking_date', tomorrowKey)
            .order('booking_time', ascending: true),
        sb
            .from('staff_working_hours')
            .select(
              'staff_id, weekday, is_working, starts_at, ends_at, break_starts_at, break_ends_at',
            ),
        sb
            .from('staff_time_off')
            .select('staff_id, starts_at, ends_at')
            .lt('starts_at', tomorrowStart.toUtc().toIso8601String())
            .gt('ends_at', todayStart.toUtc().toIso8601String()),
        sb
            .from('schedule_blocks')
            .select('staff_id, block_date, start_minute, end_minute')
            .eq('block_date', todayKey),
        sb.from('sucursales').select(),
      ]);

      final resS = results[0];
      final resV = results[1];
      final resW = results[2];
      final resTodayBookings = results[3];
      final resStaffWorkingHours = results[4];
      final resStaffTimeOff = results[5];
      final resScheduleBlocks = results[6];
      final resB = results[6 + 1];

      _branches = (resB as List).map((m) => _Branch.fromMap(m)).toList();
      if (!kEnableMultiBranch && _branches.isEmpty) {
        _branches = [_Branch.fromMap(defaultBranchMap())];
      }

      if (!mounted) return;
      setState(() {
        _staff = (resS as List).map((m) => _Staff.fromMap(m)).toList();
        _todayBookings = List<Map<String, dynamic>>.from(
          resTodayBookings as List,
        );
        _staffWorkingHours = (resStaffWorkingHours as List)
            .cast<Map<String, dynamic>>()
            .map(_StaffWorkingHoursRow.fromMap)
            .toList();
        _staffTimeOff = (resStaffTimeOff as List)
            .cast<Map<String, dynamic>>()
            .map(_StaffTimeOffRow.fromMap)
            .toList();
        _scheduleBlocks = (resScheduleBlocks as List)
            .cast<Map<String, dynamic>>()
            .map(_StaffScheduleBlockRow.fromMap)
            .toList();
        _services = (resV as List).map((m) => _ServiceItem.fromMap(m)).toList();
        _templates = (resW as List)
            .map((m) => WhatsAppTemplate.fromMap(m))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStaffActive(_Staff s) async {
    try {
      await Supabase.instance.client
          .from('staff')
          .update({'active': !s.active})
          .eq('id', s.id);
      _load();
    } catch (_) {}
  }

  Future<void> _toggleServiceActive(_ServiceItem s) async {
    try {
      await Supabase.instance.client
          .from('services')
          .update({'active': !s.active})
          .eq('id', s.id);
      _load();
    } catch (_) {}
  }

  Future<void> _toggleTemplateActive(WhatsAppTemplate s) async {
    try {
      await Supabase.instance.client
          .from('whatsapp_templates')
          .update({'active': !s.active})
          .eq('id', s.id);
      _load();
    } catch (_) {}
  }

  void _openStaffForm([_Staff? edit]) {
    showDialog(
      context: context,
      builder: (_) =>
          _StaffFormDialog(staff: edit, onSaved: _load, currentUserRole: _role),
    );
  }

  void _openServiceForm([_ServiceItem? edit]) {
    showDialog(
      context: context,
      builder: (_) => _ServiceFormDialog(service: edit, onSaved: _load),
    );
  }

  void _openWhatsAppForm([WhatsAppTemplate? edit]) {
    if (edit == null) {
      showDialog(
        context: context,
        builder: (_) => _WhatsAppSelectionDialog(
          onSelected: (template) {
            Navigator.pop(context);
            _showWhatsAppEditDialog(template);
          },
        ),
      );
    } else {
      _showWhatsAppEditDialog(edit);
    }
  }

  void _showWhatsAppEditDialog(WhatsAppTemplate template) {
    showDialog(
      context: context,
      builder: (_) => _WhatsAppFormDialog(template: template, onSaved: _load),
    );
  }

  Future<void> _deleteStaff(_Staff s) async {
    final ok = await _confirmDelete(
      context,
      'Eliminar miembro',
      'Seguro que deseas eliminar a ${s.name}?',
    );
    if (ok == true) {
      await Supabase.instance.client.from('staff').delete().eq('id', s.id);
      _load();
    }
  }

  Future<void> _deleteService(_ServiceItem s) async {
    final ok = await _confirmDelete(
      context,
      'Eliminar servicio',
      'Seguro que deseas eliminar el servicio ${s.name}?',
    );
    if (ok == true) {
      await Supabase.instance.client.from('services').delete().eq('id', s.id);
      _load();
    }
  }

  Future<void> _deleteTemplate(WhatsAppTemplate s) async {
    final ok = await _confirmDelete(
      context,
      'Eliminar plantilla',
      'Seguro que deseas eliminar esta plantilla?',
    );
    if (ok == true) {
      await Supabase.instance.client
          .from('whatsapp_templates')
          .delete()
          .eq('id', s.id);
      _load();
    }
  }

  String get _activeAdminTitle {
    switch (_tab.index) {
      case 0:
        return 'Equipo Sahara';
      case 1:
        return 'Servicios';
      case 2:
        return 'Plantillas WhatsApp';
      case 3:
        return 'Productos';
      case 4:
        return 'Finanzas';
      case 5:
        return 'Permisos Recepcion';
      case 6:
        return 'Configuraciones IA';
      default:
        return 'Configuracion';
    }
  }

  String get _activeAdminSubtitle {
    switch (_tab.index) {
      case 0:
        return 'Gestion interna del personal, permisos y operaciones.';
      case 1:
        return 'Catalogo, duraciones, precios y disponibilidad de servicios.';
      case 2:
        return 'Mensajes automatizados y seguimiento operativo por WhatsApp.';
      case 3:
        return 'Control de inventario, productos y activacion comercial.';
      case 4:
        return 'Metricas, flujo operativo y seguimiento financiero del negocio.';
      case 5:
        return 'Reglas de acceso y acciones permitidas para recepcion.';
      case 6:
        return 'Centro de control del agente IA: plantillas, FAQs, horarios, base de conocimiento y cola WhatsApp.';
      default:
        return 'Ajustes de negocio, sucursales e integraciones internas.';
    }
  }

  bool get _canCreateInCurrentTab => _tab.index <= 2;

  String get _currentActionLabel {
    switch (_tab.index) {
      case 0:
        return 'Nuevo miembro';
      case 1:
        return 'Nuevo servicio';
      case 2:
        return 'Nueva plantilla';
      default:
        return '';
    }
  }

  VoidCallback? get _currentPrimaryAction {
    switch (_tab.index) {
      case 0:
        return _openStaffForm;
      case 1:
        return _openServiceForm;
      case 2:
        return _openWhatsAppForm;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EF),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFAF6),
              border: Border(
                bottom: BorderSide(
                  color: SaharaTheme.gold.withValues(alpha: 0.14),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B2118).withValues(alpha: 0.03),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _tab,
                  builder: (context, child) {
                    if (_tab.index != 0) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 188),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/hero.jpg'),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2B2118).withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.96),
                              const Color(0xFFF4E6CB).withValues(alpha: 0.88),
                            ],
                          ),
                          border: Border.all(
                            color: SaharaTheme.gold.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sahara Club Spa',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: SaharaTheme.gold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _activeAdminTitle,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 31,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 470),
                                    child: Text(
                                      _activeAdminSubtitle,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        height: 1.55,
                                        color: const Color(0xFF6D655B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            if (_canCreateInCurrentTab &&
                                _currentPrimaryAction != null)
                              FilledButton.icon(
                                onPressed: _currentPrimaryAction,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFC6A76A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 18,
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(
                                  _currentActionLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _tab,
                  builder: (context, child) =>
                      _tab.index == 0 ? const SizedBox(height: 16) : const SizedBox.shrink(),
                ),
                AnimatedBuilder(
                  animation: _tab,
                  builder: (context, child) {
                    if (_tab.index == 0) return const SizedBox.shrink();
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sahara Club Spa',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.8,
                                      color: SaharaTheme.gold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _activeAdminTitle,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _activeAdminSubtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: const Color(0xFF6D655B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            if (_canCreateInCurrentTab &&
                                _currentPrimaryAction != null)
                              FilledButton.icon(
                                onPressed: _currentPrimaryAction,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFC6A76A),
                                  foregroundColor: const Color(0xFF1F170F),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(
                                  _currentActionLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                    );
                  },
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: SaharaTheme.gold.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2B2118).withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tab,
                    isScrollable: false,
                    padding: EdgeInsets.zero,
                    labelPadding: EdgeInsets.zero,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(16),
                    labelColor: const Color(0xFF8C6623),
                    unselectedLabelColor: const Color(0xFF7D7366),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFFFFFCF7),
                      border: Border.all(
                        color: SaharaTheme.gold.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2B2118).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(
                        child: _AdminTabLabel(
                          icon: Icons.groups_outlined,
                          label: 'Personal',
                        ),
                      ),
                      Tab(
                        child: _AdminTabLabel(
                          icon: Icons.grid_view_rounded,
                          label: 'Servicios',
                        ),
                      ),
                      Tab(
                        child: _AdminTabLabel(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'WhatsApp',
                        ),
                      ),
                      Tab(
                        child: _AdminTabLabel(
                          icon: Icons.inventory_2_outlined,
                          label: 'Productos',
                        ),
                      ),
                      Tab(
                        child: _AdminTabLabel(
                          icon: Icons.attach_money_rounded,
                          label: 'Finanzas',
                        ),
                      ),
                      Tab(
                        child: _AdminTabLabel(
                          icon: Icons.verified_user_outlined,
                          label: 'Permisos',
                        ),
                      ),
                      Tab(
                        child: _AdminTabLabel(
                          icon: Icons.monitor_heart_outlined,
                          label: 'Monitor IA',
                        ),
                      ),
                      Tab(
                        child: _AdminTabLabel(
                          icon: Icons.smart_toy_outlined,
                          label: 'Configuraciones IA',
                        ),
                      ),
                      Tab(
                        child: _AdminTabLabel(
                          icon: Icons.settings_outlined,
                          label: 'Configuracion',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : !_canAccessAdministration
                ? const Center(
                    child: Text('Acceso restringido a administradores'),
                  )
                : TabBarView(
                    controller: _tab,
                    children: [
                      _StaffTab(
                        staff: _staff,
                        todayBookings: _todayBookings,
                        staffWorkingHours: _staffWorkingHours,
                        staffTimeOff: _staffTimeOff,
                        scheduleBlocks: _scheduleBlocks,
                        onToggle: _toggleStaffActive,
                        onEdit: _openStaffForm,
                        onDelete: _deleteStaff,
                        onAdd: _openStaffForm,
                        onRefresh: _load,
                      ),
                      _ServicesTab(
                        services: _services,
                        onToggle: _toggleServiceActive,
                        onEdit: _openServiceForm,
                        onDelete: _deleteService,
                      ),
                      _WhatsAppTab(
                        templates: _templates,
                        onToggle: _toggleTemplateActive,
                        onEdit: _openWhatsAppForm,
                        onDelete: _deleteTemplate,
                      ),
                      const ProductosModule(),
                      const FinanzasModule(),
                      const ReceptionPermissionsModule(),
                      const AiMonitorTab(),
                      const _AiSettingsTab(),
                      _SettingsTab(branches: _branches, onRefresh: _load),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Tabs
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _StaffTab extends StatefulWidget {
  const _StaffTab({
    required this.staff,
    required this.todayBookings,
    required this.staffWorkingHours,
    required this.staffTimeOff,
    required this.scheduleBlocks,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
    required this.onRefresh,
  });
  final List<_Staff> staff;
  final List<Map<String, dynamic>> todayBookings;
  final List<_StaffWorkingHoursRow> staffWorkingHours;
  final List<_StaffTimeOffRow> staffTimeOff;
  final List<_StaffScheduleBlockRow> scheduleBlocks;
  final void Function(_Staff) onToggle;
  final void Function(_Staff) onEdit;
  final void Function(_Staff) onDelete;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _roleFilter = 'Todos';
  String _statusFilter = 'Todos';
  bool _cardView = true;
  Timer? _availabilityTimer;

  @override
  void initState() {
    super.initState();
    _availabilityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _availabilityTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openScheduleDialog(_Staff staffMember) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _StaffScheduleDialog(
        staff: staffMember,
        onSaved: () async {
          await widget.onRefresh();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _openPermissionsDialog(_Staff staffMember) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _StaffPermissionsDialog(
        staff: staffMember,
        onSaved: () async {
          await widget.onRefresh();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  List<_StaffSnapshot> get _snapshots {
    final items = widget.staff.map(_buildSnapshot).toList();
    items.sort((a, b) {
      if (a.staff.active != b.staff.active) {
        return a.staff.active ? -1 : 1;
      }
      if (a.statusPriority != b.statusPriority) {
        return a.statusPriority.compareTo(b.statusPriority);
      }
      return a.staff.name.toLowerCase().compareTo(b.staff.name.toLowerCase());
    });
    return items;
  }

  List<_StaffSnapshot> get _filteredSnapshots {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _snapshots.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.staff.name.toLowerCase().contains(query) ||
          _roleLabel(item.staff.role).toLowerCase().contains(query) ||
          (item.staff.email ?? '').toLowerCase().contains(query) ||
          (item.staff.phone ?? '').toLowerCase().contains(query);
      final matchesRole =
          _roleFilter == 'Todos' || _roleLabel(item.staff.role) == _roleFilter;
      final matchesStatus =
          _statusFilter == 'Todos' || item.statusLabel == _statusFilter;
      return matchesQuery && matchesRole && matchesStatus;
    }).toList();
  }

  _StaffSnapshot _buildSnapshot(_Staff staffMember) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final bookings = widget.todayBookings
        .where((row) => row['therapist_id']?.toString().trim() == staffMember.id)
        .toList()
      ..sort((a, b) => _bookingDateTime(a).compareTo(_bookingDateTime(b)));
    final validBookings = bookings.where((row) => !_isCancelled(row)).toList();
    final todayBookings = validBookings
        .where((row) {
          final bookingDate = _bookingDateTime(row);
          return !bookingDate.isBefore(todayStart) &&
              bookingDate.isBefore(tomorrowStart);
        })
        .toList();
    final currentBooking = validBookings.cast<Map<String, dynamic>?>().firstWhere(
      (row) {
        if (row == null) return false;
        if (!_isBusyStatus(row['status']?.toString())) return false;
        final start = _bookingDateTime(row);
        final duration = (row['duration_min'] as num?)?.toInt() ?? 60;
        final end = start.add(Duration(minutes: duration));
        return !now.isBefore(start) && now.isBefore(end);
      },
      orElse: () => null,
    );
    final upcomingBooking = validBookings.cast<Map<String, dynamic>?>().firstWhere(
      (row) => row != null && !_bookingDateTime(row).isBefore(now),
      orElse: () => null,
    );
    final totalMinutes = todayBookings.fold<int>(
      0,
      (sum, row) => sum + ((row['duration_min'] as num?)?.toInt() ?? 60),
    );
    final commissionRate = (staffMember.commissionPercentage ?? 0) / 100;
    final estimatedCommission = todayBookings.fold<double>(0, (sum, row) {
      final service = row['service'];
      final price = service is Map ? (service['price'] as num?)?.toDouble() : 0.0;
      return sum + ((price ?? 0) * commissionRate);
    });

    String statusLabel;
    Color statusColor;
    int statusPriority;
    switch (_getStaffAvailabilityStatus(staffMember, now, currentBooking)) {
      case _StaffAvailabilityStatus.busy:
        statusLabel = 'Ocupada';
        statusColor = const Color(0xFFB24A43);
        statusPriority = 0;
        break;
      case _StaffAvailabilityStatus.lunch:
        statusLabel = 'En descanso';
        statusColor = const Color(0xFFD99032);
        statusPriority = 1;
        break;
      case _StaffAvailabilityStatus.available:
        statusLabel = 'Disponible';
        statusColor = const Color(0xFF2F8F5B);
        statusPriority = 2;
        break;
      case _StaffAvailabilityStatus.unavailable:
        statusLabel = 'No disponible';
        statusColor = const Color(0xFF8C8780);
        statusPriority = 3;
        break;
    }

    return _StaffSnapshot(
      staff: staffMember,
      statusLabel: statusLabel,
      statusColor: statusColor,
      statusPriority: statusPriority,
      nextBookingTime: upcomingBooking != null
          ? _formatTime(_bookingDateTime(upcomingBooking))
          : currentBooking != null
          ? _formatTime(_bookingDateTime(currentBooking))
          : '—',
      nextBookingService: _serviceName(upcomingBooking ?? currentBooking) ??
          (todayBookings.isEmpty ? 'Sin citas programadas' : 'Agenda completada'),
      servicesToday: todayBookings.length,
      scheduledHours: _formatMinutes(totalMinutes),
      shiftLabel: _shiftLabel(staffMember, now),
      estimatedCommission: estimatedCommission,
      contactLabel: staffMember.email?.trim().isNotEmpty == true
          ? staffMember.email!.trim()
          : (staffMember.phone?.trim().isNotEmpty == true
                ? staffMember.phone!.trim()
                : 'Sin contacto registrado'),
    );
  }

  _StaffAvailabilityStatus _getStaffAvailabilityStatus(
    _Staff staffMember,
    DateTime now,
    Map<String, dynamic>? currentBooking,
  ) {
    if (!staffMember.active) return _StaffAvailabilityStatus.unavailable;

    final workingHours = _workingHoursFor(staffMember.id, now);
    final worksToday = _worksToday(staffMember, workingHours, now);
    if (!worksToday) return _StaffAvailabilityStatus.unavailable;

    if (currentBooking != null) return _StaffAvailabilityStatus.busy;

    final nowMinute = now.hour * 60 + now.minute;
    if (_hasActiveTimeOff(staffMember.id, now) ||
        _hasActiveScheduleBlock(staffMember.id, now)) {
      return _StaffAvailabilityStatus.unavailable;
    }

    final breakStartsAt = workingHours?.breakStartsAt;
    final breakEndsAt = workingHours?.breakEndsAt;
    if (breakStartsAt != null &&
        breakEndsAt != null &&
        nowMinute >= breakStartsAt &&
        nowMinute < breakEndsAt) {
      return _StaffAvailabilityStatus.lunch;
    }

    final startsAt = workingHours?.startsAt ??
        _StaffWorkingDay._timeToMinute(staffMember.workStartTime ?? '');
    final endsAt = workingHours?.endsAt ??
        _StaffWorkingDay._timeToMinute(staffMember.workEndTime ?? '');
    if (startsAt == null ||
        endsAt == null ||
        nowMinute < startsAt ||
        nowMinute >= endsAt) {
      return _StaffAvailabilityStatus.unavailable;
    }

    return _StaffAvailabilityStatus.available;
  }

  _StaffWorkingHoursRow? _workingHoursFor(String staffId, DateTime date) {
    final weekday = date.weekday % 7;
    for (final row in widget.staffWorkingHours) {
      if (row.staffId == staffId && row.weekday == weekday) return row;
    }
    return null;
  }

  bool _worksToday(
    _Staff staffMember,
    _StaffWorkingHoursRow? workingHours,
    DateTime date,
  ) {
    if (workingHours != null) return workingHours.isWorking;
    if (staffMember.workDays.isEmpty) return false;
    final weekdayNames = {
      1: ['lunes', 'mon', 'monday'],
      2: ['martes', 'tue', 'tuesday'],
      3: ['miercoles', 'miércoles', 'wed', 'wednesday'],
      4: ['jueves', 'thu', 'thursday'],
      5: ['viernes', 'fri', 'friday'],
      6: ['sabado', 'sábado', 'sat', 'saturday'],
      7: ['domingo', 'sun', 'sunday'],
    };
    final allowed = weekdayNames[date.weekday] ?? const <String>[];
    return staffMember.workDays.any((day) {
      final normalized = day.trim().toLowerCase();
      return allowed.contains(normalized);
    });
  }

  bool _hasActiveTimeOff(String staffId, DateTime now) {
    return widget.staffTimeOff.any((row) {
      return row.staffId == staffId &&
          !now.isBefore(row.startsAt) &&
          now.isBefore(row.endsAt);
    });
  }

  bool _hasActiveScheduleBlock(String staffId, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final nowMinute = now.hour * 60 + now.minute;
    return widget.scheduleBlocks.any((block) {
      final blockStaffId = block.staffId?.trim() ?? '';
      return (blockStaffId.isEmpty || blockStaffId == staffId) &&
          block.blockDate == today &&
          nowMinute >= block.startMinute &&
          nowMinute < block.endMinute;
    });
  }

  bool _isBusyStatus(String? raw) {
    final status = raw?.trim().toLowerCase() ?? '';
    return const {
      'confirmed',
      'checked_in',
      'in_progress',
      'arrived',
      'arrival',
      'llegada',
    }.contains(status);
  }

  DateTime _bookingDateTime(Map<String, dynamic> row) {
    final date = DateTime.tryParse(row['booking_date']?.toString() ?? '');
    final timeParts = (row['booking_time']?.toString() ?? '00:00:00').split(':');
    final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
    final base = date ?? DateTime.now();
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  bool _isCancelled(Map<String, dynamic> row) {
    final status = (row['status']?.toString().toLowerCase() ?? '').trim();
    return status == 'cancelled' || status == 'canceled' || status == 'no_show';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '${remainder}m';
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }

  String _shiftLabel(_Staff staffMember, DateTime now) {
    final workingHours = _workingHoursFor(staffMember.id, now);
    if (workingHours != null && !workingHours.isWorking) {
      return 'Descanso hoy';
    }
    final start = workingHours?.startsAt != null
        ? _minuteToTime(workingHours!.startsAt!)
        : staffMember.workStartTime;
    final end = workingHours?.endsAt != null
        ? _minuteToTime(workingHours!.endsAt!)
        : staffMember.workEndTime;
    if ((start ?? '').isEmpty || (end ?? '').isEmpty) return 'Horario pendiente';
    return '${_normalizeHour(start!)} - ${_normalizeHour(end!)}';
  }

  String _minuteToTime(int minute) {
    return '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}:00';
  }

  String _normalizeHour(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1].padLeft(2, '0');
    final normalizedHour = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '$normalizedHour:$minute $suffix';
  }

  String? _serviceName(Map<String, dynamic>? row) {
    if (row == null) return null;
    final service = row['service'];
    if (service is Map) return service['name']?.toString();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final snapshots = _filteredSnapshots;
    final activeCount = _snapshots.where((item) => item.staff.active).length;
    final receptionCount = _snapshots
        .where(
          (item) =>
              item.staff.active &&
              item.staff.role.toLowerCase().contains('reception'),
        )
        .length;
    final busyTherapists = _snapshots
        .where(
          (item) =>
              item.staff.active &&
              item.staff.role.toLowerCase().contains('therap') &&
              item.statusLabel == 'Ocupada',
        )
        .length;
    final payrollBase = _snapshots.fold<double>(
      0,
      (sum, item) => sum + (item.staff.fixedSalary ?? 0),
    );
    final servicesToday = _snapshots.fold<int>(
      0,
      (sum, item) => sum + item.servicesToday,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PersonnelResponsiveCardGrid(
            children: [
              _PersonnelStatCard(
                icon: Icons.groups_outlined,
                title: 'Personal activo',
                value: '$activeCount',
                subtitle: '${widget.staff.length} registrados',
              ),
              _PersonnelStatCard(
                icon: Icons.headset_mic_outlined,
                title: 'Recepcion conectada',
                value: '$receptionCount',
                subtitle: 'Con acceso y turno activo',
              ),
              _PersonnelStatCard(
                icon: Icons.spa_outlined,
                title: 'Terapeutas ocupadas',
                value: '$busyTherapists',
                subtitle: 'Atendiendo ahora',
              ),
              _PersonnelStatCard(
                icon: Icons.payments_outlined,
                title: 'Nomina base registrada',
                value: _currency(payrollBase),
                subtitle: 'Sueldos fijos capturados',
              ),
              _PersonnelStatCard(
                icon: Icons.trending_up_rounded,
                title: 'Servicios programados hoy',
                value: '$servicesToday',
                subtitle: 'Citas activas del dia',
              ),
            ],
          ),
          const SizedBox(height: 22),
          _PersonnelFiltersBar(
            searchController: _searchCtrl,
            roleFilter: _roleFilter,
            statusFilter: _statusFilter,
            cardView: _cardView,
            onSearchChanged: (_) => setState(() {}),
            onRoleChanged: (value) => setState(() => _roleFilter = value),
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onCardViewChanged: (value) => setState(() => _cardView = value),
          ),
          const SizedBox(height: 16),
          if (snapshots.isEmpty)
            _PersonnelEmptyState(onAdd: widget.onAdd)
          else if (_cardView)
            Column(
              children: snapshots
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PersonnelStaffCard(
                        snapshot: item,
                        onToggle: () => widget.onToggle(item.staff),
                        onEdit: () => widget.onEdit(item.staff),
                        onSchedule: () => _openScheduleDialog(item.staff),
                        onPermissions: () => _openPermissionsDialog(item.staff),
                        onDelete: () => widget.onDelete(item.staff),
                      ),
                    ),
                  )
                  .toList(),
            )
          else
            _PersonnelTable(
              snapshots: snapshots,
              onToggle: widget.onToggle,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
            ),
        ],
      ),
    );
  }
}

String? _extractMissingStaffColumnCompat(Object error) {
  final message = error.toString();
  final match = RegExp(
    "Could not find the '([^']+)' column of 'staff'",
  ).firstMatch(message);
  return match?.group(1);
}

Map<String, dynamic> _normalizeStaffPayloadCompat(Map<String, dynamic> payload) {
  final cleaned = <String, dynamic>{};
  payload.forEach((key, value) {
    if (value == null) return;
    if (value is String && value.trim().isEmpty) return;
    cleaned[key] = value;
  });
  return cleaned;
}

Future<void> _updateStaffWithCompatiblePayloadCompat(
  String staffId,
  Map<String, dynamic> payload,
) async {
  final mutable = Map<String, dynamic>.from(
    _normalizeStaffPayloadCompat(payload),
  );
  while (true) {
    try {
      await Supabase.instance.client.from('staff').update(mutable).eq('id', staffId);
      return;
    } catch (error) {
      final missingColumn = _extractMissingStaffColumnCompat(error);
      if (missingColumn == null || !mutable.containsKey(missingColumn)) rethrow;
      mutable.remove(missingColumn);
      debugPrint(
        'Staff quick update retry without unsupported column: $missingColumn',
      );
    }
  }
}

class _StaffSnapshot {
  const _StaffSnapshot({
    required this.staff,
    required this.statusLabel,
    required this.statusColor,
    required this.statusPriority,
    required this.nextBookingTime,
    required this.nextBookingService,
    required this.servicesToday,
    required this.scheduledHours,
    required this.shiftLabel,
    required this.estimatedCommission,
    required this.contactLabel,
  });

  final _Staff staff;
  final String statusLabel;
  final Color statusColor;
  final int statusPriority;
  final String nextBookingTime;
  final String nextBookingService;
  final int servicesToday;
  final String scheduledHours;
  final String shiftLabel;
  final double estimatedCommission;
  final String contactLabel;
}

class _PersonnelStatCard extends StatelessWidget {
  const _PersonnelStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 138,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E6D8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B2118).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F1E6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: SaharaTheme.gold, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF7A746C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F1A17),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF2F9E62),
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
    );
  }
}

class _PersonnelResponsiveCardGrid extends StatelessWidget {
  const _PersonnelResponsiveCardGrid({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minItemWidth = 266.0;
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

class _AdminTabLabel extends StatelessWidget {
  const _AdminTabLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _PersonnelFiltersBar extends StatelessWidget {
  const _PersonnelFiltersBar({
    required this.searchController,
    required this.roleFilter,
    required this.statusFilter,
    required this.cardView,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onCardViewChanged,
  });

  final TextEditingController searchController;
  final String roleFilter;
  final String statusFilter;
  final bool cardView;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onCardViewChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E6D8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B2118).withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Buscar empleado...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: const Color(0xFFFFFCF8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE9DDD0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE9DDD0)),
                ),
              ),
            ),
          ),
          _PersonnelDropdown(
            width: 180,
            value: roleFilter,
            items: const ['Todos', 'Terapeuta', 'Recepcion', 'Administrador'],
            onChanged: onRoleChanged,
          ),
          _PersonnelDropdown(
            width: 180,
            value: statusFilter,
            items: const [
              'Todos',
              'Disponible',
              'En descanso',
              'Ocupada',
              'No disponible',
            ],
            onChanged: onStatusChanged,
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F1E6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8DAC3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeToggleButton(
                  label: 'Vista tarjetas',
                  icon: Icons.grid_view_rounded,
                  active: cardView,
                  onTap: () => onCardViewChanged(true),
                ),
                _ModeToggleButton(
                  label: 'Vista tabla',
                  icon: Icons.table_rows_rounded,
                  active: !cardView,
                  onTap: () => onCardViewChanged(false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonnelDropdown extends StatelessWidget {
  const _PersonnelDropdown({
    required this.width,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
        style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFFFFCF8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE9DDD0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE9DDD0)),
          ),
        ),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  const _ModeToggleButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? SaharaTheme.gold : const Color(0xFF7A746C),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? const Color(0xFF805D22) : const Color(0xFF7A746C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonnelEmptyState extends StatelessWidget {
  const _PersonnelEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E6D8)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F1E6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.groups_rounded,
              size: 34,
              color: SaharaTheme.gold,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No encontramos personal con esos filtros',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F1A17),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajusta la busqueda o agrega un nuevo miembro para comenzar.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF6D655B),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: SaharaTheme.gold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'Nuevo miembro',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonnelStaffCard extends StatelessWidget {
  const _PersonnelStaffCard({
    required this.snapshot,
    required this.onToggle,
    required this.onEdit,
    required this.onSchedule,
    required this.onPermissions,
    required this.onDelete,
  });

  final _StaffSnapshot snapshot;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onSchedule;
  final VoidCallback onPermissions;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final staffMember = snapshot.staff;
    final badges = <String>[
      if (staffMember.showInCalendar) 'Visible en agenda',
      if (staffMember.canAccessWeb) 'Web',
      if (staffMember.canAccessMobile) 'Movil',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1220;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF0E6D8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2B2118).withValues(alpha: 0.045),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PersonnelCardHeader(snapshot: snapshot),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _PersonnelInfoTile(
                          icon: Icons.calendar_today_outlined,
                          title: 'Proxima cita',
                          value: snapshot.nextBookingTime,
                          subtitle: snapshot.nextBookingService,
                        ),
                        _PersonnelInfoTile(
                          icon: Icons.spa_outlined,
                          title: 'Servicios hoy',
                          value: '${snapshot.servicesToday}',
                          subtitle: 'Programados',
                        ),
                        _PersonnelInfoTile(
                          icon: Icons.payments_outlined,
                          title: 'Comision estimada',
                          value: _currency(snapshot.estimatedCommission),
                          subtitle: '${staffMember.commissionPercentage ?? 0}% aplicado',
                        ),
                        _PersonnelInfoTile(
                          icon: Icons.schedule_outlined,
                          title: 'Jornada',
                          value: snapshot.scheduledHours,
                          subtitle: snapshot.shiftLabel,
                        ),
                      ],
                    ),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: badges
                            .map((badge) => _PersonnelBadge(label: badge))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PersonnelActionButton(
                          icon: Icons.edit_outlined,
                          label: 'Editar',
                          onTap: onEdit,
                        ),
                        _PersonnelActionButton(
                          icon: Icons.badge_outlined,
                          label: 'Permisos',
                          onTap: onPermissions,
                        ),
                        _PersonnelActionButton(
                          icon: Icons.calendar_today_outlined,
                          label: 'Horario',
                          onTap: onSchedule,
                        ),
                        _PersonnelSwitchChip(
                          active: staffMember.active,
                          onTap: onToggle,
                        ),
                        _PersonnelActionButton(
                          icon: Icons.delete_outline,
                          label: 'Eliminar',
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _PersonnelCardHeader(snapshot: snapshot),
                    ),
                    _PersonnelVerticalMetric(
                      icon: Icons.calendar_today_outlined,
                      title: 'Proxima cita',
                      value: snapshot.nextBookingTime,
                      subtitle: snapshot.nextBookingService,
                    ),
                    _PersonnelVerticalMetric(
                      icon: Icons.spa_outlined,
                      title: 'Servicios hoy',
                      value: '${snapshot.servicesToday}',
                      subtitle: 'Programados',
                    ),
                    _PersonnelVerticalMetric(
                      icon: Icons.payments_outlined,
                      title: 'Comision estimada',
                      value: _currency(snapshot.estimatedCommission),
                      subtitle: '${staffMember.commissionPercentage ?? 0}% aplicado',
                    ),
                    _PersonnelVerticalMetric(
                      icon: Icons.schedule_outlined,
                      title: 'Jornada',
                      value: snapshot.scheduledHours,
                      subtitle: snapshot.shiftLabel,
                    ),
                    const Spacer(),
                    if (badges.isNotEmpty)
                      SizedBox(
                        width: 150,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: badges
                              .map((badge) => _PersonnelBadge(label: badge))
                              .toList(),
                        ),
                      ),
                    const SizedBox(width: 12),
                    _PersonnelActionButton(
                      icon: Icons.edit_outlined,
                      label: 'Editar',
                      onTap: onEdit,
                    ),
                    _PersonnelActionButton(
                      icon: Icons.badge_outlined,
                      label: 'Permisos',
                      onTap: onPermissions,
                    ),
                    _PersonnelActionButton(
                      icon: Icons.calendar_today_outlined,
                      label: 'Horario',
                      onTap: onSchedule,
                    ),
                    const SizedBox(width: 12),
                    _PersonnelSwitchChip(
                      active: staffMember.active,
                      onTap: onToggle,
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _PersonnelCardHeader extends StatelessWidget {
  const _PersonnelCardHeader({required this.snapshot});

  final _StaffSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final staffMember = snapshot.staff;
    final photoUrl = staffMember.photoUrl;
    final displayLetter = staffMember.name.isEmpty ? '?' : staffMember.name[0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: SaharaTheme.gold.withValues(alpha: 0.18),
              foregroundImage: (photoUrl ?? '').isNotEmpty
                  ? NetworkImage(photoUrl!)
                  : null,
              child: (photoUrl ?? '').isEmpty
                  ? Text(
                      displayLetter,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF805D22),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: snapshot.statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                staffMember.name,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F1A17),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _roleLabel(staffMember.role),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6D655B),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: snapshot.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  snapshot.statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: snapshot.statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                snapshot.contactLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF7A746C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonnelVerticalMetric extends StatelessWidget {
  const _PersonnelVerticalMetric({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFFF0E6D8)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: SaharaTheme.gold),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6D655B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F1A17),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF8B847A),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonnelInfoTile extends StatelessWidget {
  const _PersonnelInfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E6D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: SaharaTheme.gold),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6D655B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F1A17),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF8B847A),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonnelBadge extends StatelessWidget {
  const _PersonnelBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: const Color(0xFF805D22),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PersonnelActionButton extends StatelessWidget {
  const _PersonnelActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 82,
        height: 66,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0E6D8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF805D22)),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF6D655B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonnelSwitchChip extends StatelessWidget {
  const _PersonnelSwitchChip({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: active
              ? SaharaTheme.gold.withValues(alpha: 0.24)
              : const Color(0xFFE5DED2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Align(
          alignment: active ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffScheduleDialog extends StatefulWidget {
  const _StaffScheduleDialog({
    required this.staff,
    required this.onSaved,
  });

  final _Staff staff;
  final Future<void> Function() onSaved;

  @override
  State<_StaffScheduleDialog> createState() => _StaffScheduleDialogState();
}

class _StaffScheduleDialogState extends State<_StaffScheduleDialog> {
  static const _dayOptions = <MapEntry<String, String>>[
    MapEntry('monday', 'Lun'),
    MapEntry('tuesday', 'Mar'),
    MapEntry('wednesday', 'Mie'),
    MapEntry('thursday', 'Jue'),
    MapEntry('friday', 'Vie'),
    MapEntry('saturday', 'Sab'),
    MapEntry('sunday', 'Dom'),
  ];

  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  late final TextEditingController _breakCtrl;
  late bool _showInCalendar;
  late Set<String> _workDays;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(text: widget.staff.workStartTime ?? '');
    _endCtrl = TextEditingController(text: widget.staff.workEndTime ?? '');
    _breakCtrl = TextEditingController(text: widget.staff.breakTime ?? '');
    _showInCalendar = widget.staff.showInCalendar;
    _workDays = widget.staff.workDays.map((day) => day.toLowerCase()).toSet();
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    _breakCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_showInCalendar && _workDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un dia de trabajo.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _updateStaffWithCompatiblePayloadCompat(widget.staff.id, {
        'work_days': _workDays.toList(),
        'work_start_time': _startCtrl.text.trim(),
        'work_end_time': _endCtrl.text.trim(),
        'break_time': _breakCtrl.text.trim(),
        'show_in_calendar': _showInCalendar,
      });
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horario actualizado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar horario: $e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Color(0xFF805D22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Horario de ${widget.staff.name}',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F1A17),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Configura la jornada, descanso y visibilidad en agenda.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6D655B),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dayOptions.map((entry) {
                  final selected = _workDays.contains(entry.key);
                  return FilterChip(
                    selected: selected,
                    onSelected: _saving
                        ? null
                        : (value) {
                            setState(() {
                              if (value) {
                                _workDays.add(entry.key);
                              } else {
                                _workDays.remove(entry.key);
                              }
                            });
                          },
                    label: Text(entry.value),
                    selectedColor: const Color(0xFFEEDAAE),
                    checkmarkColor: const Color(0xFF805D22),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFF805D22)
                          : const Color(0xFF6D655B),
                    ),
                    side: const BorderSide(color: Color(0xFFE9DDD0)),
                    backgroundColor: const Color(0xFFFFFCF8),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _QuickTextField(
                      controller: _startCtrl,
                      label: 'Entrada',
                      hint: '09:00',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickTextField(
                      controller: _endCtrl,
                      label: 'Salida',
                      hint: '18:00',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _QuickTextField(
                controller: _breakCtrl,
                label: 'Descanso',
                hint: '14:00 - 15:00',
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _showInCalendar,
                onChanged: _saving ? null : (value) => setState(() => _showInCalendar = value),
                activeColor: SaharaTheme.gold,
                title: Text(
                  'Mostrar en agenda',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Permite que aparezca como profesional disponible.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF7A746C),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC6A76A),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? 'Guardando...' : 'Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffPermissionsDialog extends StatefulWidget {
  const _StaffPermissionsDialog({
    required this.staff,
    required this.onSaved,
  });

  final _Staff staff;
  final Future<void> Function() onSaved;

  @override
  State<_StaffPermissionsDialog> createState() => _StaffPermissionsDialogState();
}

class _StaffPermissionsDialogState extends State<_StaffPermissionsDialog> {
  late bool _active;
  late bool _canAccessWeb;
  late bool _canAccessMobile;
  late bool _allowOffHours;
  late final TextEditingController _emailCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _active = widget.staff.active;
    _canAccessWeb = widget.staff.canAccessWeb;
    _canAccessMobile = widget.staff.canAccessMobile;
    _allowOffHours = widget.staff.allowOffHoursBooking;
    _emailCtrl = TextEditingController(
      text: widget.staff.accessEmail ?? widget.staff.email ?? '',
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final accessEnabled = _canAccessWeb || _canAccessMobile;
    if (accessEnabled && _emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura un correo para el acceso.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _updateStaffWithCompatiblePayloadCompat(widget.staff.id, {
        'active': _active,
        'can_access_web': _canAccessWeb,
        'can_access_mobile': _canAccessMobile,
        'allow_off_hours_booking': _allowOffHours,
        'email': _emailCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos actualizados.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar permisos: $e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 500,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: Color(0xFF805D22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Permisos de ${widget.staff.name}',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F1A17),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Define acceso y estado operativo del miembro del equipo.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6D655B),
                ),
              ),
              const SizedBox(height: 18),
              _QuickTextField(
                controller: _emailCtrl,
                label: 'Correo de acceso',
                hint: 'correo@empresa.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _active,
                onChanged: _saving ? null : (value) => setState(() => _active = value),
                activeColor: SaharaTheme.gold,
                title: Text(
                  'Empleado activo',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _canAccessWeb,
                onChanged: _saving ? null : (value) => setState(() => _canAccessWeb = value),
                activeColor: SaharaTheme.gold,
                title: Text(
                  'Permitir acceso web',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _canAccessMobile,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _canAccessMobile = value),
                activeColor: SaharaTheme.gold,
                title: Text(
                  'Permitir acceso movil',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _allowOffHours,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _allowOffHours = value),
                activeColor: SaharaTheme.gold,
                title: Text(
                  'Permitir agendar fuera de horario',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Habilita agendar citas aunque esté en comida, fuera de jornada o sea su día de descanso.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF6D655B),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC6A76A),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? 'Guardando...' : 'Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTextField extends StatelessWidget {
  const _QuickTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6D655B),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFFFFCF8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE9DDD0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE9DDD0)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonnelTable extends StatelessWidget {
  const _PersonnelTable({
    required this.snapshots,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_StaffSnapshot> snapshots;
  final void Function(_Staff) onToggle;
  final void Function(_Staff) onEdit;
  final void Function(_Staff) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E6D8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B2118).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 28,
          headingTextStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6D655B),
          ),
          dataTextStyle: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF1F1A17),
          ),
          columns: const [
            DataColumn(label: Text('Personal')),
            DataColumn(label: Text('Rol')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Proxima cita')),
            DataColumn(label: Text('Servicios hoy')),
            DataColumn(label: Text('Comision estimada')),
            DataColumn(label: Text('Jornada')),
            DataColumn(label: Text('Activo')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: snapshots.map((item) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: SaharaTheme.gold.withValues(alpha: 0.16),
                        child: Text(
                          item.staff.name.isEmpty ? '?' : item.staff.name[0],
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF805D22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.staff.name,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            item.contactLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF8B847A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                DataCell(Text(_roleLabel(item.staff.role))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: item.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: item.statusColor,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nextBookingTime),
                      Text(
                        item.nextBookingService,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF8B847A),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(Text('${item.servicesToday}')),
                DataCell(Text(_currency(item.estimatedCommission))),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.scheduledHours),
                      Text(
                        item.shiftLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF8B847A),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Switch(
                    value: item.staff.active,
                    activeThumbColor: const Color(0xFFC6A76A),
                    onChanged: (_) => onToggle(item.staff),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => onEdit(item.staff),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      IconButton(
                        onPressed: () => onDelete(item.staff),
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

String _roleLabel(String role) {
  switch (role.toLowerCase()) {
    case 'therapist':
      return 'Terapeuta';
    case 'reception':
      return 'Recepcion';
    case 'admin':
      return 'Administrador';
    default:
      return role.isEmpty ? 'Sin rol' : role;
  }
}

String _currency(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final decimal = parts[1];
  final buffer = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    final position = whole.length - i;
    buffer.write(whole[i]);
    if (position > 1 && position % 3 == 1) {
      buffer.write(',');
    }
  }
  return '\$${buffer.toString()}.$decimal';
}

class _ServicesTab extends StatelessWidget {
  const _ServicesTab({
    required this.services,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final List<_ServiceItem> services;
  final void Function(_ServiceItem) onToggle;
  final void Function(_ServiceItem) onEdit;
  final void Function(_ServiceItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: services.length,
      itemBuilder: (_, i) {
        final s = services[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              s.name,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${s.category} · ${s.duration} min · \$${s.price}',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: s.active,
                  activeThumbColor: const Color(0xFFC6A76A),
                  onChanged: (_) => onToggle(s),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => onEdit(s),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => onDelete(s),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WhatsAppTab extends StatefulWidget {
  const _WhatsAppTab({
    required this.templates,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final List<WhatsAppTemplate> templates;
  final void Function(WhatsAppTemplate) onToggle;
  final void Function(WhatsAppTemplate?) onEdit;
  final void Function(WhatsAppTemplate) onDelete;

  @override
  State<_WhatsAppTab> createState() => _WhatsAppTabState();
}

class _WhatsAppTabState extends State<_WhatsAppTab> {
  int _subTab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF91CAFF)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.star_outline,
                color: Color(0xFF1677FF),
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF003A8C),
                    ),
                    children: [
                      TextSpan(
                        text:
                            'Ahora podras enviar mensajes personalizados por WhatsApp! ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(
                        text:
                            'Configuralos y envialos de manera personalizada desde la Agenda.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              _SubTabBtn(
                label: 'Plantillas',
                active: _subTab == 0,
                onTap: () => setState(() => _subTab = 0),
              ),
              const SizedBox(width: 12),
              _SubTabBtn(
                label: 'Recordatorios Pendientes',
                active: _subTab == 1,
                onTap: () => setState(() => _subTab = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _subTab == 0
                  ? _TemplatesList(
                      templates: widget.templates,
                      onToggle: widget.onToggle,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                      onNew: widget.onEdit,
                    )
                  : _RemindersList(templates: widget.templates),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SubTabBtn extends StatelessWidget {
  const _SubTabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFC6A76A).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFFC6A76A) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? const Color(0xFFC6A76A) : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _TemplatesList extends StatelessWidget {
  const _TemplatesList({
    required this.templates,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onNew,
  });
  final List<WhatsAppTemplate> templates;
  final void Function(WhatsAppTemplate) onToggle;
  final void Function(WhatsAppTemplate?) onEdit;
  final void Function(WhatsAppTemplate) onDelete;
  final void Function(WhatsAppTemplate?) onNew;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return _WhatsAppLanding(onNew: () => onNew(null));
    return Column(
      children: [
        Container(
          color: const Color(0xFFFAFAFA),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              _Th('TITULO', flex: 2),
              _Th('MENSAJE', flex: 5),
              _Th('ESTADO', flex: 1),
              const SizedBox(width: 80),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = templates[i];
              return ListTile(
                title: Text(
                  t.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  t.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: t.active,
                      activeThumbColor: const Color(0xFFC6A76A),
                      onChanged: (_) => onToggle(t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => onEdit(t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => onDelete(t),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WhatsAppLanding extends StatelessWidget {
  const _WhatsAppLanding({required this.onNew});
  final VoidCallback onNew;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Potencia tus mensajes de WhatsApp con nuestras plantillas predisenadas!',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Crea mensajes personalizados de manera rapida y efectiva con nuestras plantillas listas para usar.',
                  style: GoogleFonts.inter(fontSize: 15, color: Colors.black54),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: onNew,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC6A76A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Probar plantillas'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          const Expanded(flex: 4, child: _WhatsAppIllustration()),
        ],
      ),
    );
  }
}

class _WhatsAppIllustration extends StatelessWidget {
  const _WhatsAppIllustration();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dots background
          Positioned(
            right: 0,
            top: 40,
            child: Opacity(
              opacity: 0.1,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(
                  24,
                  (i) => Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main Bubble
          Positioned(
            right: 20,
            child: Container(
              width: 240,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6A76A).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 180,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 140,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 12,
                            color: Color(0xFF25D366),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Enviado',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF25D366),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating small bubble
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFC6A76A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC6A76A).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemindersList extends StatefulWidget {
  const _RemindersList({required this.templates});
  final List<WhatsAppTemplate> templates;
  @override
  State<_RemindersList> createState() => _RemindersListState();
}

class _RemindersListState extends State<_RemindersList> {
  List<Map<String, dynamic>> _reminders = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final res = await Supabase.instance.client
          .from('bookings')
          .select(
            '*, client_record:client_record_id(full_name, phone), services:service_id(name)',
          )
          .eq('status', 'confirmed');
      final logs = await Supabase.instance.client
          .from('whatsapp_logs')
          .select('booking_id, type');
      final logSet = (logs as List)
          .map((l) => '${l['booking_id']}_${l['type']}')
          .toSet();
      final filtered = <Map<String, dynamic>>[];
      for (var b in (res as List)) {
        if (b['client_record'] == null || b['services'] == null) continue;
        final bDate = DateTime.parse(b['booking_date']);
        if (bDate.day == tomorrow.day &&
            !logSet.contains('${b['id']}_reminder_24h'))
          filtered.add({...b, 'rem_type': 'reminder_24h'});
        if (bDate.day == now.day && !logSet.contains('${b['id']}_reminder_2h'))
          filtered.add({...b, 'rem_type': 'reminder_2h'});
      }
      setState(() {
        _reminders = filtered;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _send(Map<String, dynamic> b, String type) async {
    final t = widget.templates.firstWhere(
      (e) => e.type == type,
      orElse: () => widget.templates.first,
    );
    final phone = b['client_record']['phone'];
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(t.message)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      await Supabase.instance.client.from('whatsapp_logs').insert({
        'booking_id': b['id'],
        'type': type,
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView.separated(
      itemCount: _reminders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final b = _reminders[i];
        return ListTile(
          title: Text(
            b['client_record']['full_name'],
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(b['services']['name']),
          trailing: ElevatedButton(
            onPressed: () => _send(b, b['rem_type']),
            child: const Text('Enviar'),
          ),
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Dialogs
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _WhatsAppSelectionDialog extends StatefulWidget {
  const _WhatsAppSelectionDialog({required this.onSelected});
  final void Function(WhatsAppTemplate) onSelected;
  @override
  State<_WhatsAppSelectionDialog> createState() =>
      _WhatsAppSelectionDialogState();
}

class _WhatsAppSelectionDialogState extends State<_WhatsAppSelectionDialog> {
  int _selectedIdx = 0;
  final List<Map<String, String>> _presets = [
    {
      'title': 'Confirmacion de cita',
      'message':
          '[[emoji_confirmacion]] Hola [[nombre_cliente]], tu cita de [[nombre_servicio]] quedo confirmada para el [[fecha_reserva]] a las [[hora_reserva]] con [[nombre_terapeuta]]. Te esperamos en [[nombre_local]].',
      'type': 'reservation_confirmed',
    },
    {
      'title': 'Post servicio',
      'message':
          '[[emoji_confirmacion]] Gracias por visitarnos, [[nombre_cliente]]. Si disfrutaste tu experiencia en [[nombre_local]], compartenos en Instagram: [[instagram]]',
      'type': 'post_service',
    },
    {
      'title': 'Cumpleanos',
      'message':
          'Feliz cumpleanos, [[nombre_cliente]]. Queremos consentirte con una experiencia especial en [[nombre_local]].',
      'type': 'birthday_customer',
    },
    {
      'title': 'Bienvenida',
      'message':
          '[[emoji_confirmacion]] Bienvenida a [[nombre_local]], [[nombre_cliente]]. Estamos emocionados de acompanarte en tu camino de bienestar.',
      'type': 'first_visit',
    },
    {
      'title': 'Pago pendiente',
      'message':
          '[[emoji_pago]] Hola [[nombre_cliente]], tu reserva [[codigo_reserva]] tiene un pago pendiente. Puedes completarlo aqui: [[link_pago]]',
      'type': 'payment_pending',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 1000,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Plantillas predisenadas',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Elige entre plantillas predisenadas para utilizarlas como base para tu mensaje ideal.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _presets.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final active = _selectedIdx == i;
                                return InkWell(
                                  onTap: () => setState(() => _selectedIdx = i),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: active
                                            ? const Color(0xFFC6A76A)
                                            : const Color(0xFFE0E0E0),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _presets[i]['title']!,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: active
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: active
                                              ? const Color(0xFFC6A76A)
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      color: const Color(0xFFF9F9F9),
                      child: Center(
                        child: _PhoneMockup(
                          child: _MsgBubble(
                            text: _presets[_selectedIdx]['message']!,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(color: Colors.black54),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => widget.onSelected(
                      WhatsAppTemplate(
                        id: '',
                        branchId: kDefaultBranchId,
                        templateKey: _presets[_selectedIdx]['type']!,
                        triggerEvent: _presets[_selectedIdx]['type']!,
                        languageCode: 'es_MX',
                        category: 'general',
                        emojiEnabled: true,
                        markdownEnabled: true,
                        title: _presets[_selectedIdx]['title']!,
                        message: _presets[_selectedIdx]['message']!,
                        type: _presets[_selectedIdx]['type']!,
                        active: true,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC6A76A),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Seleccionar y editar',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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

class _WhatsAppFormDialog extends StatefulWidget {
  const _WhatsAppFormDialog({required this.template, required this.onSaved});
  final WhatsAppTemplate template;
  final VoidCallback onSaved;
  @override
  State<_WhatsAppFormDialog> createState() => _WhatsAppFormDialogState();
}

class _WhatsAppFormDialogState extends State<_WhatsAppFormDialog> {
  late final _title = TextEditingController(text: widget.template.title);
  late final _msg = TextEditingController(text: widget.template.message);
  late String _type = widget.template.type;
  bool _saving = false;

  static const Map<String, String> _previewVars = {
    'nombre_cliente': 'Sofia',
    'apellido_cliente': 'Martinez',
    'telefono': '+52 664 123 4567',
    'nombre_servicio': 'Facial Premium',
    'duracion': '60',
    'fecha_reserva': '12/05/2026',
    'hora_reserva': '16:30',
    'nombre_terapeuta': 'Pamela',
    'nombre_local': 'Sahara Club Spa',
    'direccion_local': 'Zona Rio, Tijuana',
    'telefono_local': '+52 664 555 0000',
    'instagram': 'https://instagram.com/saharaclubspa',
    'facebook': 'https://facebook.com/saharaclubspa',
    'pagina_web': 'https://saharaclubspa.com',
    'link_pago': 'https://pay.saharaclubspa.com/abc123',
    'codigo_reserva': 'AB12CD34',
    'emoji_confirmacion': '✨',
    'emoji_recordatorio': '⏰',
    'emoji_pago': '💳',
  };

  String get _previewMessage {
    var preview = _msg.text;
    _previewVars.forEach((key, value) {
      preview = preview.replaceAll('[[$key]]', value);
    });
    return preview;
  }

  void _addTag(String tag) {
    final text = _msg.text;
    final pos = _msg.selection.baseOffset;
    _msg.text = pos < 0
        ? '$text$tag'
        : text.substring(0, pos) + tag + text.substring(pos);
    _msg.selection = TextSelection.fromPosition(
      TextPosition(offset: (pos < 0 ? text.length : pos) + tag.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 1100,
        height: 800,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Editando ${widget.template.title}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('Nombre del mensaje *'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _title,
                            style: const TextStyle(color: Colors.black87),
                            decoration: _deco('Ej: Confirmacion'),
                          ),
                          const SizedBox(height: 32),
                          _Label('Personaliza el mensaje *'),
                          const SizedBox(height: 16),
                          _TagSection(
                            title: 'Datos de reserva',
                            tags: [
                              '[[nombre_cliente]]',
                              '[[apellido_cliente]]',
                              '[[telefono]]',
                              '[[nombre_servicio]]',
                              '[[duracion]]',
                              '[[fecha_reserva]]',
                              '[[hora_reserva]]',
                              '[[nombre_terapeuta]]',
                              '[[codigo_reserva]]',
                            ],
                            onTag: _addTag,
                          ),
                          const SizedBox(height: 16),
                          _TagSection(
                            title: 'Datos del local',
                            tags: [
                              '[[nombre_local]]',
                              '[[direccion_local]]',
                              '[[telefono_local]]',
                              '[[instagram]]',
                              '[[facebook]]',
                              '[[pagina_web]]',
                              '[[link_pago]]',
                            ],
                            onTag: _addTag,
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _msg,
                            maxLines: 10,
                            style: const TextStyle(color: Colors.black87),
                            onChanged: (_) => setState(() {}),
                            decoration: _deco('Escribe tu mensaje...'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_msg.text.characters.length} caracteres',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              _Label('Tipo: '),
                              const SizedBox(width: 12),
                              _AutomationEventDropdown(
                                value: _type,
                                onChanged: (v) => setState(() => _type = v!),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          const Text(
                            'Previsualizacion del mensaje',
                            style: TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(height: 24),
                          _PhoneMockup(
                            child: _MsgBubble(text: _previewMessage),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () async {
                      setState(() => _saving = true);
                      try {
                        final data = {
                          'branch_id':
                              widget.template.branchId ?? kDefaultBranchId,
                          'template_key': _type,
                          'template_name': _title.text,
                          'message_body': _msg.text,
                          'is_active': true,
                          'trigger_event': _type,
                          'language_code': widget.template.languageCode,
                          'category': widget.template.category,
                          'emoji_enabled': widget.template.emojiEnabled,
                          'markdown_enabled': widget.template.markdownEnabled,
                          'title': _title.text,
                          'message': _msg.text,
                          'type': _type,
                          'active': true,
                        };
                        if (widget.template.id.isEmpty)
                          await Supabase.instance.client
                              .from('whatsapp_templates')
                              .insert(data);
                        else
                          await Supabase.instance.client
                              .from('whatsapp_templates')
                              .update(data)
                              .eq('id', widget.template.id);
                        widget.onSaved();
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Plantilla guardada'),
                              backgroundColor: Color(0xFFC6A76A),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC6A76A),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      'Guardar',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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

class _TagSection extends StatelessWidget {
  const _TagSection({
    required this.title,
    required this.tags,
    required this.onTag,
  });
  final String title;
  final List<String> tags;
  final ValueChanged<String> onTag;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tags
              .map(
                (t) => InkWell(
                  onTap: () => onTag(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBDBDBD)),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MsgBubble extends StatelessWidget {
  const _MsgBubble({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10).copyWith(topLeft: Radius.zero),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black),
      ),
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 450,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 8),
      ),
      child: Column(
        children: [
          Container(
            height: 40,
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFE5DDD5),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [child],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DropdownType extends StatelessWidget {
  const _DropdownType({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      items: const [
        DropdownMenuItem(
          value: 'confirmation',
          child: Text('Confirmacion', style: TextStyle(color: Colors.black87)),
        ),
        DropdownMenuItem(
          value: 'reminder_24h',
          child: Text(
            'Recordatorio 24h',
            style: TextStyle(color: Colors.black87),
          ),
        ),
        DropdownMenuItem(
          value: 'reminder_2h',
          child: Text(
            'Recordatorio 2h',
            style: TextStyle(color: Colors.black87),
          ),
        ),
        DropdownMenuItem(
          value: 'welcome',
          child: Text('Bienvenida', style: TextStyle(color: Colors.black87)),
        ),
        DropdownMenuItem(
          value: 'custom',
          child: Text('Personalizado', style: TextStyle(color: Colors.black87)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _AutomationEventDropdown extends StatelessWidget {
  const _AutomationEventDropdown({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('reservation_confirmed', 'Confirmacion'),
      ('reminder_24h', 'Recordatorio 24h'),
      ('reminder_3h', 'Recordatorio 3h'),
      ('reminder_1h', 'Recordatorio 1h'),
      ('reservation_rescheduled', 'Reagendado'),
      ('reservation_cancelled', 'Cancelacion'),
      ('payment_pending', 'Pago pendiente'),
      ('payment_confirmed', 'Pago confirmado'),
      ('birthday_customer', 'Cumpleanos'),
      ('first_visit', 'Bienvenida'),
      ('membership_created', 'Membresia'),
      ('giftcard_created', 'Gift card'),
      ('post_service', 'Post-servicio'),
      ('promotion', 'Promocion'),
      ('custom', 'Personalizado'),
    ];

    final normalized = options.any((opt) => opt.$1 == value) ? value : 'custom';

    return DropdownButton<String>(
      value: normalized,
      items: options
          .map(
            (opt) => DropdownMenuItem(
              value: opt.$1,
              child: Text(
                opt.$2,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  );
}

class _StaffFormDialog extends StatefulWidget {
  const _StaffFormDialog({
    required this.staff,
    required this.onSaved,
    required this.currentUserRole,
  });
  final _Staff? staff;
  final VoidCallback onSaved;
  final String currentUserRole;
  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _emergNameCtrl = TextEditingController();
  final _emergPhoneCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl = TextEditingController();
  final _breakTimeCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  final _payNotesCtrl = TextEditingController();
  final _accessEmailCtrl = TextEditingController();
  final _accessPassCtrl = TextEditingController();

  String _role = 'other';
  bool _active = true;
  List<String> _workDays = [];
  bool _showInCalendar = false;
  bool _canLogin = false;
  late Map<int, _StaffWorkingDay> _workingHours;

  // Servicios (para terapeutas)
  List<Map<String, dynamic>> _allServices = [];
  Set<String> _selectedServiceIds = {};

  bool get _isAdmin =>
      widget.currentUserRole == 'admin' ||
      widget.currentUserRole == 'super_admin';

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _workingHours = _defaultWorkingHours(s);
    if (s != null) {
      _nameCtrl.text = s.name;
      _phoneCtrl.text = s.phone ?? '';
      _whatsappCtrl.text = s.whatsapp ?? '';
      _emailCtrl.text = s.email ?? '';
      _addressCtrl.text = s.address ?? '';
      _cityCtrl.text = s.city ?? '';
      _emergNameCtrl.text = s.emergencyContactName ?? '';
      _emergPhoneCtrl.text = s.emergencyContactPhone ?? '';
      _startTimeCtrl.text = s.workStartTime ?? '';
      _endTimeCtrl.text = s.workEndTime ?? '';
      _breakTimeCtrl.text = s.breakTime ?? '';
      _salaryCtrl.text = s.fixedSalary?.toString() ?? '';
      _commissionCtrl.text = s.commissionPercentage?.toString() ?? '';
      _payNotesCtrl.text = s.paymentNotes ?? '';
      _accessEmailCtrl.text = s.accessEmail ?? '';

      _role = s.role;
      _active = s.active;
      _workDays = List.from(s.workDays);
      _showInCalendar = s.showInCalendar;
      _canLogin = s.canAccessWeb || s.canAccessMobile;
    }
    _loadServices();
    _loadWorkingHours();
  }

  Map<int, _StaffWorkingDay> _defaultWorkingHours(_Staff? staff) {
    const labels = {
      0: 'Domingo',
      1: 'Lunes',
      2: 'Martes',
      3: 'Miercoles',
      4: 'Jueves',
      5: 'Viernes',
      6: 'Sabado',
    };
    final days = (staff?.workDays ?? const <String>[])
        .map((d) => d.toLowerCase().trim())
        .toSet();
    bool works(int weekday) {
      if (days.isEmpty) return weekday >= 1 && weekday <= 6;
      const names = {
        0: ['domingo', 'sunday'],
        1: ['lunes', 'monday'],
        2: ['martes', 'tuesday'],
        3: ['miercoles', 'miércoles', 'wednesday'],
        4: ['jueves', 'thursday'],
        5: ['viernes', 'friday'],
        6: ['sabado', 'sábado', 'saturday'],
      };
      return names[weekday]!.any(days.contains);
    }

    return {
      for (final weekday in labels.keys)
        weekday: _StaffWorkingDay(
          weekday: weekday,
          label: labels[weekday]!,
          isWorking: works(weekday),
          startsAt: staff?.workStartTime?.trim().isNotEmpty == true
              ? staff!.workStartTime!
              : '10:00',
          endsAt: staff?.workEndTime?.trim().isNotEmpty == true
              ? staff!.workEndTime!
              : '19:00',
        ),
    };
  }

  Future<void> _loadWorkingHours() async {
    final staffId = widget.staff?.id;
    if (staffId == null || staffId.isEmpty) return;
    try {
      final data = await Supabase.instance.client
          .from('staff_working_hours')
          .select(
            'weekday, is_working, starts_at, ends_at, break_starts_at, break_ends_at',
          )
          .eq('staff_id', staffId)
          .order('weekday');
      if (!mounted) return;
      setState(() {
        for (final raw in (data as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          final weekday = (row['weekday'] as num?)?.toInt();
          final day = weekday == null ? null : _workingHours[weekday];
          if (day == null) continue;
          day.isWorking = row['is_working'] == true;
          day.startsAt = _shortTime(row['starts_at']?.toString()) ?? day.startsAt;
          day.endsAt = _shortTime(row['ends_at']?.toString()) ?? day.endsAt;
          day.breakStartsAt =
              _shortTime(row['break_starts_at']?.toString()) ?? '';
          day.breakEndsAt = _shortTime(row['break_ends_at']?.toString()) ?? '';
        }
      });
    } catch (e) {
      if (!_isMissingTable(e, 'staff_working_hours')) {
        debugPrint('Error cargando staff_working_hours: $e');
      }
    }
  }

  String? _shortTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return value;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  Future<void> _loadServices() async {
    try {
      final res = await Supabase.instance.client
          .from('services')
          .select('id, name')
          .eq('active', true);
      if (mounted)
        setState(() => _allServices = List<Map<String, dynamic>>.from(res));

      if (widget.staff != null) {
        final staffId = widget.staff!.id;
        try {
          final data = await Supabase.instance.client
              .from('staff_services')
              .select('service_id')
              .eq('staff_id', staffId);
          final ids = (data as List)
              .map((e) => e['service_id'].toString())
              .toSet();
          if (mounted) setState(() => _selectedServiceIds = ids);
        } catch (e) {
          if (_isMissingTable(e, 'staff_services')) {
            debugPrint(
              'staff_services no existe en esta base; se omite carga de servicios por terapeuta.',
            );
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando staff_services: $e');
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _whatsappCtrl,
      _emailCtrl,
      _addressCtrl,
      _cityCtrl,
      _emergNameCtrl,
      _emergPhoneCtrl,
      _startTimeCtrl,
      _endTimeCtrl,
      _breakTimeCtrl,
      _salaryCtrl,
      _commissionCtrl,
      _payNotesCtrl,
      _accessEmailCtrl,
      _accessPassCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _extractMissingStaffColumn(Object error) {
    if (error is! PostgrestException) return null;
    final message = error.message;
    final match = RegExp(r"Could not find the '([^']+)' column of 'staff'")
        .firstMatch(message);
    return match?.group(1);
  }

  bool _isMissingTable(Object error, String tableName) {
    if (error is! PostgrestException) return false;
    return error.message.contains("Could not find the table 'public.$tableName'");
  }

  Map<String, dynamic> _normalizedStaffPayload(Map<String, dynamic> payload) {
    const requiredKeys = {
      'full_name',
      'role',
      'active',
      'phone',
      'show_in_calendar',
      'can_access_mobile',
      'can_access_web',
    };

    final cleaned = <String, dynamic>{};
    payload.forEach((key, value) {
      if (value == null) {
        if (requiredKeys.contains(key)) cleaned[key] = value;
        return;
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty && !requiredKeys.contains(key)) return;
        cleaned[key] = trimmed;
        return;
      }
      if (value is List && value.isEmpty && !requiredKeys.contains(key)) {
        return;
      }
      cleaned[key] = value;
    });
    return cleaned;
  }

  Future<Map<String, dynamic>> _insertStaffWithCompatiblePayload(
    Map<String, dynamic> payload,
  ) async {
    final mutable = Map<String, dynamic>.from(_normalizedStaffPayload(payload));
    while (true) {
      try {
        final res = await Supabase.instance.client
            .from('staff')
            .insert(mutable)
            .select()
            .single();
        return Map<String, dynamic>.from(res);
      } catch (error) {
        final missingColumn = _extractMissingStaffColumn(error);
        if (missingColumn == null || !mutable.containsKey(missingColumn)) rethrow;
        mutable.remove(missingColumn);
        debugPrint(
          'Staff insert retry without unsupported column: $missingColumn',
        );
      }
    }
  }

  Future<void> _updateStaffWithCompatiblePayload(
    String staffId,
    Map<String, dynamic> payload,
  ) async {
    final mutable = Map<String, dynamic>.from(_normalizedStaffPayload(payload));
    while (true) {
      try {
        await Supabase.instance.client
            .from('staff')
            .update(mutable)
            .eq('id', staffId);
        return;
      } catch (error) {
        final missingColumn = _extractMissingStaffColumn(error);
        if (missingColumn == null || !mutable.containsKey(missingColumn)) rethrow;
        mutable.remove(missingColumn);
        debugPrint(
          'Staff update retry without unsupported column: $missingColumn',
        );
      }
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio.')),
      );
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El teléfono es obligatorio.')),
      );
      return;
    }
    if (_showInCalendar && _workDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione días de trabajo.')),
      );
      return;
    }
    final scheduleError = _validateWorkingHours();
    if (scheduleError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(scheduleError)),
      );
      return;
    }
    if (_canLogin) {
      if (_accessEmailCtrl.text.trim().isEmpty ||
          (widget.staff == null && _accessPassCtrl.text.trim().length < 6)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email y contraseña (mín 6 carácteres) son requeridos para acceso.',
            ),
          ),
        );
        return;
      }
    }

    try {
      final accessEmail = _accessEmailCtrl.text.trim();
      final contactEmail = _emailCtrl.text.trim().isNotEmpty
          ? _emailCtrl.text.trim()
          : (_canLogin ? accessEmail : '');
      if (_role == 'therapist') {
        _workDays = _workingHours.values
            .where((day) => day.isWorking)
            .map((day) => day.label.toLowerCase())
            .toList();
      }

      final payload = {
        // Columna en DB es full_name (NOT NULL). Antes se enviaba 'name' y el
        // helper _insertStaffWithCompatiblePayload lo descartaba al no existir
        // → violación NOT NULL. El modelo _Staff.fromMap ya lee full_name.
        'full_name': _nameCtrl.text.trim(),
        'role': _role,
        'active': _active,
        'phone': _phoneCtrl.text.trim(),
        'whatsapp': _whatsappCtrl.text.trim(),
        'email': contactEmail,
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'emergency_contact_name': _emergNameCtrl.text.trim(),
        'emergency_contact_phone': _emergPhoneCtrl.text.trim(),
        'work_days': _workDays,
        'work_start_time': _startTimeCtrl.text.trim(),
        'work_end_time': _endTimeCtrl.text.trim(),
        'break_time': _breakTimeCtrl.text.trim(),
        'show_in_calendar': _showInCalendar,
        'fixed_salary': double.tryParse(_salaryCtrl.text.trim()),
        'commission_percentage': double.tryParse(_commissionCtrl.text.trim()),
        'payment_notes': _payNotesCtrl.text.trim(),
        'can_access_mobile': _canLogin,
        'can_access_web': _canLogin,
      };

      String staffId = '';
      if (widget.staff == null) {
        final res = await _insertStaffWithCompatiblePayload(payload);
        staffId = res['id'].toString();
      } else {
        staffId = widget.staff!.id;
        await _updateStaffWithCompatiblePayload(staffId, payload);
      }

      if (_role == 'therapist') {
        await _saveWorkingHours(staffId);
        try {
          await Supabase.instance.client
              .from('staff_services')
              .delete()
              .eq('staff_id', staffId);
          if (_selectedServiceIds.isNotEmpty) {
            final inserts = _selectedServiceIds
                .map((sid) => {'staff_id': staffId, 'service_id': sid})
                .toList();
            await Supabase.instance.client
                .from('staff_services')
                .insert(inserts);
          }
        } catch (e) {
          if (_isMissingTable(e, 'staff_services')) {
            debugPrint(
              'staff_services no existe en esta base; se omite sincronizacion de servicios del terapeuta.',
            );
          } else {
            rethrow;
          }
        }
      }

      // Vincular acceso al sistema (Supabase Auth) si aplica.
      // Invoca Edge Function admin_create_staff_user (service_role) que:
      //  - crea user en auth.users con email_confirm=true
      //  - si email ya existe, vincula sin duplicar (no resetea password)
      //  - actualiza staff.auth_user_id y can_login=true
      String? accessMessage;
      if (_canLogin && accessEmail.isNotEmpty) {
        final bool isInsert = widget.staff == null;
        final hasPassword = _accessPassCtrl.text.trim().isNotEmpty;
        if (isInsert || hasPassword) {
          try {
            final fn = await Supabase.instance.client.functions.invoke(
              'admin_create_staff_user',
              body: {
                'staff_id': staffId,
                'email': accessEmail,
                'password': _accessPassCtrl.text.trim(),
                'full_name': _nameCtrl.text.trim(),
                'role': _role,
              },
            );
            final data = fn.data is Map ? Map<String, dynamic>.from(fn.data as Map) : null;
            if (fn.status >= 400) {
              final err = data?['error']?.toString() ?? 'desconocido';
              accessMessage = 'Staff guardado, pero acceso falló: $err';
            } else {
              final linked = data?['linked'] == true;
              accessMessage = linked
                  ? 'Acceso vinculado al usuario existente (password no cambiado).'
                  : 'Acceso creado correctamente.';
            }
          } catch (e) {
            debugPrint('admin_create_staff_user invoke failed: $e');
            accessMessage = 'Staff guardado, pero acceso falló: $e';
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        if (accessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(accessMessage)),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  String? _validateWorkingHours() {
    if (_role != 'therapist') return null;
    for (final day in _workingHours.values) {
      if (!day.isWorking) continue;
      final start = _StaffWorkingDay._timeToMinute(day.startsAt);
      final end = _StaffWorkingDay._timeToMinute(day.endsAt);
      if (start == null || end == null) {
        return '${day.label}: captura hora inicio y hora fin validas.';
      }
      if (end <= start) {
        return '${day.label}: la hora fin debe ser mayor que la hora inicio.';
      }
      final breakStartText = day.breakStartsAt.trim();
      final breakEndText = day.breakEndsAt.trim();
      if (breakStartText.isEmpty && breakEndText.isEmpty) continue;
      final breakStart = _StaffWorkingDay._timeToMinute(breakStartText);
      final breakEnd = _StaffWorkingDay._timeToMinute(breakEndText);
      if (breakStart == null || breakEnd == null) {
        return '${day.label}: captura inicio y fin de comida validos.';
      }
      if (breakEnd <= breakStart || breakStart <= start || breakEnd >= end) {
        return '${day.label}: la comida debe quedar dentro del horario de trabajo.';
      }
    }
    return null;
  }

  Future<void> _saveWorkingHours(String staffId) async {
    try {
      await Supabase.instance.client.from('staff_working_hours').upsert(
            _workingHours.values.map((day) => day.toPayload(staffId)).toList(),
            onConflict: 'staff_id,weekday',
          );
      _workDays = _workingHours.values
          .where((day) => day.isWorking)
          .map((day) => day.label.toLowerCase())
          .toList();
    } catch (e) {
      if (_isMissingTable(e, 'staff_working_hours')) {
        debugPrint(
          'staff_working_hours no existe; se conserva horario legado en staff.',
        );
      } else {
        rethrow;
      }
    }
  }

  Widget _secH(String t) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(
      t,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: SaharaTheme.primary,
      ),
    ),
  );

  Widget _r2(Widget a, Widget b) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    ),
  );

  Widget _drp(
    String label,
    String value,
    List<String> opts,
    void Function(String?) onChange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDD9D3)),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              items: opts
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        o.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sw(String label, bool val, void Function(bool) onChange) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SaharaTheme.surface,
          border: Border.all(color: const Color(0xFFDDD9D3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(
              height: 24,
              child: Switch(
                value: val,
                onChanged: onChange,
                activeColor: SaharaTheme.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bx(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: SaharaTheme.primary.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: SaharaTheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  void _copyFirstWorkingDayToWeek() {
    final source = _workingHours.values.firstWhere(
      (day) => day.isWorking,
      orElse: () => _workingHours[1]!,
    );
    setState(() {
      for (final day in _workingHours.values) {
        if (day.weekday == 0) {
          day.isWorking = false;
          continue;
        }
        day.isWorking = true;
        day.startsAt = source.startsAt;
        day.endsAt = source.endsAt;
        day.breakStartsAt = source.breakStartsAt;
        day.breakEndsAt = source.breakEndsAt;
      }
    });
  }

  Widget _workingHoursEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _FieldLabel('Horario de trabajo')),
            TextButton.icon(
              onPressed: _copyFirstWorkingDayToWeek,
              icon: const Icon(Icons.copy_all_outlined, size: 16),
              label: const Text('Copiar horario a toda la semana'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._workingHours.values.map((day) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: day.isWorking ? Colors.white : SaharaTheme.surface,
              border: Border.all(color: const Color(0xFFE4DED6)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final switchRow = Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        day.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: day.isWorking,
                      activeColor: SaharaTheme.gold,
                      onChanged: (value) =>
                          setState(() => day.isWorking = value),
                    ),
                    Text(
                      day.isWorking ? 'Trabaja' : 'No trabaja',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                );
                final fields = [
                  _MiniTimeField(
                    label: 'Inicio',
                    value: day.startsAt,
                    enabled: day.isWorking,
                    onChanged: (value) => day.startsAt = value,
                  ),
                  _MiniTimeField(
                    label: 'Fin',
                    value: day.endsAt,
                    enabled: day.isWorking,
                    onChanged: (value) => day.endsAt = value,
                  ),
                  _MiniTimeField(
                    label: 'Comida inicio',
                    value: day.breakStartsAt,
                    enabled: day.isWorking,
                    onChanged: (value) => day.breakStartsAt = value,
                  ),
                  _MiniTimeField(
                    label: 'Comida fin',
                    value: day.breakEndsAt,
                    enabled: day.isWorking,
                    onChanged: (value) => day.breakEndsAt = value,
                  ),
                ];
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      switchRow,
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: fields),
                    ],
                  );
                }
                return Row(
                  children: [
                    switchRow,
                    const SizedBox(width: 8),
                    ...fields.map(
                      (field) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: field,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Las excepciones se guardan en staff_time_off desde SQL por ahora.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.event_busy_outlined, size: 16),
            label: const Text('Agregar excepcion / dia libre'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SaharaTheme.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 600,
        height: 700,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: SaharaTheme.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add_outlined,
                    color: SaharaTheme.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.staff == null
                        ? 'Agregar Personal'
                        : 'Editar Personal',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _bx('1. Datos Personales', [
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: SaharaTheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFDDD9D3)),
                        ),
                        child: widget.staff?.photoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  widget.staff!.photoUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.add_a_photo_outlined,
                                color: Colors.black38,
                              ),
                      ),
                    ),
                    _Field(ctrl: _nameCtrl, hint: 'Nombre completo'),
                    const SizedBox(height: 12),
                    _r2(
                      _drp('Rol', _role, [
                        'admin',
                        'reception',
                        'therapist',
                        'cleaning',
                        'sales',
                        'other',
                      ], (v) => setState(() => _role = v!)),
                      _drp(
                        'Estado',
                        _active ? 'activo' : 'inactivo',
                        ['activo', 'inactivo'],
                        (v) => setState(() => _active = v == 'activo'),
                      ),
                    ),
                  ]),

                  _bx('2. Contacto', [
                    _r2(
                      _Field(
                        ctrl: _phoneCtrl,
                        hint: 'Teléfono',
                        type: TextInputType.phone,
                      ),
                      _Field(
                        ctrl: _whatsappCtrl,
                        hint: 'WhatsApp (opcional)',
                        type: TextInputType.phone,
                      ),
                    ),
                    _Field(
                      ctrl: _emailCtrl,
                      hint: 'Correo electrónico (opcional)',
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _Field(ctrl: _addressCtrl, hint: 'Dirección completa'),
                    const SizedBox(height: 12),
                    _Field(ctrl: _cityCtrl, hint: 'Ciudad'),
                    _secH('Contacto de Emergencia'),
                    _r2(
                      _Field(ctrl: _emergNameCtrl, hint: 'Nombre de contacto'),
                      _Field(
                        ctrl: _emergPhoneCtrl,
                        hint: 'Teléfono de contacto',
                        type: TextInputType.phone,
                      ),
                    ),
                  ]),

                  _bx('3. Disponibilidad', [
                    _sw(
                      'Mostrar en agenda',
                      _showInCalendar,
                      (v) => setState(() => _showInCalendar = v),
                    ),
                    if (_role == 'therapist') ...[
                      _workingHoursEditor(),
                      const SizedBox(height: 16),
                    ],
                    _FieldLabel('Días de trabajo'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            'lunes',
                            'martes',
                            'miercoles',
                            'jueves',
                            'viernes',
                            'sabado',
                            'domingo',
                          ].map((d) {
                            final sel = _workDays.contains(d);
                            return InkWell(
                              onTap: () => setState(() {
                                sel ? _workDays.remove(d) : _workDays.add(d);
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? SaharaTheme.gold
                                      : SaharaTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: sel
                                        ? SaharaTheme.gold
                                        : const Color(0xFFDDD9D3),
                                  ),
                                ),
                                child: Text(
                                  d.substring(0, 3).toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: sel ? Colors.black : Colors.black54,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _r2(
                      _Field(
                        ctrl: _startTimeCtrl,
                        hint: 'Hora entrada (ej. 09:00)',
                      ),
                      _Field(
                        ctrl: _endTimeCtrl,
                        hint: 'Hora salida (ej. 18:00)',
                      ),
                    ),
                    _Field(
                      ctrl: _breakTimeCtrl,
                      hint: 'Horario de comida (ej. 14:00 - 15:00)',
                    ),

                    if (_role == 'therapist') ...[
                      _secH('Servicios que puede realizar'),
                      _allServices.isEmpty
                          ? const Text(
                              'No hay servicios disponibles.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _allServices.map((s) {
                                final sid = s['id'].toString();
                                final sel = _selectedServiceIds.contains(sid);
                                return InkWell(
                                  onTap: () => setState(() {
                                    sel
                                        ? _selectedServiceIds.remove(sid)
                                        : _selectedServiceIds.add(sid);
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? SaharaTheme.primary
                                          : SaharaTheme.surface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: sel
                                            ? SaharaTheme.primary
                                            : const Color(0xFFDDD9D3),
                                      ),
                                    ),
                                    child: Text(
                                      s['name'],
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: sel
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ]),

                  if (_isAdmin)
                    _bx('4. Pago (Solo Admin)', [
                      _r2(
                        _Field(ctrl: _salaryCtrl, hint: 'Salario Fijo (\$)'),
                        _Field(ctrl: _commissionCtrl, hint: 'Comisión (%)'),
                      ),
                      _Field(
                        ctrl: _payNotesCtrl,
                        hint: 'Notas sobre el pago',
                        maxLines: 2,
                      ),
                    ]),

                  _bx('5. Acceso al Sistema', [
                    _sw(
                      'Permitir iniciar sesión',
                      _canLogin,
                      (v) => setState(() => _canLogin = v),
                    ),
                    if (_canLogin) ...[
                      const SizedBox(height: 12),
                      _r2(
                        _Field(ctrl: _accessEmailCtrl, hint: 'Email de acceso'),
                        _Field(
                          ctrl: _accessPassCtrl,
                          hint: 'Contraseña (mín 6)',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nota: Para modificar contraseña, escriba una nueva.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF0EBE1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SaharaTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('Guardar'),
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

class _ServiceFormDialog extends StatefulWidget {
  const _ServiceFormDialog({required this.service, required this.onSaved});
  final _ServiceItem? service;
  final VoidCallback onSaved;
  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  late final _nameCtrl = TextEditingController(
    text: widget.service?.name ?? '',
  );
  late final _descCtrl = TextEditingController(text: '');
  late final _priceCtrl = TextEditingController(
    text: widget.service != null
        ? widget.service!.price.toStringAsFixed(0)
        : '',
  );
  late final _durationCtrl = TextEditingController(
    text: widget.service != null ? widget.service!.duration.toString() : '60',
  );
  late String _category = widget.service?.category ?? 'Masajes';
  late bool _active = widget.service?.active ?? true;
  bool _saving = false;

  static const _categories = [
    'Masajes',
    'Faciales',
    'Corporales',
    'Fusionadas',
    'Rituales',
    'Tecnologia Facial',
    'Tecnologia Corporal',
    'Moldeo',
    'Paquetes',
    'Otros',
  ];

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 60;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre y precio son obligatorios'),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final data = {
        'name': name,
        'category': _category,
        'duration': duration,
        'duration_min': duration,
        'price': price,
        'active': _active,
        'is_active': _active,
      };
      if (widget.service == null) {
        await Supabase.instance.client.from('services').insert(data);
      } else {
        await Supabase.instance.client
            .from('services')
            .update(data)
            .eq('id', widget.service!.id);
      }
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio guardado correctamente'),
            backgroundColor: SaharaTheme.gold,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SaharaTheme.rojoCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.service != null;
    return Dialog(
      backgroundColor: SaharaTheme.blancoAlmendra,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: Color(0xFFECE9E4))),
              ),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Editar servicio' : 'Nuevo servicio',
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _FormCard(
                      children: [
                        _FieldLabel('Nombre del servicio *'),
                        const SizedBox(height: 6),
                        _Field(
                          ctrl: _nameCtrl,
                          hint: 'Ej: Masaje Descontracturante',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormCard(
                      children: [
                        _FieldLabel('Categoria'),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _categories.contains(_category)
                                  ? _category
                                  : _categories.last,
                              isExpanded: true,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              items: _categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _category = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FormCard(
                            children: [
                              _FieldLabel('Duracion (min) *'),
                              const SizedBox(height: 6),
                              _Field(
                                ctrl: _durationCtrl,
                                hint: '60',
                                type: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormCard(
                            children: [
                              _FieldLabel('Precio MXN *'),
                              const SizedBox(height: 6),
                              _Field(
                                ctrl: _priceCtrl,
                                hint: '999',
                                type: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormCard(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _FieldLabel('Servicio activo'),
                            Switch(
                              value: _active,
                              activeColor: SaharaTheme.gold,
                              onChanged: (v) => setState(() => _active = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: Color(0xFFECE9E4))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: Text(
                      isEdit ? 'Editar Servicio' : 'Guardar Servicio',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SaharaTheme.gold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

class _Th extends StatelessWidget {
  const _Th(this.text, {this.flex = 1});
  final String text;
  final int flex;
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Colors.black87,
      ),
    ),
  );
}

Future<bool?> _confirmDelete(BuildContext context, String title, String msg) =>
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF5F3EF),
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Text(msg, style: GoogleFonts.inter(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: GoogleFonts.inter(color: Colors.black54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC6A76A),
              foregroundColor: Colors.black,
            ),
            child: Text(
              'Si',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

InputDecoration _deco(String? hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 13, color: Colors.black54),
  filled: true,
  fillColor: const Color(0xFFF9F9F9),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFC6A76A)),
  ),
);

// ---------------------------------------------------------------------------
// AI Settings Tab — centro de control del agente IA
// Reúne todos los paneles operativos del concierge IA: control, plantillas,
// FAQs, horarios, base de conocimiento de servicios y staff, cola WhatsApp.
// ---------------------------------------------------------------------------
class _AiSettingsTab extends StatefulWidget {
  const _AiSettingsTab();

  @override
  State<_AiSettingsTab> createState() => _AiSettingsTabState();
}

class _AiSettingsTabState extends State<_AiSettingsTab> {
  // Sub-pestañas con carga perezosa: solo el panel activo se monta.
  // Antes se renderizaban los 8 paneles a la vez (cada uno con su initState
  // disparando queries), lo que hacía que la pestaña sintiera lentísima.
  int _index = 0;

  static const _sections = <(IconData, String)>[
    (Icons.tune_rounded, 'Control IA'),
    (Icons.schedule_rounded, 'Horarios'),
    (Icons.article_outlined, 'Plantillas'),
    (Icons.help_outline_rounded, 'FAQs'),
    (Icons.spa_outlined, 'Servicios IA'),
    (Icons.badge_outlined, 'Perfiles staff'),
    (Icons.menu_book_outlined, 'Conocimiento'),
    (Icons.queue_play_next_outlined, 'Cola WhatsApp'),
  ];

  Widget _bodyFor(int i) {
    switch (i) {
      case 0:
        return const AiControlPanel();
      case 1:
        return const BusinessHoursPanel();
      case 2:
        return const WhatsAppMetaTemplatesPanel();
      case 3:
        return const FaqsPanel();
      case 4:
        return const ServicesAiFieldsPanel();
      case 5:
        return const StaffAiProfilePanel();
      case 6:
        return const KnowledgeBasePanel();
      case 7:
      default:
        return const WhatsAppQueueDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sections.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final selected = i == _index;
                    final (icon, label) = _sections[i];
                    return InkWell(
                      onTap: () => setState(() => _index = i),
                      borderRadius: BorderRadius.circular(22),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? SaharaTheme.gold.withValues(alpha: 0.15)
                              : Colors.white,
                          border: Border.all(
                            color: selected
                                ? SaharaTheme.gold
                                : const Color(0xFFE9E4D8),
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: selected
                                  ? SaharaTheme.gold
                                  : Colors.black54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? const Color(0xFF8C6623)
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: KeyedSubtree(
                    key: ValueKey('ai-sub-$_index'),
                    child: _bodyFor(_index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Tab (WhatsApp Connection + Stripe + Branches CRUD)
// ---------------------------------------------------------------------------
class _SettingsTab extends StatefulWidget {
  final List<_Branch> branches;
  final VoidCallback onRefresh;
  const _SettingsTab({required this.branches, required this.onRefresh});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _tokenCtrl = TextEditingController();
  final _phoneIdCtrl = TextEditingController();
  final _businessIdCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _obscureToken = true;
  String? _configId;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  bool get _isConfigured =>
      _tokenCtrl.text.trim().isNotEmpty && _phoneIdCtrl.text.trim().isNotEmpty;

  Future<void> _loadConfig() async {
    try {
      final res = await Supabase.instance.client
          .from('configuracion_sistema')
          .select()
          .maybeSingle();
      if (res != null) {
        _configId = res['id'] as String?;
        _tokenCtrl.text = res['whatsapp_access_token'] as String? ?? '';
        _phoneIdCtrl.text = res['whatsapp_phone_number_id'] as String? ?? '';
        _businessIdCtrl.text = res['whatsapp_business_id'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('loadConfig: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveWhatsApp() async {
    setState(() => _saving = true);
    try {
      final data = {
        'whatsapp_access_token': _tokenCtrl.text.trim(),
        'whatsapp_phone_number_id': _phoneIdCtrl.text.trim(),
        'whatsapp_business_id': _businessIdCtrl.text.trim(),
        'whatsapp_enabled': _isConfigured,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (_configId == null) {
        await Supabase.instance.client
            .from('configuracion_sistema')
            .insert(data);
      } else {
        await Supabase.instance.client
            .from('configuracion_sistema')
            .update(data)
            .eq('id', _configId!);
      }
      await _loadConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Configuracion guardada correctamente'),
            backgroundColor: SaharaTheme.gold,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SaharaTheme.rojoCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openBranchForm([_Branch? branch]) {
    showDialog(
      context: context,
      builder: (_) =>
          _BranchFormDialog(branch: branch, onSaved: widget.onRefresh),
    );
  }

  Future<void> _deleteBranch(_Branch b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sucursal'),
        content: Text('Seguro que deseas eliminar ${b.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client.from('sucursales').delete().eq('id', b.id);
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _WhatsAppMetaSetup(onRefresh: widget.onRefresh),
              const SizedBox(height: 32),
              _StripeSetup(onRefresh: widget.onRefresh),
              const SizedBox(height: 32),
              kEnableMultiBranch
                  ? _buildBranchesSection()
                  : _buildSingleBranchSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configuracion del Sistema',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Administra la conexion de WhatsApp Business y la operacion del spa.',
          style: GoogleFonts.inter(color: Colors.black54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildWhatsAppCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chat_bubble,
                  color: Color(0xFF25D366),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WhatsApp Business API',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: SaharaTheme.grisCarbon,
                    ),
                  ),
                  Text(
                    _isConfigured ? 'Conectado y activo' : 'Sin configurar',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _isConfigured
                          ? const Color(0xFF25D366)
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveWhatsApp,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  'Guardar',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaharaTheme.gold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildField(
            'Token de Acceso Permanente',
            _tokenCtrl,
            obscure: _obscureToken,
            onToggle: () => setState(() => _obscureToken = !_obscureToken),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildField('Phone Number ID', _phoneIdCtrl)),
              const SizedBox(width: 16),
              Expanded(
                child: _buildField('WhatsApp Business ID', _businessIdCtrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFECE9E4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFC6A76A)),
            ),
            suffixIcon: onToggle != null
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: onToggle,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleBranchSection() {
    final branch = widget.branches.isNotEmpty
        ? widget.branches.first
        : _Branch.fromMap(defaultBranchMap());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sucursal Principal',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          'El modo multi-sucursal esta desactivado temporalmente.',
          style: GoogleFonts.inter(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _BranchCard(
          branch: branch,
          onEdit: () => _openBranchForm(branch),
          onDelete: () {},
          allowDelete: false,
        ),
      ],
    );
  }

  Widget _buildBranchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Gestion de sucursales',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openBranchForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Anadir sucursal'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC6A76A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.branches.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No hay sucursales registradas'),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 300,
            ),
            itemCount: widget.branches.length,
            itemBuilder: (context, index) => _BranchCard(
              branch: widget.branches[index],
              onEdit: () => _openBranchForm(widget.branches[index]),
              onDelete: () => _deleteBranch(widget.branches[index]),
            ),
          ),
      ],
    );
  }
}

class _WhatsAppMetaSetup extends StatefulWidget {
  const _WhatsAppMetaSetup({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  State<_WhatsAppMetaSetup> createState() => _WhatsAppMetaSetupState();
}

class _WhatsAppMetaSetupState extends State<_WhatsAppMetaSetup> {
  final _businessNameCtrl = TextEditingController();
  final _metaBusinessIdCtrl = TextEditingController();
  final _wabaIdCtrl = TextEditingController();
  final _phoneNumberIdCtrl = TextEditingController();
  final _whatsAppNumberCtrl = TextEditingController();
  final _accessTokenCtrl = TextEditingController();
  final _appIdCtrl = TextEditingController();
  final _appSecretCtrl = TextEditingController();
  final _verifyTokenCtrl = TextEditingController();
  final _testPhoneCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _sendingTest = false;
  bool _showAccessToken = false;
  bool _showAppSecret = false;
  String? _accessTokenMask;
  String? _appSecretMask;
  String _selectedEnvironment = 'sandbox';
  _BusinessWhatsAppSettings _settings = _BusinessWhatsAppSettings.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _metaBusinessIdCtrl.dispose();
    _wabaIdCtrl.dispose();
    _phoneNumberIdCtrl.dispose();
    _whatsAppNumberCtrl.dispose();
    _accessTokenCtrl.dispose();
    _appIdCtrl.dispose();
    _appSecretCtrl.dispose();
    _verifyTokenCtrl.dispose();
    _testPhoneCtrl.dispose();
    super.dispose();
  }

  bool get _hasRequiredConnectionFields =>
      _phoneNumberIdCtrl.text.trim().isNotEmpty &&
      _wabaIdCtrl.text.trim().isNotEmpty &&
      _whatsAppNumberCtrl.text.trim().isNotEmpty &&
      (_accessTokenCtrl.text.trim().isNotEmpty || (_settings.hasAccessToken));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'save_whatsapp_settings',
        body: {'action': 'load'},
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      final rawSettings = Map<String, dynamic>.from(
        (payload['settings'] as Map?) ?? const {},
      );
      final settings = _BusinessWhatsAppSettings.fromMap(rawSettings);
      _applySettings(settings);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar la configuracion: $e'),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySettings(_BusinessWhatsAppSettings settings) {
    _settings = settings;
    _selectedEnvironment = settings.environment;
    _businessNameCtrl.text = settings.businessName;
    _metaBusinessIdCtrl.text = settings.metaBusinessId;
    _wabaIdCtrl.text = settings.whatsappBusinessAccountId;
    _phoneNumberIdCtrl.text = settings.phoneNumberId;
    _whatsAppNumberCtrl.text = settings.whatsappPhoneNumber;
    _appIdCtrl.text = settings.appId;
    _verifyTokenCtrl.text = settings.webhookVerifyToken;
    _accessTokenCtrl.clear();
    _appSecretCtrl.clear();
    _accessTokenMask = settings.accessTokenMasked.isEmpty
        ? null
        : settings.accessTokenMasked;
    _appSecretMask = settings.appSecretMasked.isEmpty
        ? null
        : settings.appSecretMasked;
    if (mounted) setState(() {});
  }

  Future<bool> _save() async {
    setState(() => _saving = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'save_whatsapp_settings',
        body: {
          'business_name': _businessNameCtrl.text.trim(),
          'meta_business_id': _metaBusinessIdCtrl.text.trim(),
          'whatsapp_business_account_id': _wabaIdCtrl.text.trim(),
          'phone_number_id': _phoneNumberIdCtrl.text.trim(),
          'whatsapp_phone_number': _whatsAppNumberCtrl.text.trim(),
          'access_token': _accessTokenCtrl.text.trim(),
          'app_id': _appIdCtrl.text.trim(),
          'app_secret': _appSecretCtrl.text.trim(),
          'webhook_verify_token': _verifyTokenCtrl.text.trim(),
          'environment': _selectedEnvironment,
        },
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      final rawSettings = Map<String, dynamic>.from(payload['settings'] as Map);
      _applySettings(_BusinessWhatsAppSettings.fromMap(rawSettings));
      widget.onRefresh();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuracion de WhatsApp guardada'),
          backgroundColor: SaharaTheme.gold,
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar la configuracion: $e'),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    return false;
  }

  Future<void> _testConnection() async {
    if (!_hasRequiredConnectionFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa Phone Number ID, WABA ID, numero de WhatsApp y Access Token.',
          ),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
      return;
    }

    setState(() => _testing = true);
    try {
      final saved = await _save();
      if (!saved) return;
      final response = await Supabase.instance.client.functions.invoke(
        'test_whatsapp_connection',
        body: const {},
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      final rawSettings = Map<String, dynamic>.from(payload['settings'] as Map);
      _applySettings(_BusinessWhatsAppSettings.fromMap(rawSettings));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            payload['message'] as String? ?? 'Conexion validada correctamente.',
          ),
          backgroundColor: const Color(0xFF1A9E65),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos validar la conexion con Meta. Revisa el token y los IDs configurados.',
          ),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _sendTestMessage() async {
    if (_testPhoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un numero para el mensaje de prueba.'),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
      return;
    }

    setState(() => _sendingTest = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'send_whatsapp_test_message',
        body: {'phone': _testPhoneCtrl.text.trim()},
      );
      final payload = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final ok = payload['ok'] == true;
      final noWindow = payload['no_window'] == true;
      final wamid = payload['wamid']?.toString();
      final metaErr = payload['meta_error'] is Map
          ? Map<String, dynamic>.from(payload['meta_error'] as Map)
          : null;

      String msg;
      Color color;
      if (ok) {
        msg = 'Mensaje enviado ✓ wamid=${wamid ?? "—"} (${payload['elapsed_ms'] ?? "?"} ms). '
            'Verifica entrega en el dashboard.';
        color = const Color(0xFF1A9E65);
      } else if (noWindow) {
        msg = (payload['error'] as String?) ??
            'No hay ventana de 24h activa. El cliente debe escribir primero.';
        color = const Color(0xFFC68A17);
      } else {
        final code = metaErr?['code'];
        final detail = metaErr?['message'] ?? payload['error'] ?? 'desconocido';
        msg = 'Fallo Meta: $detail (code ${code ?? "n/a"})';
        color = const Color(0xFFB32D2D);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al enviar prueba: $e'),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'connected':
        return 'Conectado';
      case 'pending':
        return 'Pendiente';
      case 'error':
        return 'Error';
      default:
        return 'No configurado';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'connected':
        return const Color(0xFF1A9E65);
      case 'pending':
        return const Color(0xFFC68A17);
      case 'error':
        return const Color(0xFFB32D2D);
      default:
        return Colors.black45;
    }
  }

  String _webhookStatusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Verificado';
      case 'error':
        return 'Error';
      default:
        return 'No verificado';
    }
  }

  Color _webhookStatusColor(String status) {
    switch (status) {
      case 'verified':
        return const Color(0xFF1A9E65);
      case 'error':
        return const Color(0xFFB32D2D);
      default:
        return Colors.black45;
    }
  }

  String get _webhookUrl {
    // SupabaseClient no expone functionsUrl; lo derivamos del REST URL del proyecto:
    // https://<ref>.supabase.co/rest/v1 -> https://<ref>.supabase.co/functions/v1/whatsapp-webhook
    final restUrl = Supabase.instance.client.rest.url.toString();
    final uri = Uri.parse(restUrl);
    final base = '${uri.scheme}://${uri.host}';
    return '$base/functions/v1/whatsapp-webhook';
  }

  Widget _envBadge(String env) {
    final isProd = env == 'production';
    final color = isProd ? const Color(0xFFB32D2D) : const Color(0xFFC68A17);
    final label = isProd ? 'PRODUCCIÓN' : 'SANDBOX';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEnvironmentSelector() {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            value: 'sandbox',
            groupValue: _selectedEnvironment,
            onChanged: (v) => setState(() => _selectedEnvironment = v ?? 'sandbox'),
            title: const Text('Sandbox (pruebas)'),
            subtitle: const Text('Número de prueba de Meta. No envía a clientes reales.'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: RadioListTile<String>(
            value: 'production',
            groupValue: _selectedEnvironment,
            onChanged: (v) => setState(() => _selectedEnvironment = v ?? 'sandbox'),
            title: const Text('Producción'),
            subtitle: const Text('Número real verificado. Envía a clientes finales.'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildWebhookPanel() {
    final url = _webhookUrl;
    final verified = _settings.webhookLastVerifiedAt;
    final lastEvent = _settings.webhookLastEventAt;
    final err = _settings.webhookLastError;
    final color = _webhookStatusColor(_settings.webhookStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cable_outlined, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'Webhook · ${_webhookStatusLabel(_settings.webhookStatus)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              _envBadge(_settings.environment),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            url,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: SaharaTheme.grisCarbon,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pega esta URL en Meta › App › Webhooks › Callback URL. Usa el "Verify Token" configurado abajo.',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
          ),
          if (verified != null) ...[
            const SizedBox(height: 10),
            Text(
              'Última verificación challenge: $verified',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.black45),
            ),
          ],
          if (lastEvent != null) ...[
            const SizedBox(height: 4),
            Text(
              'Último evento recibido: $lastEvent',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.black45),
            ),
          ],
          if (err.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Último error: $err',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFFB32D2D),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Graph API: ${_settings.graphApiVersion}',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  String _stepGuide(int step) {
    switch (step) {
      case 1:
        return 'Business Manager ID y WABA ID se obtienen en Meta Business Settings.';
      case 2:
        return 'Usa el numero y Phone Number ID registrados dentro de WhatsApp Cloud API.';
      case 3:
        return 'El Access Token y App Secret se guardan enmascarados y nunca regresan completos al frontend.';
      case 4:
        return 'La prueba valida token, Phone Number ID y la cuenta de WhatsApp Business.';
      default:
        return 'Envia un texto de verificacion a cualquier celular para confirmar la integracion.';
    }
  }

  Widget _wizardStep({
    required int step,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: SaharaTheme.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$step',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: SaharaTheme.gold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: SaharaTheme.grisCarbon,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _stepGuide(step),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    VoidCallback? onToggle,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SaharaTheme.grisCarbon,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFECE9E4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFC6A76A)),
            ),
            suffixIcon: onToggle == null
                ? null
                : IconButton(
                    onPressed: onToggle,
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                  ),
          ),
        ),
        if (helper != null && helper.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.black45),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF7F1E7), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECE9E4)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Color(0xFF25D366),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp / Meta Business',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: SaharaTheme.grisCarbon,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configura la conexion de WhatsApp Cloud API sin exponer secretos ni tocar Supabase manualmente.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(
                    _settings.connectionStatus,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(_settings.connectionStatus),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(_settings.connectionStatus),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_settings.lastValidatedAt != null) ...[
          const SizedBox(height: 12),
          Text(
            'Ultima validacion: ${_settings.lastValidatedAt}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
          ),
        ],
        const SizedBox(height: 16),
        _buildWebhookPanel(),
        const SizedBox(height: 20),
        _wizardStep(
          step: 0,
          title: 'Entorno (sandbox / producción)',
          child: _buildEnvironmentSelector(),
        ),
        _wizardStep(
          step: 1,
          title: 'Datos de Meta Business',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      'Nombre de la empresa',
                      _businessNameCtrl,
                      hint: 'Sahara Club Spa',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _textField(
                      'Business Manager ID',
                      _metaBusinessIdCtrl,
                      hint: 'Meta Business Manager ID',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _textField(
                'WhatsApp Business Account ID',
                _wabaIdCtrl,
                hint: 'Cuenta de WhatsApp Business en Meta',
              ),
            ],
          ),
        ),
        _wizardStep(
          step: 2,
          title: 'Numero de WhatsApp Business',
          child: Row(
            children: [
              Expanded(
                child: _textField(
                  'Phone Number ID',
                  _phoneNumberIdCtrl,
                  hint: 'ID tecnico del numero en Cloud API',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _textField(
                  'Numero de WhatsApp Business',
                  _whatsAppNumberCtrl,
                  hint: '+52...',
                ),
              ),
            ],
          ),
        ),
        _wizardStep(
          step: 3,
          title: 'Token y seguridad',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      'Access Token',
                      _accessTokenCtrl,
                      hint: _accessTokenMask == null
                          ? 'Pega aqui el token de Meta'
                          : 'Token guardado: $_accessTokenMask',
                      obscure: !_showAccessToken,
                      onToggle: () =>
                          setState(() => _showAccessToken = !_showAccessToken),
                      helper: _settings.hasAccessToken
                          ? 'Deja este campo vacio si no deseas reemplazar el token guardado.'
                          : '',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _textField(
                      'App ID',
                      _appIdCtrl,
                      hint: 'App ID de Meta',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      'App Secret',
                      _appSecretCtrl,
                      hint: _appSecretMask == null
                          ? 'Pega aqui el App Secret'
                          : 'Secret guardado: $_appSecretMask',
                      obscure: !_showAppSecret,
                      onToggle: () =>
                          setState(() => _showAppSecret = !_showAppSecret),
                      helper: _settings.hasAppSecret
                          ? 'Deja este campo vacio si no deseas reemplazar el App Secret guardado.'
                          : '',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _textField(
                      'Webhook Verify Token',
                      _verifyTokenCtrl,
                      hint: 'Token de verificacion para webhook',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _wizardStep(
          step: 4,
          title: 'Guardar y probar conexion',
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _save(),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Guardar configuracion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaharaTheme.gold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Probar conexion'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SaharaTheme.grisCarbon,
                  side: const BorderSide(color: Color(0xFFE0D8CA)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        _wizardStep(
          step: 5,
          title: 'Enviar mensaje de prueba',
          child: Row(
            children: [
              Expanded(
                child: _textField(
                  'Numero destino',
                  _testPhoneCtrl,
                  hint: '+52...',
                  helper:
                      'Se enviara: Hola, este es un mensaje de prueba de Sahara Club Spa...',
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _sendingTest ? null : _sendTestMessage,
                icon: _sendingTest
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
                label: const Text('Enviar prueba'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A9E65),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StripeSetup extends StatefulWidget {
  const _StripeSetup({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  State<_StripeSetup> createState() => _StripeSetupState();
}

class _StripeSetupState extends State<_StripeSetup> {
  final _publishableKeyCtrl = TextEditingController();
  final _secretKeyCtrl = TextEditingController();
  final _webhookSecretCtrl = TextEditingController();
  final _accountIdCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _showSecretKey = false;
  bool _showWebhookSecret = false;
  String _environmentMode = 'testing';
  Map<String, _StripeSettingsSnapshot> _settingsByMode =
      <String, _StripeSettingsSnapshot>{};
  String? _secretKeyMask;
  String? _webhookSecretMask;
  _StripeSettingsSnapshot _settings = _StripeSettingsSnapshot.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _publishableKeyCtrl.dispose();
    _secretKeyCtrl.dispose();
    _webhookSecretCtrl.dispose();
    _accountIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'save_stripe_settings',
        body: {'action': 'load'},
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      final activeMode = payload['active_mode'] as String? ?? _environmentMode;
      final rows = ((payload['settings'] as List?) ?? const [])
          .map(
            (row) => _StripeSettingsSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
      _settingsByMode = {for (final row in rows) row.environmentMode: row};
      final current = rows.firstWhere(
        (row) => row.environmentMode == activeMode,
        orElse: () =>
            _StripeSettingsSnapshot.empty(environmentMode: activeMode),
      );
      _applySettings(current);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar Stripe: $e'),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySettings(_StripeSettingsSnapshot settings) {
    _settings = settings;
    _environmentMode = settings.environmentMode;
    _publishableKeyCtrl.text = settings.publishableKey;
    _accountIdCtrl.text = settings.accountId;
    _secretKeyCtrl.clear();
    _webhookSecretCtrl.clear();
    _secretKeyMask = settings.secretKeyMasked.isEmpty
        ? null
        : settings.secretKeyMasked;
    _webhookSecretMask = settings.webhookSecretMasked.isEmpty
        ? null
        : settings.webhookSecretMasked;
    if (mounted) setState(() {});
  }

  bool get _hasRequiredFields =>
      _publishableKeyCtrl.text.trim().isNotEmpty &&
      (_secretKeyCtrl.text.trim().isNotEmpty || _settings.hasSecretKey) &&
      (_webhookSecretCtrl.text.trim().isNotEmpty || _settings.hasWebhookSecret);

  Future<bool> _save() async {
    setState(() => _saving = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'save_stripe_settings',
        body: {
          'environment_mode': _environmentMode,
          'publishable_key': _publishableKeyCtrl.text.trim(),
          'secret_key': _secretKeyCtrl.text.trim(),
          'webhook_secret': _webhookSecretCtrl.text.trim(),
          'stripe_account_id': _accountIdCtrl.text.trim(),
          'is_active': true,
        },
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      final current = _StripeSettingsSnapshot.fromMap(
        Map<String, dynamic>.from(payload['current'] as Map),
      );
      _settingsByMode = {..._settingsByMode, current.environmentMode: current};
      _applySettings(current);
      widget.onRefresh();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuracion de Stripe guardada'),
          backgroundColor: SaharaTheme.gold,
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar Stripe: $e'),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_hasRequiredFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa publishable key, secret key y webhook secret para probar Stripe.',
          ),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
      return;
    }

    setState(() => _testing = true);
    try {
      final saved = await _save();
      if (!saved) return;

      final response = await Supabase.instance.client.functions.invoke(
        'test_stripe_connection',
        body: {'environment_mode': _environmentMode},
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      final settings = _StripeSettingsSnapshot.fromMap(
        Map<String, dynamic>.from(payload['settings'] as Map),
      );
      _applySettings(settings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            payload['message'] as String? ??
                'La conexion con Stripe fue validada correctamente.',
          ),
          backgroundColor: const Color(0xFF1A9E65),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos validar Stripe. Revisa las credenciales del entorno activo.',
          ),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'connected':
        return 'Conectado';
      case 'pending':
        return 'Pendiente';
      case 'error':
        return 'Error';
      default:
        return 'No configurado';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'connected':
        return const Color(0xFF1A9E65);
      case 'pending':
        return const Color(0xFFC68A17);
      case 'error':
        return const Color(0xFFB32D2D);
      default:
        return Colors.black45;
    }
  }

  String _connectionButtonLabel(String status) {
    if (_testing) return 'Probando conexion...';
    switch (status) {
      case 'connected':
        return 'Conexion correcta';
      case 'error':
        return 'Conexion con error';
      case 'pending':
        return 'Probar conexion';
      default:
        return 'Probar conexion';
    }
  }

  Color _connectionButtonBackgroundColor(String status) {
    if (_testing) return const Color(0xFFF5F2EC);
    switch (status) {
      case 'connected':
        return const Color(0xFF1A9E65);
      case 'error':
        return const Color(0xFFB32D2D);
      case 'pending':
        return const Color(0xFFC6A76A);
      default:
        return Colors.white;
    }
  }

  Color _connectionButtonForegroundColor(String status) {
    if (_testing) return SaharaTheme.grisCarbon;
    switch (status) {
      case 'connected':
      case 'error':
      case 'pending':
        return Colors.white;
      default:
        return SaharaTheme.grisCarbon;
    }
  }

  BorderSide _connectionButtonBorder(String status) {
    if (_testing) {
      return const BorderSide(color: Color(0xFFE0D8CA));
    }
    switch (status) {
      case 'connected':
        return const BorderSide(color: Color(0xFF1A9E65));
      case 'error':
        return const BorderSide(color: Color(0xFFB32D2D));
      case 'pending':
        return const BorderSide(color: Color(0xFFC6A76A));
      default:
        return const BorderSide(color: Color(0xFFE0D8CA));
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    VoidCallback? onToggle,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SaharaTheme.grisCarbon,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFECE9E4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFC6A76A)),
            ),
            suffixIcon: onToggle == null
                ? null
                : IconButton(
                    onPressed: onToggle,
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                  ),
          ),
        ),
        if (helper != null && helper.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.black45),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF7F1E7), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECE9E4)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF635BFF).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.credit_card_outlined,
                  color: Color(0xFF635BFF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stripe Checkout',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: SaharaTheme.grisCarbon,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configura credenciales de Stripe en testing o produccion sin hardcodear secretos en el frontend.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(
                    _settings.connectionStatus,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(_settings.connectionStatus),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(_settings.connectionStatus),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_settings.lastValidatedAt != null) ...[
          const SizedBox(height: 12),
          Text(
            'Ultima validacion: ${_settings.lastValidatedAt}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFECE9E4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _environmentMode,
                      decoration: InputDecoration(
                        labelText: 'Modo',
                        filled: true,
                        fillColor: const Color(0xFFF9F9F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFECE9E4),
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'testing',
                          child: Text('Testing / Sandbox'),
                        ),
                        DropdownMenuItem(
                          value: 'production',
                          child: Text('Produccion'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        final snapshot =
                            _settingsByMode[value] ??
                            _StripeSettingsSnapshot.empty(
                              environmentMode: value,
                            );
                        _applySettings(snapshot);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _field(
                      'Stripe Account ID',
                      _accountIdCtrl,
                      hint: 'acct_...',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _field(
                'Publishable Key',
                _publishableKeyCtrl,
                hint: 'pk_test_...',
              ),
              const SizedBox(height: 16),
              _field(
                'Secret Key',
                _secretKeyCtrl,
                hint: _secretKeyMask == null
                    ? 'sk_test_...'
                    : 'Secret guardado: $_secretKeyMask',
                obscure: !_showSecretKey,
                onToggle: () =>
                    setState(() => _showSecretKey = !_showSecretKey),
                helper: _settings.hasSecretKey
                    ? 'Deja este campo vacio si no deseas reemplazar la secret key guardada.'
                    : '',
              ),
              const SizedBox(height: 16),
              _field(
                'Webhook Secret',
                _webhookSecretCtrl,
                hint: _webhookSecretMask == null
                    ? 'whsec_...'
                    : 'Webhook guardado: $_webhookSecretMask',
                obscure: !_showWebhookSecret,
                onToggle: () =>
                    setState(() => _showWebhookSecret = !_showWebhookSecret),
                helper: _settings.hasWebhookSecret
                    ? 'Deja este campo vacio si no deseas reemplazar el webhook secret guardado.'
                    : '',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Guardar configuracion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SaharaTheme.gold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_outlined, size: 18),
                    label: Text(
                      _connectionButtonLabel(_settings.connectionStatus),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _connectionButtonForegroundColor(
                        _settings.connectionStatus,
                      ),
                      backgroundColor: _connectionButtonBackgroundColor(
                        _settings.connectionStatus,
                      ),
                      side: _connectionButtonBorder(_settings.connectionStatus),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StripeSettingsSnapshot {
  const _StripeSettingsSnapshot({
    required this.environmentMode,
    required this.publishableKey,
    required this.secretKeyMasked,
    required this.webhookSecretMasked,
    required this.accountId,
    required this.connectionStatus,
    required this.lastValidatedAt,
    required this.isActive,
    required this.hasSecretKey,
    required this.hasWebhookSecret,
  });

  final String environmentMode;
  final String publishableKey;
  final String secretKeyMasked;
  final String webhookSecretMasked;
  final String accountId;
  final String connectionStatus;
  final String? lastValidatedAt;
  final bool isActive;
  final bool hasSecretKey;
  final bool hasWebhookSecret;

  factory _StripeSettingsSnapshot.empty({String environmentMode = 'testing'}) {
    return _StripeSettingsSnapshot(
      environmentMode: environmentMode,
      publishableKey: '',
      secretKeyMasked: '',
      webhookSecretMasked: '',
      accountId: '',
      connectionStatus: 'not_configured',
      lastValidatedAt: null,
      isActive: environmentMode == 'testing',
      hasSecretKey: false,
      hasWebhookSecret: false,
    );
  }

  factory _StripeSettingsSnapshot.fromMap(Map<String, dynamic> map) {
    return _StripeSettingsSnapshot(
      environmentMode: map['environment_mode'] as String? ?? 'testing',
      publishableKey: map['publishable_key'] as String? ?? '',
      secretKeyMasked: map['secret_key_masked'] as String? ?? '',
      webhookSecretMasked: map['webhook_secret_masked'] as String? ?? '',
      accountId: map['stripe_account_id'] as String? ?? '',
      connectionStatus: map['connection_status'] as String? ?? 'not_configured',
      lastValidatedAt: map['last_validated_at'] as String?,
      isActive: map['is_active'] as bool? ?? false,
      hasSecretKey: map['has_secret_key'] as bool? ?? false,
      hasWebhookSecret: map['has_webhook_secret'] as bool? ?? false,
    );
  }
}

class _BranchCard extends StatelessWidget {
  final _Branch branch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool allowDelete;
  const _BranchCard({
    required this.branch,
    required this.onEdit,
    required this.onDelete,
    this.allowDelete = true,
  });

  @override
  Widget build(BuildContext context) {
    const Color dorado = Color(0xFFC5A059);
    const Color gris = Color(0xFF4A4A4A);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  branch.name,
                  style: GoogleFonts.playfairDisplay(
                    color: gris,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: dorado),
                      onPressed: onEdit,
                    ),
                    if (allowDelete)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ],
            ),
            const Divider(),
            _infoRow(Icons.location_on_outlined, branch.address),
            _infoRow(Icons.phone_outlined, branch.phone),
            _infoRow(Icons.chat_outlined, "WhatsApp: ${branch.whatsapp}"),
            _infoRow(Icons.email_outlined, branch.email),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (branch.mapsLink.isEmpty) return;
                  final uri = Uri.tryParse(branch.mapsLink);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text("Ver en Google Maps"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: dorado,
                  side: const BorderSide(color: dorado),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFC5A059)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.isEmpty ? '-' : text,
              style: GoogleFonts.inter(
                color: const Color(0xFF4A4A4A),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchFormDialog extends StatefulWidget {
  final _Branch? branch;
  final VoidCallback onSaved;
  const _BranchFormDialog({this.branch, required this.onSaved});

  @override
  State<_BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends State<_BranchFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.branch?.name);
  late final _addrCtrl = TextEditingController(text: widget.branch?.address);
  late final _phoneCtrl = TextEditingController(text: widget.branch?.phone);
  late final _whatsappCtrl = TextEditingController(
    text: widget.branch?.whatsapp,
  );
  late final _emailCtrl = TextEditingController(text: widget.branch?.email);
  late final _mapsCtrl = TextEditingController(text: widget.branch?.mapsLink);
  bool _saving = false;

  Future<void> _save() async {
    final nombre = _nameCtrl.text.trim();
    final direccion = _addrCtrl.text.trim();
    final telefono = _phoneCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final maps = _mapsCtrl.text.trim();

    if (nombre.isEmpty ||
        direccion.isEmpty ||
        telefono.isEmpty ||
        whatsapp.isEmpty ||
        email.isEmpty ||
        maps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos los campos son obligatorios'),
          backgroundColor: SaharaTheme.rojoCoral,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final data = {
        'nombre': nombre,
        'direccion_completa': direccion,
        'telefono_contacto': telefono,
        'whatsapp': whatsapp,
        'email': email,
        'link_maps': maps,
      };
      if (widget.branch == null) {
        await Supabase.instance.client.from('sucursales').insert(data);
      } else {
        await Supabase.instance.client
            .from('sucursales')
            .update(data)
            .eq('id', widget.branch!.id);
      }
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local guardado correctamente'),
            backgroundColor: SaharaTheme.gold,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: SaharaTheme.rojoCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.branch != null;
    return Dialog(
      backgroundColor: SaharaTheme.blancoAlmendra,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: Color(0xFFECE9E4))),
              ),
              child: Row(
                children: [
                  Text(
                    isEdit
                        ? 'Editar sucursal'
                        : (kEnableMultiBranch
                              ? 'Nueva sucursal'
                              : 'Sucursal principal'),
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _FormCard(
                      children: [
                        _FieldLabel('Nombre de la sucursal *'),
                        const SizedBox(height: 6),
                        _Field(ctrl: _nameCtrl, hint: kDefaultBranchName),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormCard(
                      children: [
                        _FieldLabel('Direccion Completa'),
                        const SizedBox(height: 6),
                        _Field(
                          ctrl: _addrCtrl,
                          hint: 'Calle, Numero, Ciudad...',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FormCard(
                            children: [
                              _FieldLabel('Telefono'),
                              const SizedBox(height: 6),
                              _Field(
                                ctrl: _phoneCtrl,
                                hint: '+52 ...',
                                type: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormCard(
                            children: [
                              _FieldLabel('WhatsApp'),
                              const SizedBox(height: 6),
                              _Field(
                                ctrl: _whatsappCtrl,
                                hint: '+52 ...',
                                type: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormCard(
                      children: [
                        _FieldLabel('Email de la sucursal'),
                        const SizedBox(height: 6),
                        _Field(
                          ctrl: _emailCtrl,
                          hint: 'local1@saharaclub.com',
                          type: TextInputType.emailAddress,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormCard(
                      children: [
                        _FieldLabel('Link Google Maps'),
                        const SizedBox(height: 6),
                        _Field(
                          ctrl: _mapsCtrl,
                          hint: 'https://maps.google.com/...',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: Color(0xFFECE9E4))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: Text(
                      isEdit ? 'Editar Local' : 'Guardar Sucursal',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SaharaTheme.gold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Form Helpers (Styled like Client Dialog)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFECE9E4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _MiniTimeField extends StatelessWidget {
  const _MiniTimeField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: TextFormField(
        key: ValueKey('$label-$value-$enabled'),
        initialValue: value,
        enabled: enabled,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          hintText: '10:00',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 9,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.ctrl, this.hint, this.type, this.maxLines = 1});
  final TextEditingController ctrl;
  final String? hint;
  final TextInputType? type;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: type,
    maxLines: maxLines,
    style: GoogleFonts.inter(color: Colors.black87, fontSize: 13),
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.black26),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFDDD9D3)),
        borderRadius: BorderRadius.circular(6),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: SaharaTheme.gold),
        borderRadius: BorderRadius.circular(6),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
  );
}
