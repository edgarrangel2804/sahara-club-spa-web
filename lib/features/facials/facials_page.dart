import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/sahara_theme.dart';
import '../cart/cart_page.dart';
import '../store/controllers/store_cart_controller.dart';
import '../store/data/store_catalog_repository.dart';
import '../store/models/store_product.dart';
import '../store/product_detail_page.dart';

class FacialsPage extends StatefulWidget {
  const FacialsPage({super.key});

  @override
  State<FacialsPage> createState() => _FacialsPageState();
}

class _FacialsPageState extends State<FacialsPage> {
  final StoreCatalogRepository _repository = const StoreCatalogRepository();
  final StoreCartController _cart = StoreCartController.instance;
  late Future<List<StoreProduct>> _productsFuture;
  String _selectedFilter = 'todos';

  static const List<_FacialFilter> _filters = [
    _FacialFilter(id: 'todos', label: 'Todos los rituales'),
    _FacialFilter(id: 'hidratante', label: 'Hidratante'),
    _FacialFilter(id: 'antiedad', label: 'Antiedad'),
    _FacialFilter(id: 'detox', label: 'Purificante'),
    _FacialFilter(id: 'express', label: 'Rapido'),
  ];

  @override
  void initState() {
    super.initState();
    _productsFuture = _repository.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _FacialPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _FacialBackdrop()),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: _FacialPalette.surface.withValues(alpha: 0.78),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: _FacialPalette.primary),
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: Text(
                  'SAHARA CLUB',
                  style: GoogleFonts.playfairDisplay(
                    color: _FacialPalette.primary,
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
                              icon: const Icon(Icons.shopping_bag_outlined, color: _FacialPalette.primary),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CartPage()),
                                );
                              },
                            ),
                            if (_cart.totalItems > 0)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: _FacialPalette.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _cart.totalItems > 9 ? '9+' : '${_cart.totalItems}',
                                    style: GoogleFonts.inter(
                                      color: _FacialPalette.onPrimary,
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
                    final allFacials = snapshot.data
                            ?.where((product) => product.categoryKey == 'facials')
                            .toList() ??
                        <StoreProduct>[];
                    final products = _applyFilter(allFacials);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FacialHeader(),
                        _FacialFilters(
                          filters: _filters,
                          selectedId: _selectedFilter,
                          onSelected: (value) => setState(() => _selectedFilter = value),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
                          child: snapshot.connectionState == ConnectionState.waiting
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 80),
                                  child: Center(
                                    child: CircularProgressIndicator(color: SaharaTheme.gold),
                                  ),
                                )
                              : products.isEmpty
                                  ? const _EmptyFacialsState()
                                  : _FacialBento(
                                      products: products,
                                      allProducts: allFacials,
                                      onOpen: _openDetails,
                                      onAdd: _addToCart,
                                    ),
                        ),
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

  List<StoreProduct> _applyFilter(List<StoreProduct> products) {
    if (_selectedFilter == 'todos') return products;
    return products.where((product) {
      final haystack = '${product.name} ${product.shortDescription} ${product.description}'.toLowerCase();
      switch (_selectedFilter) {
        case 'hidratante':
          return haystack.contains('hidrat') || haystack.contains('lumino') || haystack.contains('glow');
        case 'antiedad':
          return haystack.contains('antiedad') || haystack.contains('firmeza') || haystack.contains('rejuven');
        case 'detox':
          return haystack.contains('detox') || haystack.contains('purif') || haystack.contains('arcilla');
        case 'express':
          return (product.durationMinutes ?? 999) <= 45;
        default:
          return true;
      }
    }).toList();
  }

  void _addToCart(StoreProduct product) {
    _cart.add(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} se agrego al carrito.')),
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
}

