import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/sahara_theme.dart';
import '../cart/cart_page.dart';
import '../store/controllers/store_cart_controller.dart';
import '../store/models/store_product.dart';

class GiftCardPage extends StatefulWidget {
  const GiftCardPage({
    super.key,
    required this.product,
  });

  final StoreProduct product;

  @override
  State<GiftCardPage> createState() => _GiftCardPageState();
}

class _GiftCardPageState extends State<GiftCardPage> {
  final StoreCartController _cart = StoreCartController.instance;
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _senderController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  int? _selectedAmount = 2500;
  bool _physicalDelivery = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _senderController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  static const List<int> _presetAmounts = <int>[1000, 2500, 5000];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      backgroundColor: _GiftPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _GiftBackdrop()),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: _GiftPalette.surface.withValues(alpha: 0.78),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: _GiftPalette.primary),
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: Text(
                  'SAHARA CLUB',
                  style: GoogleFonts.playfairDisplay(
                    color: _GiftPalette.primary,
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
                              icon: const Icon(Icons.shopping_bag_outlined, color: _GiftPalette.primary),
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
                                    color: _GiftPalette.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _cart.totalItems > 9 ? '9+' : '${_cart.totalItems}',
                                    style: GoogleFonts.inter(
                                      color: _GiftPalette.onPrimary,
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
                child: Column(
                  children: [
                    const _GiftHero(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(isMobile ? 24 : 80, 120, isMobile ? 24 : 80, 0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 1000;
                          final left = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(title: 'Selecciona el monto'),
                              const SizedBox(height: 32),
                              _AmountGrid(
                                selectedAmount: _selectedAmount,
                                onSelected: (amount) => setState(() => _selectedAmount = amount),
                              ),
                              const SizedBox(height: 72),
                              _SectionTitle(title: 'Ritual de entrega'),
                              const SizedBox(height: 32),
                              _DeliverySelector(
                                physicalDelivery: _physicalDelivery,
                                onDigitalTap: () => setState(() => _physicalDelivery = false),
                                onPhysicalTap: () => setState(() => _physicalDelivery = true),
                              ),
                            ],
                          );
                          final right = _PersonalizationCard(
                            recipientController: _recipientController,
                            senderController: _senderController,
                            messageController: _messageController,
                            totalLabel: _selectedPriceLabel,
                            onPurchase: _handlePurchase,
                          );

                          if (stacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                left,
                                const SizedBox(height: 48),
                                right,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: left),
                              const SizedBox(width: 24),
                              Expanded(flex: 5, child: right),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 120),
                    const _GiftStorySection(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _selectedPriceLabel {
    final product = _buildSelectedGiftCard();
    return product.priceLabel;
  }

  StoreProduct _buildSelectedGiftCard() {
    final base = widget.product;
    final selectedAmount = _selectedAmount ?? base.price.round();
    final deliveryLabel = _physicalDelivery
        ? 'Entrega fisica premium'
        : 'Entrega digital inmediata';
    final message = _messageController.text.trim();
    final recipient = _recipientController.text.trim();
    final sender = _senderController.text.trim();

    return StoreProduct(
      id: '${base.id}-$selectedAmount-${_physicalDelivery ? 'physical' : 'digital'}',
      name: base.name,
      slug: '${base.slug}-$selectedAmount',
      description: [
        base.description,
        'Denominacion seleccionada: $selectedAmount MXN.',
        'Entrega: $deliveryLabel.',
        if (recipient.isNotEmpty) 'Destinatario: $recipient.',
        if (sender.isNotEmpty) 'Remitente: $sender.',
        if (message.isNotEmpty) 'Mensaje: $message.',
      ].join(' '),
      shortDescription: base.shortDescription,
      price: selectedAmount.toDouble(),
      currency: base.currency,
      type: base.type,
      imageUrl: base.imageUrl,
      categoryKey: base.categoryKey,
      categoryLabel: base.categoryLabel,
      benefits: base.benefits,
      availability: _physicalDelivery
          ? 'Preparacion premium para entrega fisica'
          : 'Codigo digital generado al pagar',
      durationMinutes: base.durationMinutes,
      stockQuantity: base.stockQuantity,
      isFeatured: base.isFeatured,
    );
  }

  void _handlePurchase() {
    final recipient = _recipientController.text.trim();
    final sender = _senderController.text.trim();

    if (recipient.isEmpty || sender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa destinatario y remitente para continuar.')),
      );
      return;
    }

    final product = _buildSelectedGiftCard();
    _cart.add(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} agregada al carrito por ${product.priceLabel}.')),
    );
  }
}

class _GiftHero extends StatelessWidget {
  const _GiftHero();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    return SizedBox(
      height: isMobile ? 520 : 620,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1515377905703-c4788e51af15?auto=format&fit=crop&w=1600&q=80',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0x66131313),
                  Color(0xFF131313),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Regala la experiencia',
                      style: GoogleFonts.inter(
                        color: _GiftPalette.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Regala quietud',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: _GiftPalette.textStrong,
                        fontSize: isMobile ? 42 : 78,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Invitales al santuario. Un recorrido curado de restauracion, silencio y despertar sensorial.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: _GiftPalette.textSoft,
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 1,
          color: _GiftPalette.primary.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            color: _GiftPalette.textStrong,
            fontSize: 34,
          ),
        ),
      ],
    );
  }
}

