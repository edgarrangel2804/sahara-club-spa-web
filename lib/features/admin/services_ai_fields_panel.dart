// Panel admin: captura los campos del agente IA en cada servicio
// (benefits, contraindications, recommended_for, internal_notes).
// NO toca campos comerciales (precio, duración, descripción base).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/sahara_theme.dart';

class ServicesAiFieldsPanel extends StatefulWidget {
  const ServicesAiFieldsPanel({super.key});

  @override
  State<ServicesAiFieldsPanel> createState() => _ServicesAiFieldsPanelState();
}

class _ServiceAiRow {
  final String id;
  final String name;
  final String? description;
  final String? category;
  List<String> benefits;
  List<String> contraindications;
  List<String> recommendedFor;
  String internalNotes;
  bool dirty = false;
  bool saving = false;

  _ServiceAiRow({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.benefits,
    required this.contraindications,
    required this.recommendedFor,
    required this.internalNotes,
  });

  factory _ServiceAiRow.fromMap(Map<String, dynamic> m) {
    List<String> asList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return _ServiceAiRow(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      description: m['description'] as String?,
      category: m['category'] as String?,
      benefits: asList(m['benefits']),
      contraindications: asList(m['contraindications']),
      recommendedFor: asList(m['recommended_for']),
      internalNotes: (m['internal_notes'] as String?) ?? '',
    );
  }
}

class _ServicesAiFieldsPanelState extends State<ServicesAiFieldsPanel> {
  bool _loading = true;
  List<_ServiceAiRow> _rows = [];
  String? _flash;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('services')
          .select('id, name, description, category, benefits, contraindications, recommended_for, internal_notes, is_active')
          .eq('is_active', true)
          .order('name');
      _rows = (data as List)
          .map((e) => _ServiceAiRow.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _flash = 'Error: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(_ServiceAiRow r) async {
    setState(() => r.saving = true);
    try {
      await Supabase.instance.client.from('services').update({
        'benefits': r.benefits,
        'contraindications': r.contraindications,
        'recommended_for': r.recommendedFor,
        'internal_notes': r.internalNotes,
      }).eq('id', r.id);
      r.dirty = false;
      _flash = '✓ ${r.name} guardado';
    } catch (e) {
      _flash = 'Error guardando ${r.name}: $e';
    } finally {
      if (mounted) setState(() => r.saving = false);
    }
  }

  Widget _tagEditor({
    required String label,
    required List<String> values,
    required ValueChanged<List<String>> onChanged,
    String? hint,
  }) {
    final ctrl = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...values.asMap().entries.map((e) => Chip(
                  label: Text(e.value, style: const TextStyle(fontSize: 12)),
                  onDeleted: () {
                    final copy = List<String>.from(values)..removeAt(e.key);
                    onChanged(copy);
                  },
                )),
            SizedBox(
              width: 200,
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint ?? '+ agregar (Enter)',
                  hintStyle: const TextStyle(fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isEmpty) return;
                  onChanged([...values, t]);
                  ctrl.clear();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _serviceCard(_ServiceAiRow r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: r.dirty ? const Color(0xFFC68A17) : const Color(0xFFECE9E4),
          width: r.dirty ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              if (r.category != null && r.category!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1ECE3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(r.category!, style: const TextStyle(fontSize: 11)),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: r.dirty && !r.saving ? () => _save(r) : null,
                icon: r.saving
                    ? const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 14),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaharaTheme.gold,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          if (r.description != null && r.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.description!,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          _tagEditor(
            label: 'Beneficios (qué le aporta al cliente)',
            values: r.benefits,
            hint: 'ej. relajación profunda',
            onChanged: (v) => setState(() { r.benefits = v; r.dirty = true; }),
          ),
          const SizedBox(height: 10),
          _tagEditor(
            label: 'Recomendado para (palabras clave / problemas)',
            values: r.recommendedFor,
            hint: 'ej. estrés, primera visita',
            onChanged: (v) => setState(() { r.recommendedFor = v; r.dirty = true; }),
          ),
          const SizedBox(height: 10),
          _tagEditor(
            label: 'Contraindicaciones',
            values: r.contraindications,
            hint: 'ej. embarazo primer trimestre',
            onChanged: (v) => setState(() { r.contraindications = v; r.dirty = true; }),
          ),
          const SizedBox(height: 10),
          Text(
            'Notas internas (solo recepción/agente, no público)',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: r.internalNotes),
            maxLines: 2,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'ej. la terapeuta María es especialista en este servicio',
            ),
            onChanged: (v) {
              r.internalNotes = v;
              r.dirty = true;
            },
          ),
        ],
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
              'Datos del agente IA por servicio',
              style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: SaharaTheme.grisCarbon,
              ),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Estos campos alimentan al agente recepcionista. Sin esto, el agente no podrá recomendar servicios ni avisar contraindicaciones.',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
        ),
        if (_flash != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F1E7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_flash!, style: GoogleFonts.inter(fontSize: 12)),
            ),
          ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ..._rows.map(_serviceCard),
      ],
    );
  }
}
