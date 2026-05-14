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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Models
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _Staff {
  final String id;
  String fullName;
  String email;
  String phone;
  String role;
  bool active;

  _Staff({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.active,
  });

  factory _Staff.fromMap(Map<String, dynamic> m) => _Staff(
    id: m['id'] as String,
    fullName: m['full_name'] as String? ?? '',
    email: m['email'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    role: m['role'] as String? ?? 'therapist',
    active: m['active'] as bool? ?? true,
  );
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
  late final _tab = TabController(length: 7, vsync: this);
  bool _loading = true;
  List<_Staff> _staff = [];
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

      final resS = await Supabase.instance.client.from('staff').select();
      final resV = await Supabase.instance.client.from('services').select();
      final resW = await Supabase.instance.client
          .from('whatsapp_templates')
          .select();

      if (_canAccessAdministration) {
        final resB = await Supabase.instance.client.from('sucursales').select();
        _branches = (resB as List).map((m) => _Branch.fromMap(m)).toList();
        if (!kEnableMultiBranch && _branches.isEmpty) {
          _branches = [
            _Branch.fromMap(defaultBranchMap()),
          ];
        }
      }

      if (!mounted) return;
      setState(() {
        _staff = (resS as List).map((m) => _Staff.fromMap(m)).toList();
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
      builder: (_) => _StaffFormDialog(staff: edit, onSaved: _load),
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
      'Seguro que deseas eliminar a ${s.fullName}?',
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
                            'Administracion',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Centro privado de operacion, configuracion y control interno de Sahara.',
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
                    AnimatedBuilder(
                      animation: _tab,
                      builder: (_, __) {
                        if (_tab.index >= 3) return const SizedBox.shrink();
                        return FilledButton.icon(
                          onPressed: () {
                            if (_tab.index == 0) {
                              _openStaffForm();
                            } else if (_tab.index == 1) {
                              _openServiceForm();
                            } else {
                              _openWhatsAppForm();
                            }
                          },
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
                            _tab.index == 1
                                ? 'Nuevo servicio'
                                : (_tab.index == 2
                                      ? 'Nueva plantilla'
                                      : 'Nuevo miembro'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F0E6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: SaharaTheme.gold.withValues(alpha: 0.16),
                    ),
                  ),
                  child: TabBar(
                    controller: _tab,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(14),
                    labelColor: const Color(0xFF1F170F),
                    unselectedLabelColor: const Color(0xFF7D7366),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      border: Border.all(
                        color: SaharaTheme.gold.withValues(alpha: 0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2B2118).withValues(alpha: 0.05),
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
                      Tab(text: 'Personal'),
                      Tab(text: 'Servicios'),
                      Tab(text: 'Plantillas WhatsApp'),
                      Tab(text: 'Productos'),
                      Tab(text: 'Finanzas'),
                      Tab(text: 'Permisos Recepcion'),
                      Tab(text: 'Configuración'),
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
                        onToggle: _toggleStaffActive,
                        onEdit: _openStaffForm,
                        onDelete: _deleteStaff,
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
class _StaffTab extends StatelessWidget {
  const _StaffTab({
    required this.staff,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final List<_Staff> staff;
  final void Function(_Staff) onToggle;
  final void Function(_Staff) onEdit;
  final void Function(_Staff) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: staff.length,
      itemBuilder: (_, i) {
        final s = staff[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: _Avatar(name: s.fullName, size: 40),
            title: Text(
              s.fullName,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(s.role, style: GoogleFonts.inter(fontSize: 12)),
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
                          _PhoneMockup(child: _MsgBubble(text: _previewMessage)),
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
                          'branch_id': widget.template.branchId ?? kDefaultBranchId,
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
  const _StaffFormDialog({required this.staff, required this.onSaved});
  final _Staff? staff;
  final VoidCallback onSaved;
  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  late final _name = TextEditingController(text: widget.staff?.fullName ?? '');
  late String _role = widget.staff?.role ?? 'therapist';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.staff != null;
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
                    isEdit ? 'Editar personal' : 'Nuevo personal',
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
                        _FieldLabel('Nombre completo *'),
                        const SizedBox(height: 6),
                        _Field(ctrl: _name, hint: 'Ej: Juan Perez'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormCard(
                      children: [
                        _FieldLabel('Rol'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _role,
                          dropdownColor: Colors.white,
                          style: GoogleFonts.inter(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFFDDD9D3),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: SaharaTheme.gold,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'therapist',
                              child: Text('Terapeuta'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Administrador'),
                            ),
                            DropdownMenuItem(
                              value: 'reception',
                              child: Text('Recepcion'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _role = v!),
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
                    onPressed: _saving
                        ? null
                        : () async {
                            if (_name.text.trim().isEmpty) return;
                            setState(() => _saving = true);
                            try {
                              final data = {
                                'full_name': _name.text.trim(),
                                'role': _role,
                              };
                              if (widget.staff == null) {
                                await Supabase.instance.client
                                    .from('staff')
                                    .insert(data);
                              } else {
                                await Supabase.instance.client
                                    .from('staff')
                                    .update(data)
                                    .eq('id', widget.staff!.id);
                              }
                              widget.onSaved();
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Personal guardado correctamente',
                                    ),
                                    backgroundColor: SaharaTheme.gold,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
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
                      isEdit ? 'Guardar cambios' : 'Crear personal',
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) =>
      CircleAvatar(radius: size / 2, child: Text(name.isEmpty ? '?' : name[0]));
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Settings Tab (WhatsApp Config + Branches CRUD)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
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
      final payload = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            payload['message'] as String? ?? 'Mensaje de prueba enviado.',
          ),
          backgroundColor: const Color(0xFF1A9E65),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo enviar el mensaje de prueba. Verifica el numero y la conexion.',
          ),
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
                  color: _statusColor(_settings.connectionStatus).withValues(
                    alpha: 0.12,
                  ),
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
                      onToggle: () => setState(
                        () => _showAccessToken = !_showAccessToken,
                      ),
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
                      onToggle: () => setState(
                        () => _showAppSecret = !_showAppSecret,
                      ),
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
                        : (kEnableMultiBranch ? 'Nueva sucursal' : 'Sucursal principal'),
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
                        _Field(
                          ctrl: _nameCtrl,
                          hint: kDefaultBranchName,
                        ),
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
