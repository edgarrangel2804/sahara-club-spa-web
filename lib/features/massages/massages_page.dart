import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/sahara_theme.dart';
import '../cart/cart_page.dart';
import '../store/controllers/store_cart_controller.dart';
import '../store/data/store_catalog_repository.dart';
import '../store/models/store_product.dart';
import '../store/product_detail_page.dart';

class MassagesPage extends StatefulWidget {
  const MassagesPage({super.key});

  @override
  State<MassagesPage> createState() => _MassagesPageState();
}

class _MassagesPageState extends State<MassagesPage> {
  final StoreCatalogRepository _repository = const StoreCatalogRepository();
  final StoreCartController _cart = StoreCartController.instance;
  late Future<List<StoreProduct>> _productsFuture;
  String _selectedFilter = 'todos';

  static const List<_MassageFilter> _filters = [
    _MassageFilter(id: 'todos', label: 'Todos los rituales'),
    _MassageFilter(id: 'sueco', label: 'Sueco'),
    _MassageFilter(id: 'profundo', label: 'Tejido profundo'),
    _MassageFilter(id: 'piedras', label: 'Piedras calientes'),
    _MassageFilter(id: 'aromaterapia', label: 'Aromaterapia'),
  ];

  @override
  void initState() {
    super.initState();
    _productsFuture = _repository.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _MassagePalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _MassageBackdrop()),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: _MassagePalette.surface.withValues(alpha: 0.78),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: _MassagePalette.primary),
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: Text(
                  'SAHARA CLUB',
                  style: GoogleFonts.playfairDisplay(
                    color: _MassagePalette.primary,
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
                              icon: const Icon(Icons.shopping_bag_outlined, color: _MassagePalette.primary),
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
                                    color: _MassagePalette.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _cart.totalItems > 9 ? '9+' : '${_cart.totalItems}',
                                    style: GoogleFonts.inter(
                                      color: _MassagePalette.onPrimary,
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
                    final allMassages = snapshot.data
                            ?.where((product) => product.categoryKey == 'massages')
                            .toList() ??
                        <StoreProduct>[];
                    final products = _applyFilter(allMassages);

                    return Column(
                      children: [
                        const _MassageHeader(),
                        _FilterBar(
                          filters: _filters,
                          selectedId: _selectedFilter,
                          onSelected: (value) => setState(() => _selectedFilter = value),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
                          child: snapshot.connectionState == ConnectionState.waiting
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 80),
                                  child: CircularProgressIndicator(color: SaharaTheme.gold),
                                )
                              : products.isEmpty
                                  ? const _EmptyMassagesState()
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        final width = constraints.maxWidth;
                                        final columns = width >= 1120 ? 3 : width >= 760 ? 2 : 1;
                                        return GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: products.length,
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            mainAxisSpacing: 48,
                                            crossAxisSpacing: 32,
                                            childAspectRatio: 0.66,
                                          ),
                                          itemBuilder: (context, index) {
                                            final product = products[index];
                                            return _MassageCard(
                                              product: product,
                                              subtitle: _subtitleFor(product),
                                              onDetails: () => _openDetails(product, allMassages),
                                              onAdd: () => _addToCart(product),
                                            );
                                          },
                                        );
                                      },
                                    ),
                        ),
                        const _MassageQuoteSection(),
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

  List<StoreProduct> _applyFilter(List<StoreProduct> products) {
    if (_selectedFilter == 'todos') return products;
    return products.where((product) {
      final haystack = '${product.name} ${product.shortDescription} ${product.description}'.toLowerCase();
      switch (_selectedFilter) {
        case 'sueco':
          return haystack.contains('relaj') || haystack.contains('suave') || haystack.contains('armony');
        case 'profundo':
          return haystack.contains('deep') ||
              haystack.contains('profund') ||
              haystack.contains('cronica') ||
              haystack.contains('muscular');
        case 'piedras':
          return haystack.contains('piedra') || haystack.contains('stone') || haystack.contains('volcan');
        case 'aromaterapia':
          return haystack.contains('aceite') ||
              haystack.contains('botanic') ||
              haystack.contains('aroma') ||
              haystack.contains('sensorial');
        default:
          return true;
      }
    }).toList();
  }

  String _subtitleFor(StoreProduct product) {
    final haystack = '${product.name} ${product.shortDescription} ${product.description}'.toLowerCase();
    if (haystack.contains('stone') || haystack.contains('piedra')) {
      return '${product.durationMinutes ?? 90} MIN • CALOR PROFUNDO';
    }
    if (haystack.contains('deep') || haystack.contains('profund')) {
      return '${product.durationMinutes ?? 90} MIN • RECUPERACION MUSCULAR';
    }
    if (haystack.contains('relaj') || haystack.contains('sensorial') || haystack.contains('oasis')) {
      return '${product.durationMinutes ?? 90} MIN • ARMONIA SENSORIAL';
    }
    return '${product.durationMinutes ?? 90} MIN • RITUAL CORPORAL';
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

class _MassageHeader extends StatelessWidget {
  const _MassageHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 88, 24, 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              Text(
                'El toque sanador',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _MassagePalette.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4.2,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Manos que restauran',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  color: _MassagePalette.primary,
                  fontSize: 68,
                  height: 1.06,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 96,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _MassagePalette.primary,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Una coleccion de rituales restaurativos disenados para alinear el cuerpo y aquietar el espiritu. Cada movimiento es un paso hacia una quietud mas profunda.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _MassagePalette.textSoft.withValues(alpha: 0.82),
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filters,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_MassageFilter> filters;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 96),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 24),
            for (final filter in filters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: InkWell(
                  onTap: () => onSelected(filter.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selectedId == filter.id
                              ? _MassagePalette.primary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Text(
                      filter.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: selectedId == filter.id
                            ? _MassagePalette.primary
                            : _MassagePalette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}

class _MassageCard extends StatefulWidget {
  const _MassageCard({
    required this.product,
    required this.subtitle,
    required this.onDetails,
    required this.onAdd,
  });

  final StoreProduct product;
  final String subtitle;
  final VoidCallback onDetails;
  final VoidCallback onAdd;

  @override
  State<_MassageCard> createState() => _MassageCardState();
}

class _MassageCardState extends State<_MassageCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: _MassagePalette.surfaceContainer,
          border: Border.all(color: _MassagePalette.primary.withValues(alpha: _hovered ? 0.30 : 0.10)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 1600),
                      scale: _hovered ? 1.07 : 1.0,
                      child: _MassageImage(imageUrl: widget.product.imageUrl),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            _MassagePalette.surface.withValues(alpha: 0.40),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: GoogleFonts.playfairDisplay(
                            color: _MassagePalette.primary,
                            fontSize: 32,
                            height: 1.12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        widget.product.priceLabel,
                        style: GoogleFonts.inter(
                          color: _MassagePalette.primary.withValues(alpha: 0.82),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.inter(
                      color: _MassagePalette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.product.shortDescription,
                    style: GoogleFonts.inter(
                      color: _MassagePalette.textSoft.withValues(alpha: 0.74),
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _MassagePalette.primary.withValues(alpha: 0.30)),
                            foregroundColor: _MassagePalette.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          onPressed: widget.onDetails,
                          child: Text(
                            'VER DETALLES',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _MassagePalette.primary,
                            foregroundColor: _MassagePalette.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          onPressed: widget.onAdd,
                          child: Text(
                            'AGREGAR',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MassageQuoteSection extends StatelessWidget {
  const _MassageQuoteSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 1,
            color: _MassagePalette.primary.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 80),
          Text(
            '"En el silencio del desierto encontramos el ritmo del alma."',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: _MassagePalette.primary.withValues(alpha: 0.42),
              fontSize: 44,
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 36),
          Container(
            width: 180,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _MassagePalette.primary,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMassagesState extends StatelessWidget {
  const _EmptyMassagesState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.spa_outlined, color: _MassagePalette.primary.withValues(alpha: 0.78), size: 44),
          const SizedBox(height: 18),
          Text(
            'Aun no hay masajes disponibles.',
            style: GoogleFonts.playfairDisplay(
              color: _MassagePalette.textPrimary,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Cuando carguemos mas rituales en Supabase apareceran aqui automaticamente.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _MassagePalette.textMuted,
              fontSize: 15,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _MassageImage extends StatelessWidget {
  const _MassageImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, fit: BoxFit.cover);
    }
    return Image.asset(imageUrl, fit: BoxFit.cover);
  }
}

class _MassageBackdrop extends StatelessWidget {
  const _MassageBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _MassagePalette.background),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _MassageGrainPainter()),
          ),
        ),
      ],
    );
  }
}

class _MassageGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _MassagePalette.primary.withValues(alpha: 0.02)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + 12, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MassageFilter {
  const _MassageFilter({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class _MassagePalette {
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF151312);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color primary = SaharaTheme.gold;
  static const Color onPrimary = Color(0xFF412D00);
  static const Color textPrimary = Color(0xFFE5E2E1);
  static const Color textSoft = Color(0xFFD1C5B4);
  static const Color textMuted = Color(0xFF9A8F80);
}