class _AmountGrid extends StatelessWidget {
  const _AmountGrid({
    required this.selectedAmount,
    required this.onSelected,
  });

  final int? selectedAmount;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1,
          children: [
            for (final amount in _GiftCardPageState._presetAmounts)
              _AmountTile(
                label: 'MXN',
                value: '\$${amount.toString()}',
                selected: selectedAmount == amount,
                onTap: () => onSelected(amount),
              ),
            _AmountTile(
              label: 'OTRO',
              icon: Icons.edit_outlined,
              selected: selectedAmount == null,
              onTap: () => onSelected(null),
            ),
          ],
        );
      },
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    this.value,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          color: selected
              ? _GiftPalette.primary.withValues(alpha: 0.09)
              : _GiftPalette.surfaceLow,
          border: Border.all(
            color: selected
                ? _GiftPalette.primary
                : _GiftPalette.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: selected ? _GiftPalette.primary : _GiftPalette.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 12),
            if (value != null)
              Text(
                value!,
                style: GoogleFonts.playfairDisplay(
                  color: selected ? _GiftPalette.primary : _GiftPalette.textStrong,
                  fontSize: 34,
                ),
              )
            else
              Icon(icon, color: selected ? _GiftPalette.primary : _GiftPalette.textMuted, size: 26),
          ],
        ),
      ),
    );
  }
}

class _DeliverySelector extends StatelessWidget {
  const _DeliverySelector({
    required this.physicalDelivery,
    required this.onDigitalTap,
    required this.onPhysicalTap,
  });

  final bool physicalDelivery;
  final VoidCallback onDigitalTap;
  final VoidCallback onPhysicalTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 660;
        final digital = _DeliveryCard(
          selected: !physicalDelivery,
          icon: Icons.mail_outline_rounded,
          title: 'Entrega digital',
          description:
              'Transmision inmediata al correo del destinatario. Ideal para regalar en el momento.',
          footer: 'Seleccionado',
          onTap: onDigitalTap,
        );
        final physical = _DeliveryCard(
          selected: physicalDelivery,
          icon: Icons.card_giftcard_rounded,
          title: 'Entrega fisica',
          description:
              'Sobre premium entregado con una presentacion boutique de Sahara para una experiencia de regalo mas especial.',
          footer: '+ Preparacion premium',
          onTap: onPhysicalTap,
        );

