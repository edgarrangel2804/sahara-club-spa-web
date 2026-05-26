import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/sahara_theme.dart';

const _kBranchId = '11111111-1111-1111-1111-111111111111';
const _kCategories = ['general', 'pagos', 'citas', 'servicios', 'politicas', 'ubicacion'];

class FaqsPanel extends StatefulWidget {
  const FaqsPanel({super.key});

  @override
  State<FaqsPanel> createState() => _FaqsPanelState();
}

class _Faq {
  final String id;
  String question;
  String answer;
  String category;
  bool isActive;
  int order;
  List<String> tags;
  String scopeCategory;
  bool dirty;
  bool saving;

  _Faq({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.isActive,
    required this.order,
    required this.tags,
    required this.scopeCategory,
    this.dirty = false,
    this.saving = false,
  });

  factory _Faq.fromMap(Map<String, dynamic> m) => _Faq(
        id: m['id'] as String,
        question: (m['question'] as String?) ?? '',
        answer: (m['answer'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'general',
        isActive: (m['is_active'] as bool?) ?? true,
        order: (m['display_order'] as num?)?.toInt() ?? 100,
        tags: ((m['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
        scopeCategory: (m['scope_category'] as String?) ?? 'sahara',
      );
}

class _FaqsPanelState extends State<FaqsPanel> {
  bool _loading = true;
  List<_Faq> _faqs = [];
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
          .from('faqs')
          .select()
          .order('category')
          .order('display_order');
      _faqs = (data as List)
          .map((e) => _Faq.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _flash = 'Error: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    String cat = 'general';
    if (!mounted) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva FAQ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qCtrl, decoration: const InputDecoration(labelText: 'Pregunta')),
              const SizedBox(height: 8),
              TextField(controller: aCtrl, decoration: const InputDecoration(labelText: 'Respuesta'), maxLines: 3),
              const SizedBox(height: 8),
              StatefulBuilder(builder: (_, setS) {
                return DropdownButtonFormField<String>(
                  value: cat,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: _kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setS(() => cat = v ?? 'general'),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
        ],
      ),
    );
    if (created != true) return;
    if (qCtrl.text.trim().isEmpty || aCtrl.text.trim().isEmpty) return;
    try {
      await Supabase.instance.client.from('faqs').insert({
        'branch_id': _kBranchId,
        'question': qCtrl.text.trim(),
        'answer': aCtrl.text.trim(),
        'category': cat,
      });
      await _load();
    } catch (e) {
      setState(() => _flash = 'Error: $e');
    }
  }

  Future<void> _save(_Faq f) async {
    setState(() => f.saving = true);
    try {
      await Supabase.instance.client.from('faqs').update({
        'question': f.question,
        'answer': f.answer,
        'category': f.category,
        'is_active': f.isActive,
        'tags': f.tags,
        'scope_category': f.scopeCategory,
      }).eq('id', f.id);
      f.dirty = false;
      _flash = '✓ FAQ guardada';
    } catch (e) {
      _flash = 'Error: $e';
    } finally {
      if (mounted) setState(() => f.saving = false);
    }
  }

  Future<void> _delete(_Faq f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar FAQ'),
        content: Text('¿Eliminar "${f.question}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB32D2D)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('faqs').delete().eq('id', f.id);
      await _load();
    } catch (e) {
      setState(() => _flash = 'Error: $e');
    }
  }

  Widget _faqCard(_Faq f) {
    final outOfScope = f.scopeCategory != 'sahara';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: outOfScope ? const Color(0xFFFFF5F5) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: f.dirty
              ? const Color(0xFFC68A17)
              : outOfScope
                  ? const Color(0xFFB32D2D)
                  : const Color(0xFFECE9E4),
          width: f.dirty || outOfScope ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1ECE3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(f.category, style: const TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 6),
              // Chip de scope. Toggle Sahara <-> Fuera de scope.
              GestureDetector(
                onTap: () => setState(() {
                  f.scopeCategory = outOfScope ? 'sahara' : 'out_of_scope';
                  f.dirty = true;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: outOfScope
                        ? const Color(0xFFFFE5E5)
                        : const Color(0xFFE5F4E8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: outOfScope
                          ? const Color(0xFFB32D2D)
                          : const Color(0xFF2D8A4F),
                    ),
                  ),
                  child: Text(
                    outOfScope ? '⚠ fuera de scope' : '✓ sahara',
                    style: TextStyle(
                      fontSize: 11,
                      color: outOfScope
                          ? const Color(0xFFB32D2D)
                          : const Color(0xFF2D8A4F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: f.isActive,
                onChanged: (v) => setState(() {
                  f.isActive = v;
                  f.dirty = true;
                }),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: f.dirty && !f.saving ? () => _save(f) : null,
                icon: f.saving
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 14),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaharaTheme.gold,
                  foregroundColor: Colors.black,
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(f)),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: f.question),
            decoration: const InputDecoration(labelText: 'Pregunta', isDense: true),
            onChanged: (v) { f.question = v; f.dirty = true; },
          ),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: f.answer),
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Respuesta', isDense: true),
            onChanged: (v) { f.answer = v; f.dirty = true; },
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
              'Preguntas frecuentes (FAQs)',
              style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: SaharaTheme.grisCarbon,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nueva FAQ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SaharaTheme.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'El agente usará estas preguntas para responder a clientes en WhatsApp.',
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
        else if (_faqs.isEmpty)
          Center(child: Text('Sin FAQs.', style: GoogleFonts.inter(color: Colors.black54)))
        else
          ..._faqs.map(_faqCard),
      ],
    );
  }
}
