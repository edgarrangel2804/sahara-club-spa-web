import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/role_permissions.dart';

class ReceptionPermissionsModule extends StatefulWidget {
  const ReceptionPermissionsModule({super.key});

  @override
  State<ReceptionPermissionsModule> createState() =>
      _ReceptionPermissionsModuleState();
}

class _ReceptionPermissionsModuleState extends State<ReceptionPermissionsModule> {
  bool _loading = true;
  bool _saving = false;
  List<RoleModulePermission> _permissions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final permissions = await RolePermissions.fetchRolePermissions(
        RolePermissions.receptionistRole,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _permissions = permissions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los permisos: $e')),
      );
    }
  }

  void _updatePermission(
    String moduleKey, {
    bool? canView,
    bool? canCreate,
    bool? canEdit,
    bool? canDelete,
    bool? canExport,
    bool? canManage,
  }) {
    setState(() {
      _permissions = _permissions.map((permission) {
        if (permission.moduleKey != moduleKey) {
          return permission;
        }
        final updated = permission.copyWith(
          canView: canView,
          canCreate: canCreate,
          canEdit: canEdit,
          canDelete: canDelete,
          canExport: canExport,
          canManage: canManage,
        );
        if (updated.canView) {
          return updated;
        }
        return updated.copyWith(
          canCreate: false,
          canEdit: false,
          canDelete: false,
          canExport: false,
          canManage: false,
        );
      }).toList();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await RolePermissions.saveRolePermissions(
        RolePermissions.receptionistRole,
        _permissions,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos de recepción guardados.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron guardar los permisos: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final definitions = RolePermissions.configurableModules;
    final permissionMap = {
      for (final permission in _permissions) permission.moduleKey: permission,
    };
    return Container(
      color: const Color(0xFFF5F3EF),
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permisos de Recepcion',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          color: const Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Controla exactamente que puede ver y operar la recepcionista.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Recargar'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _loading || _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC6A76A),
                    foregroundColor: Colors.white,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: definitions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final definition = definitions[index];
                      final permission =
                          permissionMap[definition.key] ??
                          RoleModulePermission(
                            moduleKey: definition.key,
                            canView: false,
                            canCreate: false,
                            canEdit: false,
                            canDelete: false,
                            canExport: false,
                            canManage: false,
                          );
                      return _PermissionCard(
                        icon: _iconFor(definition.key),
                        title: definition.title,
                        description: definition.description,
                        permission: permission,
                        onToggle: (field, value) {
                          switch (field) {
                            case 'view':
                              _updatePermission(definition.key, canView: value);
                              break;
                            case 'create':
                              _updatePermission(definition.key, canCreate: value);
                              break;
                            case 'edit':
                              _updatePermission(definition.key, canEdit: value);
                              break;
                            case 'delete':
                              _updatePermission(definition.key, canDelete: value);
                              break;
                            case 'export':
                              _updatePermission(definition.key, canExport: value);
                              break;
                            case 'manage':
                              _updatePermission(definition.key, canManage: value);
                              break;
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'dashboard':
        return Icons.dashboard_outlined;
      case 'agenda':
        return Icons.calendar_today_outlined;
      case 'clients':
        return Icons.people_outline;
      case 'sales':
        return Icons.point_of_sale_outlined;
      case 'messages':
        return Icons.chat_bubble_outline;
      case 'products':
        return Icons.inventory_2_outlined;
      case 'finances':
        return Icons.account_balance_wallet_outlined;
      case 'reports':
        return Icons.bar_chart_outlined;
      case 'payroll':
        return Icons.payments_outlined;
      case 'fixed_expenses':
        return Icons.receipt_long_outlined;
      case 'supplier_expenses':
        return Icons.local_shipping_outlined;
      case 'services':
        return Icons.spa_outlined;
      case 'templates':
        return Icons.text_snippet_outlined;
      case 'whatsapp':
        return Icons.forum_outlined;
      case 'settings':
        return Icons.settings_outlined;
      case 'staff':
        return Icons.badge_outlined;
      case 'memberships':
        return Icons.workspace_premium_outlined;
      case 'gift_cards':
        return Icons.card_giftcard_outlined;
      case 'inventory':
        return Icons.warehouse_outlined;
      case 'analytics':
        return Icons.analytics_outlined;
      case 'administration':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.lock_open_outlined;
    }
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.permission,
    required this.onToggle,
  });

  final IconData icon;
  final String title;
  final String description;
  final RoleModulePermission permission;
  final void Function(String field, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDCA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFC6A76A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFC6A76A)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _ToggleChip(
                label: 'VIEW',
                value: permission.canView,
                onChanged: (value) => onToggle('view', value),
              ),
              _ToggleChip(
                label: 'CREATE',
                value: permission.canCreate,
                enabled: permission.canView,
                onChanged: (value) => onToggle('create', value),
              ),
              _ToggleChip(
                label: 'EDIT',
                value: permission.canEdit,
                enabled: permission.canView,
                onChanged: (value) => onToggle('edit', value),
              ),
              _ToggleChip(
                label: 'DELETE',
                value: permission.canDelete,
                enabled: permission.canView,
                onChanged: (value) => onToggle('delete', value),
              ),
              _ToggleChip(
                label: 'EXPORT',
                value: permission.canExport,
                enabled: permission.canView,
                onChanged: (value) => onToggle('export', value),
              ),
              _ToggleChip(
                label: 'MANAGE',
                value: permission.canManage,
                enabled: permission.canView,
                onChanged: (value) => onToggle('manage', value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFFC6A76A).withValues(alpha: 0.12)
            : const Color(0xFFF4F1EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? const Color(0xFFC6A76A) : const Color(0xFFE2D8C8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? const Color(0xFF4B3A22)
                  : const Color(0xFFB3A893),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: const Color(0xFFC6A76A),
          ),
        ],
      ),
    );
  }
}
