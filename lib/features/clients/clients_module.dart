import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ── Capitalización de nombre ──────────────────────────────────────────────────
// Regla del negocio: nombre y apellidos siempre con la primera letra de cada
// palabra en mayúscula. Espeja el trigger normalize_client_full_name() de la BD
// para dar feedback inmediato en el form (la BD es la fuente de verdad y aplica
// la misma regla a todos los orígenes: recepción, IA, app y landing).
String titleCaseName(String input) {
  final cleaned = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return cleaned;
  return cleaned
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : '${w.substring(0, 1).toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
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
  // Mapa por client_id → tipo de beneficio activo: 'membership' | 'gift_card' | null
  final Map<String, String> _benefitByClient = {};

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
      await _loadBenefitsBulk();
    } catch (e) {
      debugPrint('loadClients: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBenefitsBulk() async {
    try {
      _benefitByClient.clear();
      final today = DateTime.now().toIso8601String().split('T').first;
      // Memberships activas con sesiones disponibles
      final memData = await Supabase.instance.client
          .from('client_memberships')
          .select('client_id, sessions_total, sessions_used, end_date, status')
          .eq('status', 'active');
      for (final r in (memData as List)) {
        final m = r as Map;
        final total = (m['sessions_total'] as num?)?.toInt() ?? 0;
        final used = (m['sessions_used'] as num?)?.toInt() ?? 0;
        final endDate = m['end_date']?.toString() ?? '';
        final endOk = endDate.isEmpty || endDate.compareTo(today) >= 0;
        if (total - used > 0 && endOk) {
          final id = m['client_id']?.toString();
          if (id != null) _benefitByClient[id] = 'membership';
        }
      }
      // Gift cards activas con saldo (no sobreescriben membresía: ya tiene prioridad)
      final gcData = await Supabase.instance.client
          .from('gift_cards')
          .select('client_id, current_balance, expires_at, status')
          .eq('status', 'active')
          .gt('current_balance', 0);
      final nowIso = DateTime.now().toIso8601String();
      for (final r in (gcData as List)) {
        final m = r as Map;
        final exp = m['expires_at']?.toString();
        if (exp == null || exp.compareTo(nowIso) > 0) {
          final id = m['client_id']?.toString();
          if (id != null && !_benefitByClient.containsKey(id)) {
            _benefitByClient[id] = 'gift_card';
          }
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('loadBenefitsBulk: $e');
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
                                  benefit:  _benefitByClient[_filtered[i].id],
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
    this.benefit,
  });
  final _Client      client;
  final bool         selected;
  final VoidCallback onTap;
  // 'membership' | 'gift_card' | null (null = regular, requires deposit)
  final String?      benefit;

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
                Row(children: [
                  Expanded(
                    child: Text(c.fullName,
                        style: GoogleFonts.inter(
                          fontSize:   13,
                          fontWeight: widget.selected
                              ? FontWeight.w600 : FontWeight.w500,
                          color:      Colors.black87,
                        )),
                  ),
                  if (widget.benefit == 'membership')
                    const _TileBadge(label: 'M', color: Color(0xFF6A54E0), tooltip: 'Membresía activa')
                  else if (widget.benefit == 'gift_card')
                    const _TileBadge(label: 'GC', color: Color(0xFFE07B00), tooltip: 'Gift card activa')
                  else
                    const _TileBadge(label: '\$', color: Color(0xFFB32D2D), tooltip: 'Requiere anticipo'),
                ]),
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

class _TileBadge extends StatelessWidget {
  const _TileBadge({required this.label, required this.color, required this.tooltip});
  final String label;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
    ),
  );
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
  List<Map<String, dynamic>> _history = [];
  bool   _loadingHistory = true;
  int    _totalVisits    = 0;
  int    _totalReservas  = 0;
  String _lastVisit      = '—';

  Map<String, dynamic>? _benefits;
  List<Map<String, dynamic>> _packages = const [];
  bool _loadingBenefits = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadBenefits();
  }

  @override
  void didUpdateWidget(_ClientDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.client.id != widget.client.id) {
      _loadHistory();
      _loadBenefits();
    }
  }

  Future<void> _loadBenefits() async {
    setState(() => _loadingBenefits = true);
    try {
      final res = await Supabase.instance.client.rpc(
        'get_customer_benefits_summary',
        params: {'p_client_id': widget.client.id},
      );
      final packages = await _loadPackages();
      if (!mounted) return;
      setState(() {
        _benefits = res is Map ? Map<String, dynamic>.from(res) : null;
        _packages = packages;
        _loadingBenefits = false;
      });
    } catch (e) {
      debugPrint('loadBenefits: $e');
      if (mounted) setState(() => _loadingBenefits = false);
    }
  }

  // Paquetes activos del cliente + conteo de sesiones (total / usadas).
  Future<List<Map<String, dynamic>>> _loadPackages() async {
    try {
      final db = Supabase.instance.client;
      final pkgRows = await db
          .from('client_packages')
          .select(
              'id, name, status, total_amount, paid_amount, created_at')
          .eq('client_id', widget.client.id)
          .neq('status', 'cancelado')
          .order('created_at', ascending: false);
      final packages = (pkgRows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (packages.isEmpty) return const [];

      final sessRows = await db
          .from('client_package_sessions')
          .select('client_package_id, status')
          .eq('client_id', widget.client.id);
      final counts = <String, List<int>>{}; // id -> [total, used]
      for (final s in (sessRows as List)) {
        final m = Map<String, dynamic>.from(s as Map);
        final pid = m['client_package_id']?.toString();
        if (pid == null) continue;
        final c = counts.putIfAbsent(pid, () => [0, 0]);
        c[0]++;
        if ((m['status'] as String?) == 'usada') c[1]++;
      }
      for (final p in packages) {
        final c = counts[p['id']?.toString()] ?? const [0, 0];
        p['sessions_total'] = c[0];
        p['sessions_used'] = c[1];
      }
      return packages;
    } catch (e) {
      debugPrint('loadPackages: $e');
      return const [];
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      // Paso 1: Buscar el profile ID del auth por nombre o email
      // (para capturar reservas creadas con client_id en lugar de client_record_id)
      String? profileId;
      try {
        // Intentar primero por email si existe
        if (widget.client.email.isNotEmpty) {
          final byEmail = await Supabase.instance.client
              .from('profiles')
              .select('id')
              .eq('email', widget.client.email)
              .maybeSingle();
          profileId = byEmail?['id'] as String?;
        }
        // Fallback: buscar por nombre exacto
        if (profileId == null && widget.client.fullName.isNotEmpty) {
          final byName = await Supabase.instance.client
              .from('profiles')
              .select('id')
              .eq('full_name', widget.client.fullName)
              .maybeSingle();
          profileId = byName?['id'] as String?;
        }
      } catch (_) {
        // Si falla la búsqueda del perfil, continuar sin él
      }

      // Paso 2: Construir filtro OR: client_record_id O client_id (perfil)
      final orFilter = profileId != null
          ? 'client_record_id.eq.${widget.client.id},client_id.eq.$profileId'
          : 'client_record_id.eq.${widget.client.id}';

      // Paso 3: Traer todas las reservas del cliente por ambos vínculos
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
          .limit(100) as List;

      // Fecha de la reserva más reciente (primera de la lista ordenada DESC)
      String lastVisitStr = '—';
      if (data.isNotEmpty) {
        final firstDate = data.first['booking_date'] as String? ?? '';
        if (firstDate.isNotEmpty) lastVisitStr = _fmtDate(firstDate);
      }

      if (!mounted) return;
      setState(() {
        _history       = data.cast<Map<String, dynamic>>();
        _totalVisits   = data.length;  // total citas
        _totalReservas = data.length;  // total reservas (mismo origen)
        _lastVisit     = lastVisitStr;
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
                label: 'Total citas',
                value: '$_totalVisits',
                color: SaharaTheme.gold,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon:  Icons.history_outlined,
                label: 'Última cita',
                value: _lastVisit,
                color: const Color(0xFF5B8FF9),
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon:  Icons.list_alt_outlined,
                label: 'Total reservas',
                value: '$_totalReservas',
                color: const Color(0xFF52C41A),
              )),
            ]),

            const SizedBox(height: 16),

            // ── Benefits & saldo ────────────────────────────────────────────
            _BenefitsCard(
              loading: _loadingBenefits,
              benefits: _benefits,
              packages: _packages,
              onAddGiftCard: () => _openAddGiftCardDialog(),
              onAddMembership: () => _openAddMembershipDialog(),
              onAddPackage: () => _openAddPackageDialog(),
              onSeeMovements: () => _openMovementsDialog(),
              onRefresh: _loadBenefits,
            ),
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

  Future<void> _openAddGiftCardDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _GiftCardFormDialog(client: widget.client),
    );
    if (saved == true) await _loadBenefits();
  }

  Future<void> _openAddMembershipDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _MembershipFormDialog(client: widget.client),
    );
    if (saved == true) await _loadBenefits();
  }

  Future<void> _openAddPackageDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PackageAssignDialog(client: widget.client),
    );
    if (saved == true) await _loadBenefits();
  }

  Future<void> _openMovementsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BenefitsMovementsDialog(client: widget.client),
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
      final normalizedName = titleCaseName(_nameCtrl.text);
      final payload = {
        'full_name':  normalizedName,
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
        fullName:  normalizedName,
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

// ─────────────────────────────────────────────────────────────────────────────
// Beneficios y saldo del cliente
// ─────────────────────────────────────────────────────────────────────────────
class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard({
    required this.loading,
    required this.benefits,
    required this.packages,
    required this.onAddGiftCard,
    required this.onAddMembership,
    required this.onAddPackage,
    required this.onSeeMovements,
    required this.onRefresh,
  });

  final bool loading;
  final Map<String, dynamic>? benefits;
  final List<Map<String, dynamic>> packages;
  final VoidCallback onAddGiftCard;
  final VoidCallback onAddMembership;
  final VoidCallback onAddPackage;
  final VoidCallback onSeeMovements;
  final VoidCallback onRefresh;

  String _fmtMoney(num v) => '\$${v.toStringAsFixed(0)} MXN';
  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    if (s.isEmpty) return '—';
    try {
      final d = DateTime.parse(s);
      const m = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return s; }
  }

  Widget _packageRow(Map<String, dynamic> p) {
    final name = (p['name'] as String?)?.trim();
    final total = (p['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (p['paid_amount'] as num?)?.toDouble() ?? 0;
    final pending = (total - paid).clamp(0, total).toDouble();
    final sessionsTotal = (p['sessions_total'] as num?)?.toInt() ?? 0;
    final sessionsUsed = (p['sessions_used'] as num?)?.toInt() ?? 0;
    final sessionsLeft = (sessionsTotal - sessionsUsed).clamp(0, sessionsTotal);
    final status = (p['status'] as String?) ?? 'activo';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (name == null || name.isEmpty) ? 'Paquete' : name,
            style: GoogleFonts.inter(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          Text(
            'Sesiones restantes: $sessionsLeft (usadas $sessionsUsed de $sessionsTotal)',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
          ),
          Text(
            pending <= 0
                ? 'Pagado: ${_fmtMoney(total)} · liquidado'
                : 'Pagado: ${_fmtMoney(paid)} · Pendiente: ${_fmtMoney(pending)}',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: pending <= 0 ? const Color(0xFF2D8A4F) : const Color(0xFFB37500),
            ),
          ),
          if (status != 'activo')
            Text('Estado: $status',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.black45)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = benefits ?? const {};
    final type = (b['customer_type'] as String?) ?? 'regular';
    final hasGc = b['has_active_gift_card'] == true;
    final gcBalance = (b['gift_card_balance'] as num?)?.toDouble() ?? 0;
    final gcExpires = b['gift_card_expires_at'];
    final hasMem = b['has_active_membership'] == true;
    final memPlan = (b['membership_plan'] as String?) ?? '—';
    final memStart = b['membership_start_date'];
    final memEnd = b['membership_end_date'];
    final used = (b['sessions_used'] as num?)?.toInt() ?? 0;
    final remaining = (b['sessions_remaining'] as num?)?.toInt() ?? 0;
    final requiresDeposit = b['requires_deposit'] == true;
    final waiver = b['waiver_reason'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard_outlined, size: 16, color: Colors.black54),
              const SizedBox(width: 8),
              Text('Beneficios y saldo del cliente',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
              const Spacer(),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18, color: Colors.black54),
                tooltip: 'Refrescar',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(
                  color: SaharaTheme.gold, strokeWidth: 2)),
            )
          else ...[
            // Tipo + anticipo
            Row(children: [
              _BenefitChip(
                label: type == 'membership'
                    ? 'Membresía'
                    : type == 'gift_card'
                        ? 'Gift Card'
                        : type == 'package'
                            ? 'Paquete'
                            : 'Regular',
                color: type == 'membership'
                    ? const Color(0xFF6A54E0)
                    : type == 'gift_card'
                        ? const Color(0xFFE07B00)
                        : type == 'package'
                            ? const Color(0xFF1E7E68)
                            : const Color(0xFF8B8B8B),
              ),
              const SizedBox(width: 8),
              _BenefitChip(
                label: requiresDeposit ? 'Requiere anticipo' : 'Sin anticipo',
                color: requiresDeposit
                    ? const Color(0xFFB32D2D)
                    : const Color(0xFF2D8A4F),
              ),
              if (!requiresDeposit && waiver != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    waiver == 'active_gift_card_with_balance'
                        ? '· cubierto por gift card'
                        : waiver == 'active_membership_with_sessions'
                            ? '· cubierto por membresía'
                            : waiver == 'active_package_with_sessions'
                                ? '· cubierto por paquete'
                                : '· $waiver',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF0EEEA)),
            const SizedBox(height: 14),

            // Gift Card
            Row(children: [
              Icon(Icons.redeem_outlined,
                  size: 14,
                  color: hasGc ? const Color(0xFFE07B00) : Colors.black26),
              const SizedBox(width: 6),
              Text('Gift card',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
            ]),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: hasGc
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Saldo disponible: ${_fmtMoney(gcBalance)}',
                          style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text('Vence: ${_fmtDate(gcExpires)}',
                          style: GoogleFonts.inter(fontSize: 11.5, color: Colors.black54)),
                    ])
                  : Text('Sin gift card activa',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.black38)),
            ),

            const SizedBox(height: 14),

            // Membresía
            Row(children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 14,
                  color: hasMem ? const Color(0xFF6A54E0) : Colors.black26),
              const SizedBox(width: 6),
              Text('Membresía',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
            ]),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: hasMem
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Plan: $memPlan',
                          style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black87)),
                      Text('Sesiones restantes: $remaining (usadas $used)',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
                      Text('Vigencia: ${_fmtDate(memStart)} → ${_fmtDate(memEnd)}',
                          style: GoogleFonts.inter(fontSize: 11.5, color: Colors.black54)),
                    ])
                  : Text('Sin membresía activa',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.black38)),
            ),

            const SizedBox(height: 14),

            // Paquetes
            Row(children: [
              Icon(Icons.inventory_2_outlined,
                  size: 14,
                  color: packages.isNotEmpty
                      ? const Color(0xFFC6A76A)
                      : Colors.black26),
              const SizedBox(width: 6),
              Text('Paquetes',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
            ]),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: packages.isEmpty
                  ? Text('Sin paquetes activos',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.black38))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final p in packages) _packageRow(p),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // Acciones
            Wrap(spacing: 8, runSpacing: 8, children: [
              _BenefitActionBtn(
                  icon: Icons.add_card_outlined,
                  label: 'Agregar gift card',
                  onTap: onAddGiftCard),
              _BenefitActionBtn(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Agregar membresía',
                  onTap: onAddMembership),
              _BenefitActionBtn(
                  icon: Icons.inventory_2_outlined,
                  label: 'Agregar paquete',
                  onTap: onAddPackage),
              _BenefitActionBtn(
                  icon: Icons.receipt_long_outlined,
                  label: 'Ver movimientos',
                  onTap: onSeeMovements),
            ]),
          ],
        ],
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(label,
        style: GoogleFonts.inter(
            fontSize: 11, color: color, fontWeight: FontWeight.w700)),
  );
}

