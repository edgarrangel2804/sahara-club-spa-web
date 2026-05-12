import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/sahara_theme.dart';
import '../store/checkout_page.dart';
import '../store/controllers/store_cart_controller.dart';
import '../store/data/store_catalog_repository.dart';
import '../store/models/cart_item.dart';
import '../store/models/store_product.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final StoreCartController _cart = StoreCartController.instance;
  final StoreCatalogRepository _repository = const StoreCatalogRepository();

  List<StoreProduct> _enhancements = <StoreProduct>[];

  @override
  void initState() {
    super.initState();
    _loadEnhancements();
  }

  Future<void> _loadEnhancements() async {
    final products = await _repository.loadProducts();
    if (!mounted) return;
    setState(() {
      _enhancements = products
          .where((product) => !_cart.items.any((item) => item.product.id == product.id))
          .take(3)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _CartPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _CartTexture()),
          AnimatedBuilder(
            animation: _cart,
            builder: (context, _) {
              return SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: _CartTopBar(totalItems: _cart.totalItems),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Rituals',
                              style: GoogleFonts.playfairDisplay(
                                color: _CartPalette.textPrimary,
                                fontSize: 64,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: Text(
                                'Every selection is a step toward stillness. Review your curated experiences and essentials before proceeding.',
                                style: GoogleFonts.inter(
                                  color: _CartPalette.textMuted.withValues(alpha: 0.7),
                                  fontSize: 18,
                                  height: 1.7,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 50, 24, 0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 980;
                            final items = _cart.isEmpty
                                ? const _EmptyCartState()
                                : _CartItemsList(cart: _cart);
                            final summary = _OrderSummary(
                              cart: _cart,
                              onCheckout: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CheckoutPage()),
                                );
                              },
                            );

                            if (stacked) {
                              return Column(
                                children: [
                                  items,
                                  const SizedBox(height: 32),
                                  summary,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: items),
                                const SizedBox(width: 32),
                                Expanded(flex: 5, child: summary),
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
                              'Enhance Your Journey',
                              style: GoogleFonts.playfairDisplay(
                                color: _CartPalette.textPrimary,
                                fontSize: 34,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 32),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 980 ? 3 : 1;
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _enhancements.length,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 24,
                                    mainAxisSpacing: 24,
                                    childAspectRatio: 0.8,
                                  ),
                                  itemBuilder: (context, index) {
                                    final product = _enhancements[index];
                                    return _EnhancementCard(
                                      product: product,
                                      onAdd: () => _cart.add(product),
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
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CartTopBar extends StatelessWidget {
  const _CartTopBar({required this.totalItems});

  final int totalItems;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.menu, color: _CartPalette.gold),
            ),
            const SizedBox(width: 8),
            Text(
              'SAHARA CLUB',
              style: GoogleFonts.playfairDisplay(
                color: _CartPalette.gold,
                fontSize: 28,
                letterSpacing: 6,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (MediaQuery.of(context).size.width >= 768) ...[
              _NavText(label: 'Sanctuary'),
              const SizedBox(width: 28),
              _NavText(label: 'Rituals'),
              const SizedBox(width: 28),
              Text(
                'Cart',
                style: GoogleFonts.inter(
                  color: _CartPalette.gold,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 18),
            ],
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_bag_outlined, color: _CartPalette.gold),
                if (totalItems > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _CartPalette.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _NavText extends StatelessWidget {
  const _NavText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        color: _CartPalette.textMuted.withValues(alpha: 0.7),
        fontSize: 12,
        letterSpacing: 2,
      ),
    );
  }
}

class _CartItemsList extends StatelessWidget {
  const _CartItemsList({required this.cart});

  final StoreCartController cart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: cart.items.map((item) => _CartItemCard(item: item, cart: cart)).toList(),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.cart,
  });

  final CartItem item;
  final StoreCartController cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.only(bottom: 32),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _CartPalette.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 680;
          final image = SizedBox(
            width: stacked ? double.infinity : 192,
            height: stacked ? 260 : 192,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _CartImage(imageUrl: item.product.imageUrl),
            ),
          );

          final content = Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: stacked ? 0 : 24, top: stacked ? 18 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: GoogleFonts.playfairDisplay(
                            color: _CartPalette.textPrimary,
                            fontSize: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatPrice(item.product.price),
                        style: GoogleFonts.inter(
                          color: _CartPalette.gold,
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cartMeta(item.product),
                    style: GoogleFonts.inter(
                      color: _CartPalette.textMuted.withValues(alpha: 0.6),
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: _CartPalette.gold.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => cart.decrease(item.product.id),
                              icon: const Icon(Icons.remove, color: _CartPalette.textMuted, size: 16),
                              constraints: const BoxConstraints.tightFor(width: 20, height: 20),
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 22),
                            Text(
                              '${item.quantity}',
                              style: GoogleFonts.inter(
                                color: _CartPalette.textPrimary,
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 22),
                            IconButton(
                              onPressed: () => cart.increase(item.product.id),
                              icon: const Icon(Icons.add, color: _CartPalette.textMuted, size: 16),
                              constraints: const BoxConstraints.tightFor(width: 20, height: 20),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => cart.remove(item.product.id),
                        child: Text(
                          'Remove',
                          style: GoogleFonts.inter(
                            color: _CartPalette.textMuted.withValues(alpha: 0.45),
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [image, content],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [image, content],
          );
        },
      ),
    );
  }

  String _cartMeta(StoreProduct product) {
    if (product.durationMinutes != null) {
      return '${product.durationMinutes} MINUTES • ${product.typeLabel.toUpperCase()}';
    }
    return product.typeLabel.toUpperCase();
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.cart,
    required this.onCheckout,
  });

  final StoreCartController cart;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final fee = cart.subtotal * 0.03;
    final tax = cart.subtotal * 0.0824;
    final total = cart.subtotal + fee + tax;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _CartPalette.surfaceLow,
        border: Border.all(color: _CartPalette.gold.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: GoogleFonts.playfairDisplay(
              color: _CartPalette.textPrimary,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: 28),
          _SummaryRow(label: 'Subtotal', value: _formatPrice(cart.subtotal)),
          const SizedBox(height: 18),
          _SummaryRow(label: 'Service Fee', value: _formatPrice(fee)),
          const SizedBox(height: 18),
          _SummaryRow(label: 'Tax', value: _formatPrice(tax)),
          const SizedBox(height: 24),
          Container(height: 1, color: _CartPalette.gold.withValues(alpha: 0.15)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.inter(
                  color: _CartPalette.gold,
                  fontSize: 12,
                  letterSpacing: 3,
                ),
              ),
              Text(
                _formatPrice(total),
                style: GoogleFonts.playfairDisplay(
                  color: _CartPalette.gold,
                  fontSize: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: cart.isEmpty ? null : onCheckout,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              backgroundColor: _CartPalette.gold,
              foregroundColor: _CartPalette.onPrimary,
              disabledBackgroundColor: Colors.white12,
            ),
            child: Text(
              'Secure Checkout',
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
              'Complimentary shipping on all ritual essentials.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _CartPalette.textMuted.withValues(alpha: 0.4),
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _CartPalette.textMuted.withValues(alpha: 0.6),
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: _CartPalette.textPrimary,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _EnhancementCard extends StatelessWidget {
  const _EnhancementCard({
    required this.product,
    required this.onAdd,
  });

  final StoreProduct product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _CartImage(imageUrl: product.imageUrl),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            product.name,
            style: GoogleFonts.inter(
              color: _CartPalette.textPrimary,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.priceLabel,
            style: GoogleFonts.inter(
              color: _CartPalette.gold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.shopping_bag_outlined, color: _CartPalette.gold, size: 40),
            const SizedBox(height: 16),
            Text(
              'Tu carrito esta vacio',
              style: GoogleFonts.playfairDisplay(
                color: _CartPalette.textPrimary,
                fontSize: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartImage extends StatelessWidget {
  const _CartImage({required this.imageUrl});

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
      decoration: const BoxDecoration(color: _CartPalette.surfaceHigh),
      child: const Center(
        child: Icon(Icons.spa_outlined, color: SaharaTheme.gold),
      ),
    );
  }
}

class _CartTexture extends StatelessWidget {
  const _CartTexture();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(color: Colors.black.withValues(alpha: 0.01)),
    );
  }
}

String _formatPrice(double value) {
  return '\$${value.toStringAsFixed(2)}';
}

class _CartPalette {
  static const Color background = Color(0xFF131313);
  static const Color surfaceLow = Color(0xFF201F1F);
  static const Color surfaceHigh = Color(0xFF2A2A2A);
  static const Color gold = Color(0xFFE9C176);
  static const Color onPrimary = Color(0xFF412D00);
  static const Color textPrimary = Color(0xFFE5E2E1);
  static const Color textMuted = Color(0xFFD1C5B4);
  static const Color divider = Color(0x264E4639);
}
