import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/sahara_theme.dart';
import '../cart/cart_page.dart';
import 'controllers/store_cart_controller.dart';
import 'data/store_catalog_repository.dart';
import 'models/store_product.dart';
import 'product_detail_page.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final StoreCatalogRepository _repository = const StoreCatalogRepository();
  final StoreCartController _cart = StoreCartController.instance;

  bool _loading = true;
  String _selectedCategory = 'all';
  List<StoreProduct> _products = <StoreProduct>[];

  static const List<_StoreCategory> _categories = <_StoreCategory>[
    _StoreCategory(id: 'all', label: 'All'),
    _StoreCategory(id: 'massages', label: 'Massages'),
    _StoreCategory(id: 'facials', label: 'Facials'),
    _StoreCategory(id: 'rituals', label: 'Rituals'),
    _StoreCategory(id: 'digital', label: 'Digital'),
    _StoreCategory(id: 'memberships', label: 'Memberships'),
    _StoreCategory(id: 'gift_cards', label: 'Gift Cards'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _repository.loadProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  List<StoreProduct> get _filteredProducts {
    if (_selectedCategory == 'all') return _products;
    return _products.where((product) => product.categoryKey == _selectedCategory).toList();
  }

  List<StoreProduct> get _signatureProducts {
    final products = _filteredProducts;
    final featured = products.where((product) => product.isFeatured).toList();
    return (featured.isNotEmpty ? featured : products).take(6).toList();
  }

  void _addToCart(StoreProduct product) {
    _cart.add(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} se agrego al carrito'),
        backgroundColor: _StorePalette.gold,
      ),
    );
  }

  void _openDetails(StoreProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: product,
          allProducts: _products,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _signatureProducts;
    return Scaffold(
      backgroundColor: _StorePalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _TextureOverlay()),
          const Positioned(
            bottom: -100,
            left: -60,
            child: _AmbientGlow(size: 380),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _StoreTopBar(cart: _cart),
                ),
                SliverToBoxAdapter(
                  child: _StoreHero(
                    onExplore: () {},
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final selected = _selectedCategory == category.id;
                          return _CategoryChip(
                            label: category.label,
                            selected: selected,
                            onTap: () => setState(() => _selectedCategory = category.id),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Curated Experiences',
                              style: GoogleFonts.inter(
                                color: _StorePalette.gold,
                                fontSize: 12,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Signature Rituals',
                              style: GoogleFonts.playfairDisplay(
                                color: _StorePalette.textPrimary,
                                fontSize: 42,
                              ),
                            ),
                          ],
                        ),
                        if (MediaQuery.of(context).size.width >= 768)
                          Row(
                            children: const [
                              _GhostCircleIcon(icon: Icons.arrow_back),
                              SizedBox(width: 12),
                              _GhostCircleIcon(icon: Icons.arrow_forward),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(
                            child: CircularProgressIndicator(color: _StorePalette.gold),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final columns = width >= 1120 ? 3 : width >= 760 ? 2 : 1;
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: products.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 32,
                                  crossAxisSpacing: 32,
                                  childAspectRatio: 0.62,
                                ),
                                itemBuilder: (context, index) {
                                  final product = products[index];
                                  return _ProductCard(
                                    product: product,
                                    onAdd: () => _addToCart(product),
                                    onDetails: () => _openDetails(product),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
                    child: _MembershipCta(
                      onTap: () {
                        final membership = _products.where(
                          (product) => product.type == StoreProductType.membership,
                        );
                        if (membership.isNotEmpty) {
                          _openDetails(membership.first);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreTopBar extends StatelessWidget {
  const _StoreTopBar({required this.cart});

  final StoreCartController cart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.menu, color: _StorePalette.gold),
          ),
          Text(
            'SAHARA CLUB',
            style: GoogleFonts.playfairDisplay(
              color: _StorePalette.gold,
              fontSize: 28,
              letterSpacing: 6,
            ),
          ),
          AnimatedBuilder(
            animation: cart,
            builder: (context, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartPage()),
                      );
                    },
                    icon: const Icon(Icons.shopping_bag_outlined, color: _StorePalette.gold),
                  ),
                  if (cart.totalItems > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _StorePalette.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 120),
      child: SizedBox(
        height: 760,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/hero.jpg', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    _StorePalette.background.withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 72,
              child: Column(
                children: [
                  Text(
                    'The Sanctuary\nof Stillness',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      color: _StorePalette.textPrimary,
                      fontSize: MediaQuery.of(context).size.width >= 768 ? 76 : 46,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton(
                    onPressed: onExplore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _StorePalette.gold,
                      side: const BorderSide(color: _StorePalette.gold),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    ),
                    child: Text(
                      'Explore',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected ? _StorePalette.onPrimary : _StorePalette.textMuted,
        backgroundColor: selected ? _StorePalette.gold : Colors.transparent,
        side: BorderSide(
          color: selected ? _StorePalette.gold : _StorePalette.gold.withValues(alpha: 0.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          letterSpacing: 2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onAdd,
    required this.onDetails,
  });

  final StoreProduct product;
  final VoidCallback onAdd;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _StorePalette.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _StorePalette.gold.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _ProductImage(imageUrl: product.imageUrl),
                ),
                if (product.durationMinutes != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            border: Border.all(
                              color: _StorePalette.gold.withValues(alpha: 0.12),
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${product.durationMinutes} min',
                            style: GoogleFonts.inter(
                              color: _StorePalette.gold,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
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
                Text(
                  product.name,
                  style: GoogleFonts.playfairDisplay(
                    color: _StorePalette.textPrimary,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  product.shortDescription,
                  style: GoogleFonts.inter(
                    color: _StorePalette.textMuted,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text(
                      product.priceLabel,
                      style: GoogleFonts.playfairDisplay(
                        color: _StorePalette.gold,
                        fontSize: 30,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onDetails,
                      child: Text(
                        'Details',
                        style: GoogleFonts.inter(
                          color: _StorePalette.textMuted,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: onAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _StorePalette.gold,
                        foregroundColor: _StorePalette.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      child: Text(
                        'Add',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
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
    );
  }
}

class _MembershipCta extends StatelessWidget {
  const _MembershipCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 400,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _StorePalette.gold.withValues(alpha: 0.12)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/portada.png', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'The Membership Elite',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      color: _StorePalette.textPrimary,
                      fontSize: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      'Unparalleled access to our global sanctuaries, priority rituals, and a bespoke digital wellness companion.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: _StorePalette.textMuted,
                        fontSize: 18,
                        height: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Apply for Access',
                    style: GoogleFonts.inter(
                      color: _StorePalette.gold,
                      fontSize: 12,
                      letterSpacing: 5,
                    ),
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

class _GhostCircleIcon extends StatelessWidget {
  const _GhostCircleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _StorePalette.gold.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: _StorePalette.gold),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(color: _StorePalette.surfaceHigh),
      child: const Center(
        child: Icon(Icons.spa_outlined, color: _StorePalette.gold, size: 42),
      ),
    );
  }
}

class _TextureOverlay extends StatelessWidget {
  const _TextureOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.01),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _StorePalette.gold.withValues(alpha: 0.06),
          boxShadow: [
            BoxShadow(
              color: _StorePalette.gold.withValues(alpha: 0.12),
              blurRadius: 140,
              spreadRadius: 40,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreCategory {
  const _StoreCategory({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class _StorePalette {
  static const Color background = Color(0xFF131313);
  static const Color surfaceLow = Color(0xFF1C1B1B);
  static const Color surfaceHigh = Color(0xFF2A2A2A);
  static const Color gold = Color(0xFFE9C176);
  static const Color onPrimary = Color(0xFF412D00);
  static const Color textPrimary = Color(0xFFE5E2E1);
  static const Color textMuted = Color(0xFFD1C5B4);
}
