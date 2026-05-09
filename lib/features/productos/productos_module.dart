import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class _Product {
  final String id;
  String name;
  String description;
  double price;
  int    stock;
  String category;
  bool   active;

  _Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    required this.active,
  });

  factory _Product.fromMap(Map<String, dynamic> m) => _Product(
    id:          m['id']          as String,
    name:        m['name']        as String? ?? '',
    description: m['description'] as String? ?? '',
    price:       (m['price']      as num?)?.toDouble() ?? 0,
    stock:       (m['stock']      as num?)?.toInt()    ?? 0,
    category:    m['category']    as String? ?? 'general',
    active:      m['active']      as bool?   ?? true,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────
class ProductosModule extends StatefulWidget {
  const ProductosModule({super.key});

  @override
  State<ProductosModule> createState() => _ProductosModuleState();
}

class _ProductosModuleState extends State<ProductosModule> {
  List<_Product> _products  = [];
  _Product?      _selected;
  bool           _loading   = true;
  String         _search    = '';
  String         _catFilter = 'all';

  static const _categories = [
    ('all',        'Todos'),
    ('general',    'General'),
    ('aceite',     'Aceites'),
    ('vela',       'Velas'),
    ('crema',      'Cremas'),
    ('suplemento', 'Suplementos'),
    ('accesorio',  'Accesorios'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var q = Supabase.instance.client.from('products').select();
      final data = await q.order('name');
      if (!mounted) return;
      setState(() {
        _products = (data as List)
            .map((m) => _Product.fromMap(m as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(_Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar producto',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('¿Eliminar "${p.name}"? Esta acción no se puede deshacer.',
          style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.inter())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: GoogleFonts.inter())),
        ],
      ),
    );
    if (ok != true) return;
    await Supabase.instance.client.from('products').delete().eq('id', p.id);
    setState(() {
      if (_selected?.id == p.id) _selected = null;
    });
    _load();
  }

  List<_Product> get _filtered {
    var list = _products;
    if (_catFilter != 'all') list = list.where((p) => p.category == _catFilter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _openForm([_Product? edit]) {
    showDialog(
      context: context,
      builder: (_) => _ProductFormDialog(product: edit, onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        // ── Top bar ────────────────────────────────────────────
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: Row(
            children: [
              Text('Productos',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20, fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                )),
              const SizedBox(width: 24),
              // Category chips
              ..._categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _CatChip(
                  label:    c.$2,
                  selected: _catFilter == c.$1,
                  onTap:    () => setState(() => _catFilter = c.$1),
                ),
              )),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black38),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Colors.black38),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openForm(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC6A76A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text('Nuevo producto',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        // ── Body ───────────────────────────────────────────────
        Expanded(
          child: Row(
            children: [
              // Table
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F3EF),
                  child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.black12),
                              const SizedBox(height: 16),
                              Text('No hay productos',
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.black38)),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _openForm(),
                                child: Text('Agregar el primero',
                                  style: GoogleFonts.inter(color: const Color(0xFFC6A76A)))),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFEEEEEE)),
                            ),
                            child: Column(
                              children: [
                                // Table header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                                  ),
                                  child: Row(children: [
                                    _Th('PRODUCTO',   flex: 3),
                                    _Th('CATEGORÍA',  flex: 2),
                                    _Th('PRECIO',     flex: 1),
                                    _Th('STOCK',      flex: 1),
                                    _Th('ESTADO',     flex: 1),
                                    const SizedBox(width: 72),
                                  ]),
                                ),
                                // Rows
                                Expanded(
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                      const Divider(height: 1, color: Color(0xFFF5F5F5)),
                                    itemBuilder: (_, i) => _ProductRow(
                                      product:    filtered[i],
                                      selected:   _selected?.id == filtered[i].id,
                                      onTap:      () => setState(() => _selected = filtered[i]),
                                      onEdit:     () => _openForm(filtered[i]),
                                      onDelete:   () => _delete(filtered[i]),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),

              // Detail panel
              if (_selected != null)
                _ProductDetail(
                  product:  _selected!,
                  onEdit:   () => _openForm(_selected),
                  onDelete: () => _delete(_selected!),
                  onClose:  () => setState(() => _selected = null),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product Row
// ─────────────────────────────────────────────────────────────────────────────
class _ProductRow extends StatefulWidget {
  const _ProductRow({
    required this.product,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final _Product     product;
  final bool         selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p  = widget.product;
    final bg = widget.selected ? const Color(0xFFFFF8EE)
             : _hover          ? const Color(0xFFFAFAFA)
             : Colors.white;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(flex: 3, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    )),
                  if (p.description.isNotEmpty)
                    Text(p.description,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
                      overflow: TextOverflow.ellipsis),
                ],
              )),
              Expanded(flex: 2, child: Text(_catLabel(p.category),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black54))),
              Expanded(flex: 1, child: Text('\$${p.price.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ))),
              Expanded(flex: 1, child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.stock <= 3
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${p.stock}',
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: p.stock <= 3
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    )),
                ),
              ])),
              Expanded(flex: 1, child: _StatusBadge(active: p.active)),
              SizedBox(
                width: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      color: Colors.black38,
                      onPressed: widget.onEdit,
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      color: Colors.red.shade300,
                      onPressed: widget.onDelete,
                      tooltip: 'Eliminar',
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
// Product Detail Panel
// ─────────────────────────────────────────────────────────────────────────────
class _ProductDetail extends StatelessWidget {
  const _ProductDetail({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });
  final _Product     product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
            child: Row(
              children: [
                Expanded(
                  child: Text(p.name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    )),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price + stock stats
                  Row(children: [
                    _StatCard(label: 'PRECIO',  value: '\$${p.price.toStringAsFixed(0)}'),
                    const SizedBox(width: 10),
                    _StatCard(label: 'STOCK',   value: '${p.stock} uds'),
                  ]),
                  const SizedBox(height: 16),
                  _InfoRow(label: 'Categoría', value: _catLabel(p.category)),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Estado',    value: p.active ? 'Activo' : 'Inactivo'),
                  if (p.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('DESCRIPCIÓN',
                      style: GoogleFonts.inter(
                        fontSize: 11, letterSpacing: 1.5,
                        color: Colors.black38, fontWeight: FontWeight.w600,
                      )),
                    const SizedBox(height: 6),
                    Text(p.description,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.black54, height: 1.5)),
                  ],
                  const SizedBox(height: 24),
                  // Low stock warning
                  if (p.stock <= 3)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(children: [
                        Icon(Icons.warning_amber_outlined, size: 16, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          p.stock == 0 ? 'Sin stock' : 'Stock bajo (${p.stock} restantes)',
                          style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        )),
                      ]),
                    ),
                ],
              ),
            ),
          ),
          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Eliminar', style: GoogleFonts.inter(fontSize: 13)))),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC6A76A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Editar', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)))),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product Form Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product, required this.onSaved});
  final _Product? product;
  final VoidCallback onSaved;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey   = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _desc = TextEditingController(text: widget.product?.description ?? '');
  late final _price = TextEditingController(
      text: widget.product != null ? widget.product!.price.toStringAsFixed(0) : '');
  late final _stock = TextEditingController(
      text: widget.product != null ? '${widget.product!.stock}' : '0');
  late String _category = widget.product?.category ?? 'general';
  late bool   _active   = widget.product?.active   ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _desc.dispose();
    _price.dispose(); _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'name':        _name.text.trim(),
        'description': _desc.text.trim(),
        'price':       double.tryParse(_price.text) ?? 0,
        'stock':       int.tryParse(_stock.text)    ?? 0,
        'category':    _category,
        'active':      _active,
      };
      if (widget.product == null) {
        await Supabase.instance.client.from('products').insert(payload);
      } else {
        await Supabase.instance.client.from('products')
            .update(payload).eq('id', widget.product!.id);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Editar producto' : 'Nuevo producto',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20, fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                  )),
                const SizedBox(height: 24),
                _Field(label: 'NOMBRE *', child: TextFormField(
                  controller: _name,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: _deco('Ej: Aceite esencial lavanda'),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requerido' : null,
                )),
                const SizedBox(height: 14),
                _Field(label: 'DESCRIPCIÓN', child: TextFormField(
                  controller: _desc,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: _deco('Descripción opcional'),
                  maxLines: 2,
                )),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _Field(label: 'PRECIO *', child: TextFormField(
                    controller: _price,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _deco('\$0').copyWith(prefixText: '\$'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null,
                  ))),
                  const SizedBox(width: 14),
                  Expanded(child: _Field(label: 'STOCK', child: TextFormField(
                    controller: _stock,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: _deco('0'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ))),
                ]),
                const SizedBox(height: 14),
                _Field(label: 'CATEGORÍA', child: DropdownButtonFormField<String>(
                  value: _category,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                  decoration: _deco(null),
                  items: const [
                    DropdownMenuItem(value: 'general',    child: Text('General')),
                    DropdownMenuItem(value: 'aceite',     child: Text('Aceites')),
                    DropdownMenuItem(value: 'vela',       child: Text('Velas')),
                    DropdownMenuItem(value: 'crema',      child: Text('Cremas')),
                    DropdownMenuItem(value: 'suplemento', child: Text('Suplementos')),
                    DropdownMenuItem(value: 'accesorio',  child: Text('Accesorios')),
                  ],
                  onChanged: (v) => setState(() => _category = v!),
                )),
                const SizedBox(height: 14),
                Row(children: [
                  Switch(
                    value: _active,
                    activeColor: const Color(0xFFC6A76A),
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  const SizedBox(width: 8),
                  Text('Activo', style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
                ]),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar', style: GoogleFonts.inter())),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC6A76A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _saving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Guardar cambios' : 'Crear producto',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _CatChip extends StatelessWidget {
  const _CatChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool   selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC6A76A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: selected ? Colors.white : Colors.black54,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          )),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(active ? 'Activo' : 'Inactivo',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: active ? Colors.green.shade700 : Colors.grey.shade500,
          fontWeight: FontWeight.w600,
        )),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC6A76A).withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, letterSpacing: 1.2, color: Colors.black38)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.black38))),
        Expanded(child: Text(value,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500))),
      ],
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text, {this.flex = 1});
  final String text;
  final int    flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text,
        style: GoogleFonts.inter(
          fontSize: 11, letterSpacing: 1.2,
          color: Colors.black38, fontWeight: FontWeight.w600,
        )),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 11, letterSpacing: 1.2, color: Colors.black38)),
      const SizedBox(height: 5),
      child,
    ]);
  }
}

InputDecoration _deco(String? hint) => InputDecoration(
  hintText: hint,
  hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black26),
  filled: true,
  fillColor: const Color(0xFFF8F8F8),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFC6A76A)),
  ),
);

String _catLabel(String cat) {
  const map = {
    'general':    'General',
    'aceite':     'Aceite',
    'vela':       'Vela',
    'crema':      'Crema',
    'suplemento': 'Suplemento',
    'accesorio':  'Accesorio',
  };
  return map[cat] ?? cat;
}
