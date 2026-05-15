import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class _Product {
  final String id;
  String name;
  String description;
  String shortDescription;
  double price;
  int stock;
  String category;
  String productType;
  String imageUrl;
  String digitalFileUrl;
  int? durationMinutes;
  bool active;

  _Product({
    required this.id,
    required this.name,
    required this.description,
    required this.shortDescription,
    required this.price,
    required this.stock,
    required this.category,
    required this.productType,
    required this.imageUrl,
    required this.digitalFileUrl,
    required this.durationMinutes,
    required this.active,
  });

  factory _Product.fromMap(Map<String, dynamic> m) => _Product(
    id: (m['id'] ?? '').toString(),
    name: m['name'] as String? ?? '',
    description: m['description'] as String? ?? '',
    shortDescription:
        (m['short_description'] as String? ?? m['description'] as String? ?? '')
            .trim(),
    price: (m['price'] as num?)?.toDouble() ?? 0,
    stock: (m['stock_quantity'] as num?)?.toInt() ??
        (m['stock'] as num?)?.toInt() ??
        0,
    category: _normalizeProductCategory(m['category'] as String?),
    productType: _normalizeProductType(
      m['product_type'] as String? ?? m['type'] as String?,
      fallbackCategory: m['category'] as String?,
      name: m['name'] as String?,
    ),
    imageUrl: (m['image_url'] as String? ?? '').trim(),
    digitalFileUrl: (m['digital_file_url'] as String? ?? '').trim(),
    durationMinutes: (m['duration_minutes'] as num?)?.toInt(),
    active: (m['is_active'] as bool?) ?? (m['active'] as bool?) ?? true,
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
  bool? _supportsRichProductSchema;

  static const _categories = [
    ('all', 'Todos'),
    ('service', 'Servicios'),
    ('digital', 'Digitales'),
    ('membership', 'Membresias'),
    ('physical', 'Fisicos'),
    ('gift_card', 'Gift cards'),
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

  Future<void> _seedStripeDemoProducts() async {
    setState(() => _loading = true);
    try {
      final products = [
        <String, dynamic>{
          'name': 'musica mp3',
          'slug': 'musica-mp3',
          'description':
              'Paisaje sonoro premium para relajacion, meditacion y ritual en casa.',
          'short_description': 'Audio digital premium de relajacion.',
          'price': 130,
          'currency': 'MXN',
          'category': 'digital',
          'product_type': 'digital',
          'image_url': 'assets/images/04.png',
          'digital_file_url': 'https://example.com/demo/musica.mp3',
          'duration_minutes': 45,
          'stock': 999,
          'stock_quantity': 999,
          'active': true,
          'is_active': true,
        },
        <String, dynamic>{
          'name': 'video mp4',
          'slug': 'video-mp4',
          'description':
              'Video guiado de bienestar y respiracion para acompanar tu ritual.',
          'short_description': 'Video digital premium para pausas conscientes.',
          'price': 189,
          'currency': 'MXN',
          'category': 'digital',
          'product_type': 'digital',
          'image_url': 'assets/images/03.png',
          'digital_file_url': 'https://example.com/demo/video.mp4',
          'duration_minutes': 30,
          'stock': 999,
          'stock_quantity': 999,
          'active': true,
          'is_active': true,
        },
        <String, dynamic>{
          'name': 'membresia sahara club spa',
          'slug': 'membresia-sahara-club-spa',
          'description':
              'Membresia de prueba para checkout Stripe con activacion automatica.',
          'short_description': 'Plan de membresia con activacion inmediata.',
          'price': 3000,
          'currency': 'MXN',
          'category': 'memberships',
          'product_type': 'membership',
          'image_url': 'assets/images/07.png',
          'duration_minutes': 90,
          'stock': 999,
          'stock_quantity': 999,
          'active': true,
          'is_active': true,
        },
      ];

      for (final product in products) {
        final slug = product['slug'] as String;
        final existing = await _findProductBySlugOrName(
          slug: slug,
          name: product['name'] as String,
        );

        if (existing == null) {
          await _insertProductWithSchemaFallback(product);
        } else {
          await _updateProductWithSchemaFallback(
            existing['id'].toString(),
            product,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Productos demo de Stripe listos para prueba'),
          backgroundColor: Color(0xFFC6A76A),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando demo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<Map<String, dynamic>?> _findProductBySlugOrName({
    required String slug,
    required String name,
  }) async {
    final supportsRichSchema = await _detectRichProductSchema();
    try {
      if (!supportsRichSchema) {
        return await Supabase.instance.client
            .from('products')
            .select('id')
            .eq('name', name)
            .maybeSingle();
      }
      return await Supabase.instance.client
          .from('products')
          .select('id')
          .eq('slug', slug)
          .maybeSingle();
    } catch (_) {
      try {
        return await Supabase.instance.client
            .from('products')
            .select('id')
            .eq('name', name)
            .maybeSingle();
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _insertProductWithSchemaFallback(
    Map<String, dynamic> payload,
  ) async {
    final supportsRichSchema = await _detectRichProductSchema();
    if (supportsRichSchema) {
      await Supabase.instance.client.from('products').insert(payload);
    } else {
      await Supabase.instance.client
          .from('products')
          .insert(_legacyProductPayload(payload));
    }
  }

  Future<void> _updateProductWithSchemaFallback(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final supportsRichSchema = await _detectRichProductSchema();
    if (supportsRichSchema) {
      await Supabase.instance.client
          .from('products')
          .update(payload)
          .eq('id', id);
    } else {
      await Supabase.instance.client
          .from('products')
          .update(_legacyProductPayload(payload))
          .eq('id', id);
    }
  }

  Future<bool> _detectRichProductSchema() async {
    if (_supportsRichProductSchema != null) return _supportsRichProductSchema!;
    try {
      await Supabase.instance.client
          .from('products')
          .select('slug')
          .limit(1);
      _supportsRichProductSchema = true;
    } catch (_) {
      _supportsRichProductSchema = false;
    }
    return _supportsRichProductSchema!;
  }

  Map<String, dynamic> _legacyProductPayload(Map<String, dynamic> payload) {
    final legacyCategory = _legacyCategoryForType(
      payload['product_type']?.toString(),
      payload['category']?.toString(),
    );
    final legacyType = _legacyStorageType(payload['product_type']?.toString());
    return <String, dynamic>{
      'name': payload['name'],
      'description': payload['description'],
      'price': payload['price'],
      'stock': payload['stock'],
      'category': legacyCategory,
      'type': legacyType,
      'active': payload['active'],
    };
  }

  List<_Product> get _filtered {
    var list = _products;
    if (_catFilter != 'all') {
      list = list.where((p) => p.productType == _catFilter).toList();
    }
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
      builder: (_) => _UnifiedProductFormDialog(product: edit, onSaved: _load),
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
              OutlinedButton.icon(
                onPressed: _loading ? null : _seedStripeDemoProducts,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC6A76A),
                  side: const BorderSide(color: Color(0xFFE0D2B5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                label: Text(
                  'Cargar demo Stripe',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
                                    separatorBuilder: (context, index) =>
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
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: Colors.black38,
                      onPressed: widget.onEdit,
                      tooltip: 'Editar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.red.shade300,
                      onPressed: widget.onDelete,
                      tooltip: 'Eliminar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      visualDensity: VisualDensity.compact,
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
  // ignore: unused_element_parameter
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
  late String _category =
      _normalizeProductCategory(widget.product?.category);
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
        'category':    _normalizeProductCategory(_category),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto guardado correctamente'),
            backgroundColor: Color(0xFFC6A76A),
          ),
        );
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
      backgroundColor: const Color(0xFFF5F3EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  initialValue: _category,
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
                    activeThumbColor: const Color(0xFFC6A76A),
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
                        foregroundColor: Colors.black,
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
class _UnifiedProductFormDialog extends StatefulWidget {
  const _UnifiedProductFormDialog({this.product, required this.onSaved});

  final _Product? product;
  final VoidCallback onSaved;

  @override
  State<_UnifiedProductFormDialog> createState() =>
      _UnifiedProductFormDialogState();
}

class _UnifiedProductFormDialogState extends State<_UnifiedProductFormDialog> {
  static const String _digitalBucket = 'digital-products';

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _desc = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final _shortDesc = TextEditingController(
    text: widget.product?.shortDescription ?? '',
  );
  late final _price = TextEditingController(
    text: widget.product != null ? widget.product!.price.toStringAsFixed(0) : '',
  );
  late final _stock = TextEditingController(
    text: widget.product != null ? '${widget.product!.stock}' : '0',
  );
  late final _imageUrl = TextEditingController(
    text: widget.product?.imageUrl ?? '',
  );
  late final _digitalFileUrl = TextEditingController(
    text: widget.product?.digitalFileUrl ?? '',
  );
  late final _duration = TextEditingController(
    text: widget.product?.durationMinutes?.toString() ?? '',
  );
  late String _productType = _normalizeProductType(
    widget.product?.productType,
    fallbackCategory: widget.product?.category,
    name: widget.product?.name,
  );
  late String _category = _categoryForType(
    _productType,
    widget.product?.category,
  );
  late bool _active = widget.product?.active ?? true;
  bool _saving = false;
  bool _uploadingDigitalFile = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _shortDesc.dispose();
    _price.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    _digitalFileUrl.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final normalizedType = _normalizeProductType(_productType);
      final stockValue =
          normalizedType == 'physical' ? (int.tryParse(_stock.text) ?? 0) : 999;
      final durationValue = int.tryParse(_duration.text);

      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'slug': _slugify(_name.text.trim()),
        'description': _desc.text.trim(),
        'short_description': _shortDesc.text.trim().isEmpty
            ? _desc.text.trim()
            : _shortDesc.text.trim(),
        'price': double.tryParse(_price.text) ?? 0,
        'currency': 'MXN',
        'stock': stockValue,
        'stock_quantity': stockValue,
        'category': _categoryForType(normalizedType, _category),
        'product_type': normalizedType,
        'image_url': _imageUrl.text.trim(),
        'digital_file_url':
            normalizedType == 'digital' ? _digitalFileUrl.text.trim() : '',
        'duration_minutes': normalizedType == 'digital'
            ? durationValue
            : normalizedType == 'membership'
                ? (durationValue ?? 90)
                : null,
        'active': _active,
        'is_active': _active,
      };

      if (widget.product == null) {
        await _persistProductInsert(payload);
      } else {
        await _persistProductUpdate(widget.product!.id, payload);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto guardado correctamente'),
          backgroundColor: Color(0xFFC6A76A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickAndUploadDigitalFile() async {
    setState(() => _uploadingDigitalFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: const ['mp3', 'mp4'],
        withData: true,
      );

      final file =
          result != null && result.files.isNotEmpty ? result.files.first : null;
      if (file == null || file.bytes == null || file.name.trim().isEmpty) {
        return;
      }

      final extension = file.extension?.toLowerCase() ??
          file.name.split('.').last.toLowerCase();
      final safeName = _slugify(file.name.replaceAll('.$extension', ''));
      final storagePath =
          'products/${DateTime.now().millisecondsSinceEpoch}-$safeName.$extension';

      await Supabase.instance.client.storage
          .from(_digitalBucket)
          .uploadBinary(
            storagePath,
            file.bytes!,
            fileOptions: FileOptions(
              upsert: true,
              contentType: extension == 'mp4' ? 'video/mp4' : 'audio/mpeg',
            ),
          );

      final publicUrl = Supabase.instance.client.storage
          .from(_digitalBucket)
          .getPublicUrl(storagePath);

      if (!mounted) return;
      setState(() {
        _digitalFileUrl.text = publicUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Archivo digital cargado correctamente'),
          backgroundColor: Color(0xFFC6A76A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo subir el archivo. Revisa que exista el bucket "digital-products" en Supabase Storage. Error: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingDigitalFile = false);
      }
    }
  }

  Future<void> _persistProductInsert(Map<String, dynamic> payload) async {
    final supportsRichSchema = await _detectRichProductSchema();
    if (supportsRichSchema) {
      await Supabase.instance.client.from('products').insert(payload);
    } else {
      await Supabase.instance.client
          .from('products')
          .insert(_legacyDialogPayload(payload));
    }
  }

  Future<void> _persistProductUpdate(
    String productId,
    Map<String, dynamic> payload,
  ) async {
    final supportsRichSchema = await _detectRichProductSchema();
    if (supportsRichSchema) {
      await Supabase.instance.client
          .from('products')
          .update(payload)
          .eq('id', productId);
    } else {
      await Supabase.instance.client
          .from('products')
          .update(_legacyDialogPayload(payload))
          .eq('id', productId);
    }
  }

  Future<bool> _detectRichProductSchema() async {
    final state = context.findAncestorStateOfType<_ProductosModuleState>();
    if (state?._supportsRichProductSchema != null) {
      return state!._supportsRichProductSchema!;
    }
    try {
      await Supabase.instance.client
          .from('products')
          .select('slug')
          .limit(1);
      if (state != null) state._supportsRichProductSchema = true;
      return true;
    } catch (_) {
      if (state != null) state._supportsRichProductSchema = false;
      return false;
    }
  }

  Map<String, dynamic> _legacyDialogPayload(Map<String, dynamic> payload) {
    final legacyCategory = _legacyCategoryForType(
      payload['product_type']?.toString(),
      payload['category']?.toString(),
    );
    final legacyType = _legacyStorageType(payload['product_type']?.toString());
    return <String, dynamic>{
      'name': payload['name'],
      'description': payload['description'],
      'price': payload['price'],
      'stock': payload['stock'],
      'category': legacyCategory,
      'type': legacyType,
      'active': payload['active'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Dialog(
      backgroundColor: const Color(0xFFF5F3EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 580,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Editar producto' : 'Nuevo producto',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Field(
                    label: 'NOMBRE *',
                    child: TextFormField(
                      controller: _name,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _deco('Ej: musica mp3'),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'DESCRIPCION',
                    child: TextFormField(
                      controller: _desc,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _deco('Descripcion completa'),
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'DESCRIPCION CORTA',
                    child: TextFormField(
                      controller: _shortDesc,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _deco('Resumen para la tienda'),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: 'TIPO *',
                          child: DropdownButtonFormField<String>(
                            initialValue: _productType,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            decoration: _deco(null),
                            items: const [
                              DropdownMenuItem(
                                value: 'service',
                                child: Text('Servicio'),
                              ),
                              DropdownMenuItem(
                                value: 'digital',
                                child: Text('Digital'),
                              ),
                              DropdownMenuItem(
                                value: 'membership',
                                child: Text('Membresia'),
                              ),
                              DropdownMenuItem(
                                value: 'physical',
                                child: Text('Fisico'),
                              ),
                              DropdownMenuItem(
                                value: 'gift_card',
                                child: Text('Gift card'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _productType = value;
                                _category = _categoryForType(value, _category);
                                if (value != 'physical') {
                                  _stock.text = '999';
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _Field(
                          label: 'CATEGORIA',
                          child: DropdownButtonFormField<String>(
                            initialValue: _category,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            decoration: _deco(null),
                            items: _categoryItemsFor(_productType),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _category = value);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: 'PRECIO *',
                          child: TextFormField(
                            controller: _price,
                            style: GoogleFonts.inter(fontSize: 13),
                            decoration: _deco('\$0').copyWith(prefixText: '\$'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) =>
                                (v?.isEmpty ?? true) ? 'Requerido' : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _productType == 'physical'
                            ? _Field(
                                label: 'STOCK',
                                child: TextFormField(
                                  controller: _stock,
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: _deco('0'),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8EE),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFECE2CF),
                                  ),
                                ),
                                child: Text(
                                  _productType == 'membership'
                                      ? 'Se activa al pagar'
                                      : 'Entrega digital inmediata',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'IMAGEN / PORTADA',
                    child: TextFormField(
                      controller: _imageUrl,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _deco('https://... o assets/images/...'),
                    ),
                  ),
                  if (_productType == 'digital') ...[
                    const SizedBox(height: 14),
                    _Field(
                      label: 'ARCHIVO DIGITAL *',
                      child: TextFormField(
                        controller: _digitalFileUrl,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: _deco(
                          'https://.../musica.mp3 o https://.../video.mp4',
                        ),
                        validator: (v) => _productType == 'digital' &&
                                (v?.trim().isEmpty ?? true)
                            ? 'Requerido para producto digital'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              _uploadingDigitalFile ? null : _pickAndUploadDigitalFile,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC6A76A),
                            side: const BorderSide(color: Color(0xFFE0D2B5)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          icon: _uploadingDigitalFile
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file_outlined, size: 16),
                          label: Text(
                            _uploadingDigitalFile
                                ? 'Subiendo archivo...'
                                : 'Subir MP3 / MP4',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _digitalFileUrl.text.isEmpty
                                ? 'Tambien puedes pegar una URL directa.'
                                : _digitalFileUrl.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      label: 'DURACION (MIN)',
                      child: TextFormField(
                        controller: _duration,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: _deco('Ej: 45'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                  if (_productType == 'membership') ...[
                    const SizedBox(height: 14),
                    _Field(
                      label: 'DURACION DEL PLAN (DIAS)',
                      child: TextFormField(
                        controller: _duration,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: _deco('Ej: 90'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Switch(
                        value: _active,
                        activeThumbColor: const Color(0xFFC6A76A),
                        onChanged: (value) => setState(() => _active = value),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Activo',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancelar', style: GoogleFonts.inter()),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC6A76A),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEdit ? 'Guardar cambios' : 'Crear producto',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

String _normalizeProductCategory(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  switch (value) {
    case 'massages':
    case 'facials':
    case 'rituals':
    case 'services':
    case 'digital':
    case 'memberships':
    case 'gift_cards':
    case 'physical':
    case 'general':
    case 'aceite':
    case 'vela':
    case 'crema':
    case 'suplemento':
    case 'accesorio':
      return value;
    case 'aceites':
      return 'aceite';
    case 'velas':
      return 'vela';
    case 'cremas':
      return 'crema';
    case 'suplementos':
      return 'suplemento';
    case 'accesorios':
      return 'accesorio';
    case 'corporales':
    case 'fusionadas':
    case 'tecnologia_corporal':
    case 'tecnologia_facial':
    case 'moldeo':
    case 'faciales_combo':
      return 'general';
    default:
      return 'general';
  }
}

String _normalizeProductType(
  String? raw, {
  String? fallbackCategory,
  String? name,
}) {
  final haystack =
      '${raw ?? ''} ${fallbackCategory ?? ''} ${name ?? ''}'.toLowerCase();
  if (haystack.contains('membership') || haystack.contains('membres')) {
    return 'membership';
  }
  if (haystack.contains('gift')) return 'gift_card';
  if (haystack.contains('digital') ||
      haystack.contains('audio') ||
      haystack.contains('video') ||
      haystack.contains('mp3') ||
      haystack.contains('mp4') ||
      haystack.contains('musica')) {
    return 'digital';
  }
  if (haystack.contains('service') ||
      haystack.contains('masaje') ||
      haystack.contains('facial') ||
      haystack.contains('ritual')) {
    return 'service';
  }
  if (haystack.contains('physical')) return 'physical';
  return 'physical';
}

String _categoryForType(String type, String? currentCategory) {
  switch (_normalizeProductType(type, fallbackCategory: currentCategory)) {
    case 'service':
      final normalized = _normalizeProductCategory(currentCategory);
      if (const {'massages', 'facials', 'rituals'}.contains(normalized)) {
        return normalized;
      }
      return 'services';
    case 'digital':
      return 'digital';
    case 'membership':
      return 'memberships';
    case 'gift_card':
      return 'gift_cards';
    case 'physical':
      final normalized = _normalizeProductCategory(currentCategory);
      if (const {
        'aceite',
        'vela',
        'crema',
        'suplemento',
        'accesorio',
        'physical',
      }.contains(normalized)) {
        return normalized;
      }
      return 'physical';
    default:
      return 'general';
  }
}

String _legacyCategoryForType(String? type, String? currentCategory) {
  switch (_normalizeProductType(type, fallbackCategory: currentCategory)) {
    case 'digital':
      return 'digital';
    case 'membership':
      return 'membresia';
    case 'gift_card':
      return 'gift';
    case 'service':
      if (_normalizeProductCategory(currentCategory) == 'facials') {
        return 'facial';
      }
      if (_normalizeProductCategory(currentCategory) == 'rituals') {
        return 'ritual';
      }
      return 'masaje';
    case 'physical':
      final normalized = _normalizeProductCategory(currentCategory);
      if (const {
        'aceite',
        'vela',
        'crema',
        'suplemento',
        'accesorio',
      }.contains(normalized)) {
        return normalized;
      }
      return 'general';
    default:
      return 'general';
  }
}

String _legacyStorageType(String? type) {
  switch (_normalizeProductType(type)) {
    case 'digital':
      return 'digital';
    case 'physical':
      return 'physical';
    case 'membership':
    case 'gift_card':
    case 'service':
    default:
      return 'service';
  }
}

List<DropdownMenuItem<String>> _categoryItemsFor(String type) {
  switch (_normalizeProductType(type)) {
    case 'service':
      return const [
        DropdownMenuItem(value: 'services', child: Text('Servicios')),
        DropdownMenuItem(value: 'massages', child: Text('Masajes')),
        DropdownMenuItem(value: 'facials', child: Text('Faciales')),
        DropdownMenuItem(value: 'rituals', child: Text('Rituales')),
      ];
    case 'digital':
      return const [
        DropdownMenuItem(value: 'digital', child: Text('Productos digitales')),
      ];
    case 'membership':
      return const [
        DropdownMenuItem(value: 'memberships', child: Text('Membresias')),
      ];
    case 'gift_card':
      return const [
        DropdownMenuItem(value: 'gift_cards', child: Text('Gift cards')),
      ];
    case 'physical':
      return const [
        DropdownMenuItem(value: 'physical', child: Text('Productos fisicos')),
        DropdownMenuItem(value: 'aceite', child: Text('Aceites')),
        DropdownMenuItem(value: 'vela', child: Text('Velas')),
        DropdownMenuItem(value: 'crema', child: Text('Cremas')),
        DropdownMenuItem(value: 'suplemento', child: Text('Suplementos')),
        DropdownMenuItem(value: 'accesorio', child: Text('Accesorios')),
      ];
    default:
      return const [
        DropdownMenuItem(value: 'general', child: Text('General')),
      ];
  }
}

String _catLabel(String cat) {
  const map = {
    'services': 'Servicios',
    'massages': 'Masajes',
    'facials': 'Faciales',
    'rituals': 'Rituales',
    'digital': 'Digital',
    'memberships': 'Membresias',
    'gift_cards': 'Gift cards',
    'physical': 'Fisicos',
    'general': 'General',
    'aceite': 'Aceite',
    'vela': 'Vela',
    'crema': 'Crema',
    'suplemento': 'Suplemento',
    'accesorio': 'Accesorio',
  };
  return map[cat] ?? cat;
}

String _slugify(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
