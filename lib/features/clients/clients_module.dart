import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/sahara_theme.dart';

// ── UUID helper (no external package needed) ──────────────────────────────────
String _genUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int n) => n.toRadixString(16).padLeft(2, '0');
  return '${h(b[0])}${h(b[1])}${h(b[2])}${h(b[3])}-'
      '${h(b[4])}${h(b[5])}-${h(b[6])}${h(b[7])}-'
      '${h(b[8])}${h(b[9])}-'
      '${h(b[10])}${h(b[11])}${h(b[12])}${h(b[13])}${h(b[14])}${h(b[15])}';
}

// ── Model ─────────────────────────────────────────────────────────────────────
class _Client {
  final String  id;
  final String  fullName;
  final String  email;
  final String  phone;
  final String? birthDate;
  final String  notes;
  final DateTime createdAt;

  const _Client({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.birthDate,
    required this.notes,
    required this.createdAt,
  });

  factory _Client.fromMap(Map<String, dynamic> m) => _Client(
    id:        m['id']         as String,
    fullName:  m['full_name']  as String? ?? '',
    email:     m['email']      as String? ?? '',
    phone:     m['phone']      as String? ?? '',
    birthDate: m['birth_date'] as String?,
    notes:     m['notes']      as String? ?? '',
    createdAt: m['created_at'] != null
        ? DateTime.parse(m['created_at'] as String)
        : DateTime.now(),
  );

  _Client copyWith({
    String? fullName, String? email, String? phone,
    String? birthDate, String? notes,
  }) => _Client(
    id:        id,
    fullName:  fullName  ?? this.fullName,
    email:     email     ?? this.email,
    phone:     phone     ?? this.phone,
    birthDate: birthDate ?? this.birthDate,
    notes:     notes     ?? this.notes,
    createdAt: createdAt,
  );

