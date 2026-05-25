// Sahara Club Spa - Centro de Control IA
// Switches + kill switch + estado en vivo del agente recepcionista.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/sahara_theme.dart';

class AiControlPanel extends StatefulWidget {
  const AiControlPanel({super.key});

  @override
  State<AiControlPanel> createState() => _AiControlPanelState();
}

class _Metrics {
  final bool aiEnabled;
  final String aiMode;
  final String activeModel;
  final List<String> allowedNumbers;
  final List<String> adminNumbers;
  final bool pauseAll;
  final bool handoffPriority;
  final bool allowAfterHours;
  final num maxDailyCost;
  final num maxAdminDailyCost;
  final bool adminReportEnabled;
  final num costToday;
  final int activeConversations;
  final int userMessagesToday;
  final int assistantMessagesToday;
  final int? avgLatencyMs;
  final int escalatedTotal;
  final int adminQueriesToday;

  _Metrics.fromMap(Map<String, dynamic> m)
      : aiEnabled = (m['ai_enabled'] as bool?) ?? false,
        aiMode = (m['ai_mode'] as String?) ?? 'pilot',
        activeModel = (m['active_model'] as String?) ?? '',
        allowedNumbers = ((m['allowed_test_numbers'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        adminNumbers = ((m['ai_admin_numbers'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        pauseAll = (m['ai_pause_all_conversations'] as bool?) ?? false,
        handoffPriority = (m['handoff_human_priority'] as bool?) ?? true,
        allowAfterHours = (m['allow_after_hours_responses'] as bool?) ?? false,
        maxDailyCost = (m['max_daily_cost_usd'] as num?) ?? 25,
        maxAdminDailyCost = (m['max_admin_daily_cost_usd'] as num?) ?? 5,
        adminReportEnabled = (m['admin_daily_report_enabled'] as bool?) ?? false,
        costToday = (m['cost_today_usd'] as num?) ?? 0,
        activeConversations =
            (m['active_conversations_24h'] as num?)?.toInt() ?? 0,
        userMessagesToday = (m['user_messages_today'] as num?)?.toInt() ?? 0,
        assistantMessagesToday =
            (m['assistant_messages_today'] as num?)?.toInt() ?? 0,
        avgLatencyMs = (m['avg_latency_ms_24h'] as num?)?.toInt(),
        escalatedTotal = (m['escalated_total'] as num?)?.toInt() ?? 0,
        adminQueriesToday =
            (m['admin_queries_today'] as num?)?.toInt() ?? 0;
}

class _AuditRow {
  final DateTime at;
  final String? email;
  final String field;
  final String? oldV;
  final String? newV;
  _AuditRow(this.at, this.email, this.field, this.oldV, this.newV);
  factory _AuditRow.fromMap(Map<String, dynamic> m) => _AuditRow(
        DateTime.parse(m['changed_at'] as String),
        m['changed_by_email'] as String?,
        m['field'] as String,
        m['old_value'] as String?,
        m['new_value'] as String?,
      );
}

class _AiControlPanelState extends State<AiControlPanel> {
  bool _loading = true;
  bool _saving = false;
  _Metrics? _metrics;
  List<_AuditRow> _audit = [];
  String? _flash;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final supa = Supabase.instance.client;
      final m = await supa.from('ai_metrics_dashboard').select().maybeSingle();
      if (m != null) _metrics = _Metrics.fromMap(Map<String, dynamic>.from(m));
      final a = await supa
          .from('ai_settings_audit')
          .select()
          .order('changed_at', ascending: false)
          .limit(15);
      _audit = (a as List)
          .map((e) => _AuditRow.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _flash = 'Error: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateField(Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('ai_settings')
          .update(patch)
          .eq('id', 1);
      _flash = '✓ Guardado';
      await _load();
    } catch (e) {
      _flash = 'Error: $e';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _killSwitch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detener IA inmediatamente'),
        content: const Text(
          'Esto pausará TODAS las respuestas automáticas de la IA. '
          'Los inbounds seguirán guardándose. Recepción opera normal. '
          '¿Confirmas?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB32D2D)),
            child: const Text('DETENER IA'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _updateField({'ai_pause_all_conversations': true});
    }
  }

  Future<void> _resumeAI() async {
    await _updateField({'ai_pause_all_conversations': false});
  }

  Future<void> _addNumber() async {
    final ctrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar número al piloto'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej. 6462882480'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (phone == null || phone.isEmpty || _metrics == null) return;
    final next = [..._metrics!.allowedNumbers, phone];
    await _updateField({'allowed_test_numbers': next});
  }

  Future<void> _removeNumber(String n) async {
    if (_metrics == null) return;
    final next = _metrics!.allowedNumbers.where((x) => x != n).toList();
    await _updateField({'allowed_test_numbers': next});
  }

  Future<void> _addAdminNumber() async {
    final ctrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar número administrador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Ej. 6462882480'),
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠ Los administradores pueden consultar datos internos del negocio por WhatsApp (resúmenes, ingresos, citas). No revela datos personales de clientes.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB32D2D)),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Agregar admin'),
          ),
        ],
      ),
    );
    if (phone == null || phone.isEmpty || _metrics == null) return;
    final next = [..._metrics!.adminNumbers, phone];
    await _updateField({'ai_admin_numbers': next});
  }

  Future<void> _removeAdminNumber(String n) async {
    if (_metrics == null) return;
    final next = _metrics!.adminNumbers.where((x) => x != n).toList();
    await _updateField({'ai_admin_numbers': next});
  }

  // ----------------------------------------------------------- Render --------

  Widget _statusBadge() {
    if (_metrics == null) return const SizedBox.shrink();
    String emoji;
    String label;
    Color color;
    if (!_metrics!.aiEnabled || _metrics!.aiMode == 'disabled') {
      emoji = '🔴'; label = 'IA APAGADA'; color = const Color(0xFFB32D2D);
    } else if (_metrics!.pauseAll) {
      emoji = '🟠'; label = 'IA PAUSADA'; color = const Color(0xFFC68A17);
    } else if (_metrics!.aiMode == 'pilot') {
      emoji = '🟡'; label = 'MODO PILOTO'; color = const Color(0xFFC68A17);
    } else {
      emoji = '🟢'; label = 'IA ACTIVA'; color = const Color(0xFF1A9E65);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$emoji  $label',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          color: color,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _kpi(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color ?? SaharaTheme.grisCarbon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: SaharaTheme.grisCarbon,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _metrics == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final m = _metrics!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ----- Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SaharaTheme.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: Color(0xFFC6A76A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Control IA Sahara',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: SaharaTheme.grisCarbon,
                    ),
                  ),
                  Text(
                    'La recepcionista SIEMPRE tiene prioridad sobre la IA.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            _statusBadge(),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        if (_flash != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F1E7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_flash!, style: GoogleFonts.inter(fontSize: 12)),
            ),
          ),
        const SizedBox(height: 16),

