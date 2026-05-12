import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/sahara_theme.dart';
import 'controllers/store_cart_controller.dart';
import 'models/cart_item.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = StoreCartController.instance;
    final subtotal = cart.subtotal;
    final memberCredit = subtotal * 0.10;
    final serviceCharge = subtotal * 0.037;
    final total = subtotal - memberCredit + serviceCharge;

    return Scaffold(
      backgroundColor: _CheckoutPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _CheckoutTexture()),
          const Positioned(
            top: -80,
            right: -80,
            child: _CheckoutGlow(),
          ),
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
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.menu, color: _CheckoutPalette.gold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SAHARA CLUB',
                              style: GoogleFonts.playfairDisplay(
                                color: _CheckoutPalette.gold,
                                fontSize: 28,
                                letterSpacing: 6,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.shopping_bag_outlined, color: _CheckoutPalette.gold),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: const [
                          _CheckoutStep(number: '01', label: 'Guest', active: true),
                          _StepDivider(),
                          _CheckoutStep(number: '02', label: 'Payment'),
                          _StepDivider(),
                          _CheckoutStep(number: '03', label: 'Confirm'),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 980;
                        final left = const _CheckoutForm();
                        final right = _CheckoutSummary(
                          subtotal: subtotal,
                          memberCredit: memberCredit,
                          serviceCharge: serviceCharge,
                          total: total,
                          items: cart.items,
                        );

                        if (stacked) {
                          return Column(
                            children: [
                              left,
                              const SizedBox(height: 32),
                              right,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(flex: 7, child: _CheckoutForm()),
                            const SizedBox(width: 32),
                            Expanded(
                              flex: 5,
                              child: _CheckoutSummary(
                                subtotal: subtotal,
                                memberCredit: memberCredit,
                                serviceCharge: serviceCharge,
                                total: total,
                                items: cart.items,
                              ),
                            ),
                          ],
                        );
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

class _CheckoutForm extends StatelessWidget {
  const _CheckoutForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guest Details',
          style: GoogleFonts.playfairDisplay(
            color: _CheckoutPalette.gold,
            fontSize: 34,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 30),
        const _FormGrid(),
        const SizedBox(height: 70),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Secure Payment',
              style: GoogleFonts.playfairDisplay(
                color: _CheckoutPalette.gold,
                fontSize: 34,
                fontStyle: FontStyle.italic,
              ),
            ),
            const Row(
              children: [
                Icon(Icons.credit_card, color: _CheckoutPalette.textMuted, size: 20),
                SizedBox(width: 8),
                Icon(Icons.contactless, color: _CheckoutPalette.textMuted, size: 20),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: const [
            Expanded(
              child: _PaymentMethod(
                icon: Icons.credit_card,
                label: 'Card',
                active: true,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _PaymentMethod(
                icon: Icons.phone_iphone,
                label: 'Apple Pay',
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _CheckoutInput(
          label: 'Card Number',
          hint: '0000 0000 0000 0000',
        ),
        const SizedBox(height: 28),
        const Row(
          children: [
            Expanded(
              child: _CheckoutInput(label: 'Expiry', hint: 'MM / YY'),
            ),
            SizedBox(width: 24),
            Expanded(
              child: _CheckoutInput(label: 'CVC', hint: '***'),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormGrid extends StatelessWidget {
  const _FormGrid();

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.of(context).size.width < 760;
    if (stacked) {
      return const Column(
        children: [
          _CheckoutInput(label: 'Full Name', hint: 'Elias Vance'),
          SizedBox(height: 28),
          _CheckoutInput(label: 'Email Address', hint: 'elias.v@sanctuary.com'),
          SizedBox(height: 28),
          _CheckoutInput(
            label: 'Ritual Requests (Optional)',
            hint: 'Specify any preferences or allergies...',
          ),
        ],
      );
    }
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CheckoutInput(label: 'Full Name', hint: 'Elias Vance'),
            ),
            SizedBox(width: 24),
            Expanded(
              child: _CheckoutInput(label: 'Email Address', hint: 'elias.v@sanctuary.com'),
            ),
          ],
        ),
        SizedBox(height: 28),
        _CheckoutInput(
          label: 'Ritual Requests (Optional)',
          hint: 'Specify any preferences or allergies...',
        ),
      ],
    );
  }
}

class _CheckoutInput extends StatelessWidget {
  const _CheckoutInput({
    required this.label,
    required this.hint,
  });

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _CheckoutPalette.textMuted.withValues(alpha: 0.6),
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        TextField(
          style: GoogleFonts.inter(
            color: _CheckoutPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w300,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: _CheckoutPalette.textMuted.withValues(alpha: 0.3),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _CheckoutPalette.divider),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _CheckoutPalette.gold),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethod extends StatelessWidget {
  const _PaymentMethod({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? _CheckoutPalette.gold.withValues(alpha: 0.4)
              : _CheckoutPalette.gold.withValues(alpha: 0.1),
        ),
        color: active
            ? _CheckoutPalette.gold.withValues(alpha: 0.06)
            : _CheckoutPalette.surfaceLow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? _CheckoutPalette.gold : _CheckoutPalette.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              color: active ? _CheckoutPalette.gold : _CheckoutPalette.textMuted,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({
    required this.subtotal,
    required this.memberCredit,
    required this.serviceCharge,
    required this.total,
    required this.items,
  });

  final double subtotal;
  final double memberCredit;
  final double serviceCharge;
  final double total;
  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            border: Border.all(color: _CheckoutPalette.gold.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Sanctuary',
                style: GoogleFonts.playfairDisplay(
                  color: _CheckoutPalette.gold,
                  fontSize: 34,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: _CheckoutPalette.divider),
              const SizedBox(height: 24),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: _SummaryImage(imageUrl: item.product.imageUrl),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: GoogleFonts.inter(
                                color: _CheckoutPalette.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.product.shortDescription,
                              style: GoogleFonts.inter(
                                color: _CheckoutPalette.textMuted.withValues(alpha: 0.6),
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${item.subtotal.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                color: _CheckoutPalette.gold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: _CheckoutPalette.divider),
              const SizedBox(height: 18),
              _CheckoutTotalRow(label: 'Subtotal', value: subtotal),
              const SizedBox(height: 10),
              _CheckoutTotalRow(label: 'Member Credit', value: -memberCredit, highlight: true),
              const SizedBox(height: 10),
              _CheckoutTotalRow(label: 'Service Charge', value: serviceCharge),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.playfairDisplay(
                      color: _CheckoutPalette.textPrimary,
                      fontSize: 28,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplay(
                      color: _CheckoutPalette.gold,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La confirmacion y Stripe real se conectan en la siguiente fase.'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  backgroundColor: _CheckoutPalette.gold,
                  foregroundColor: _CheckoutPalette.onPrimary,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Complete Reservation',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.lock, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Encrypted by Sahara Secure Systems',
                  style: GoogleFonts.inter(
                    color: _CheckoutPalette.textMuted.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutTotalRow extends StatelessWidget {
  const _CheckoutTotalRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final double value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _CheckoutPalette.textMuted.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        Text(
          '${value < 0 ? '-' : ''}\$${value.abs().toStringAsFixed(2)}',
          style: GoogleFonts.inter(
            color: highlight ? _CheckoutPalette.gold : _CheckoutPalette.textMuted.withValues(alpha: 0.9),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _CheckoutStep extends StatelessWidget {
  const _CheckoutStep({
    required this.number,
    required this.label,
    this.active = false,
  });

  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? _CheckoutPalette.gold
                  : _CheckoutPalette.gold.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            number,
            style: GoogleFonts.inter(
              color: active
                  ? _CheckoutPalette.gold
                  : _CheckoutPalette.textMuted.withValues(alpha: 0.4),
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            color: active ? _CheckoutPalette.gold : _CheckoutPalette.textMuted,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 1,
      color: _CheckoutPalette.gold.withValues(alpha: 0.2),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class _SummaryImage extends StatelessWidget {
  const _SummaryImage({required this.imageUrl});

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
      decoration: const BoxDecoration(color: _CheckoutPalette.surfaceLow),
      child: const Center(
        child: Icon(Icons.spa_outlined, color: SaharaTheme.gold),
      ),
    );
  }
}

class _CheckoutTexture extends StatelessWidget {
  const _CheckoutTexture();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(color: Colors.black.withValues(alpha: 0.01)),
    );
  }
}

class _CheckoutGlow extends StatelessWidget {
  const _CheckoutGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _CheckoutPalette.gold.withValues(alpha: 0.05),
          boxShadow: [
            BoxShadow(
              color: _CheckoutPalette.gold.withValues(alpha: 0.08),
              blurRadius: 140,
              spreadRadius: 40,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutPalette {
  static const Color background = Color(0xFF131313);
  static const Color surfaceLow = Color(0xFF201F1F);
  static const Color gold = Color(0xFFE9C176);
  static const Color onPrimary = Color(0xFF412D00);
  static const Color textPrimary = Color(0xFFE5E2E1);
  static const Color textMuted = Color(0xFFD1C5B4);
  static const Color divider = Color(0x264E4639);
}
