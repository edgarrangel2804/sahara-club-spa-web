import 'package:supabase_flutter/supabase_flutter.dart';

class PermissionModuleDefinition {
  const PermissionModuleDefinition({
    required this.key,
    required this.title,
    required this.description,
    this.topNavId,
  });

  final String key;
  final String title;
  final String description;
  final String? topNavId;
}

class RoleModulePermission {
  const RoleModulePermission({
    required this.moduleKey,
    required this.canView,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.canExport,
    required this.canManage,
  });

  final String moduleKey;
  final bool canView;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canExport;
  final bool canManage;

  factory RoleModulePermission.fromMap(Map<String, dynamic> map) {
    return RoleModulePermission(
      moduleKey: map['module_key']?.toString() ?? '',
      canView: map['can_view'] == true,
      canCreate: map['can_create'] == true,
      canEdit: map['can_edit'] == true,
      canDelete: map['can_delete'] == true,
      canExport: map['can_export'] == true,
      canManage: map['can_manage'] == true,
    );
  }

  RoleModulePermission copyWith({
    bool? canView,
    bool? canCreate,
    bool? canEdit,
    bool? canDelete,
    bool? canExport,
    bool? canManage,
  }) {
    return RoleModulePermission(
      moduleKey: moduleKey,
      canView: canView ?? this.canView,
      canCreate: canCreate ?? this.canCreate,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      canExport: canExport ?? this.canExport,
      canManage: canManage ?? this.canManage,
    );
  }

  Map<String, dynamic> toDbMap(String role) {
    return {
      'role': role,
      'module_key': moduleKey,
      'can_view': canView,
      'can_create': canCreate,
      'can_edit': canEdit,
      'can_delete': canDelete,
      'can_export': canExport,
      'can_manage': canManage,
    };
  }
}

class RolePermissions {
  const RolePermissions._();

  static const receptionistRole = 'receptionist';

  static final List<PermissionModuleDefinition> _definitions = [
    const PermissionModuleDefinition(
      key: 'dashboard',
      title: 'Dashboard',
      description: 'Vista general operativa del sistema.',
    ),
    const PermissionModuleDefinition(
      key: 'agenda',
      title: 'Agenda',
      description: 'Permite administrar citas y reservas.',
      topNavId: 'agenda',
    ),
    const PermissionModuleDefinition(
      key: 'clients',
      title: 'Clientes',
      description: 'Permite consultar y administrar clientes.',
      topNavId: 'clientes',
    ),
    const PermissionModuleDefinition(
      key: 'sales',
      title: 'Ventas',
      description: 'Permite cobrar, generar tickets y revisar ventas.',
      topNavId: 'ventas',
    ),
    const PermissionModuleDefinition(
      key: 'messages',
      title: 'Mensajes',
      description: 'Permite enviar mensajes y dar seguimiento.',
      topNavId: 'mensajes',
    ),
    const PermissionModuleDefinition(
      key: 'products',
      title: 'Productos',
      description: 'Acceso al catalogo y administracion de productos.',
      topNavId: 'productos',
    ),
    const PermissionModuleDefinition(
      key: 'finances',
      title: 'Finanzas',
      description: 'Acceso a ventas, ingresos, egresos y ganancia neta.',
      topNavId: 'finanzas',
    ),
    const PermissionModuleDefinition(
      key: 'reports',
      title: 'Reportes',
      description: 'Acceso a reportes operativos y administrativos.',
      topNavId: 'reportes',
    ),
    const PermissionModuleDefinition(
      key: 'payroll',
      title: 'Nomina',
      description: 'Permite ver y administrar nomina.',
    ),
    const PermissionModuleDefinition(
      key: 'fixed_expenses',
      title: 'Gastos fijos',
      description: 'Permite registrar y consultar gastos recurrentes.',
    ),
    const PermissionModuleDefinition(
      key: 'supplier_expenses',
      title: 'Gastos proveedores',
      description: 'Permite registrar compras e insumos de proveedores.',
    ),
    const PermissionModuleDefinition(
      key: 'services',
      title: 'Servicios',
      description: 'Acceso a catalogo y configuracion de servicios.',
    ),
    const PermissionModuleDefinition(
      key: 'templates',
      title: 'Plantillas WhatsApp',
      description: 'Permite administrar plantillas de mensajes.',
    ),
    const PermissionModuleDefinition(
      key: 'whatsapp',
      title: 'WhatsApp',
      description: 'Permite configurar integraciones y flujos de WhatsApp.',
    ),
    const PermissionModuleDefinition(
      key: 'settings',
      title: 'Configuraciones',
      description: 'Permite modificar configuraciones del negocio.',
    ),
    const PermissionModuleDefinition(
      key: 'staff',
      title: 'Personal',
      description: 'Permite administrar terapeutas y colaboradores.',
    ),
    const PermissionModuleDefinition(
      key: 'memberships',
      title: 'Membresias',
      description: 'Permite administrar membresias.',
    ),
    const PermissionModuleDefinition(
      key: 'gift_cards',
      title: 'Gift Cards',
      description: 'Permite administrar tarjetas de regalo.',
    ),
    const PermissionModuleDefinition(
      key: 'inventory',
      title: 'Inventario',
      description: 'Permite consultar y administrar inventario.',
    ),
    const PermissionModuleDefinition(
      key: 'analytics',
      title: 'Estadisticas',
      description: 'Permite ver indicadores y tendencias.',
    ),
    const PermissionModuleDefinition(
      key: 'administration',
      title: 'Administracion',
      description: 'Centro de control administrativo.',
      topNavId: 'admin',
    ),
  ];