        // ----- KILL SWITCH
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: m.pauseAll
                ? const Color(0xFFC68A17).withValues(alpha: 0.10)
                : const Color(0xFFB32D2D).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: m.pauseAll ? const Color(0xFFC68A17) : const Color(0xFFB32D2D),
            ),
          ),
          child: Row(
            children: [
              Icon(
                m.pauseAll ? Icons.pause_circle : Icons.power_settings_new,
                color: m.pauseAll ? const Color(0xFFC68A17) : const Color(0xFFB32D2D),
                size: 32,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.pauseAll ? 'IA PAUSADA' : 'IA respondiendo',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      m.pauseAll
                          ? 'Los inbounds se siguen guardando. Recepción opera normal.'
                          : 'Pulsa para detener todas las respuestas automáticas.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (m.pauseAll)
                ElevatedButton.icon(
                  onPressed: _saving ? null : _resumeAI,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('REANUDAR IA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A9E65),
                    foregroundColor: Colors.white,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _saving ? null : _killSwitch,
                  icon: const Icon(Icons.stop),
                  label: const Text('DETENER IA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB32D2D),
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ----- KPIs
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.0,
          children: [
            _kpi('Modelo activo', m.activeModel),
            _kpi(
              'Costo hoy',
              '\$${m.costToday.toStringAsFixed(4)}',
              color: m.costToday >= m.maxDailyCost
                  ? const Color(0xFFB32D2D)
                  : null,
            ),
            _kpi('Cap diario', '\$${m.maxDailyCost.toStringAsFixed(2)}'),
            _kpi('Conv. activas 24h', '${m.activeConversations}'),
            _kpi('Msgs entrantes hoy', '${m.userMessagesToday}'),
            _kpi('Msgs IA hoy', '${m.assistantMessagesToday}'),
            _kpi('Latencia avg', m.avgLatencyMs == null ? '—' : '${m.avgLatencyMs}ms'),
            _kpi('Escaladas a recepción', '${m.escalatedTotal}'),
          ],
        ),
        const SizedBox(height: 20),

        // ----- Switch principal IA
        _section(
          title: 'Activación principal',
          child: SwitchListTile(
            value: m.aiEnabled,
            onChanged: (v) => _updateField({'ai_enabled': v}),
            title: Text('IA Activada (master switch)',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Si está OFF, todos los inbounds se guardan pero la IA no responde.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
            ),
          ),
        ),

        // ----- Modo
        _section(
          title: 'Modo de operación',
          child: Wrap(
            spacing: 8,
            children: [
              for (final mode in const ['disabled', 'pilot', 'read_only', 'assisted'])
                ChoiceChip(
                  label: Text(mode),
                  selected: m.aiMode == mode,
                  onSelected: mode == 'assisted'
                      ? null
                      : (sel) => _updateField({'ai_mode': mode}),
                ),
            ],
          ),
        ),

        // ----- Números piloto
        _section(
          title: 'Números autorizados (modo piloto)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...m.allowedNumbers.map((n) => Chip(
                        label: Text(n),
                        onDeleted: () => _removeNumber(n),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar'),
                    onPressed: _addNumber,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'En modo PILOT solo estos números reciben respuesta de la IA. '
                'En READ_ONLY responde a todos.',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),

        // ----- Números administradores (modo admin IA por WhatsApp)
        _section(
          title: 'Números administradores',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB32D2D).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFB32D2D).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 18, color: Color(0xFFB32D2D)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estos números pueden consultar datos internos del negocio '
                        '(resúmenes, ingresos, citas) por WhatsApp. NO revela datos '
                        'personales de clientes. Solo lectura.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF6B1F1F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...m.adminNumbers.map((n) => Chip(
                        avatar: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 16,
                          color: Color(0xFFB32D2D),
                        ),
                        label: Text(n),
                        onDeleted: () => _removeAdminNumber(n),
                        backgroundColor:
                            const Color(0xFFB32D2D).withValues(alpha: 0.10),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar admin'),
                    onPressed: _addAdminNumber,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Consultas admin hoy: ${m.adminQueriesToday}',
                      style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.black54,
                      ),
                    ),
                  ),
                  Text(
                    'Cap admin: \$${m.maxAdminDailyCost.toStringAsFixed(2)} USD/día',
                    style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ----- Switches secundarios
        _section(
          title: 'Reglas de operación',
          child: Column(
            children: [
              SwitchListTile(
                value: m.handoffPriority,
                onChanged: (v) => _updateField({'handoff_human_priority': v}),
                title: const Text('Recepción tiene prioridad'),
                subtitle: const Text(
                  'Cuando una conversación está escalada o cerrada por recepción, la IA no responde.',
                ),
              ),
              SwitchListTile(
                value: m.allowAfterHours,
                onChanged: (v) => _updateField({'allow_after_hours_responses': v}),
                title: const Text('Permitir respuestas fuera de horario'),
                subtitle: const Text(
                  'Si OFF, la IA solo responde dentro del horario operativo del spa.',
                ),
              ),
            ],
          ),
        ),

        // ----- Audit trail
        _section(
          title: 'Últimos cambios (auditoría)',
          child: _audit.isEmpty
              ? Text('Sin cambios registrados.',
                  style: GoogleFonts.inter(color: Colors.black54, fontSize: 12))
              : Column(
                  children: _audit.map((a) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.history, size: 14, color: Colors.black45),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.black87,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${a.at.toLocal().toString().substring(0, 16)} · ',
                                    style: const TextStyle(color: Colors.black45),
                                  ),
                                  TextSpan(text: '${a.email ?? "sistema"} '),
                                  TextSpan(
                                    text: 'cambió ${a.field} ',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(text: 'de "${a.oldV}" a "${a.newV}"'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