        if (stacked) {
          return Column(
            children: [
              digital,
              const SizedBox(height: 20),
              physical,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: digital),
            const SizedBox(width: 24),
            Expanded(child: physical),
          ],
        );
      },
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.footer,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final String footer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: selected
              ? _GiftPalette.primary.withValues(alpha: 0.06)
              : _GiftPalette.surfaceLowest,
          border: Border.all(
            color: selected
                ? _GiftPalette.primary
                : _GiftPalette.primary.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? _GiftPalette.primary : _GiftPalette.textMuted, size: 28),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                color: _GiftPalette.textStrong,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.inter(
                color: _GiftPalette.textSoft,
                fontSize: 15,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              footer.toUpperCase(),
              style: GoogleFonts.inter(
                color: selected ? _GiftPalette.primary : _GiftPalette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalizationCard extends StatelessWidget {
  const _PersonalizationCard({
    required this.recipientController,
    required this.senderController,
    required this.messageController,
    required this.totalLabel,
    required this.onPurchase,
  });

  final TextEditingController recipientController;
  final TextEditingController senderController;
  final TextEditingController messageController;
  final String totalLabel;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _GiftPalette.surfaceContainer.withValues(alpha: 0.30),
            border: Border.all(color: _GiftPalette.primary.withValues(alpha: 0.05)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: _GiftPalette.primary.withValues(alpha: 0.20),
                  size: 48,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personaliza',
                    style: GoogleFonts.playfairDisplay(
                      color: _GiftPalette.textStrong,
                      fontSize: 34,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _GiftInput(
                    label: 'Nombre del destinatario',
                    hint: 'Quien recibira la experiencia?',
                    controller: recipientController,
                  ),
                  const SizedBox(height: 28),
                  _GiftInput(
                    label: 'Nombre de quien regala',
                    hint: 'Tu nombre',
                    controller: senderController,
                  ),
                  const SizedBox(height: 28),
                  _GiftInput(
                    label: 'Mensaje de bienestar',
                    hint: 'Escribe un mensaje con intencion...',
                    controller: messageController,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.playfairDisplay(
                          color: _GiftPalette.textSoft,
                          fontSize: 26,
                        ),
                      ),
                      Text(
                        totalLabel,
                        style: GoogleFonts.playfairDisplay(
                          color: _GiftPalette.primary,
                          fontSize: 34,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _GiftPalette.primary,
                      foregroundColor: _GiftPalette.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: onPurchase,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'COMPRAR REGALO RITUAL',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.6,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'PROTEGIDO POR EL CHECKOUT ENCRIPTADO DE SAHARA CLUB',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: _GiftPalette.textMuted.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftInput extends StatelessWidget {
  const _GiftInput({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: _GiftPalette.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(
            color: _GiftPalette.textStrong,
            fontSize: 18,
            fontWeight: FontWeight.w300,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: _GiftPalette.textMuted.withValues(alpha: 0.35),
              fontSize: 18,
              fontWeight: FontWeight.w300,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _GiftPalette.primary.withValues(alpha: 0.40)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _GiftPalette.primary),
            ),
            border: const UnderlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _GiftStorySection extends StatelessWidget {
  const _GiftStorySection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      child: Container(
        color: _GiftPalette.surfaceLowest,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 0,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : 560,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 48,
                  vertical: isMobile ? 40 : 72,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mas alla de la tarjeta',
                      style: GoogleFonts.playfairDisplay(
                        color: _GiftPalette.textStrong,
                        fontSize: isMobile ? 38 : 54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Cada tarjeta de regalo es una llave a nuestro oasis privado en el desierto. Ya sea para un sound bath bajo las estrellas, un masaje de tejido profundo o una membresia para nuestras piscinas twilight, la experiencia sera completamente suya.',
                      style: GoogleFonts.inter(
                        color: _GiftPalette.textSoft,
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DESCUBRIR NUESTROS RITUALES',
                          style: GoogleFonts.inter(
                            color: _GiftPalette.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.8,
                          ),
                        ),
                        const SizedBox(width: 14),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          width: 60,
                          height: 1,
                          color: _GiftPalette.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 560,
              height: isMobile ? 380 : 500,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Colors.black38, BlendMode.darken),
                child: Image.network(
                  'https://images.unsplash.com/photo-1512290923902-8a9f81dc236c?auto=format&fit=crop&w=1400&q=80',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftBackdrop extends StatelessWidget {
  const _GiftBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _GiftPalette.background),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _GiftTexturePainter()),
          ),
        ),
      ],
    );
  }
}

class _GiftTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _GiftPalette.primary.withValues(alpha: 0.022)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 8), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GiftPalette {
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF151312);
  static const Color surfaceLow = Color(0xFF1C1B1B);
  static const Color surfaceLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color primary = SaharaTheme.gold;
  static const Color onPrimary = Color(0xFF412D00);
  static const Color textStrong = Color(0xFFE5E2E1);
  static const Color textSoft = Color(0xFFD1C5B4);
  static const Color textMuted = Color(0xFF9A8F80);
}
