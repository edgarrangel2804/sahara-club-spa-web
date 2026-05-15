import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/sahara_theme.dart';
import 'controllers/store_cart_controller.dart';
import 'models/cart_item.dart';
import 'services/store_checkout_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final StoreCartController _cart = StoreCartController.instance;
  final StoreCheckoutService _checkoutService = const StoreCheckoutService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from the authenticated session so customer_email matches the account
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (user.email != null) _emailController.text = user.email!;
      final meta = user.userMetadata;
      if (meta != null) {
        final name = meta['full_name'] as String? ??
            meta['name'] as String? ?? '';
        if (name.isNotEmpty) _nameController.text = name;
      }
    }
  }

  double get _subtotal => _cart.subtotal;
  double get _memberCredit => _subtotal * 0.10;
  double get _serviceCharge => _subtotal * 0.037;
  double get _total => _subtotal - _memberCredit + _serviceCharge;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          _CheckoutStep(number: '01', label: 'Datos', active: true),
                          _StepDivider(),
                          _CheckoutStep(number: '02', label: 'Pago'),
                          _StepDivider(),
                          _CheckoutStep(number: '03', label: 'Confirmar'),
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
                        final left = _CheckoutForm(
                          nameController: _nameController,
                          emailController: _emailController,
                          phoneController: _phoneController,
                          notesController: _notesController,
                        );
                        final right = _CheckoutSummary(
                          subtotal: _subtotal,
                          memberCredit: _memberCredit,
                          serviceCharge: _serviceCharge,
                          total: _total,
                          items: _cart.items,
                          submitting: _submitting,
                          onComplete: _handleCheckout,
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
                            Expanded(flex: 7, child: left),
                            const SizedBox(width: 32),
                            Expanded(flex: 5, child: right),
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

  Future<void> _handleCheckout() async {
    if (_submitting) return;
    if (_cart.isEmpty) {
      _showMessage('Tu carrito esta vacio. Agrega un ritual antes de pagar.');
      return;
    }

    final customerName = _nameController.text.trim();
    final customerEmail = _emailController.text.trim();
    final customerPhone = _phoneController.text.trim();
    final notes = _notesController.text.trim();

    if (customerName.isEmpty || customerEmail.isEmpty || customerPhone.isEmpty) {
      _showMessage('Completa nombre, telefono y correo para continuar.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final successUrl = _buildReturnUrl('success', includeSessionPlaceholder: true);
      final cancelUrl = _buildReturnUrl('cancel');

      final result = await _checkoutService.createCheckoutSession(
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        notes: notes,
        items: _cart.items,
        pricing: CheckoutPricing(
          subtotal: _subtotal,
          memberCredit: _memberCredit,
          serviceCharge: _serviceCharge,
          total: _total,
        ),
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );

      final uri = Uri.tryParse(result.checkoutUrl);
      if (uri == null) {
        throw const CheckoutException('Stripe devolvio una URL invalida.');
      }

      final launched = await launchUrl(
        uri,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );

      if (!launched) {
        throw const CheckoutException('No se pudo abrir Stripe Checkout.');
      }
    } on CheckoutException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No se pudo iniciar el pago. Intenta nuevamente.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _buildReturnUrl(String status, {bool includeSessionPlaceholder = false}) {
    final current = Uri.base;
    final params = <String, String>{
      ...current.queryParameters,
      'checkout': status,
    };
    // Build base URL without session_id so queryParameters doesn't percent-encode the braces
    final base = current.replace(queryParameters: params).toString();
    if (includeSessionPlaceholder) {
      // Append raw so Stripe substitutes {CHECKOUT_SESSION_ID} at redirect time
      return '$base&session_id={CHECKOUT_SESSION_ID}';
    }
    return base;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CheckoutForm extends StatelessWidget {
  const _CheckoutForm({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.notesController,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datos del cliente',
          style: GoogleFonts.playfairDisplay(
            color: _CheckoutPalette.gold,
            fontSize: 34,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 30),
        _FormGrid(
          nameController: nameController,
          emailController: emailController,
          phoneController: phoneController,
          notesController: notesController,
        ),
        const SizedBox(height: 70),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Pago seguro',
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
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _CheckoutPalette.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_outline_rounded,
                        color: _CheckoutPalette.gold, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pago procesado por Stripe',
                            style: GoogleFonts.inter(
                              color: _CheckoutPalette.textStrong,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 2),
                        Text('Al continuar seras redirigido a la pagina segura de Stripe para ingresar los datos de tu tarjeta.',
                            style: GoogleFonts.inter(
                              color: _CheckoutPalette.textMuted,
                              fontSize: 12,
                              height: 1.5,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _CardBadge(icon: Icons.credit_card_rounded, label: 'Visa / MC'),
                  const SizedBox(width: 10),
                  _CardBadge(icon: Icons.contactless_rounded, label: 'Amex'),
                  const SizedBox(width: 10),
                  _CardBadge(icon: Icons.shield_outlined, label: 'SSL 256-bit'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormGrid extends StatelessWidget {
  const _FormGrid({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.notesController,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.of(context).size.width < 760;
    if (stacked) {
      return Column(
        children: [
          _CheckoutInput(
            label: 'Nombre completo',
            hint: 'Elias Vance',
            controller: nameController,
          ),
          const SizedBox(height: 28),
          _CheckoutInput(
            label: 'Correo electronico',
            hint: 'elias.v@sanctuary.com',
            controller: emailController,
          ),
          const SizedBox(height: 28),
          _CheckoutInput(
            label: 'Telefono',
            hint: '+52 664 000 0000',
            controller: phoneController,
          ),
          const SizedBox(height: 28),
          _CheckoutInput(
            label: 'Preferencias del ritual (opcional)',
            hint: 'Especifica preferencias o alergias...',
            controller: notesController,
          ),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CheckoutInput(
                label: 'Nombre completo',
                hint: 'Elias Vance',
                controller: nameController,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _CheckoutInput(
                label: 'Correo electronico',
                hint: 'elias.v@sanctuary.com',
                controller: emailController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _CheckoutInput(
                label: 'Telefono',
                hint: '+52 664 000 0000',
                controller: phoneController,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _CheckoutInput(
                label: 'Preferencias del ritual (opcional)',
                hint: 'Especifica preferencias o alergias...',
                controller: notesController,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckoutInput extends StatelessWidget {
  const _CheckoutInput({
    required this.label,
    required this.hint,
    this.controller,
    this.readOnly = false,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final bool readOnly;

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
          controller: controller,
          readOnly: readOnly,
          style: GoogleFonts.inter(
            color: _CheckoutPalette.inputText,
            fontSize: 18,
            fontWeight: FontWeight.w300,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: _CheckoutPalette.inputHint,
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
    required this.submitting,
    required this.onComplete,
  });

  final double subtotal;
  final double memberCredit;
  final double serviceCharge;
  final double total;
  final List<CartItem> items;
  final bool submitting;
  final VoidCallback onComplete;

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
                'Tu santuario',
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
              _CheckoutTotalRow(label: 'Credito de membresia', value: -memberCredit, highlight: true),
              const SizedBox(height: 10),
              _CheckoutTotalRow(label: 'Cargo por servicio', value: serviceCharge),
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
                onPressed: submitting ? null : onComplete,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  backgroundColor: _CheckoutPalette.gold,
                  foregroundColor: _CheckoutPalette.onPrimary,
                  disabledBackgroundColor: _CheckoutPalette.gold.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (submitting) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      submitting ? 'Redirigiendo a Stripe...' : 'Ir a pagar con Stripe',
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
                  'Stripe captura los datos sensibles en un entorno seguro.',
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
  static const Color inputText = Color(0xFF1A1612);
  static const Color inputHint = Color(0xFF8A8178);
  static const Color textPrimary = Color(0xFFE5E2E1);
  static const Color textStrong = Color(0xFFF5F0EB);
  static const Color textMuted = Color(0xFFD1C5B4);
  static const Color divider = Color(0x264E4639);
}

class _CardBadge extends StatelessWidget {
  const _CardBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _CheckoutPalette.textMuted),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _CheckoutPalette.textMuted,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}