  static final Map<String, Map<String, RoleModulePermission>> _cache = {};

  static List<PermissionModuleDefinition> get configurableModules =>
      List.unmodifiable(_definitions);

  static String normalize(String? role) {
    final value = (role ?? '').trim().toLowerCase();
    if (value.isEmpty) {
      return 'reception';
    }
    return value;
  }

  static String canonicalRole(String? role) {
    final value = normalize(role);
    if (value == 'reception') {
      return receptionistRole;
    }
    return value;
  }

  static bool isSuperAdmin(String? role) => normalize(role) == 'super_admin';

  static bool isAdmin(String? role) => normalize(role) == 'admin';

  static bool isAdminLevel(String? role) =>
      isAdmin(role) || isSuperAdmin(role);

  static bool isReception(String? role) {
    final value = normalize(role);
    return value == 'reception' || value == receptionistRole;
  }

  static bool isTherapist(String? role) => normalize(role) == 'therapist';

  static bool isClient(String? role) => normalize(role) == 'client';

  static Future<void> warmup(String? role, {bool forceRefresh = false}) async {
    final normalized = canonicalRole(role);
    if (!forceRefresh && _cache.containsKey(normalized)) {
      return;
    }

    if (isAdminLevel(normalized) || isTherapist(normalized) || isClient(normalized)) {
      _cache[normalized] = _buildDefaultMap(normalized);
      return;
    }

    final defaults = _buildDefaultMap(normalized);
    try {
      final rows = await Supabase.instance.client
          .from('role_permissions')
          .select(
            'module_key, can_view, can_create, can_edit, can_delete, can_export, can_manage',
          )
          .eq('role', normalized);
      final merged = <String, RoleModulePermission>{...defaults};
      for (final row in (rows as List)) {
        final permission = RoleModulePermission.fromMap(
          Map<String, dynamic>.from(row as Map),
        );
        if (permission.moduleKey.isEmpty) {
          continue;
        }
        merged[permission.moduleKey] = permission;
      }
      _cache[normalized] = merged;
    } catch (_) {
      _cache[normalized] = defaults;
    }
  }

  static Future<List<RoleModulePermission>> fetchRolePermissions(
    String role, {
    bool forceRefresh = false,
  }) async {
    await warmup(role, forceRefresh: forceRefresh);
    final normalized = canonicalRole(role);
    final map = _cache[normalized] ?? _buildDefaultMap(normalized);
    return _definitions
        .map((definition) => map[definition.key] ?? _defaultFor(normalized, definition.key))
        .toList();
  }

  static Future<void> saveRolePermissions(
    String role,
    List<RoleModulePermission> permissions,
  ) async {
    final normalized = canonicalRole(role);
    final rows = permissions
        .map((permission) => permission.toDbMap(normalized))
        .toList();
    await Supabase.instance.client
        .from('role_permissions')
        .upsert(rows, onConflict: 'role,module_key');
    _cache[normalized] = {
      for (final permission in permissions) permission.moduleKey: permission,
    };
  }