class _FacialHeader extends StatelessWidget {
  const _FacialHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 72),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nuestra coleccion curada',
              style: GoogleFonts.inter(
                color: _FacialPalette.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 4.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Luminosidad y resplandor',
              style: GoogleFonts.playfairDisplay(
                color: _FacialPalette.textPrimary,
                fontSize: 70,
                fontStyle: FontStyle.italic,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Entra en un espacio de silencio restaurativo. Nuestros rituales faciales combinan sabiduria del desierto con precision contemporanea para revelar la luminosidad natural de tu piel.',
              style: GoogleFonts.inter(
                color: _FacialPalette.textSoft,
                fontSize: 18,
                fontWeight: FontWeight.w300,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacialFilters extends StatelessWidget {
  const _FacialFilters({
    required this.filters,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_FacialFilter> filters;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 56),
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _FacialPalette.primary.withValues(alpha: 0.10)),
          bottom: BorderSide(color: _FacialPalette.primary.withValues(alpha: 0.10)),
        ),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 16,
        children: [
          for (final filter in filters)
            InkWell(
              onTap: () => onSelected(filter.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selectedId == filter.id
                          ? _FacialPalette.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  filter.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: selectedId == filter.id
                        ? _FacialPalette.primary
                        : _FacialPalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FacialBento extends StatelessWidget {
  const _FacialBento({
    required this.products,
    required this.allProducts,
    required this.onOpen,
    required this.onAdd,
  });

  final List<StoreProduct> products;
  final List<StoreProduct> allProducts;
  final void Function(StoreProduct product, List<StoreProduct> allProducts) onOpen;
  final void Function(StoreProduct product) onAdd;

  @override
  Widget build(BuildContext context) {
    final first = products.isNotEmpty ? products[0] : null;
    final second = products.length > 1 ? products[1] : null;
    final third = products.length > 2 ? products[2] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (final product in products) ...[
                _FacialCard(
                  product: product,
                  wide: false,
                  subtitle: _subtitleFor(product),
                  onOpen: () => onOpen(product, allProducts),
                  onAdd: () => onAdd(product),
                ),
                const SizedBox(height: 24),
              ],
              const _FacialPromiseCard(),
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: first == null
                      ? const SizedBox.shrink()
                      : _FacialCard(
                          product: first,
                          wide: false,
                          subtitle: _subtitleFor(first),
                          onOpen: () => onOpen(first, allProducts),
                          onAdd: () => onAdd(first),
                        ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 8,
                  child: second == null
                      ? const SizedBox.shrink()
                      : _FacialCard(
                          product: second,
                          wide: true,
                          subtitle: _subtitleFor(second),
                          onOpen: () => onOpen(second, allProducts),
                          onAdd: () => onAdd(second),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: third == null
                      ? const SizedBox.shrink()
                      : _FacialCard(
                          product: third,
                          wide: false,
                          subtitle: _subtitleFor(third),
                          onOpen: () => onOpen(third, allProducts),
                          onAdd: () => onAdd(third),
                        ),
                ),
                const SizedBox(width: 24),
                const Expanded(
                  flex: 8,
                  child: _FacialPromiseCard(),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _subtitleFor(StoreProduct product) {
    final haystack = '${product.name} ${product.shortDescription} ${product.description}'.toLowerCase();
    if (haystack.contains('gold') || haystack.contains('rejuven') || haystack.contains('antiedad')) {
      return 'ANTIEDAD';
    }
    if (haystack.contains('detox') || haystack.contains('purif') || haystack.contains('arcilla')) {
      return 'DETOX';
    }
    if (haystack.contains('hidrat') || haystack.contains('lumino') || haystack.contains('glow')) {
      return 'HIDRATANTE';
    }
    return 'RITUAL FACIAL';
  }
}

class _FacialCard extends StatefulWidget {
  const _FacialCard({
    required this.product,
    required this.wide,
    required this.subtitle,
    required this.onOpen,
    required this.onAdd,
  });

  final StoreProduct product;
  final bool wide;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  State<_FacialCard> createState() => _FacialCardState();
}

class _FacialCardState extends State<_FacialCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final content = widget.wide
        ? Row(
            children: [
              Expanded(
                child: _ImagePane(imageUrl: widget.product.imageUrl, hovered: _hovered),
              ),
              Expanded(
                child: _TextPane(
                  product: widget.product,
                  subtitle: widget.subtitle,
                  featured: true,
                  onOpen: widget.onOpen,
                  onAdd: widget.onAdd,
                ),
              ),
            ],
          )
        : Column(
            children: [
              SizedBox(
                height: 400,
                width: double.infinity,
                child: _ImagePane(imageUrl: widget.product.imageUrl, hovered: _hovered),
              ),
              _TextPane(
                product: widget.product,
                subtitle: widget.subtitle,
                featured: false,
                onOpen: widget.onOpen,
                onAdd: widget.onAdd,
              ),
            ],
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        decoration: BoxDecoration(
          color: widget.wide ? _FacialPalette.surfaceContainer : _FacialPalette.surfaceContainer,
          border: Border.all(color: _FacialPalette.primary.withValues(alpha: _hovered ? 0.14 : 0.05)),
        ),
        child: content,
      ),
    );
  }
}

class _ImagePane extends StatelessWidget {
  const _ImagePane({
    required this.imageUrl,
    required this.hovered,
  });

  final String imageUrl;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedScale(
          duration: const Duration(milliseconds: 1000),
          scale: hovered ? 1.04 : 1,
          child: imageUrl.startsWith('http')
              ? Image.network(imageUrl, fit: BoxFit.cover)
              : Image.asset(imageUrl, fit: BoxFit.cover),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _FacialPalette.surface.withValues(alpha: 0.04),
                _FacialPalette.surface.withValues(alpha: 0.56),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}

class _TextPane extends StatelessWidget {
  const _TextPane({
    required this.product,
    required this.subtitle,
    required this.featured,
    required this.onOpen,
    required this.onAdd,
  });

  final StoreProduct product;
  final String subtitle;
  final bool featured;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(featured ? 40 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured) ...[
            const Icon(Icons.auto_awesome_rounded, color: _FacialPalette.primary, size: 24),
            const SizedBox(height: 12),
          ],
          Text(
            product.name,
            style: GoogleFonts.playfairDisplay(
              color: _FacialPalette.textPrimary,
              fontSize: featured ? 34 : 30,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                product.priceLabel,
                style: GoogleFonts.inter(
                  color: _FacialPalette.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: _FacialPalette.primary.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                '${product.durationMinutes ?? 60} min',
                style: GoogleFonts.inter(
                  color: _FacialPalette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: _FacialPalette.primary.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: _FacialPalette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            product.shortDescription,
            style: GoogleFonts.inter(
              color: _FacialPalette.textSoft,
              fontSize: 15,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: featured
                    ? FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _FacialPalette.primary,
                          foregroundColor: _FacialPalette.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: onOpen,
                        child: Text(
                          'RESERVAR EXPERIENCIA',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                          ),
                        ),
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _FacialPalette.primary.withValues(alpha: 0.30)),
                          foregroundColor: _FacialPalette.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: onOpen,
                        child: Text(
                          'RESERVAR SESION',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              if (!featured)
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _FacialPalette.primary,
                      foregroundColor: _FacialPalette.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: onAdd,
                    child: Text(
                      'AGREGAR',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FacialPromiseCard extends StatelessWidget {
  const _FacialPromiseCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: _FacialPalette.surfaceLow,
        border: Border.all(color: _FacialPalette.primary.withValues(alpha: 0.05)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _FacialPalette.primary.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    radius: 0.9,
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.spa_outlined,
                color: _FacialPalette.primary.withValues(alpha: 0.44),
                size: 52,
              ),
              const SizedBox(height: 24),
              Text(
                'La promesa del ritual',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  color: _FacialPalette.textPrimary,
                  fontSize: 34,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cada facial en Sahara Club incluye vapor botanico y drenaje linfatico con piedra fria para que salgas en un estado de equilibrio total.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _FacialPalette.textSoft,
                  fontSize: 16,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyFacialsState extends StatelessWidget {
  const _EmptyFacialsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.auto_awesome_rounded, color: _FacialPalette.primary.withValues(alpha: 0.8), size: 42),
            const SizedBox(height: 16),
            Text(
              'Aun no hay faciales disponibles.',
              style: GoogleFonts.playfairDisplay(
                color: _FacialPalette.textPrimary,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Cuando carguemos faciales en Supabase apareceran aqui automaticamente.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _FacialPalette.textMuted,
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacialBackdrop extends StatelessWidget {
  const _FacialBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _FacialPalette.background),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _FacialTexturePainter()),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    _FacialPalette.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  radius: 0.75,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FacialTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _FacialPalette.primary.withValues(alpha: 0.016)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 18) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + 4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FacialFilter {
  const _FacialFilter({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class _FacialPalette {
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF151312);
  static const Color surfaceLow = Color(0xFF1C1B1B);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color primary = SaharaTheme.gold;
  static const Color onPrimary = Color(0xFF412D00);
  static const Color textPrimary = Color(0xFFE5E2E1);
  static const Color textSoft = Color(0xFFD1C5B4);
  static const Color textMuted = Color(0xFF9A8F80);
}
