import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cart/cart_page.dart';
import '../store/controllers/store_cart_controller.dart';
import '../store/data/store_catalog_repository.dart';
import '../store/models/store_product.dart';
import '../store/product_detail_page.dart';
import '../../theme/sahara_theme.dart';

class MyRitualPage extends StatefulWidget {
  const MyRitualPage({super.key});

  @override
  State<MyRitualPage> createState() => _MyRitualPageState();
}

class _MyRitualPageState extends State<MyRitualPage> {
  final StoreCatalogRepository _repository = const StoreCatalogRepository();
  final StoreCartController _cart = StoreCartController.instance;
  late Future<List<StoreProduct>> _productsFuture;
  String _selectedCategory = 'all';

  static const List<_DigitalCategory> _categories = [
    _DigitalCategory(id: 'all', label: 'Todas las experiencias'),
    _DigitalCategory(id: 'guided', label: 'Meditaciones guiadas'),
    _DigitalCategory(id: 'ambient', label: 'Paisajes sonoros'),
    _DigitalCategory(id: 'journal', label: 'Guias de bienestar'),
  ];

  @override
  void initState() {
    super.initState();
    _productsFuture = _repository.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DigitalPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _DigitalBackdrop()),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: _DigitalPalette.surface.withValues(alpha: 0.78),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: _DigitalPalette.primary),
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: Text(
                  'SAHARA CLUB',
                  style: GoogleFonts.playfairDisplay(
                    color: _DigitalPalette.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5,
                  ),
                ),
                centerTitle: true,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedBuilder(
                      animation: _cart,
                      builder: (context, _) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shopping_bag_outlined, color: _DigitalPalette.primary),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CartPage()),
                                );
                              },
                            ),
                            if (_cart.totalItems > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: _DigitalPalette.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _cart.totalItems > 9 ? '9+' : '${_cart.totalItems}',
                                    style: GoogleFonts.inter(
                                      color: _DigitalPalette.onPrimary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FutureBuilder<List<StoreProduct>>(
                  future: _productsFuture,
                  builder: (context, snapshot) {
                    final products = _digitalProductsFrom(
                      snapshot.data ?? const <StoreProduct>[],
                    );
                    final filtered = _filterProducts(products);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DigitalHero(productCount: products.length),
                        _CategoryNav(
                          categories: _categories,
                          selectedId: _selectedCategory,
                          onSelected: (value) => setState(() => _selectedCategory = value),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: snapshot.connectionState == ConnectionState.waiting
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 80),
                                    child: CircularProgressIndicator(color: SaharaTheme.gold),
                                  ),
                                )
                              : filtered.isEmpty
                                  ? const _EmptyDigitalState()
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        final width = constraints.maxWidth;
                                        final columns = width >= 1180
                                            ? 3
                                            : width >= 760
                                                ? 2
                                                : 1;
                                        return GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: filtered.length,
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            mainAxisSpacing: 56,
                                            crossAxisSpacing: 40,
                                            childAspectRatio: 0.63,
                                          ),
                                          itemBuilder: (context, index) {
                                            final product = filtered[index];
                                            final classification = _classificationFor(product);
                                            return _DigitalProductCard(
                                              product: product,
                                              label: classification.label,
                                              meta: classification.meta,
                                              ctaLabel: classification.previewLabel,
                                              onPreview: () => _openDetails(product, filtered),
                                              onAdd: () => _addToCart(product),
                                              onOpen: () => _openDetails(product, filtered),
                                            );
                                          },
                                        );
                                      },
                                    ),
                        ),
                        const _NewsletterSection(),
                        const SizedBox(height: 120),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<StoreProduct> _filterProducts(List<StoreProduct> products) {
    if (_selectedCategory == 'all') return products;
    return products.where((product) {
      final haystack = '${product.name} ${product.shortDescription} ${product.description}'.toLowerCase();
      switch (_selectedCategory) {
        case 'guided':
          return haystack.contains('medita') ||
              haystack.contains('guiad') ||
              haystack.contains('respira') ||
              haystack.contains('ritual');
        case 'ambient':
          return haystack.contains('music') ||
              haystack.contains('musica') ||
              haystack.contains('sonido') ||
              haystack.contains('sound') ||
              haystack.contains('ambient');
        case 'journal':
          return haystack.contains('guide') ||
              haystack.contains('guia') ||
              haystack.contains('journal') ||
              haystack.contains('pdf') ||
              haystack.contains('notion');
        default:
          return true;
      }
    }).toList();
  }

  _DigitalClassification _classificationFor(StoreProduct product) {
    final haystack = '${product.name} ${product.shortDescription} ${product.description}'.toLowerCase();
    if (haystack.contains('guide') ||
        haystack.contains('guia') ||
        haystack.contains('journal') ||
        haystack.contains('pdf') ||
        haystack.contains('notion')) {
      return const _DigitalClassification(
        label: 'Guia digital',
        meta: 'Interactivo • PDF / Notion',
        previewLabel: 'VER INTERIOR',
      );
    }
    if (haystack.contains('music') ||
        haystack.contains('musica') ||
        haystack.contains('sound') ||
        haystack.contains('sonido') ||
        haystack.contains('ambient')) {
      return const _DigitalClassification(
        label: 'Solo digital',
        meta: 'Ambiental • 60 min',
        previewLabel: 'VISTA PREVIA',
      );
    }
    return const _DigitalClassification(
      label: 'Solo digital',
      meta: 'Guiado • 20 min',
      previewLabel: 'VISTA PREVIA',
    );
  }

  void _openDetails(StoreProduct product, List<StoreProduct> allProducts) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: product,
          allProducts: allProducts,
        ),
      ),
    );
  }

  void _addToCart(StoreProduct product) {
    _cart.add(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} agregado a tu coleccion.')),
    );
  }

  List<StoreProduct> _digitalProductsFrom(List<StoreProduct> source) {
    final fromSource = source.where((product) => product.type == StoreProductType.digital).toList();
    if (fromSource.isNotEmpty) return fromSource;
    return <StoreProduct>[
      StoreProduct(
        id: 'fallback-digital-soundscape',
        name: 'Paisaje Sonoro Medianoche',
        slug: 'paisaje-sonoro-medianoche',
        description:
            'Una composicion ambiental de baja estimulacion para convertir cualquier espacio en una pausa profunda y restaurativa.',
        shortDescription: 'Audio inmersivo para descanso, respiracion y calma diaria.',
        price: 240,
        currency: 'MXN',
        type: StoreProductType.digital,
        imageUrl: 'assets/images/03.png',
        categoryKey: 'digital',
        categoryLabel: 'Productos digitales',
        benefits: const ['Acceso inmediato', 'Escucha ilimitada', 'Ambiente inmersivo'],
        availability: 'Acceso inmediato despues del pago',
      ),
      StoreProduct(
        id: 'fallback-digital-guide',
        name: 'Guia Ritual de 7 Dias',
        slug: 'guia-ritual-7-dias',
        description:
            'Una guia interactiva para acompanar siete dias de reset sensorial, descanso y reconexion personal.',
        shortDescription: 'Guia premium descargable para sostener tu ritual en casa.',
        price: 450,
        currency: 'MXN',
        type: StoreProductType.digital,
        imageUrl: 'assets/images/04.png',
        categoryKey: 'digital',
        categoryLabel: 'Productos digitales',
        benefits: const ['Descarga inmediata', 'Formato premium', 'Uso personal'],
        availability: 'Acceso inmediato despues del pago',
      ),
    ];
  }
}

