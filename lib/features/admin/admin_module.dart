import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class _Staff {
  final String id;
  String fullName;
  String email;
  String phone;
  String role;
  bool   active;

  _Staff({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.active,
  });

  factory _Staff.fromMap(Map<String, dynamic> m) => _Staff(
    id:       m['id']        as String,
    fullName: m['full_name'] as String? ?? '',
    email:    m['email']     as String? ?? '',
    phone:    m['phone']     as String? ?? '',
    role:     m['role']      as String? ?? 'therapist',
    active:   m['active']    as bool?   ?? true,
  );
}

class _ServiceItem {
  final String id;
  String name;
  String category;
  int    duration;
  double price;
  bool   active;

  _ServiceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.duration,
    required this.price,
    required this.active,
  });

  factory _ServiceItem.fromMap(Map<String, dynamic> m) => _ServiceItem(
    id:       m['id']       as String,
    name:     m['name']     as String? ?? '',
    category: m['category'] as String? ?? '',
    duration: (m['duration'] as num?)?.toInt() ?? 60,
    price:    (m['price']    as num?)?.toDouble() ?? 0,
    active:   m['active']   as bool? ?? true,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────
class AdminModule extends StatefulWidget {
  const AdminModule({super.key});

  @override
  State<AdminModule> createState() => _AdminModuleState();
}

class _AdminModuleState extends State<AdminModule>
    with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 2, vsync: this);
  bool _loading = true;
  List<_Staff>       _staff    = [];
  List<_ServiceItem> _services = [];

  @override
  void initState() {
    super.initState();
    _load();
    _tab.addListener(() { if (!_tab.indexIsChanging) _load(); });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_tab.index == 0) {
        final data = await Supabase.instance.client
            .from('staff')
            .select()
            .inFilter('role', ['therapist', 'receptionist', 'admin'])
            .order('full_name');
        if (!mounted) return;
        _staff = (data as List)
            .map((m) => _Staff.fromMap(m as Map<String, dynamic>))
            .toList();
      } else {
        final data = await Supabase.instance.client
            .from('services')
            .select()
            .order('name');
        if (!mounted) return;
        _services = (data as List)
            .map((m) => _ServiceItem.fromMap(m as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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

  Future<void> _deleteStaff(_Staff s) async {
    final ok = await _confirmDelete(context, 'Eliminar staff',
        '¿Eliminar a "${s.fullName}"? Esta acción no se puede deshacer.');
    if (ok != true) return;
    await Supabase.instance.client.from('staff').delete().eq('id', s.id);
    _load();
  }

  Future<void> _deleteService(_ServiceItem s) async {
    final ok = await _confirmDelete(context, 'Eliminar servicio',
        '¿Eliminar "${s.name}"? Esta acción no se puede deshacer.');
    if (ok != true) return;
    await Supabase.instance.client.from('services').delete().eq('id', s.id);
    _load();
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
              Text('Administración',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20, fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                )),
              const SizedBox(width: 28),
              TabBar(
                controller: _tab,
                isScrollable: true,
                labelColor: const Color(0xFFC6A76A),
                unselectedLabelColor: Colors.black45,
                indicatorColor: const Color(0xFFC6A76A),
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                tabs: const [
                  Tab(text: 'Personal'),
                  Tab(text: 'Servicios'),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _tab.index == 0
                    ? _openStaffForm()
                    : _openServiceForm(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC6A76A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: AnimatedBuilder(
                  animation: _tab,
                  builder: (_, __) => Text(
                    _tab.index == 0 ? 'Nuevo miembro' : 'Nuevo servicio',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Body ───────────────────────────────────────────────
        Expanded(
          child: Container(
            color: const Color(0xFFF5F3EF),
            child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _StaffTab(
                      staff:         _staff,
                      onToggle:      _toggleStaffActive,
                      onEdit:        _openStaffForm,
                      onDelete:      _deleteStaff,
                    ),
                    _ServicesTab(
                      services:  _services,
                      onToggle:  _toggleServiceActive,
                      onEdit:    _openServiceForm,
                      onDelete:  _deleteService,
                    ),
                  ],
                ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staff Tab
// ─────────────────────────────────────────────────────────────────────────────
class _StaffTab extends StatelessWidget {
  const _StaffTab({
    required this.staff,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final List<_Staff>           staff;
  final void Function(_Staff)  onToggle;
  final void Function(_Staff)  onEdit;
  final void Function(_Staff)  onDelete;

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return Center(child: Text('No hay personal registrado',
        style: GoogleFonts.inter(fontSize: 14, color: Colors.black38)));
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
              child: Row(children: [
                _Th('NOMBRE',   flex: 3),
                _Th('ROL',      flex: 2),
                _Th('CONTACTO', flex: 3),
                _Th('ESTADO',   flex: 1),
                const SizedBox(width: 80),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: staff.length,
                separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF5F5F5)),
                itemBuilder: (_, i) {
                  final s = staff[i];
                  return _StaffRow(
                    staff:    s,
                    onToggle: () => onToggle(s),
                    onEdit:   () => onEdit(s),
                    onDelete: () => onDelete(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffRow extends StatefulWidget {
  const _StaffRow({
    required this.staff,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final _Staff       staff;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_StaffRow> createState() => _StaffRowState();
}

class _StaffRowState extends State<_StaffRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.staff;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hover ? const Color(0xFFFAFAFA) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(flex: 3, child: Row(children: [
              _Avatar(name: s.fullName, size: 34),
              const SizedBox(width: 10),
              Expanded(child: Text(s.fullName,
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ))),
            ])),
            Expanded(flex: 2, child: _RoleBadge(role: s.role)),
            Expanded(flex: 3, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.email.isNotEmpty)
                  Text(s.email, style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
                    overflow: TextOverflow.ellipsis),
                if (s.phone.isNotEmpty)
                  Text(s.phone, style: GoogleFonts.inter(fontSize: 12, color: Colors.black38)),
              ],
            )),
            Expanded(flex: 1, child: Switch(
              value: s.active,
              activeColor: const Color(0xFFC6A76A),
              onChanged: (_) => widget.onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: Colors.black38,
                    onPressed: widget.onEdit,
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: Colors.red.shade300,
                    onPressed: widget.onDelete,
                    tooltip: 'Eliminar',
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

// ─────────────────────────────────────────────────────────────────────────────
// Services Tab
// ─────────────────────────────────────────────────────────────────────────────
class _ServicesTab extends StatelessWidget {
  const _ServicesTab({
    required this.services,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final List<_ServiceItem>           services;
  final void Function(_ServiceItem)  onToggle;
  final void Function(_ServiceItem)  onEdit;
  final void Function(_ServiceItem)  onDelete;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Center(child: Text('No hay servicios registrados',
        style: GoogleFonts.inter(fontSize: 14, color: Colors.black38)));
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
              child: Row(children: [
                _Th('SERVICIO',  flex: 3),
                _Th('CATEGORÍA', flex: 2),
                _Th('DURACIÓN',  flex: 1),
                _Th('PRECIO',    flex: 1),
                _Th('ACTIVO',    flex: 1),
                const SizedBox(width: 80),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: services.length,
                separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF5F5F5)),
                itemBuilder: (_, i) {
                  final s = services[i];
                  return _ServiceRow(
                    service:  s,
                    onToggle: () => onToggle(s),
                    onEdit:   () => onEdit(s),
                    onDelete: () => onDelete(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatefulWidget {
  const _ServiceRow({
    required this.service,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final _ServiceItem service;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hover ? const Color(0xFFFAFAFA) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(s.name,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ))),
            Expanded(flex: 2, child: Text(s.category,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black54))),
            Expanded(flex: 1, child: Text('${s.duration} min',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black54))),
            Expanded(flex: 1, child: Text('\$${s.price.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ))),
            Expanded(flex: 1, child: Switch(
              value: s.active,
              activeColor: const Color(0xFFC6A76A),
              onChanged: (_) => widget.onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: Colors.black38,
                    onPressed: widget.onEdit,
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: Colors.red.shade300,
                    onPressed: widget.onDelete,
                    tooltip: 'Eliminar',
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

// ─────────────────────────────────────────────────────────────────────────────
// Staff Form Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _StaffFormDialog extends StatefulWidget {
  const _StaffFormDialog({this.staff, required this.onSaved});
  final _Staff?      staff;
  final VoidCallback onSaved;

  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name  = TextEditingController(text: widget.staff?.fullName ?? '');
  late final _email = TextEditingController(text: widget.staff?.email    ?? '');
  late final _phone = TextEditingController(text: widget.staff?.phone    ?? '');
  late String _role   = widget.staff?.role   ?? 'therapist';
  late bool   _active = widget.staff?.active ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'full_name': _name.text.trim(),
        'email':     _email.text.trim(),
        'phone':     _phone.text.trim(),
        'role':      _role,
        'active':    _active,
      };
      if (widget.staff == null) {
        await Supabase.instance.client.from('staff').insert(payload);
      } else {
        await Supabase.instance.client
            .from('staff').update(payload).eq('id', widget.staff!.id);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.staff != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Editar miembro' : 'Nuevo miembro del personal',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20, fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 24),
                _Field(label: 'NOMBRE COMPLETO *', child: TextFormField(
                  controller: _name,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: _deco('Ej: Ana González'),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requerido' : null,
                )),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _Field(label: 'EMAIL', child: TextFormField(
                    controller: _email,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _deco('email@ejemplo.com'),
                    keyboardType: TextInputType.emailAddress,
                  ))),
                  const SizedBox(width: 14),
                  Expanded(child: _Field(label: 'TELÉFONO', child: TextFormField(
                    controller: _phone,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _deco('+52 555 000 0000'),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-]'))],
                  ))),
                ]),
                const SizedBox(height: 14),
                _Field(label: 'ROL', child: DropdownButtonFormField<String>(
                  value: _role,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                  decoration: _deco(null),
                  items: const [
                    DropdownMenuItem(value: 'therapist',  child: Text('Terapeuta')),
                    DropdownMenuItem(value: 'receptionist',  child: Text('Recepción')),
                    DropdownMenuItem(value: 'admin',      child: Text('Administrador')),
                  ],
                  onChanged: (v) => setState(() => _role = v!),
                )),
                const SizedBox(height: 14),
                Row(children: [
                  Switch(
                    value: _active,
                    activeColor: const Color(0xFFC6A76A),
                    onChanged: (v) => setState(() => _active = v)),
                  const SizedBox(width: 8),
                  Text('Activo', style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
                ]),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar', style: GoogleFonts.inter())),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC6A76A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _saving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Guardar cambios' : 'Agregar',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
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

// ─────────────────────────────────────────────────────────────────────────────
// Service Form Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceFormDialog extends StatefulWidget {
  const _ServiceFormDialog({this.service, required this.onSaved});
  final _ServiceItem? service;
  final VoidCallback  onSaved;

  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name     = TextEditingController(text: widget.service?.name     ?? '');
  late final _category = TextEditingController(text: widget.service?.category ?? '');
  late final _duration = TextEditingController(
      text: widget.service != null ? '${widget.service!.duration}' : '60');
  late final _price    = TextEditingController(
      text: widget.service != null ? widget.service!.price.toStringAsFixed(0) : '');
  late bool _active = widget.service?.active ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _category.dispose();
    _duration.dispose(); _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'name':     _name.text.trim(),
        'category': _category.text.trim(),
        'duration': int.tryParse(_duration.text)    ?? 60,
        'price':    double.tryParse(_price.text)    ?? 0,
        'active':   _active,
      };
      if (widget.service == null) {
        await Supabase.instance.client.from('services').insert(payload);
      } else {
        await Supabase.instance.client
            .from('services').update(payload).eq('id', widget.service!.id);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.service != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Editar servicio' : 'Nuevo servicio',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20, fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 24),
                _Field(label: 'NOMBRE *', child: TextFormField(
                  controller: _name,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: _deco('Ej: Masaje relajante'),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requerido' : null,
                )),
                const SizedBox(height: 14),
                _Field(label: 'CATEGORÍA', child: TextFormField(
                  controller: _category,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: _deco('Ej: Masajes, Faciales, Corporales...'),
                )),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _Field(label: 'DURACIÓN (min) *', child: TextFormField(
                    controller: _duration,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _deco('60'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null,
                  ))),
                  const SizedBox(width: 14),
                  Expanded(child: _Field(label: 'PRECIO *', child: TextFormField(
                    controller: _price,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _deco('\$0').copyWith(prefixText: '\$'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null,
                  ))),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Switch(
                    value: _active,
                    activeColor: const Color(0xFFC6A76A),
                    onChanged: (v) => setState(() => _active = v)),
                  const SizedBox(width: 8),
                  Text('Activo', style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
                ]),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar', style: GoogleFonts.inter())),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC6A76A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _saving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Guardar cambios' : 'Crear servicio',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});
  final String name;
  final double size;

  static const _colors = [
    Color(0xFFE8D5B7), Color(0xFFB7D5E8), Color(0xFFD5E8B7),
    Color(0xFFE8B7D5), Color(0xFFD5B7E8), Color(0xFFB7E8D5),
    Color(0xFFE8C4B7), Color(0xFFB7C4E8),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % 8;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _colors[idx]),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  static const _meta = {
    'therapist': ('Terapeuta',     Color(0xFF5B8FF9)),
    'reception': ('Recepción',     Color(0xFFC6A76A)),
    'admin':     ('Administrador', Color(0xFF52C41A)),
  };

  @override
  Widget build(BuildContext context) {
    final m = _meta[role] ?? (role, const Color(0xFF888888));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (m.$2).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(m.$1,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: m.$2,
        )),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text, {this.flex = 1});
  final String text;
  final int    flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text,
        style: GoogleFonts.inter(
          fontSize: 11, letterSpacing: 1.2,
          color: Colors.black38, fontWeight: FontWeight.w600,
        )),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(
        fontSize: 11, letterSpacing: 1.2, color: Colors.black38)),
      const SizedBox(height: 5),
      child,
    ]);
  }
}

InputDecoration _deco(String? hint) => InputDecoration(
  hintText: hint,
  hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black26),
  filled: true,
  fillColor: const Color(0xFFF8F8F8),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

Future<bool?> _confirmDelete(BuildContext context, String title, String msg) =>
  showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      content: Text(msg, style: GoogleFonts.inter()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancelar', style: GoogleFonts.inter())),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Eliminar', style: GoogleFonts.inter())),
      ],
    ),
  );
