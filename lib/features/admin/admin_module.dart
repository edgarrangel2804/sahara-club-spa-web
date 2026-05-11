import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

class WhatsAppTemplate {
  final String id;
  String title;
  String message;
  String type;
  bool   active;

  WhatsAppTemplate({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.active,
  });

  factory WhatsAppTemplate.fromMap(Map<String, dynamic> m) => WhatsAppTemplate(
    id:      m['id']      as String,
    title:   m['title']   as String? ?? '',
    message: m['message'] as String? ?? '',
    type:    m['type']    as String? ?? 'custom',
    active:  m['active']  as bool?   ?? true,
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
  late final _tab = TabController(length: 3, vsync: this);
  bool _loading = true;
  List<_Staff>           _staff     = [];
  List<_ServiceItem>     _services  = [];
  List<WhatsAppTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resS = await Supabase.instance.client.from('staff').select();
      final resV = await Supabase.instance.client.from('services').select();
      final resW = await Supabase.instance.client.from('whatsapp_templates').select();
      
      if (!mounted) return;
      setState(() {
        _staff     = (resS as List).map((m) => _Staff.fromMap(m)).toList();
        _services  = (resV as List).map((m) => _ServiceItem.fromMap(m)).toList();
        _templates = (resW as List).map((m) => WhatsAppTemplate.fromMap(m)).toList();
        _loading   = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStaffActive(_Staff s) async {
    try {
      await Supabase.instance.client.from('staff').update({'active': !s.active}).eq('id', s.id);
      _load();
    } catch (_) {}
  }

  Future<void> _toggleServiceActive(_ServiceItem s) async {
    try {
      await Supabase.instance.client.from('services').update({'active': !s.active}).eq('id', s.id);
      _load();
    } catch (_) {}
  }

  Future<void> _toggleTemplateActive(WhatsAppTemplate s) async {
    try {
      await Supabase.instance.client.from('whatsapp_templates').update({'active': !s.active}).eq('id', s.id);
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
    final ok = await _confirmDelete(context, 'Eliminar miembro', '¿Seguro que deseas eliminar a ${s.fullName}?');
    if (ok == true) {
      await Supabase.instance.client.from('staff').delete().eq('id', s.id);
      _load();
    }
  }

  Future<void> _deleteService(_ServiceItem s) async {
    final ok = await _confirmDelete(context, 'Eliminar servicio', '¿Seguro que deseas eliminar el servicio ${s.name}?');
    if (ok == true) {
      await Supabase.instance.client.from('services').delete().eq('id', s.id);
      _load();
    }
  }

  Future<void> _deleteTemplate(WhatsAppTemplate s) async {
    final ok = await _confirmDelete(context, 'Eliminar plantilla', '¿Seguro que deseas eliminar esta plantilla?');
    if (ok == true) {
      await Supabase.instance.client.from('whatsapp_templates').delete().eq('id', s.id);
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                Text('Administración',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                const SizedBox(width: 40),
                TabBar(
                  controller: _tab,
                  isScrollable: true,
                  labelColor: const Color(0xFFC6A76A),
                  unselectedLabelColor: Colors.black45,
                  indicatorColor: const Color(0xFFC6A76A),
                  labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                  tabs: const [
                    Tab(text: 'Personal'),
                    Tab(text: 'Servicios'),
                    Tab(text: 'WhatsApp'),
                  ],
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    if (_tab.index == 0) _openStaffForm();
                    else if (_tab.index == 1) _openServiceForm();
                    else _openWhatsAppForm();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC6A76A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: AnimatedBuilder(
                    animation: _tab,
                    builder: (_, __) {
                      String label = 'Nuevo miembro';
                      if (_tab.index == 1) label = 'Nuevo servicio';
                      if (_tab.index == 2) label = 'Nueva plantilla';
                      return Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600));
                    },
                  ),
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
                    _StaffTab(staff: _staff, onToggle: _toggleStaffActive, onEdit: _openStaffForm, onDelete: _deleteStaff),
                    _ServicesTab(services: _services, onToggle: _toggleServiceActive, onEdit: _openServiceForm, onDelete: _deleteService),
                    _WhatsAppTab(templates: _templates, onToggle: _toggleTemplateActive, onEdit: _openWhatsAppForm, onDelete: _deleteTemplate),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabs
// ─────────────────────────────────────────────────────────────────────────────
class _StaffTab extends StatelessWidget {
  const _StaffTab({required this.staff, required this.onToggle, required this.onEdit, required this.onDelete});
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
            title: Text(s.fullName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text(s.role, style: GoogleFonts.inter(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: s.active, activeThumbColor: const Color(0xFFC6A76A), onChanged: (_) => onToggle(s)),
                IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => onEdit(s)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => onDelete(s)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ServicesTab extends StatelessWidget {
  const _ServicesTab({required this.services, required this.onToggle, required this.onEdit, required this.onDelete});
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
            title: Text(s.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text('${s.category} · ${s.duration} min · \$${s.price}', style: GoogleFonts.inter(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: s.active, activeThumbColor: const Color(0xFFC6A76A), onChanged: (_) => onToggle(s)),
                IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => onEdit(s)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => onDelete(s)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WhatsAppTab extends StatefulWidget {
  const _WhatsAppTab({required this.templates, required this.onToggle, required this.onEdit, required this.onDelete});
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
              const Icon(Icons.star_outline, color: Color(0xFF1677FF), size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF003A8C)),
                    children: [
                      TextSpan(text: '¡Ahora podrás enviar mensajes personalizados por WhatsApp! ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: 'Configúralos y envíalos de manera personalizada desde la Agenda.'),
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
              _SubTabBtn(label: 'Plantillas', active: _subTab == 0, onTap: () => setState(() => _subTab = 0)),
              const SizedBox(width: 12),
              _SubTabBtn(label: 'Recordatorios Pendientes', active: _subTab == 1, onTap: () => setState(() => _subTab = 1)),
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
  const _SubTabBtn({required this.label, required this.active, required this.onTap});
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
          color: active ? const Color(0xFFC6A76A).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFFC6A76A) : const Color(0xFFE0E0E0)),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? const Color(0xFFC6A76A) : Colors.black54)),
      ),
    );
  }
}

class _TemplatesList extends StatelessWidget {
  const _TemplatesList({required this.templates, required this.onToggle, required this.onEdit, required this.onDelete, required this.onNew});
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
          child: Row(children: [
            _Th('TITULO', flex: 2),
            _Th('MENSAJE', flex: 5),
            _Th('ESTADO', flex: 1),
            const SizedBox(width: 80),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = templates[i];
              return ListTile(
                title: Text(t.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(t.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(value: t.active, activeThumbColor: const Color(0xFFC6A76A), onChanged: (_) => onToggle(t)),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => onEdit(t)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => onDelete(t)),
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
                Text('¡Potencia tus mensajes de WhatsApp con nuestras plantillas prediseñadas!', style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 20),
                Text('Crea mensajes personalizados de manera rápida y efectiva con nuestras plantillas listas para usar.', style: GoogleFonts.inter(fontSize: 15, color: Colors.black54)),
                const SizedBox(height: 32),
                FilledButton(onPressed: onNew, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC6A76A)), child: const Text('Probar plantillas')),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(flex: 4, child: Image.network('https://via.placeholder.com/300x400', fit: BoxFit.contain)),
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
      final res = await Supabase.instance.client.from('bookings').select('*, client_record:client_record_id(full_name, phone), services:service_id(name)').eq('status', 'confirmed');
      final logs = await Supabase.instance.client.from('whatsapp_logs').select('booking_id, type');
      final logSet = (logs as List).map((l) => '${l['booking_id']}_${l['type']}').toSet();
      final filtered = <Map<String, dynamic>>[];
      for (var b in (res as List)) {
        if (b['client_record'] == null || b['services'] == null) continue;
        final bDate = DateTime.parse(b['booking_date']);
        if (bDate.day == tomorrow.day && !logSet.contains('${b['id']}_reminder_24h')) filtered.add({...b, 'rem_type': 'reminder_24h'});
        if (bDate.day == now.day && !logSet.contains('${b['id']}_reminder_2h')) filtered.add({...b, 'rem_type': 'reminder_2h'});
      }
      setState(() { _reminders = filtered; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _send(Map<String, dynamic> b, String type) async {
    final t = widget.templates.firstWhere((e) => e.type == type, orElse: () => widget.templates.first);
    final phone = b['client_record']['phone'];
    final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(t.message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      await Supabase.instance.client.from('whatsapp_logs').insert({'booking_id': b['id'], 'type': type});
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
          title: Text(b['client_record']['full_name'], style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          subtitle: Text(b['services']['name']),
          trailing: ElevatedButton(onPressed: () => _send(b, b['rem_type']), child: const Text('Enviar')),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogs
// ─────────────────────────────────────────────────────────────────────────────
class _WhatsAppSelectionDialog extends StatefulWidget {
  const _WhatsAppSelectionDialog({required this.onSelected});
  final void Function(WhatsAppTemplate) onSelected;
  @override
  State<_WhatsAppSelectionDialog> createState() => _WhatsAppSelectionDialogState();
}

class _WhatsAppSelectionDialogState extends State<_WhatsAppSelectionDialog> {
  int _selectedIdx = 0;
  final List<Map<String, String>> _presets = [
    {
      'title': 'Mensaje de confirmación',
      'message': 'Hola [Nombre cliente]!\nTe queremos recordar tu cita de [Nombre servicio] en Sahara Club Spa.\n\n📅 ¿Cuándo?: [Fecha y hora reserva]\n📍 ¿Dónde?: Ubicación del local\n💆 ¿Con quién?: [Profesional]\n\n¡Te esperamos!',
      'type': 'confirmation',
    },
    {
      'title': 'Mensaje para redes sociales',
      'message': '¡Hola! Nos encantó tenerte hoy. Si te gustó tu servicio de [Nombre servicio], ¡compártenos en tus historias y etiquétanos!',
      'type': 'custom',
    },
    {
      'title': 'Descuento por cumpleaños',
      'message': '¡Feliz cumpleaños [Nombre cliente]! 🎂 Queremos consentirte con un 15% de descuento en tu próximo servicio.',
      'type': 'custom',
    },
    {
      'title': 'Mensaje de bienvenida',
      'message': '¡Bienvenida a Sahara Club Spa, [Nombre cliente]! ✨ Estamos emocionados de acompañarte en tu camino de bienestar.',
      'type': 'welcome',
    },
    {
      'title': 'Pago en línea',
      'message': 'Hola [Nombre cliente], para confirmar tu cita de [Nombre servicio], puedes realizar tu pago en el siguiente link: [Link de pago]',
      'type': 'custom',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 1000, height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text('Plantillas prediseñadas', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
                          Text('Elige entre plantillas prediseñadas para utilizarlas como base para tu mensaje ideal.',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.black54, height: 1.5)),
                          const SizedBox(height: 24),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _presets.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final active = _selectedIdx == i;
                                return InkWell(
                                  onTap: () => setState(() => _selectedIdx = i),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: active ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: active ? const Color(0xFFC6A76A) : const Color(0xFFE0E0E0)),
                                    ),
                                    child: Center(child: Text(_presets[i]['title']!,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                      color: active ? const Color(0xFFC6A76A) : Colors.black87))),
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
                      child: Center(child: _PhoneMockup(child: _MsgBubble(text: _presets[_selectedIdx]['message']!))),
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
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.black87))),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => widget.onSelected(WhatsAppTemplate(id: '', title: _presets[_selectedIdx]['title']!, message: _presets[_selectedIdx]['message']!, type: _presets[_selectedIdx]['type']!, active: true)),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF722ED1), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    child: const Text('Seleccionar y editar')),
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
  late final _msg   = TextEditingController(text: widget.template.message);
  late String _type = widget.template.type;
  bool _saving = false;

  void _addTag(String tag) {
    final text = _msg.text;
    final pos  = _msg.selection.baseOffset;
    _msg.text = pos < 0 ? '$text$tag' : text.substring(0, pos) + tag + text.substring(pos);
    _msg.selection = TextSelection.fromPosition(TextPosition(offset: (pos < 0 ? text.length : pos) + tag.length));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 1100, height: 800,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text('Editando ${widget.template.title}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
                          TextField(controller: _title, style: const TextStyle(color: Colors.black87), decoration: _deco('Ej: Confirmación')),
                          const SizedBox(height: 32),
                          _Label('Personaliza el mensaje *'),
                          const SizedBox(height: 16),
                          _TagSection(title: 'Datos de reserva', tags: ['[Nombre cliente]', '[Apellido cliente]', '[Profesional]', '[Nombre servicio]', '[Precio reserva]', '[Duración]', '[Fecha y hora reserva]'], onTag: _addTag),
                          const SizedBox(height: 16),
                          _TagSection(title: 'Datos del local', tags: ['[Nombre local]', '[Ubicación local]', '[Teléfono local]'], onTag: _addTag),
                          const SizedBox(height: 24),
                          TextField(controller: _msg, maxLines: 10, style: const TextStyle(color: Colors.black87), onChanged: (_) => setState(() {}), decoration: _deco('Escribe tu mensaje...')),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              _Label('Tipo: '),
                              const SizedBox(width: 12),
                              _DropdownType(value: _type, onChanged: (v) => setState(() => _type = v!)),
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
                          const Text('Previsualización del mensaje', style: TextStyle(color: Colors.black87)),
                          const SizedBox(height: 24),
                          _PhoneMockup(child: _MsgBubble(text: _msg.text)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.black87))),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () async {
                      setState(() => _saving = true);
                      final data = {'title': _title.text, 'message': _msg.text, 'type': _type, 'active': true};
                      if (widget.template.id.isEmpty) await Supabase.instance.client.from('whatsapp_templates').insert(data);
                      else await Supabase.instance.client.from('whatsapp_templates').update(data).eq('id', widget.template.id);
                      widget.onSaved(); Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF722ED1), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
                    child: const Text('Guardar')),
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
  const _TagSection({required this.title, required this.tags, required this.onTag});
  final String title; final List<String> tags; final ValueChanged<String> onTag;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: tags.map((t) => InkWell(onTap: () => onTag(t), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFBDBDBD))), child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black))))).toList()),
    ]);
  }
}

