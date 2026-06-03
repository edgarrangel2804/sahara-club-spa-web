import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/sahara_theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Sistema de paquetes por sesiones — Sahara Club Spa
//
// Soporta dos flujos:
//   • Vender paquete nuevo  → crea venta como ingreso del día + crea sesiones
//   • Registrar existente   → migración sin ingreso nuevo, sesiones ajustadas
// ══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// Panel principal de paquetes (se usa desde _ClientDetailPanel)
// ─────────────────────────────────────────────────────────────────────────────
class ClientPackagesPanel extends StatefulWidget {
  const ClientPackagesPanel({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  final String clientId;
  final String clientName;

  @override
  State<ClientPackagesPanel> createState() => _ClientPackagesPanelState();
}

class _ClientPackagesPanelState extends State<ClientPackagesPanel> {
  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ClientPackagesPanel old) {
    super.didUpdateWidget(old);
    if (old.clientId != widget.clientId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('client_packages')
          .select('''
            id, name, status, sessions_total, sessions_used, sessions_remaining,
            total_amount, paid_amount, origin, migration_note, purchased_at,
            service:service_id(name, price, sessions_count),
            base_service:base_service_id(id, name)
          ''')
          .eq('client_id', widget.clientId)
          .gt('sessions_total', 0)
          .order('purchased_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _packages = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      debugPrint('ClientPackagesPanel._load: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                const Icon(Icons.local_activity_outlined,
                    size: 16, color: SaharaTheme.gold),
                const SizedBox(width: 8),
                Text('Paquetes de sesiones',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openSellDialog(),
                  icon: const Icon(Icons.add, size: 14),
                  label: Text('Vender',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: SaharaTheme.gold,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 28),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openMigrateDialog(),
                  icon: const Icon(Icons.history_edu_outlined, size: 14),
                  label: Text('Registrar existente',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black54,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 28),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFECECEC)),

          // Lista de paquetes
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(color: SaharaTheme.gold)),
            )
          else if (_packages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Sin paquetes registrados',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.black38)),
            )
          else
            ..._packages.map(_buildPackageRow),
        ],
      ),
    );
  }

  Widget _buildPackageRow(Map<String, dynamic> p) {
    final name = (p['name'] as String?) ?? 'Paquete';
    final total = (p['sessions_total'] as num?)?.toInt() ?? 0;
    final used = (p['sessions_used'] as num?)?.toInt() ?? 0;
    final remaining = (p['sessions_remaining'] as num?)?.toInt() ?? 0;
    final status = (p['status'] as String?) ?? 'activo';
    final origin = (p['origin'] as String?) ?? 'nueva_venta';
    final isMigrated = origin == 'migracion_manual';
    final isCompleted = status == 'completado';

    final statusColor = isCompleted
        ? Colors.grey.shade500
        : remaining <= 1
            ? const Color(0xFFB32D2D)
            : const Color(0xFF2D8A4F);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F3EF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ),
              if (isMigrated)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text('Migrado',
                      style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600)),
                ),
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isCompleted ? 'Completado' : 'Activo',
                  style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Barra de progreso de sesiones
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? used / total : 0,
              minHeight: 6,
              backgroundColor: const Color(0xFFEEEEEE),
              color: isCompleted ? Colors.grey.shade400 : SaharaTheme.gold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event_available_outlined,
                  size: 13, color: statusColor),
              const SizedBox(width: 4),
              Text(
                isCompleted
                    ? 'Completado · $total sesiones usadas'
                    : 'Restan $remaining de $total sesiones (usadas $used)',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor),
              ),
              const Spacer(),
              if (!isCompleted)
                TextButton(
                  onPressed: () => _openSessionHistory(p),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black45,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Ver historial',
                      style: GoogleFonts.inter(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<void> _openSellDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _SellPackageDialog(
        clientId: widget.clientId,
        clientName: widget.clientName,
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _openMigrateDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _MigratePackageDialog(
        clientId: widget.clientId,
        clientName: widget.clientName,
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _openSessionHistory(Map<String, dynamic> pkg) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PackageSessionHistoryDialog(pkg: pkg),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo: Vender paquete nuevo (genera ingreso)
// ─────────────────────────────────────────────────────────────────────────────
class _SellPackageDialog extends StatefulWidget {
  const _SellPackageDialog({
    required this.clientId,
    required this.clientName,
  });
  final String clientId;
  final String clientName;

  @override
  State<_SellPackageDialog> createState() => _SellPackageDialogState();
}

class _SellPackageDialogState extends State<_SellPackageDialog> {
  List<Map<String, dynamic>> _packageServices = [];
  List<Map<String, dynamic>> _baseServices = [];
  String? _selectedPkgServiceId;
  String? _selectedBaseServiceId;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _paymentMethod = 'efectivo';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final data = await Supabase.instance.client
          .from('services')
          .select('id, name, price, sessions_count, is_package')
          .order('name');
      if (!mounted) return;
      final all = (data as List).cast<Map<String, dynamic>>();
      setState(() {
        _packageServices = all.where((s) => s['is_package'] == true).toList();
        _baseServices = all.where((s) => s['is_package'] != true).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los servicios: $e';
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _selectedPkg =>
      _packageServices.where((s) => s['id'] == _selectedPkgServiceId).firstOrNull;

  double get _price =>
      (_selectedPkg?['price'] as num?)?.toDouble() ?? 0;

  int get _sessions =>
      (_selectedPkg?['sessions_count'] as num?)?.toInt() ?? 0;

  Future<void> _save() async {
    if (_selectedPkgServiceId == null) {
      setState(() => _error = 'Selecciona el paquete a vender');
      return;
    }
    if (_selectedBaseServiceId == null) {
      setState(() => _error = 'Selecciona el servicio individual que se agendará por sesión');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      final db = Supabase.instance.client;

      // 1. Crear la venta (ingreso del día)
      final saleRes = await db.from('sales').insert({
        'client_id': null,
        'customer_id': widget.clientId,
        'total': _price,
        'subtotal': _price,
        'payment_method': _paymentMethod,
        'payment_status': 'paid',
        'sale_status': 'completed',
        'status': 'paid',
        'created_by': me,
        'notes': 'Venta de paquete: ${_selectedPkg!['name']}',
      }).select('id').single();
      final saleId = saleRes['id'] as String;

      await db.from('sale_items').insert({
        'sale_id': saleId,
        'name': _selectedPkg!['name'],
        'description': '$_sessions sesiones de paquete',
        'quantity': 1,
        'unit_price': _price,
        'total_price': _price,
        'service_id': _selectedPkgServiceId,
      });

      // 2. Crear el client_package con sesiones via RPC
      await db.rpc('create_client_package', params: {
        'p_client_id': widget.clientId,
        'p_service_id': _selectedPkgServiceId,
        'p_base_service_id': _selectedBaseServiceId,
        'p_sessions_total': _sessions,
        'p_sessions_used': 0,
        'p_total_amount': _price,
        'p_origin': 'nueva_venta',
        'p_sale_id': saleId,
        'p_migration_note': null,
        'p_created_by': me,
        'p_name': null,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Paquete vendido: $_sessions sesiones registradas. Venta guardada como ingreso.'),
          backgroundColor: const Color(0xFF2D8A4F),
        ),
      );
    } catch (e) {
      if (mounted) setState(() { _error = 'Error: $e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF5F3EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
              const Icon(Icons.local_activity_outlined,
                  size: 18, color: SaharaTheme.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Vender paquete · ${widget.clientName}',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.black38),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Body
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: SaharaTheme.gold),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _card([
                      _label('Paquete a vender *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPkgServiceId,
                        isExpanded: true,
                        hint: const Text('Selecciona el paquete'),
                        decoration: _inputDeco(),
                        items: _packageServices.map((s) {
                          final price = (s['price'] as num?)?.toDouble() ?? 0;
                          final sess = (s['sessions_count'] as num?)?.toInt() ?? 0;
                          return DropdownMenuItem<String>(
                            value: s['id'] as String,
                            child: Text(
                                '${s['name']}  ·  $sess ses.  ·  \$${price.toStringAsFixed(0)}',
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() { _selectedPkgServiceId = v; _error = null; }),
                      ),
                      if (_selectedPkg != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SaharaTheme.gold.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: SaharaTheme.gold),
                            const SizedBox(width: 8),
                            Text(
                              '$_sessions sesiones  ·  \$${_price.toStringAsFixed(0)} MXN',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87),
                            ),
                          ]),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    _card([
                      _label('Servicio individual por sesión *'),
                      const SizedBox(height: 4),
                      Text(
                        'El servicio que se agendará en cada cita del paquete',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.black45),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedBaseServiceId,
                        isExpanded: true,
                        hint: const Text('Selecciona el servicio'),
                        decoration: _inputDeco(),
                        items: _baseServices.map((s) {
                          final price = (s['price'] as num?)?.toDouble() ?? 0;
                          return DropdownMenuItem<String>(
                            value: s['id'] as String,
                            child: Text(
                                '${s['name']}  ·  \$${price.toStringAsFixed(0)}',
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() { _selectedBaseServiceId = v; _error = null; }),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _card([
                      _label('Método de pago'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _paymentMethod,
                        decoration: _inputDeco(),
                        items: const [
                          DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                          DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                          DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                          DropdownMenuItem(value: 'stripe', child: Text('Stripe')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _paymentMethod = v);
                        },
                      ),
                    ]),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(top: BorderSide(color: Color(0xFFECE9E4))),
            ),
            child: Row(children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar',
                    style: GoogleFonts.inter(color: Colors.black54)),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: SaharaTheme.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.check, size: 16),
                label: Text('Vender y registrar ingreso',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo: Registrar paquete existente (migración — sin ingreso nuevo)
// ─────────────────────────────────────────────────────────────────────────────
class _MigratePackageDialog extends StatefulWidget {
  const _MigratePackageDialog({
    required this.clientId,
    required this.clientName,
  });
  final String clientId;
  final String clientName;

  @override
  State<_MigratePackageDialog> createState() => _MigratePackageDialogState();
}

class _MigratePackageDialogState extends State<_MigratePackageDialog> {
  List<Map<String, dynamic>> _packageServices = [];
  List<Map<String, dynamic>> _baseServices = [];
  String? _selectedPkgServiceId;
  String? _selectedBaseServiceId;
  int _sessionsTotal = 4;
  int _sessionsUsed = 0;
  final _noteCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final data = await Supabase.instance.client
          .from('services')
          .select('id, name, price, sessions_count, is_package')
          .order('name');
      if (!mounted) return;
      final all = (data as List).cast<Map<String, dynamic>>();
      setState(() {
        _packageServices = all.where((s) => s['is_package'] == true).toList();
        _baseServices = all.where((s) => s['is_package'] != true).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Error al cargar servicios: $e'; _loading = false; });
    }
  }

  Map<String, dynamic>? get _selectedPkg =>
      _packageServices.where((s) => s['id'] == _selectedPkgServiceId).firstOrNull;

  int get _sessionsRemaining => (_sessionsTotal - _sessionsUsed).clamp(0, _sessionsTotal);

  Future<void> _save() async {
    if (_selectedPkgServiceId == null) {
      setState(() => _error = 'Selecciona el paquete');
      return;
    }
    if (_selectedBaseServiceId == null) {
      setState(() => _error = 'Selecciona el servicio individual por sesión');
      return;
    }
    if (_noteCtrl.text.trim().isEmpty) {
      setState(() => _error = 'La nota es obligatoria para paquetes existentes');
      return;
    }
    if (_sessionsUsed > _sessionsTotal) {
      setState(() => _error = 'Las sesiones usadas no pueden ser mayores al total');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.rpc('create_client_package', params: {
        'p_client_id': widget.clientId,
        'p_service_id': _selectedPkgServiceId,
        'p_base_service_id': _selectedBaseServiceId,
        'p_sessions_total': _sessionsTotal,
        'p_sessions_used': _sessionsUsed,
        'p_total_amount': 0,
        'p_origin': 'migracion_manual',
        'p_sale_id': null,
        'p_migration_note': _noteCtrl.text.trim(),
        'p_created_by': me,
        'p_name': null,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Paquete registrado: $_sessionsRemaining sesiones restantes de $_sessionsTotal.'),
          backgroundColor: const Color(0xFF2D8A4F),
        ),
      );
    } catch (e) {
      if (mounted) setState(() { _error = 'Error: $e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF5F3EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
              const Icon(Icons.history_edu_outlined,
                  size: 18, color: Colors.black54),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Registrar paquete existente · ${widget.clientName}',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.black38),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: const Color(0xFFFFF8E1),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  size: 14, color: Color(0xFFB37500)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Este flujo es para paquetes ya cobrados antes del sistema. No genera ingreso nuevo.',
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: const Color(0xFF7A5100)),
                ),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _card([
                    _label('Paquete *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPkgServiceId,
                      isExpanded: true,
                      hint: const Text('Selecciona el paquete'),
                      decoration: _inputDeco(),
                      items: _packageServices.map((s) {
                        final sess = (s['sessions_count'] as num?)?.toInt() ?? 0;
                        return DropdownMenuItem<String>(
                          value: s['id'] as String,
                          child: Text('${s['name']}  ·  $sess sesiones',
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) {
                        final pkg = _packageServices
                            .where((s) => s['id'] == v)
                            .firstOrNull;
                        final sess =
                            (pkg?['sessions_count'] as num?)?.toInt() ?? 4;
                        setState(() {
                          _selectedPkgServiceId = v;
                          _sessionsTotal = sess;
                          _sessionsUsed = 0;
                          _error = null;
                        });
                      },
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _card([
                    _label('Servicio individual por sesión *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBaseServiceId,
                      isExpanded: true,
                      hint: const Text('Servicio que se agenda cada vez'),
                      decoration: _inputDeco(),
                      items: _baseServices.map((s) {
                        return DropdownMenuItem<String>(
                          value: s['id'] as String,
                          child: Text(s['name'] as String,
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setState(() { _selectedBaseServiceId = v; _error = null; }),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _card([
                    _label('Sesiones del paquete *'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total compradas',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 6),
                            _counterField(
                              value: _sessionsTotal,
                              min: 1,
                              max: 50,
                              onChanged: (v) => setState(() {
                                _sessionsTotal = v;
                                if (_sessionsUsed > v) _sessionsUsed = v;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ya usadas',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 6),
                            _counterField(
                              value: _sessionsUsed,
                              min: 0,
                              max: _sessionsTotal,
                              onChanged: (v) =>
                                  setState(() => _sessionsUsed = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Restantes',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 6),
                            Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: SaharaTheme.gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_sessionsRemaining',
                                style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: SaharaTheme.gold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  _card([
                    _label('Nota obligatoria *'),
                    const SizedBox(height: 4),
                    Text(
                      'Explica el contexto: cuándo se compró, quién lo vendió, etc.',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.black45),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      minLines: 2,
                      maxLines: 3,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDeco().copyWith(
                        hintText:
                            'Ej: Paquete vendido antes del sistema. Cliente ya usó 2 sesiones.',
                        hintStyle: GoogleFonts.inter(
                            color: Colors.black38, fontSize: 12),
                      ),
                    ),
                  ]),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(top: BorderSide(color: Color(0xFFECE9E4))),
            ),
            child: Row(children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar',
                    style: GoogleFonts.inter(color: Colors.black54)),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.history_edu_outlined, size: 16),
                label: Text('Registrar sin ingreso',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _counterField({
    required int value,
    required int min,
    required int max,
    required void Function(int) onChanged,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDD9D3)),
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 16),
          onPressed:
              value > min ? () => onChanged(value - 1) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        Expanded(
          child: Text('$value',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 16),
          onPressed:
              value < max ? () => onChanged(value + 1) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo: Historial de sesiones del paquete
// ─────────────────────────────────────────────────────────────────────────────
class _PackageSessionHistoryDialog extends StatefulWidget {
  const _PackageSessionHistoryDialog({required this.pkg});
  final Map<String, dynamic> pkg;

  @override
  State<_PackageSessionHistoryDialog> createState() =>
      _PackageSessionHistoryDialogState();
}

class _PackageSessionHistoryDialogState
    extends State<_PackageSessionHistoryDialog> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client
          .from('client_package_sessions')
          .select('id, status, service_name, used_at, appointment_id')
          .eq('client_package_id', widget.pkg['id'])
          .order('status') // pendientes primero
          .order('used_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _sessions = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    try {
      final d = DateTime.parse(v.toString()).toLocal();
      const m = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
      return '${d.day} ${m[d.month-1]} ${d.year}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return v.toString(); }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.pkg['name'] as String?) ?? 'Paquete';
    final total = (widget.pkg['sessions_total'] as num?)?.toInt() ?? 0;
    final remaining = (widget.pkg['sessions_remaining'] as num?)?.toInt() ?? 0;

    return AlertDialog(
      backgroundColor: const Color(0xFFF5F3EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Historial · $name',
            style: GoogleFonts.playfairDisplay(
                fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Restan $remaining de $total sesiones',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
      ]),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(
                height: 80,
                child: Center(
                    child: CircularProgressIndicator(color: SaharaTheme.gold)))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: _sessions.map(_sessionRow).toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _sessionRow(Map<String, dynamic> s) {
    final used = s['status'] == 'usada';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: used
                ? const Color(0xFF2D8A4F).withValues(alpha: 0.12)
                : const Color(0xFFB37500).withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            used ? Icons.check : Icons.hourglass_empty_rounded,
            size: 14,
            color: used ? const Color(0xFF2D8A4F) : const Color(0xFFB37500),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              used ? 'Sesión usada' : 'Sesión pendiente',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87),
            ),
            if (used && s['used_at'] != null)
              Text(_fmtDate(s['used_at']),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.black45)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de UI compartidos (privados al archivo)
// ─────────────────────────────────────────────────────────────────────────────
Widget _card(List<Widget> children) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );

Widget _label(String text) => Text(text,
    style: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87));

InputDecoration _inputDeco() => InputDecoration(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFDDD9D3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: SaharaTheme.gold, width: 1.5),
      ),
    );