class _DigitalHero extends StatelessWidget {
  const _DigitalHero({required this.productCount});

  final int productCount;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, isMobile ? 72 : 104, 24, 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            children: [
              Text(
                'La coleccion digital',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _DigitalPalette.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4.5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'SANTUARIOS DIGITALES',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  color: _DigitalPalette.textStrong,
                  fontSize: isMobile ? 44 : 76,
                  height: 1.06,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Transforma tu entorno inmediato en un refugio personal del desierto mediante paisajes sonoros curados y rituales meditativos.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _DigitalPalette.textSoft.withValues(alpha: 0.84),
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  height: 1.8,
                ),
              ),
              if (productCount > 0) ...[
                const SizedBox(height: 24),
                Text(
                  '$productCount experiencias digitales disponibles',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: _DigitalPalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryNav extends StatelessWidget {
  const _CategoryNav({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_DigitalCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 44),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _DigitalPalette.primary.withValues(alpha: 0.10),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(right: 32),
                child: InkWell(
                  onTap: () => onSelected(category.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selectedId == category.id
                              ? _DigitalPalette.primary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Text(
                      category.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: selectedId == category.id
                            ? _DigitalPalette.primary
                            : _DigitalPalette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.6,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DigitalProductCard extends StatefulWidget {
  const _DigitalProductCard({
    required this.product,
    required this.label,
    required this.meta,
    required this.ctaLabel,
    required this.onPreview,
    required this.onAdd,
    required this.onOpen,
  });

  final StoreProduct product;
  final String label;
  final String meta;
  final String ctaLabel;
  final VoidCallback onPreview;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  State<_DigitalProductCard> createState() => _DigitalProductCardState();
}

class _DigitalProductCardState extends State<_DigitalProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 900),
                      scale: _hovered ? 1.03 : 1.0,
                      child: SizedBox.expand(
                        child: _ProductImage(imageUrl: widget.product.imageUrl),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: _hovered ? 0.12 : 0.22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _DigitalPalette.primary.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.label.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: _DigitalPalette.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: widget.ctaLabel == 'VER INTERIOR'
                        ? _PreviewPill(
                            label: widget.ctaLabel,
                            onTap: widget.onPreview,
                          )
                        : _PlayPill(onTap: widget.onPreview),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: GoogleFonts.playfairDisplay(
                          color: _hovered ? _DigitalPalette.primary : _DigitalPalette.textStrong,
                          fontSize: 28,
                          height: 1.16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.meta.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: _DigitalPalette.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.product.priceLabel,
                  style: GoogleFonts.inter(
                    color: _DigitalPalette.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _DigitalPalette.primary.withValues(alpha: 0.20)),
                foregroundColor: _DigitalPalette.primary,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: widget.onAdd,
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  'ADD TO COLLECTION',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsletterSection extends StatelessWidget {
  const _NewsletterSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 88, horizontal: 24),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: _DigitalPalette.primary.withValues(alpha: 0.10)),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                  Text(
                  'DESPLIEGA EL RITUAL',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    color: _DigitalPalette.textStrong,
                    fontSize: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recibe santuarios digitales curados y paisajes sonoros exclusivos directamente en tu correo.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: _DigitalPalette.textSoft.withValues(alpha: 0.84),
                    fontSize: 16,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: _DigitalPalette.textStrong,
                    fontSize: 13,
                    letterSpacing: 2.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'TU CORREO ELECTRONICO',
                    hintStyle: GoogleFonts.inter(
                      color: _DigitalPalette.textMuted.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.2,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _DigitalPalette.primary.withValues(alpha: 0.4)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: _DigitalPalette.primary),
                    ),
                    filled: false,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _DigitalPalette.primary,
                    foregroundColor: _DigitalPalette.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Suscripcion guardada.')),
                    );
                  },
                  child: Text(
                    'SUSCRIBIRME',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _DigitalPalette.surface.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _DigitalPalette.primary.withValues(alpha: 0.30)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: _DigitalPalette.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _DigitalPalette.surface.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _DigitalPalette.primary.withValues(alpha: 0.30)),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: _DigitalPalette.primary,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _EmptyDigitalState extends StatelessWidget {
  const _EmptyDigitalState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.graphic_eq_rounded, color: _DigitalPalette.primary.withValues(alpha: 0.8), size: 42),
            const SizedBox(height: 16),
            Text(
              'Aun no hay santuarios digitales disponibles.',
              style: GoogleFonts.playfairDisplay(
                color: _DigitalPalette.textStrong,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Cuando carguemos productos digitales en Supabase apareceran aqui automaticamente.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _DigitalPalette.textMuted,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, fit: BoxFit.cover);
    }
    return Image.asset(imageUrl, fit: BoxFit.cover);
  }
}

class _DigitalBackdrop extends StatelessWidget {
  const _DigitalBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _DigitalPalette.background),
        Positioned(
          top: 140,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 760,
              height: 760,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _DigitalPalette.primary.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _NoisePainter()),
          ),
        ),
      ],
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _DigitalPalette.primary.withValues(alpha: 0.02)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 18) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + 10, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DigitalCategory {
  const _DigitalCategory({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class _DigitalClassification {
  const _DigitalClassification({
    required this.label,
    required this.meta,
    required this.previewLabel,
  });

  final String label;
  final String meta;
  final String previewLabel;
}

class _DigitalPalette {
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF151312);
  static const Color primary = SaharaTheme.gold;
  static const Color onPrimary = Color(0xFF412D00);
  static const Color textStrong = Color(0xFFE5E2E1);
  static const Color textSoft = Color(0xFFD1C5B4);
  static const Color textMuted = Color(0xFF9A8F80);
}