class _BenefitActionBtn extends StatelessWidget {
  const _BenefitActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 15, color: SaharaTheme.gold),
    label: Text(label,
        style: GoogleFonts.inter(
            fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
    style: TextButton.styleFrom(
      backgroundColor: const Color(0xFFFAF6EE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE9DDC2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Gift Card form dialog
// ─────────────────────────────────────────────────────────────────────────────
class _GiftCardFormDialog extends StatefulWidget {
  const _GiftCardFormDialog({required this.client});
  final _Client client;

  @override
  State<_GiftCardFormDialog> createState() => _GiftCardFormDialogState();
}

class _GiftCardFormDialogState extends State<_GiftCardFormDialog> {
  final _codeCtrl = TextEditingController();
  DateTime _expires = DateTime.now().add(const Duration(days: 365));
  bool _saving = false;
  String? _error;

  // Catálogo de servicios para el dropdown. El gift card se define por un
  // servicio de Sahara Sol Spa; su valor = precio de ese servicio.
  List<Map<String, dynamic>> _services = [];
  String? _serviceId;
  bool _loadingServices = true;

  String _genCode() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'SAHARA-${ts.substring(ts.length - 6)}';
  }

  @override
  void initState() {
    super.initState();
    _codeCtrl.text = _genCode();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final data = await Supabase.instance.client
          .from('services')
          .select('id, name, price')
          .order('name');
      if (!mounted) return;
      setState(() {
        _services = (data as List).cast<Map<String, dynamic>>();
        _loadingServices = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los servicios: $e';
          _loadingServices = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _selectedService {
    if (_serviceId == null) return null;
    for (final s in _services) {
      if (s['id'] == _serviceId) return s;
    }
    return null;
  }

  Future<void> _save() async {
    final service = _selectedService;
    if (service == null) {
      setState(() => _error = 'Selecciona un servicio');
      return;
    }
    final amount = (service['price'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'El servicio seleccionado no tiene precio válido');
      return;
    }
    final serviceName = service['name'] as String? ?? '';
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      final res = await Supabase.instance.client
          .from('gift_cards')
          .insert({
            'code': _codeCtrl.text.trim(),
            'initial_balance': amount,
            'current_balance': amount,
            'currency': 'MXN',
            'client_id': widget.client.id,
            'recipient_name': widget.client.fullName,
            'service_id': _serviceId,
            'service_name': serviceName,
            'valid_from': DateTime.now().toIso8601String(),
            'expires_at': _expires.toIso8601String(),
            'status': 'active',
          })
          .select('id')
          .single();
      final gcId = res['id'] as String;
      await Supabase.instance.client.from('gift_card_transactions').insert({
        'gift_card_id': gcId,
        'client_id': widget.client.id,
        'type': 'load',
        'amount': amount,
        'balance_before': 0,
        'balance_after': amount,
        'notes': 'Carga inicial · Servicio: $serviceName',
        'created_by': me,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() {
        _error = '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF5F3EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Agregar gift card',
          style: GoogleFonts.playfairDisplay(
              fontSize: 18, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _codeCtrl,
            decoration: const InputDecoration(labelText: 'Código'),
          ),
          const SizedBox(height: 12),
          _loadingServices
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : DropdownButtonFormField<String>(
                  initialValue: _serviceId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Servicio'),
                  hint: const Text('Selecciona un servicio'),
                  items: _services.map((s) {
                    final price = (s['price'] as num?)?.toDouble() ?? 0;
                    return DropdownMenuItem<String>(
                      value: s['id'] as String,
                      child: Text(
                        '${s['name']}  ·  \$${price.toStringAsFixed(0)} MXN',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _serviceId = v;
                    _error = null;
                  }),
                ),
          if (_selectedService != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Valor del gift card: \$${((_selectedService!['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} MXN',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text('Vence: ${_expires.day}/${_expires.month}/${_expires.year}',
                  style: GoogleFonts.inter(fontSize: 13)),
            ),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expires,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) setState(() => _expires = picked);
              },
              child: const Text('Cambiar'),
            ),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
              backgroundColor: SaharaTheme.gold, foregroundColor: Colors.black),
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Membresía form dialog
// ─────────────────────────────────────────────────────────────────────────────
class _MembershipFormDialog extends StatefulWidget {
  const _MembershipFormDialog({required this.client});
  final _Client client;

  @override
  State<_MembershipFormDialog> createState() => _MembershipFormDialogState();
}

class _MembershipFormDialogState extends State<_MembershipFormDialog> {
  List<Map<String, dynamic>> _plans = [];
  String? _planId;
  final _sessionsCtrl = TextEditingController(text: '4');
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final data = await Supabase.instance.client
          .from('membership_plans')
          .select('id, name, sessions_per_month, price_monthly')
          .eq('is_active', true)
          .order('display_order');
      if (!mounted) return;
      setState(() {
        _plans = (data as List).cast<Map<String, dynamic>>();
        if (_plans.isNotEmpty) {
          _planId = _plans.first['id'] as String;
          final spm = (_plans.first['sessions_per_month'] as num?)?.toInt();
          if (spm != null) _sessionsCtrl.text = spm.toString();
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_planId == null) {
      setState(() => _error = 'Selecciona un plan');
      return;
    }
    final sessions = int.tryParse(_sessionsCtrl.text.trim()) ?? 0;
    if (sessions <= 0) {
      setState(() => _error = 'Sesiones inválidas');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.from('client_memberships').insert({
        'client_id': widget.client.id,
        'plan_id': _planId,
        'status': 'active',
        'start_date': _start.toIso8601String().split('T').first,
        'end_date': _end.toIso8601String().split('T').first,
        'sessions_used': 0,
        'sessions_total': sessions,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() {
        _error = '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          width: 280, height: 80,
          child: Center(child: CircularProgressIndicator(color: SaharaTheme.gold)),
        ),
      );
    }
    return AlertDialog(
      backgroundColor: const Color(0xFFF5F3EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Agregar membresía',
          style: GoogleFonts.playfairDisplay(
              fontSize: 18, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_plans.isEmpty)
            Text('No hay planes de membresía activos.\nCréalos primero en Administración → Servicios.',
                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black54))
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _planId,
              decoration: const InputDecoration(labelText: 'Plan'),
              items: _plans
                  .map((p) => DropdownMenuItem<String>(
                        value: p['id'] as String,
                        child: Text(
                            '${p['name']} · ${p['sessions_per_month']} ses · \$${p['price_monthly']}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _planId = v;
                final p = _plans.firstWhere((x) => x['id'] == v);
                final spm = (p['sessions_per_month'] as num?)?.toInt();
                if (spm != null) _sessionsCtrl.text = spm.toString();
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sessionsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Sesiones totales'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Inicio: ${_start.day}/${_start.month}/${_start.year}')),
              TextButton(
                onPressed: () async {
                  final p = await showDatePicker(
                    context: context, initialDate: _start,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (p != null) setState(() => _start = p);
                },
                child: const Text('Cambiar'),
              ),
            ]),
            Row(children: [
              Expanded(child: Text('Fin: ${_end.day}/${_end.month}/${_end.year}')),
              TextButton(
                onPressed: () async {
                  final p = await showDatePicker(
                    context: context, initialDate: _end,
                    firstDate: _start,
                    lastDate: _start.add(const Duration(days: 365 * 2)),
                  );
                  if (p != null) setState(() => _end = p);
                },
                child: const Text('Cambiar'),
              ),
            ]),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: (_saving || _plans.isEmpty) ? null : _save,
          style: FilledButton.styleFrom(
              backgroundColor: SaharaTheme.gold, foregroundColor: Colors.black),
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Asignar paquete a cliente (copia congelada)
// ─────────────────────────────────────────────────────────────────────────────
class _AssignLine {
  _AssignLine({
    this.serviceId,
    this.serviceName = '',
    this.quantity = 1,
    this.unitPrice = 0,
  });
  String? serviceId;
  String serviceName;
  int quantity;
  double unitPrice;
  double get total => quantity * unitPrice;
}

class _PackageAssignDialog extends StatefulWidget {
  const _PackageAssignDialog({required this.client});
  final _Client client;

  @override
  State<_PackageAssignDialog> createState() => _PackageAssignDialogState();
}

class _PackageAssignDialogState extends State<_PackageAssignDialog> {
  List<Map<String, dynamic>> _basePackages = const [];
  List<Map<String, dynamic>> _services = const [];
  String? _basePackageId;
  final _nameCtrl = TextEditingController();
  final List<_AssignLine> _lines = [];
  int _installments = 1; // 1 | 2 | 3
  Set<int> _allowedInstallments = {1, 2, 3};
  final _manualTotalCtrl = TextEditingController();
  bool _manualTotal = false;
  final _initialPaymentCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _manualTotalCtrl.dispose();
    _initialPaymentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final db = Supabase.instance.client;
      final pkgs = await db
          .from('products')
          .select(
              'id, name, description, price, installments_allowed, sessions_total')
          .eq('is_package', true)
          .order('name');
      List<Map<String, dynamic>> services = const [];
      try {
        final svc = await db
            .from('services')
            .select('id, name, price, is_active')
            .order('name');
        services = (svc as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => (e['is_active'] as bool?) ?? true)
            .toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _basePackages =
            (pkgs as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _services = services;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _onSelectBasePackage(String? id) async {
    if (id == null) return;
    setState(() {
      _basePackageId = id;
      _lines.clear();
    });
    final base = _basePackages.firstWhere((p) => p['id'] == id,
        orElse: () => const {});
    _nameCtrl.text = (base['name'] as String? ?? '').trim();
    // Forma de pago permitida segun el paquete base
    final allowed = ((base['installments_allowed'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList()) ??
        const [1];
    _allowedInstallments = allowed.isEmpty ? {1} : allowed.toSet();
    _installments = _allowedInstallments.contains(1)
        ? 1
        : _allowedInstallments.reduce((a, b) => a < b ? a : b);
    // Cargar lineas (package_items) como copia editable
    try {
      final items = await Supabase.instance.client
          .from('package_items')
          .select('service_id, service_name, quantity, unit_price')
          .eq('package_id', id);
      final lines = (items as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _AssignLine(
          serviceId: m['service_id']?.toString(),
          serviceName: (m['service_name'] as String? ?? '').trim(),
          quantity: (m['quantity'] as num?)?.toInt() ?? 1,
          unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _lines
          ..clear()
          ..addAll(lines);
      });
    } catch (_) {}
  }

  double get _linesTotal => _lines.fold<double>(0, (s, l) => s + l.total);
  int get _sessionsTotal => _lines.fold<int>(0, (s, l) => s + l.quantity);
  double get _finalTotal => _manualTotal
      ? (double.tryParse(_manualTotalCtrl.text.trim()) ?? _linesTotal)
      : _linesTotal;

  Future<void> _save() async {
    if (_basePackageId == null) {
      setState(() => _error = 'Selecciona un paquete');
      return;
    }
    if (_lines.isEmpty || _sessionsTotal <= 0) {
      setState(() => _error = 'El paquete debe incluir al menos un servicio');
      return;
    }
    final total = _finalTotal;
    final initialPayment =
        (double.tryParse(_initialPaymentCtrl.text.trim()) ?? 0).clamp(0, total).toDouble();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client;
      final planType = _installments == 1
          ? 'single'
          : _installments == 2
              ? 'two_payments'
              : 'three_payments';
      final snapshot = _lines
          .map((l) => {
                'service_id': l.serviceId,
                'service_name': l.serviceName.trim(),
                'quantity': l.quantity,
                'unit_price': l.unitPrice,
                'total_price': l.total,
              })
          .toList();

      // 1) client_packages (copia congelada)
      final inserted = await db
          .from('client_packages')
          .insert({
            'client_id': widget.client.id,
            'package_id': _basePackageId,
            'name': _nameCtrl.text.trim().isEmpty
                ? 'Paquete'
                : _nameCtrl.text.trim(),
            'status': 'activo',
            'total_amount': total,
            'paid_amount': initialPayment,
            'payment_plan_type': planType,
            'installments_count': _installments,
            'items_snapshot': snapshot,
          })
          .select('id')
          .single();
      final cpId = inserted['id'].toString();

      // 2) Sesiones (1 fila por unidad)
      final sessions = <Map<String, dynamic>>[];
      for (final l in _lines) {
        for (var i = 0; i < l.quantity; i++) {
          sessions.add({
            'client_package_id': cpId,
            'client_id': widget.client.id,
            'service_id': l.serviceId,
            'service_name': l.serviceName.trim(),
            'status': 'pendiente',
          });
        }
      }
      if (sessions.isNotEmpty) {
        await db.from('client_package_sessions').insert(sessions);
      }

      // 3) Plan de pagos (abonos). Reparto parejo; el ultimo cuadra el total.
      final payments = <Map<String, dynamic>>[];
      final base = (total / _installments);
      double remainingPaid = initialPayment;
      for (var n = 1; n <= _installments; n++) {
        final amount = n == _installments
            ? (total - base.floorToDouble() * (_installments - 1))
            : base.floorToDouble();
        final isPaid = remainingPaid >= amount && amount > 0;
        if (isPaid) remainingPaid -= amount;
        payments.add({
          'client_package_id': cpId,
          'client_id': widget.client.id,
          'installment_number': n,
          'amount': amount,
          'status': isPaid ? 'pagado' : 'pendiente',
          'paid_at': isPaid ? DateTime.now().toIso8601String() : null,
          'payment_method': isPaid ? 'manual' : null,
        });
      }
      if (payments.isNotEmpty) {
        await db.from('client_package_payments').insert(payments);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          width: 300,
          height: 90,
          child: Center(child: CircularProgressIndicator(color: SaharaTheme.gold)),
        ),
      );
    }
    return AlertDialog(
      backgroundColor: const Color(0xFFF5F3EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Agregar paquete',
          style: GoogleFonts.playfairDisplay(
              fontSize: 18, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_basePackages.isEmpty)
              Text(
                'No hay paquetes creados.\nCréalos primero en Administración → Productos (tipo "Paquete").',
                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black54),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _basePackageId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Paquete base'),
                items: _basePackages
                    .map((p) => DropdownMenuItem<String>(
                          value: p['id'] as String,
                          child: Text((p['name'] as String? ?? '').trim(),
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _onSelectBasePackage,
              ),
              if (_basePackageId != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del paquete'),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SERVICIOS INCLUIDOS',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.black54)),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _lines.add(_AssignLine())),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar'),
                        style: TextButton.styleFrom(
                            foregroundColor: SaharaTheme.gold),
                      ),
                    ],
                  ),
                ),
                for (int i = 0; i < _lines.length; i++) _lineRow(i),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE6E0D4)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Total: \$${_finalTotal.toStringAsFixed(0)} MXN · '
                        '$_sessionsTotal sesión(es)',
                        style: GoogleFonts.inter(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Row(children: [
                      Text('Ajustar',
                          style: GoogleFonts.inter(
                              fontSize: 11.5, color: Colors.black54)),
                      Switch(
                        value: _manualTotal,
                        activeThumbColor: SaharaTheme.gold,
                        onChanged: (v) => setState(() {
                          _manualTotal = v;
                          if (v && _manualTotalCtrl.text.trim().isEmpty) {
                            _manualTotalCtrl.text =
                                _linesTotal.toStringAsFixed(0);
                          }
                        }),
                      ),
                    ]),
                  ],
                ),
                if (_manualTotal)
                  TextField(
                    controller: _manualTotalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'Precio final del paquete', prefixText: '\$'),
                    onChanged: (_) => setState(() {}),
                  ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('FORMA DE PAGO',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Colors.black54)),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  _payChip(1, 'De contado'),
                  _payChip(2, '2 pagos'),
                  _payChip(3, '3 pagos'),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _initialPaymentCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Abono inicial (opcional)',
                    prefixText: '\$',
                    helperText:
                        'Lo que el cliente paga ahora. Déjalo vacío si paga después.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: (_saving || _basePackageId == null) ? null : _save,
          style: FilledButton.styleFrom(
              backgroundColor: SaharaTheme.gold, foregroundColor: Colors.black),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Asignar paquete'),
        ),
      ],
    );
  }

  Widget _lineRow(int index) {
    final line = _lines[index];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<String?>(
            initialValue: line.serviceId,
            isExpanded: true,
            isDense: true,
            decoration: const InputDecoration(
                isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('Personalizado')),
              for (final s in _services)
                DropdownMenuItem<String?>(
                  value: s['id']?.toString(),
                  child: Text((s['name'] as String? ?? '').trim(),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              setState(() {
                line.serviceId = value;
                if (value != null) {
                  final svc = _services.firstWhere(
                      (s) => s['id']?.toString() == value,
                      orElse: () => const {});
                  line.serviceName = (svc['name'] as String? ?? '').trim();
                  final p = (svc['price'] as num?)?.toDouble();
                  if (p != null && line.unitPrice == 0) line.unitPrice = p;
                }
              });
            },
          ),
        ),
        const SizedBox(width: 6),
        _stepBtn(Icons.remove, () {
          if (line.quantity > 1) setState(() => line.quantity--);
        }),
        SizedBox(
          width: 24,
          child: Text('${line.quantity}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        _stepBtn(Icons.add, () => setState(() => line.quantity++)),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: TextFormField(
            key: ValueKey('assign_price_$index'),
            initialValue:
                line.unitPrice == 0 ? '' : line.unitPrice.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                isDense: true, prefixText: '\$'),
            onChanged: (v) =>
                setState(() => line.unitPrice = double.tryParse(v) ?? 0),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: Colors.redAccent,
          onPressed: () => setState(() => _lines.removeAt(index)),
        ),
      ]),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EE),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE0D2B5)),
          ),
          child: Icon(icon, size: 13, color: SaharaTheme.gold),
        ),
      );

  Widget _payChip(int n, String label) {
    final enabled = _allowedInstallments.contains(n);
    final selected = _installments == n;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => setState(() => _installments = n) : null,
      selectedColor: const Color(0xFFE8D9B8),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: enabled ? Colors.black87 : Colors.black26,
      ),
      backgroundColor: const Color(0xFFFFF8EE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0D2B5)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Movimientos (gift card transactions + membership usage) viewer
// ─────────────────────────────────────────────────────────────────────────────
class _BenefitsMovementsDialog extends StatefulWidget {
  const _BenefitsMovementsDialog({required this.client});
  final _Client client;

  @override
  State<_BenefitsMovementsDialog> createState() => _BenefitsMovementsDialogState();
}

class _BenefitsMovementsDialogState extends State<_BenefitsMovementsDialog> {
  List<Map<String, dynamic>> _gcTx = [];
  List<Map<String, dynamic>> _memUse = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final txs = await Supabase.instance.client
          .from('gift_card_transactions')
          .select('id, type, amount, balance_after, notes, created_at')
          .eq('client_id', widget.client.id)
          .order('created_at', ascending: false)
          .limit(30);
      final use = await Supabase.instance.client
          .from('membership_usage')
          .select('id, used_at, notes, services(name)')
          .eq('client_id', widget.client.id)
          .order('used_at', ascending: false)
          .limit(30);
      if (!mounted) return;
      setState(() {
        _gcTx = (txs as List).cast<Map<String, dynamic>>();
        _memUse = (use as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    try {
      final d = DateTime.parse(v.toString()).toLocal();
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return v.toString(); }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF5F3EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Movimientos · ${widget.client.fullName}',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            if (_loading)
              const Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: SaharaTheme.gold)),
              )
            else
              Expanded(
                child: ListView(children: [
                  Text('Gift card',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFE07B00))),
                  const SizedBox(height: 6),
                  if (_gcTx.isEmpty)
                    Text('Sin movimientos',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.black38))
                  else
                    ..._gcTx.map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Text(t['type']?.toString() ?? '?',
                                style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              '\$${t['amount']} · saldo ${t['balance_after']}',
                              style: GoogleFonts.inter(fontSize: 12.5))),
                            Text(_fmt(t['created_at']),
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
                          ]),
                        )),
                  const SizedBox(height: 18),
                  Text('Membresía',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF6A54E0))),
                  const SizedBox(height: 6),
                  if (_memUse.isEmpty)
                    Text('Sin sesiones consumidas',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.black38))
                  else
                    ..._memUse.map((u) {
                      final svc = u['services'];
                      final svcName = svc is Map ? svc['name']?.toString() ?? '—' : '—';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline,
                              size: 14, color: Color(0xFF6A54E0)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(svcName,
                              style: GoogleFonts.inter(fontSize: 12.5))),
                          Text(_fmt(u['used_at']),
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
                        ]),
                      );
                    }),
                ]),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
