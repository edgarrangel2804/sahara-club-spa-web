import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/sahara_theme.dart';
import '../cart/cart_page.dart';
import 'controllers/store_cart_controller.dart';
import 'models/store_product.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.allProducts,
  });

  final StoreProduct product;
  final List<StoreProduct> allProducts;

  List<StoreProduct> get relatedProducts {
    return allProducts
        .where((candidate) => candidate.id != product.id)
        .take(3)
        .toList();
  }

  void _addToCart(BuildContext context) {
    StoreCartController.instance.add(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} se agrego al carrito'),
        backgroundColor: _DetailPalette.gold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = StoreCartController.instance;
    return Scaffold(
      backgroundColor: _DetailPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _DetailTexture()),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.menu, color: _DetailPalette.gold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SAHARA CLUB',
                              style: GoogleFonts.playfairDisplay(
                                color: _DetailPalette.gold,
                                fontSize: 28,
                                letterSpacing: 6,
                              ),
                            ),
                          ],
                        ),
                        AnimatedBuilder(
                          animation: cart,
                          builder: (context, _) {
                            return IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CartPage()),
                                );
                              },
                              icon: Badge(
                                isLabelVisible: cart.totalItems > 0,
                                backgroundColor: _DetailPalette.gold,
                                textColor: _DetailPalette.background,
                                label: Text('${cart.totalItems}'),
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: _DetailPalette.gold,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 700,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _DetailImage(imageUrl: product.imageUrl),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.2),
                                _DetailPalette.background.withValues(alpha: 0.95),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 48,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 96,
                                height: 1,
                                color: _DetailPalette.gold,
                              ),
                              const SizedBox(height: 28),
                              Text(
                                product.name,
                                style: GoogleFonts.playfairDisplay(
                                  color: _DetailPalette.gold,
                                  fontSize: MediaQuery.of(context).size.width >= 768 ? 64 : 42,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 24,
                                runSpacing: 12,
                                children: [
                                  _MetaText(
                                    icon: Icons.schedule,
                                    label: product.durationMinutes != null
                                        ? '${product.durationMinutes} mins'
                                        : 'Curated piece',
                                  ),
                                  _MetaText(
                                    icon: Icons.payments_outlined,
                                    label: product.priceLabel,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 980;
                        final left = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'The Experience',
                              style: GoogleFonts.playfairDisplay(
                                color: _DetailPalette.gold,
                                fontSize: 34,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              product.description,
                              style: GoogleFonts.inter(
                                color: _DetailPalette.textMuted,
                                fontSize: 18,
                                height: 1.8,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(height: 52),
                            Text(
                              'Key Benefits',
                              style: GoogleFonts.inter(
                                color: _DetailPalette.gold,
                                fontSize: 12,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Divider(color: _DetailPalette.divider),
                            const SizedBox(height: 16),
                            ...product.benefits.map(
                              (benefit) => Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle, color: _DetailPalette.gold, size: 18),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        benefit,
                                        style: GoogleFonts.inter(
                                          color: _DetailPalette.textPrimary,
                                          height: 1.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 60),
                            Text(
                              'Whispers from the Sanctuary',
                              style: GoogleFonts.playfairDisplay(
                                color: _DetailPalette.gold,
                                fontSize: 32,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 28),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                child: Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    border: Border.all(color: _DetailPalette.gold.withValues(alpha: 0.15)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.star, color: _DetailPalette.gold, size: 18),
                                          Icon(Icons.star, color: _DetailPalette.gold, size: 18),
                                          Icon(Icons.star, color: _DetailPalette.gold, size: 18),
                                          Icon(Icons.star, color: _DetailPalette.gold, size: 18),
                                          Icon(Icons.star, color: _DetailPalette.gold, size: 18),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        '"An otherworldly experience. The transition from the city to this sanctuary was immediate. Everything feels slower, warmer and more intentional."',
                                        style: GoogleFonts.inter(
                                          color: _DetailPalette.textPrimary,
                                          fontSize: 18,
                                          height: 1.8,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        '— Elena V.',
                                        style: GoogleFonts.inter(
                                          color: _DetailPalette.gold.withValues(alpha: 0.7),
                                          fontSize: 12,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );

                        final right = _BookingPanel(
                          product: product,
                          onReserve: () => _addToCart(context),
                        );

                        if (stacked) {
                          return Column(
                            children: [
                              left,
                              const SizedBox(height: 40),
                              right,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: left),
                            const SizedBox(width: 32),
                            Expanded(flex: 5, child: right),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
                    child: Column(
                      children: [
                        Text(
                          'Complementary Rituals',
                          style: GoogleFonts.inter(
                            color: _DetailPalette.gold,
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final columns = width >= 980 ? 3 : 1;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: relatedProducts.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                                childAspectRatio: 0.74,
                              ),
                              itemBuilder: (context, index) {
                                final related = relatedProducts[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProductDetailPage(
                                          product: related,
                                          allProducts: allProducts,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: _DetailImage(imageUrl: related.imageUrl),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        related.durationMinutes != null
                                            ? '${related.durationMinutes} mins'
                                            : related.typeLabel,
                                        style: GoogleFonts.inter(
                                          color: _DetailPalette.gold.withValues(alpha: 0.65),
                                          fontSize: 12,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        related.name,
                                        style: GoogleFonts.playfairDisplay(
                                          color: _DetailPalette.textPrimary,
                                          fontSize: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
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

class _MetaText extends StatelessWidget {
  const _MetaText({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _DetailPalette.gold, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: _DetailPalette.gold.withValues(alpha: 0.8),
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({
    required this.product,
    required this.onReserve,
  });

  final StoreProduct product;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: _DetailPalette.gold.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Your Moment',
                    style: GoogleFonts.inter(
                      color: _DetailPalette.gold,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'October 2023',
                        style: GoogleFonts.inter(color: _DetailPalette.textPrimary),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.chevron_left, color: _DetailPalette.textMuted),
                          SizedBox(width: 10),
                          Icon(Icons.chevron_right, color: _DetailPalette.textMuted),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      ...'MTWTFSS'.split('').map(
                            (day) => Center(
                              child: Text(
                                day,
                                style: GoogleFonts.inter(
                                  color: _DetailPalette.textMuted.withValues(alpha: 0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ...List.generate(7, (index) {
                        final label = '${index + 12}';
                        final selected = label == '15';
                        return Container(
                          alignment: Alignment.center,
                          decoration: selected
                              ? BoxDecoration(
                                  border: Border.all(color: _DetailPalette.gold.withValues(alpha: 0.3)),
                                  color: _DetailPalette.gold.withValues(alpha: 0.08),
                                )
                              : null,
                          child: Text(
                            label,
                            style: GoogleFonts.inter(
                              color: selected
                                  ? _DetailPalette.textPrimary
                                  : _DetailPalette.textPrimary.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 26),
                  ElevatedButton(
                    onPressed: onReserve,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      backgroundColor: _DetailPalette.gold,
                      foregroundColor: _DetailPalette.onPrimary,
                    ),
                    child: Text(
                      product.type == StoreProductType.service
                          ? 'Reserve Experience'
                          : 'Add to Ritual',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'cancellation required 24 hours prior',
                      style: GoogleFonts.inter(
                        color: _DetailPalette.textMuted.withValues(alpha: 0.45),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _DetailImage(imageUrl: relatedImageFor(product)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enhancement',
                        style: GoogleFonts.inter(
                          color: _DetailPalette.gold,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Facial Glow',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String relatedImageFor(StoreProduct product) {
    if (product.type == StoreProductType.service) return 'assets/images/02.png';
    return 'assets/images/hero.jpg';
  }
}

class _DetailImage extends StatelessWidget {
  const _DetailImage({required this.imageUrl});

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
      decoration: const BoxDecoration(color: _DetailPalette.surface),
      child: const Center(
        child: Icon(Icons.spa_outlined, color: _DetailPalette.gold, size: 42),
      ),
    );
  }
}

class _DetailTexture extends StatelessWidget {
  const _DetailTexture();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(color: Colors.black.withValues(alpha: 0.01)),
    );
  }
}

class _DetailPalette {
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF1C1B1B);
  static const Color gold = Color(0xFFE9C176);
  static const Color onPrimary = Color(0xFF412D00);
  static const Color textPrimary = Color(0xFFE5E2E1);
  static const Color textMuted = Color(0xFFD1C5B4);
  static const Color divider = Color(0x264E4639);
}
