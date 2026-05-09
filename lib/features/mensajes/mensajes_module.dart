import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class _Note {
  final String  id;
  final String  clientId;
  final String  clientName;
  final String  serviceName;
  final String  text;
  final DateTime date;

  const _Note({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.serviceName,
    required this.text,
    required this.date,
  });

  factory _Note.fromMap(Map<String, dynamic> m) => _Note(
    id:          m['id']           as String,
    clientId:    m['client_id']    as String? ?? '',
    clientName:  m['client_name']  as String? ?? 'Sin nombre',
    serviceName: m['service_name'] as String? ?? '',
    text:        m['notes']        as String? ?? '',
    date:        DateTime.tryParse(
                   (m['booking_date'] as String?) ?? '') ?? DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────
class MensajesModule extends StatefulWidget {
  const MensajesModule({super.key});

  @override
  State<MensajesModule> createState() => _MensajesModuleState();
}

class _MensajesModuleState extends State<MensajesModule> {
  List<_Note>  _notes    = [];
  _Note?       _selected;
  bool         _loading  = true;
  String       _search   = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('bookings')
          .select('id, client_id, client_name, service_name, notes, booking_date')
          .neq('notes', '')
          .order('booking_date', ascending: false)
          .limit(200);
      if (!mounted) return;
      setState(() {
        _notes   = (data as List).map((m) => _Note.fromMap(m as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveNote(String bookingId, String text) async {
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'notes': text})
          .eq('id', bookingId);
      _loadNotes();
    } catch (_) {}
  }

  List<_Note> get _filtered {
    if (_search.isEmpty) return _notes;
    final q = _search.toLowerCase();
    return _notes.where((n) =>
      n.clientName.toLowerCase().contains(q) ||
      n.text.toLowerCase().contains(q) ||
      n.serviceName.toLowerCase().contains(q),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left list ──────────────────────────────────────────
        SizedBox(
          width: 310,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mensajes',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20, fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                        )),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Buscar nota o cliente...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black38),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.black38),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // List
                Expanded(
                  child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _filtered.isEmpty
                      ? _EmptyState(
                          icon:    Icons.chat_bubble_outline,
                          message: _search.isEmpty
                            ? 'No hay notas en reservas.\nAgrega notas al crear o editar una reserva.'
                            : 'Sin resultados para "$_search"',
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final n = _filtered[i];
                            final selected = _selected?.id == n.id;
                            return _NoteTile(
                              note:     n,
                              selected: selected,
                              onTap:    () => setState(() => _selected = n),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        // ── Right detail ───────────────────────────────────────
        Expanded(
          child: _selected == null
            ? _EmptyState(
                icon:    Icons.mark_unread_chat_alt_outlined,
                message: 'Selecciona una nota para ver el detalle',
              )
            : _NoteDetail(
                note:     _selected!,
                onSave:   (text) => _saveNote(_selected!.id, text),
                onClose:  () => setState(() => _selected = null),
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Note Tile
// ─────────────────────────────────────────────────────────────────────────────
class _NoteTile extends StatefulWidget {
  const _NoteTile({required this.note, required this.selected, required this.onTap});
  final _Note note;
  final bool  selected;
  final VoidCallback onTap;

  @override
  State<_NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends State<_NoteTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
      ? const Color(0xFFFFF8EE)
      : _hover ? const Color(0xFFFAFAFA) : Colors.white;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              left: BorderSide(
                color: widget.selected
                    ? const Color(0xFFC6A76A)
                    : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: Color(0xFFF0F0F0)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              _Avatar(name: widget.note.clientName, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(widget.note.clientName,
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A1A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(_fmtDate(widget.note.date),
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.black38)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(widget.note.serviceName,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFFC6A76A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(widget.note.text,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Note Detail
// ─────────────────────────────────────────────────────────────────────────────
class _NoteDetail extends StatefulWidget {
  const _NoteDetail({required this.note, required this.onSave, required this.onClose});
  final _Note note;
  final Future<void> Function(String) onSave;
  final VoidCallback onClose;

  @override
  State<_NoteDetail> createState() => _NoteDetailState();
}

class _NoteDetailState extends State<_NoteDetail> {
  late final _ctrl = TextEditingController(text: widget.note.text);
  bool _saving = false;
  bool _dirty  = false;

  @override
  void didUpdateWidget(_NoteDetail old) {
    super.didUpdateWidget(old);
    if (old.note.id != widget.note.id) {
      _ctrl.text = widget.note.text;
      _dirty = false;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(_ctrl.text.trim());
    if (mounted) setState(() { _saving = false; _dirty = false; });
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return Container(
      color: const Color(0xFFF5F3EF),
      child: Column(
        children: [
          // Top bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              children: [
                _Avatar(name: n.clientName, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.clientName,
                        style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                        )),
                      Text('${n.serviceName}  ·  ${_fmtDateFull(n.date)}',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.black45)),
                    ],
                  ),
                ),
                if (_dirty)
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC6A76A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: _saving
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Guardar', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),

          // Note body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notes_outlined, size: 16, color: Color(0xFFC6A76A)),
                        const SizedBox(width: 6),
                        Text('NOTA INTERNA',
                          style: GoogleFonts.inter(
                            fontSize: 11, letterSpacing: 1.5,
                            color: const Color(0xFFC6A76A),
                            fontWeight: FontWeight.w600,
                          )),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        maxLines: null,
                        expands:  true,
                        textAlignVertical: TextAlignVertical.top,
                        onChanged: (_) => setState(() => _dirty = true),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF1A1A1A),
                          height: 1.6,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Escribe una nota sobre esta reserva...',
                          hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.black26),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String   message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.black12),
            const SizedBox(height: 16),
            Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.black38, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Hoy';
  if (d.year == now.year && d.month == now.month && d.day == now.day - 1) return 'Ayer';
  return '${d.day}/${d.month}';
}

String _fmtDateFull(DateTime d) {
  const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
