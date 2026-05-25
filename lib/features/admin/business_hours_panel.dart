import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/sahara_theme.dart';

const _kBranchId = '11111111-1111-1111-1111-111111111111';
const _kWeekdayNames = [
  'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado',
];

class BusinessHoursPanel extends StatefulWidget {
  const BusinessHoursPanel({super.key});

  @override
  State<BusinessHoursPanel> createState() => _BusinessHoursPanelState();
}

class _DayRow {
  final int weekday;
  bool isClosed;
  TimeOfDay? opensAt;
  TimeOfDay? closesAt;

  _DayRow({
    required this.weekday,
    required this.isClosed,
    required this.opensAt,
    required this.closesAt,
  });

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final p = raw.split(':');
    if (p.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(p[0]) ?? 0,
      minute: int.tryParse(p[1]) ?? 0,
    );
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  factory _DayRow.fromMap(Map<String, dynamic> m) => _DayRow(
        weekday: (m['weekday'] as num).toInt(),
        isClosed: (m['is_closed'] as bool?) ?? false,
        opensAt: _parseTime(m['opens_at'] as String?),
        closesAt: _parseTime(m['closes_at'] as String?),
      );

  Map<String, dynamic> toUpdate() => {
        'is_closed': isClosed,
        'opens_at': isClosed ? null : (opensAt == null ? null : _formatTime(opensAt!)),
        'closes_at': isClosed ? null : (closesAt == null ? null : _formatTime(closesAt!)),
      };
}

class _ClosedDay {
  final String id;
  final DateTime date;
  final String reason;
  _ClosedDay({required this.id, required this.date, required this.reason});

  factory _ClosedDay.fromMap(Map<String, dynamic> m) => _ClosedDay(
        id: m['id'] as String,
        date: DateTime.parse(m['date'] as String),
        reason: (m['reason'] as String?) ?? '',
      );
}

class _BusinessHoursPanelState extends State<BusinessHoursPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  bool _saving = false;
  String? _flash;
  List<_DayRow> _days = [];
  List<_ClosedDay> _closed = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
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
      final supa = Supabase.instance.client;
      final h = await supa
          .from('business_hours')
          .select()
          .eq('branch_id', _kBranchId)
          .order('weekday');
      _days = (h as List)
          .map((e) => _DayRow.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      final c = await supa
          .from('business_closed_days')
          .select()
          .eq('branch_id', _kBranchId)
          .gte('date', DateTime.now().toIso8601String().split('T').first)
          .order('date');
      _closed = (c as List)
          .map((e) => _ClosedDay.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _flash = 'Error al cargar: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveDay(_DayRow row) async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('business_hours')
          .update(row.toUpdate())
          .eq('branch_id', _kBranchId)
          .eq('weekday', row.weekday);
      _flash = '✓ ${_kWeekdayNames[row.weekday]} guardado';
    } catch (e) {
      _flash = 'Error guardando ${_kWeekdayNames[row.weekday]}: $e';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? initial) async {
    return showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 10, minute: 0),
    );
  }

  Future<void> _addClosedDay() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date == null) return;
    final reasonCtrl = TextEditingController();
    if (!mounted) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo del cierre'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej. Día de la madre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await Supabase.instance.client.from('business_closed_days').insert({
        'branch_id': _kBranchId,
        'date': date.toIso8601String().split('T').first,
        'reason': reason,
      });
      _flash = '✓ Día cerrado agregado';
      await _load();
    } catch (e) {
      setState(() => _flash = 'Error: $e');
    }
  }

  Future<void> _deleteClosed(_ClosedDay c) async {
    try {
      await Supabase.instance.client
          .from('business_closed_days')
          .delete()
          .eq('id', c.id);
      await _load();
    } catch (e) {
      setState(() => _flash = 'Error: $e');
    }
  }

  Widget _dayTile(_DayRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              _kWeekdayNames[row.weekday],
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          Switch(
            value: !row.isClosed,
            onChanged: (v) {
              setState(() {
                row.isClosed = !v;
                if (!row.isClosed && row.opensAt == null) {
                  row.opensAt = const TimeOfDay(hour: 10, minute: 0);
                  row.closesAt = const TimeOfDay(hour: 19, minute: 0);
                }
              });
              _saveDay(row);
            },
          ),
          const SizedBox(width: 8),
          if (row.isClosed)
            Text('Cerrado', style: GoogleFonts.inter(color: Colors.black54))
          else ...[
            OutlinedButton(
              onPressed: () async {
                final t = await _pickTime(row.opensAt);
                if (t != null) {
                  setState(() => row.opensAt = t);
                  await _saveDay(row);
                }
              },
              child: Text('Abre: ${row.opensAt?.format(context) ?? "—"}'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final t = await _pickTime(row.closesAt);
                if (t != null) {
                  setState(() => row.closesAt = t);
                  await _saveDay(row);
                }
              },
              child: Text('Cierra: ${row.closesAt?.format(context) ?? "—"}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _closedTile(_ClosedDay c) {
    return ListTile(
      leading: const Icon(Icons.event_busy, color: Color(0xFFB32D2D)),
      title: Text(
        '${c.date.year}-${c.date.month.toString().padLeft(2, '0')}-${c.date.day.toString().padLeft(2, '0')}',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(c.reason),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteClosed(c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Horario y disponibilidad',
              style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: SaharaTheme.grisCarbon,
              ),
            ),
            const Spacer(),
            if (_saving)
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        if (_flash != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F1E7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_flash!, style: GoogleFonts.inter(fontSize: 12)),
            ),
          ),
        const SizedBox(height: 8),
        TabBar(
          controller: _tab,
          labelColor: SaharaTheme.grisCarbon,
          indicatorColor: SaharaTheme.gold,
          tabs: const [
            Tab(text: 'Horario semanal'),
            Tab(text: 'Días cerrados / festivos'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 460,
          child: TabBarView(
            controller: _tab,
            children: [
              _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : ListView(children: _days.map(_dayTile).toList()),
              _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _addClosedDay,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Agregar día cerrado'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SaharaTheme.gold,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _closed.isEmpty
                              ? Center(
                                  child: Text(
                                    'No hay días cerrados configurados.',
                                    style: GoogleFonts.inter(color: Colors.black54),
                                  ),
                                )
                              : ListView(children: _closed.map(_closedTile).toList()),
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