  String get initials {
    final parts = fullName.trim().split(' ')
        .where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  Color get avatarColor {
    const palette = [
      Color(0xFF5B8FF9), Color(0xFF52C41A), Color(0xFFFFB347),
      Color(0xFFB37FEB), Color(0xFF13C2C2), Color(0xFFFF9899),
      Color(0xFF1890FF), Color(0xFFEB2F96),
    ];
    if (fullName.isEmpty) return palette[0];
    return palette[fullName.codeUnitAt(0) % palette.length];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ClientsModule  (entry point — used from AgendaPage)
// ─────────────────────────────────────────────────────────────────────────────
class ClientsModule extends StatefulWidget {
  const ClientsModule({super.key});

  @override
  State<ClientsModule> createState() => _ClientsModuleState();
}

Future<Map<String, dynamic>?> showClientFormDialog(BuildContext context) async {
  final client = await showDialog<_Client>(
    context: context,
    builder: (dialogContext) => _ClientFormDialog(
      onSaved: (client) => Navigator.pop(dialogContext, client),
    ),
  );
  if (client == null) return null;
  return {
    'id': client.id,
    'full_name': client.fullName,
    'email': client.email,
    'phone': client.phone,
  };
}

String? _missingColumn(PostgrestException e) {
  if (e.code != 'PGRST204') return null;
  return RegExp(r"Could not find the '([^']+)' column")
      .firstMatch(e.message)
      ?.group(1);
}

class _ClientsModuleState extends State<ClientsModule> {
  List<_Client> _clients  = [];
  _Client?      _selected;
  bool          _loading  = true;
  String        _search   = '';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _loading = true);
    try {
      final columns = [
        'id', 'full_name', 'email', 'phone', 'birth_date', 'notes', 'created_at',
      ];
      late List data;
      while (true) {
        try {
          data = await Supabase.instance.client
              .from('clients')
              .select(columns.join(', '))
              .order('full_name') as List;
          break;
        } on PostgrestException catch (e) {
          final missing = _missingColumn(e);
          if (missing == null || !columns.remove(missing)) rethrow;
        }
      }
      if (!mounted) return;
      setState(() {
        _clients = data
            .map((m) => _Client.fromMap(m as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('loadClients: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Client> get _filtered {
    if (_search.isEmpty) return _clients;
    final q = _search.toLowerCase();
    return _clients.where((c) =>
        c.fullName.toLowerCase().contains(q) ||
        c.email.toLowerCase().contains(q) ||
        c.phone.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left: list panel ───────────────────────────────────────────────
        Container(
          width: 300,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Color(0xFFE0DDD8))),
          ),
          child: Column(
            children: [
              // Header
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE0DDD8))),
                ),
                child: Row(children: [
                  Text('Clientes',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _openForm(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: SaharaTheme.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.add, size: 15),
                    label: Text('Nuevo',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText:    'Buscar cliente…',
                    hintStyle:   GoogleFonts.inter(
                        color: Colors.black38, fontSize: 13),
                    prefixIcon:  const Icon(Icons.search,
                        size: 16, color: Colors.black38),
                    isDense:     true,
                    filled:      true,
                    fillColor:   const Color(0xFFF5F3EF),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE0DDD8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          BorderSide(color: SaharaTheme.gold, width: 1.5),
                    ),
                  ),
                ),
              ),
              // List
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: SaharaTheme.gold))
                    : _filtered.isEmpty
                        ? Center(
                            child: Text('Sin resultados',
                                style: GoogleFonts.inter(
                                    color: Colors.black38, fontSize: 13)))
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) =>
                                _ClientTile(
                                  client:   _filtered[i],
                                  selected: _selected?.id == _filtered[i].id,
                                  onTap: () =>
                                      setState(() => _selected = _filtered[i]),
                                ),
                          ),
              ),
              // Footer count
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE0DDD8))),
                ),
                child: Text(
                  '${_filtered.length} cliente${_filtered.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.black38),
                ),
              ),
            ],
          ),
        ),

        // ── Right: detail panel ────────────────────────────────────────────
        Expanded(
          child: _selected == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: SaharaTheme.gold.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: SaharaTheme.gold.withValues(alpha: 0.25),
                              width: 1.5),
                        ),
                        child: Icon(Icons.person_outline,
                            color: SaharaTheme.gold, size: 30),
                      ),
                      const SizedBox(height: 16),
                      Text('Selecciona un cliente',
                          style: GoogleFonts.inter(
                              color: Colors.black38, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('o crea uno nuevo con el botón +',
                          style: GoogleFonts.inter(
                              color: Colors.black26, fontSize: 12)),
                    ],
                  ),
                )
              : _ClientDetailPanel(
                  client:    _selected!,
                  onEdit:    () => _openForm(context, edit: _selected),
                  onDeleted: () {
                    setState(() => _selected = null);
                    _loadClients();
                  },
                  onRefresh: () async {
                    await _loadClients();
                    // Re-select updated client
                    if (_selected != null && mounted) {
                      setState(() {
                        _selected = _clients.where((c) => c.id == _selected!.id)
                            .firstOrNull;
                      });
                    }
                  },
                ),
        ),
      ],
    );
  }

  void _openForm(BuildContext ctx, {_Client? edit}) {
    showDialog(
      context: ctx,
      builder: (_) => _ClientFormDialog(
        editClient: edit,
        onSaved:    (client) {
          Navigator.pop(ctx);
          _loadClients().then((_) {
            if (mounted) setState(() => _selected = client);
          });
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Client Tile  (list item)
// ─────────────────────────────────────────────────────────────────────────────
class _ClientTile extends StatefulWidget {
  const _ClientTile({
    required this.client,
    required this.selected,
    required this.onTap,
  });
  final _Client      client;
  final bool         selected;
  final VoidCallback onTap;

  @override
  State<_ClientTile> createState() => _ClientTileState();
}

class _ClientTileState extends State<_ClientTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: widget.selected
                ? SaharaTheme.gold.withValues(alpha: 0.08)
                : _hovered
                    ? const Color(0xFFF8F6F2)
                    : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.selected ? SaharaTheme.gold : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: Color(0xFFF0EDE8)),
            ),
          ),
          child: Row(children: [
            _Avatar(initials: c.initials, color: c.avatarColor, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.fullName,
                    style: GoogleFonts.inter(
                      fontSize:   13,
                      fontWeight: widget.selected
                          ? FontWeight.w600 : FontWeight.w500,
                      color:      Colors.black87,
                    )),
                const SizedBox(height: 2),
                Text(
                  c.email.isNotEmpty ? c.email
                      : c.phone.isNotEmpty ? c.phone
                          : 'Sin contacto',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.black38),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Client Detail Panel  (right side)
// ─────────────────────────────────────────────────────────────────────────────
class _ClientDetailPanel extends StatefulWidget {
  const _ClientDetailPanel({
    required this.client,
    required this.onEdit,
    required this.onDeleted,
    required this.onRefresh,
  });
  final _Client      client;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;
  final VoidCallback onRefresh;

  @override
  State<_ClientDetailPanel> createState() => _ClientDetailPanelState();
}

class _ClientDetailPanelState extends State<_ClientDetailPanel> {
  static const Set<String> _visitedStatuses = <String>{
    'attended',
    'completed',
    'paid',
    'awaiting_payment',
    'checked_in',
    'in_progress',
  };

  List<Map<String, dynamic>> _history = [];
  bool   _loadingHistory = true;
  int    _totalVisits    = 0;
  String _lastVisit      = '—';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(_ClientDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.client.id != widget.client.id) _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final data = await Supabase.instance.client
          .from('bookings')
          .select('''
            id, booking_date, booking_time, status, client_notes,
            services(name),
            therapist:staff!bookings_therapist_id_fkey(full_name)
          ''')
          .eq('client_record_id', widget.client.id)
          .order('booking_date', ascending: false)
          .order('booking_time', ascending: false)
          .limit(20) as List;

      if (!mounted) return;
      final visits = data
          .where((b) => _visitedStatuses.contains(
                ((b['status'] as String?) ?? '').trim().toLowerCase(),
              ))
          .length;
      final last = data.isNotEmpty
          ? _fmtDate(data.first['booking_date'] as String? ?? '')
          : '—';
      setState(() {
        _history        = data.cast<Map<String, dynamic>>();
        _totalVisits    = visits;
        _lastVisit      = last;
        _loadingHistory = false;
      });
    } catch (e) {
      debugPrint('loadHistory: $e');
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      const m = ['ene','feb','mar','abr','may','jun',
                  'jul','ago','sep','oct','nov','dic'];
      return '${d.day} de ${m[d.month - 1]} de ${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    return Container(
      color: SaharaTheme.blancoAlmendra,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: const Color(0xFFECECEC)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(
                      initials: c.initials,
                      color:    c.avatarColor,
                      size:     64),
                  const SizedBox(width: 20),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.fullName,
                          style: GoogleFonts.playfairDisplay(
                              fontSize: 22, color: Colors.black87)),
                      if (c.email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _InfoChip(Icons.email_outlined, c.email),
                      ],
                      if (c.phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _InfoChip(Icons.phone_outlined, c.phone),
                      ],
                      if (c.birthDate != null &&
                          c.birthDate!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _InfoChip(Icons.cake_outlined,
                            _fmtDate(c.birthDate!)),
                      ],
                    ],
                  )),
                  // Actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SaharaTheme.gold,
                          side: BorderSide(
                              color: SaharaTheme.gold.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: Text('Editar',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _confirmDelete(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                              color: Colors.red.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: Text('Eliminar',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Stats row ───────────────────────────────────────────────────
            Row(children: [
              Expanded(child: _StatCard(
                icon:  Icons.event_available_outlined,
                label: 'Total visitas',
                value: '$_totalVisits',
                color: SaharaTheme.gold,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon:  Icons.history_outlined,
                label: 'Última visita',
                value: _lastVisit,
                color: const Color(0xFF5B8FF9),
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon:  Icons.list_alt_outlined,
                label: 'Total reservas',
                value: '${_history.length}',
                color: const Color(0xFF52C41A),
              )),
            ]),

            const SizedBox(height: 16),

            // ── Notes ───────────────────────────────────────────────────────
            if (c.notes.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: const Color(0xFFECECEC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.sticky_note_2_outlined,
                          size: 14, color: Colors.black38),
                      const SizedBox(width: 6),
                      Text('Notas',
                          style: GoogleFonts.inter(
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
                            color:      Colors.black54,
                          )),
                    ]),
                    const SizedBox(height: 8),
                    Text(c.notes,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Booking history ─────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: const Color(0xFFECECEC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text('Historial de reservas',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                  ),
                  const Divider(height: 1, color: Color(0xFFECECEC)),
                  if (_loadingHistory)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(
                          color: SaharaTheme.gold)),
                    )
                  else if (_history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('Sin reservas registradas',
                          style: GoogleFonts.inter(
                              color: Colors.black38, fontSize: 13))),
                    )
                  else
                    ...(_history.map((b) => _HistoryRow(booking: b))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF5F3EF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar cliente',
            style: GoogleFonts.playfairDisplay(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        content: Text(
            '¿Eliminar a ${widget.client.fullName}? Esta acción no se puede deshacer.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: Colors.black54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC6A76A),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Eliminar',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !ctx.mounted) return;
    try {
      await Supabase.instance.client
          .from('clients')
          .delete()
          .eq('id', widget.client.id);
      widget.onDeleted();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Client Form Dialog  (create / edit)
// ─────────────────────────────────────────────────────────────────────────────
class _ClientFormDialog extends StatefulWidget {
  const _ClientFormDialog({
    required this.onSaved,
    this.editClient,
  });
  final _Client?                  editClient;
  final void Function(_Client)    onSaved;

  @override
  State<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<_ClientFormDialog> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  String? _birthDate;

  @override
  void initState() {
    super.initState();
    final e = widget.editClient;
    if (e != null) {
      _nameCtrl.text  = e.fullName;
      _emailCtrl.text = e.email;
      _phoneCtrl.text = e.phone;
      _notesCtrl.text = e.notes;
      _birthDate      = e.birthDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'full_name':  _nameCtrl.text.trim(),
        'email':      _emailCtrl.text.trim(),
        'phone':      _phoneCtrl.text.trim(),
        'notes':      _notesCtrl.text.trim(),
        if (_birthDate != null) 'birth_date': _birthDate,
      };

      Future<void> writeProfile(Map<String, dynamic> data, {String? id}) async {
        final current = Map<String, dynamic>.from(data);
        if (id != null) current['id'] = id;
        while (true) {
          try {
            if (id == null) {
              await Supabase.instance.client
                  .from('clients')
                  .update(current)
                  .eq('id', widget.editClient!.id);
            } else {
              await Supabase.instance.client.from('clients').insert(current);
            }
            return;
          } on PostgrestException catch (e) {
            final missing = _missingColumn(e);
            if (missing == null || !current.containsKey(missing)) rethrow;
            current.remove(missing);
            if (missing == 'birth_date') _birthDate = null;
          }
        }
      }

      String savedId;
      if (widget.editClient != null) {
        await writeProfile(payload);
        savedId = widget.editClient!.id;
      } else {
        savedId = _genUuid();
        await writeProfile(payload, id: savedId);
      }

      final saved = _Client(
        id:        savedId,
        fullName:  _nameCtrl.text.trim(),
        email:     _emailCtrl.text.trim(),
        phone:     _phoneCtrl.text.trim(),
        birthDate: _birthDate,
        notes:     _notesCtrl.text.trim(),
        createdAt: widget.editClient?.createdAt ?? DateTime.now(),
      );
      if (mounted) {
        widget.onSaved(saved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente guardado correctamente'),
            backgroundColor: Color(0xFFC6A76A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade100,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editClient != null;
    return Dialog(
      backgroundColor: const Color(0xFFF5F3EF),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
              child: Row(children: [
                Text(isEdit ? 'Editar cliente' : 'Nuevo cliente',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.black38),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  _FormCard(children: [
                    _FieldLabel('Nombre completo *'),
                    const SizedBox(height: 6),
                    _Field(ctrl: _nameCtrl, hint: 'María García López'),
                  ]),
                  const SizedBox(height: 12),
                  _FormCard(children: [
                    Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('Email'),
                          const SizedBox(height: 6),
                          _Field(
                              ctrl: _emailCtrl,
                              hint: 'cliente@email.com',
                              type: TextInputType.emailAddress),
                        ],
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('Teléfono'),
                          const SizedBox(height: 6),
                          _Field(
                              ctrl: _phoneCtrl,
                              hint: '+56 9 1234 5678',
                              type: TextInputType.phone),
                        ],
                      )),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  _FormCard(children: [
                    _FieldLabel('Fecha de nacimiento'),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _birthDate != null
                              ? DateTime.tryParse(_birthDate!) ?? DateTime(1990)
                              : DateTime(1990),
                          firstDate: DateTime(1920),
                          lastDate:  DateTime.now(),
                          builder: (_, child) => Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary:   SaharaTheme.gold,
                                onPrimary: Colors.black,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) {
                          setState(() => _birthDate =
                              '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}');
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFFDDD9D3)),
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white,
                        ),
                        child: Row(children: [
                          const Icon(Icons.cake_outlined,
                              size: 14, color: Colors.black45),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            _birthDate != null
                                ? _birthDate!
                                : 'Seleccionar fecha',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _birthDate != null
                                  ? Colors.black87
                                  : Colors.black38,
                            ),
                          )),
                          if (_birthDate != null)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _birthDate = null),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.black38),
                            ),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _FormCard(children: [
                    _FieldLabel('Notas internas'),
                    const SizedBox(height: 6),
                    _Field(
                        ctrl:     _notesCtrl,
                        hint:     'Preferencias, alergias, observaciones…',
                        maxLines: 3),
                  ]),
                ]),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(12)),
                border: Border(top: BorderSide(color: Color(0xFFECE9E4))),
              ),
              child: Row(children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.black54),
                  child: Text('Cancelar',
                      style: GoogleFonts.inter(fontSize: 13)),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC6A76A),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.check, size: 16),
                  label: Text(isEdit ? 'Guardar cambios' : 'Crear cliente',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History row
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.booking});
  final Map<String, dynamic> booking;

  static const _statusColor = {
    'scheduled': Color(0xFF5B8FF9),
    'confirmed': Color(0xFFFFB347),
    'attended':  Color(0xFFFF9899),
    'no_show':   Color(0xFFFFB3B3),
    'pending':   Color(0xFFFF4444),
    'waiting':   Color(0xFF52C41A),
    'cancelled': Color(0xFFB32D2D),
    'completed': Color(0xFF888888),
    'paid': Color(0xFF52C41A),
    'awaiting_payment': Color(0xFFE0A800),
    'checked_in': Color(0xFF5B8FF9),
    'in_progress': Color(0xFF7B61FF),
    'rescheduled': Color(0xFF91A7FF),
  };
  static const _statusLabel = {
    'scheduled': 'Reservada',
    'confirmed': 'Confirmada',
    'attended':  'Asistió',
    'no_show':   'No asistió',
    'pending':   'Pendiente',
    'waiting':   'En espera',
    'cancelled': 'Cancelada',
    'completed': 'Completada',
    'paid': 'Pagada',
    'awaiting_payment': 'Pendiente de cobro',
    'checked_in': 'Check-in',
    'in_progress': 'En progreso',
    'rescheduled': 'Reagendada',
  };

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const m = ['ene','feb','mar','abr','may','jun',
                  'jul','ago','sep','oct','nov','dic'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final status  = booking['status'] as String? ?? 'scheduled';
    final dot     = _statusColor[status] ?? const Color(0xFF5B8FF9);
    final label   = _statusLabel[status] ?? status;
    final svc     = (booking['services'] as Map?)?['name'] as String? ?? 'Servicio';
    final date    = booking['booking_date'] as String? ?? '';
    final time    = (booking['booking_time'] as String? ?? '').substring(0, 5);
    final therapist = (booking['therapist'] as Map?)?['full_name'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F3EF))),
      ),
      child: Row(children: [
        Container(
          width: 3, height: 36,
          decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(svc, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
            const SizedBox(height: 2),
            Text(
              therapist.isNotEmpty ? therapist : '',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.black38),
            ),
          ],
        )),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${_fmtDate(date)}  $time',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        dot.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: dot, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.color, this.size = 40});
  final String initials;
  final Color  color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      shape: BoxShape.circle,
      border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
    ),
    alignment: Alignment.center,
    child: Text(initials,
        style: GoogleFonts.inter(
          color:      color,
          fontSize:   size * 0.38,
          fontWeight: FontWeight.w700,
        )),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: const Color(0xFFECECEC)),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color:  color.withValues(alpha: 0.12),
          shape:  BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(
              fontSize: 10, color: Colors.black38, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
        ],
      )),
    ]),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.icon, this.text);
  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 13, color: Colors.black38),
    const SizedBox(width: 5),
    Flexible(child: Text(text,
        style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
        overflow: TextOverflow.ellipsis)),
  ]);
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: const Color(0xFFECE9E4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87));
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.hint,
    this.type     = TextInputType.text,
    this.maxLines = 1,
  });
  final TextEditingController ctrl;
  final String                hint;
  final TextInputType         type;
  final int                   maxLines;

  @override
  Widget build(BuildContext context) => TextField(
    controller:   ctrl,
    keyboardType: type,
    maxLines:     maxLines,
    style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
    decoration: InputDecoration(
      hintText:    hint,
      hintStyle:   GoogleFonts.inter(color: Colors.black38, fontSize: 13),
      isDense:     true,
      filled:      true,
      fillColor:   Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFDDD9D3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: SaharaTheme.gold, width: 1.5),
      ),
    ),
  );
}
