// Panel admin: perfil del terapeuta para el agente IA
// (specialties, certifications, bio, recommended_services, active_for_ai, years_experience)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/sahara_theme.dart';

class StaffAiProfilePanel extends StatefulWidget {
  const StaffAiProfilePanel({super.key});

  @override
  State<StaffAiProfilePanel> createState() => _StaffAiProfilePanelState();
}

class _StaffRow {
  final String id;
  final String fullName;
  final String? role;
  List<String> specialties;
  List<String> certifications;
  String bio;
  List<String> recommendedServices;  // uuids
  bool activeForAi;
  int? yearsExperience;
  bool dirty = false;
  bool saving = false;

  _StaffRow({
    required this.id,
    required this.fullName,
    required this.role,
    required this.specialties,
    required this.certifications,
    required this.bio,
    required this.recommendedServices,
    required this.activeForAi,
    required this.yearsExperience,
  });

  factory _StaffRow.fromMap(Map<String, dynamic> m) {
    List<String> asList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return _StaffRow(
      id: m['id'] as String,
      fullName: (m['full_name'] as String?) ?? '',
      role: m['role'] as String?,
      specialties: asList(m['specialties']),
      certifications: asList(m['certifications']),
      bio: (m['bio'] as String?) ?? '',
      recommendedServices: asList(m['recommended_services']),
      activeForAi: (m['active_for_ai'] as bool?) ?? true,
      yearsExperience: (m['years_experience'] as num?)?.toInt(),
    );
  }
}

class _StaffAiProfilePanelState extends State<StaffAiProfilePanel> {
  bool _loading = true;
  List<_StaffRow> _rows = [];
  Map<String, String> _services = {};  // id → name
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
      final svcs = await supa.from('services').select('id, name').eq('is_active', true);
      _services = {
        for (final s in (svcs as List)) (s['id'] as String): (s['name'] as String? ?? '')
      };
      final data = await supa
          .from('staff')
          .select('id, full_name, role, specialties, certifications, bio, recommended_services, active_for_ai, years_experience, active')
          .eq('active', true)
          .order('full_name');
      _rows = (data as List)
          .map((e) => _StaffRow.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _flash = 'Error: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(_StaffRow r) async {
    setState(() => r.saving = true);
    try {
      await Supabase.instance.client.from('staff').update({
        'specialties': r.specialties,
        'certifications': r.certifications,
        'bio': r.bio,
        'recommended_services': r.recommendedServices,
        'active_for_ai': r.activeForAi,
        'years_experience': r.yearsExperience,
      }).eq('id', r.id);
      r.dirty = false;
      _flash = '✓ ${r.fullName} guardado';
    } catch (e) {
      _flash = 'Error: $e';
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

  Widget _serviceMultiSelect(_StaffRow r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Servicios donde es referente',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _services.entries.map((e) {
            final selected = r.recommendedServices.contains(e.key);
            return FilterChip(
              label: Text(e.value, style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    r.recommendedServices = [...r.recommendedServices, e.key];
                  } else {
                    r.recommendedServices = r.recommendedServices.where((id) => id != e.key).toList();
                  }
                  r.dirty = true;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _staffCard(_StaffRow r) {
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
              CircleAvatar(
                backgroundColor: SaharaTheme.gold.withValues(alpha: 0.18),
                child: Text(
                  r.fullName.isEmpty ? '?' : r.fullName[0].toUpperCase(),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.fullName,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (r.role != null && r.role!.isNotEmpty)
                      Text(r.role!, style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              Column(
                children: [
                  const Text('Visible al agente', style: TextStyle(fontSize: 10)),
                  Switch(
                    value: r.activeForAi,
                    onChanged: (v) => setState(() {
                      r.activeForAi = v;
                      r.dirty = true;
                    }),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: r.dirty && !r.saving ? () => _save(r) : null,
                icon: r.saving
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 14),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaharaTheme.gold,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: TextEditingController(text: r.yearsExperience?.toString() ?? ''),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Años de experiencia',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    r.yearsExperience = int.tryParse(v);
                    r.dirty = true;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _tagEditor(
            label: 'Especialidades',
            values: r.specialties,
            hint: 'ej. facial, masaje sueco',
            onChanged: (v) => setState(() {
              r.specialties = v;
              r.dirty = true;
            }),
          ),
          const SizedBox(height: 10),
          _tagEditor(
            label: 'Certificaciones',
            values: r.certifications,
            hint: 'ej. Cosmetología CDMX',
            onChanged: (v) => setState(() {
              r.certifications = v;
              r.dirty = true;
            }),
          ),
          const SizedBox(height: 10),
          _serviceMultiSelect(r),
          const SizedBox(height: 10),
          Text('Bio (puede mencionarse en respuestas)',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: r.bio),
            maxLines: 3,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'Breve descripción profesional (2-3 líneas)',
            ),
            onChanged: (v) {
              r.bio = v;
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
              'Perfil profesional de terapeutas (para agente IA)',
              style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: SaharaTheme.grisCarbon,
              ),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'El agente usará estos datos para recomendar terapeutas y responder dudas sobre especialidades.',
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
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else if (_rows.isEmpty)
          Center(child: Text('Sin terapeutas activos.', style: GoogleFonts.inter(color: Colors.black54)))
        else
          ..._rows.map(_staffCard),
      ],
    );
  }
}