  static List<String> visibleModulesFor(String? role) {
    final normalized = canonicalRole(role);
    if (isAdminLevel(normalized)) {
      return const ['agenda', 'clientes', 'ventas', 'mensajes', 'admin'];
    }
    if (isTherapist(normalized)) {
      return const ['agenda'];
    }
    if (isClient(normalized)) {
      return const ['agenda'];
    }

    final permissions = _cache[normalized] ?? _buildDefaultMap(normalized);
    return _definitions
        .where((definition) => definition.topNavId != null)
        .where((definition) => definition.key != 'administration')
        .where(
          (definition) => permissions[definition.key]?.canView == true,
        )
        .map((definition) => definition.topNavId!)
        .toList();
  }

  static bool canAccessModule(String? role, String moduleId) =>
      visibleModulesFor(role).contains(moduleId);

  static bool canViewModuleKey(String? role, String moduleKey) {
    return _permissionFor(role, moduleKey).canView;
  }

  static bool hasCapability(
    String? role,
    String moduleKey,
    String capability,
  ) {
    final permission = _permissionFor(role, moduleKey);
    switch (capability) {
      case 'view':
        return permission.canView;
      case 'create':
        return permission.canCreate;
      case 'edit':
        return permission.canEdit;
      case 'delete':
        return permission.canDelete;
      case 'export':
        return permission.canExport;
      case 'manage':
        return permission.canManage;
      default:
        return false;
    }
  }

  static String moduleKeyForNavId(String navId) {
    switch (navId) {
      case 'clientes':
        return 'clients';
      case 'ventas':
        return 'sales';
      case 'mensajes':
        return 'messages';
      case 'productos':
        return 'products';
      case 'finanzas':
        return 'finances';
      case 'reportes':
        return 'reports';
      case 'admin':
        return 'administration';
      default:
        return navId;
    }
  }

  static RoleModulePermission _permissionFor(String? role, String moduleKey) {
    final normalized = canonicalRole(role);
    if (isAdminLevel(normalized)) {
      return RoleModulePermission(
        moduleKey: moduleKey,
        canView: true,
        canCreate: true,
        canEdit: true,
        canDelete: true,
        canExport: true,
        canManage: true,
      );
    }
    final map = _cache[normalized] ?? _buildDefaultMap(normalized);
    return map[moduleKey] ?? _defaultFor(normalized, moduleKey);
  }

  static Map<String, RoleModulePermission> _buildDefaultMap(String role) {
    return {
      for (final definition in _definitions)
        definition.key: _defaultFor(role, definition.key),
    };
  }

  static RoleModulePermission _defaultFor(String role, String moduleKey) {
    if (isAdminLevel(role)) {
      return RoleModulePermission(
        moduleKey: moduleKey,
        canView: true,
        canCreate: true,
        canEdit: true,
        canDelete: true,
        canExport: true,
        canManage: true,
      );
    }

    if (isTherapist(role)) {
      final agenda = moduleKey == 'agenda';
      return RoleModulePermission(
        moduleKey: moduleKey,
        canView: agenda,
        canCreate: false,
        canEdit: agenda,
        canDelete: false,
        canExport: false,
        canManage: false,
      );
    }

    if (isClient(role)) {
      final agenda = moduleKey == 'agenda';
      return RoleModulePermission(
        moduleKey: moduleKey,
        canView: agenda,
        canCreate: agenda,
        canEdit: false,
        canDelete: false,
        canExport: false,
        canManage: false,
      );
    }

    final receptionDefaults = {
      'agenda': const [true, true, true, false, false, false],
      'clients': const [true, true, true, false, false, false],
      'sales': const [true, true, true, false, false, false],
      'messages': const [true, true, true, false, false, false],
    };
    final values =
        receptionDefaults[moduleKey] ?? const [false, false, false, false, false, false];
    return RoleModulePermission(
      moduleKey: moduleKey,
      canView: values[0],
      canCreate: values[1],
      canEdit: values[2],
      canDelete: values[3],
      canExport: values[4],
      canManage: values[5],
    );
  }
}