class _MsgBubble extends StatelessWidget {
  const _MsgBubble({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10).copyWith(topLeft: Radius.zero)),
      child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black)),
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260, height: 450,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFFE0E0E0), width: 8)),
      child: Column(children: [
        Container(height: 40, alignment: Alignment.center, child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
        Expanded(child: Container(color: const Color(0xFFE5DDD5), padding: const EdgeInsets.all(16), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [child]))),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _DropdownType extends StatelessWidget {
  const _DropdownType({required this.value, required this.onChanged});
  final String value; final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value, items: const [
        DropdownMenuItem(value: 'confirmation', child: Text('Confirmación', style: TextStyle(color: Colors.black87))),
        DropdownMenuItem(value: 'reminder_24h', child: Text('Recordatorio 24h', style: TextStyle(color: Colors.black87))),
        DropdownMenuItem(value: 'reminder_2h',  child: Text('Recordatorio 2h', style: TextStyle(color: Colors.black87))),
        DropdownMenuItem(value: 'welcome',       child: Text('Bienvenida', style: TextStyle(color: Colors.black87))),
        DropdownMenuItem(value: 'custom',        child: Text('Personalizado', style: TextStyle(color: Colors.black87))),
      ], onChanged: onChanged,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text); final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87));
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
  @override
  Widget build(BuildContext context) {
    return Dialog(child: Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Miembro del personal'),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
      DropdownButton<String>(value: _role, items: const [DropdownMenuItem(value: 'therapist', child: Text('Terapeuta'))], onChanged: (v) => setState(() => _role = v!)),
      FilledButton(onPressed: () async {
        final data = {'full_name': _name.text, 'role': _role};
        if (widget.staff == null) await Supabase.instance.client.from('staff').insert(data);
        else await Supabase.instance.client.from('staff').update(data).eq('id', widget.staff!.id);
        widget.onSaved(); Navigator.pop(context);
      }, child: const Text('Guardar')),
    ])));
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
  late final _name = TextEditingController(text: widget.service?.name ?? '');
  @override
  Widget build(BuildContext context) {
    return Dialog(child: Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Servicio'),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
      FilledButton(onPressed: () async {
        final data = {'name': _name.text};
        if (widget.service == null) await Supabase.instance.client.from('services').insert(data);
        else await Supabase.instance.client.from('services').update(data).eq('id', widget.service!.id);
        widget.onSaved(); Navigator.pop(context);
      }, child: const Text('Guardar')),
    ])));
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});
  final String name; final double size;
  @override
  Widget build(BuildContext context) => CircleAvatar(radius: size/2, child: Text(name.isEmpty ? '?' : name[0]));
}

class _Th extends StatelessWidget {
  const _Th(this.text, {this.flex = 1});
  final String text; final int flex;
  @override
  Widget build(BuildContext context) => Expanded(flex: flex, child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)));
}

Future<bool?> _confirmDelete(BuildContext context, String title, String msg) => showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí'))]));

InputDecoration _deco(String? hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 13, color: Colors.black54),
  filled: true, fillColor: const Color(0xFFF9F9F9),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFC6A76A))),
);
