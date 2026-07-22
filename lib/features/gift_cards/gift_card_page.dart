import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/sahara_theme.dart';
import '../cart/cart_page.dart';
import '../store/controllers/store_cart_controller.dart';
import '../store/models/store_product.dart';
import 'gift_card_form_helpers.dart';

class GiftCardPage extends StatefulWidget {
  const GiftCardPage({super.key, required this.product});

  final StoreProduct product;

  @override
  State<GiftCardPage> createState() => _GiftCardPageState();
}

class _GiftCardPageState extends State<GiftCardPage> {
  final StoreCartController _cart = StoreCartController.instance;
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _recipientPhoneController =
      TextEditingController();
  final TextEditingController _senderController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String? _selectedServiceId;
  List<_GiftService> _services = const [];
  bool _loadingServices = true;
  String? _servicesError;
  bool _physicalDelivery = false;
  bool _sendCopyToBuyer = false;
  bool _termsAccepted = false;
  bool _addingToCart = false;
  late DateTime _validFromDate;

  @override
  void initState() {
    super.initState();
    _validFromDate = dateOnly(DateTime.now());
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      // RPC security-definer: la tabla services no es legible por anon (RLS),
      // así que el catálogo regalable se expone vía list_giftable_services.
      final data = await Supabase.instance.client.rpc('list_giftable_services');
      final list = (data as List)
          .cast<Map<String, dynamic>>()
          .map(
            (m) => _GiftService(
              id: m['id'].toString(),
              name: (m['name'] as String? ?? 'Servicio').trim(),
              price: (m['price'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _services = list;
        _selectedServiceId = list.isNotEmpty ? list.first.id : null;
        _loadingServices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _servicesError = '$e';
        _loadingServices = false;
      });
    }
  }

  _GiftService? get _selectedService {
    for (final s in _services) {
      if (s.id == _selectedServiceId) return s;
    }
    return null;
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _recipientPhoneController.dispose();
    _senderController.dispose();
    _messageController.dispose();
    super.dispose();
  }

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
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: _GiftPalette.primary,
                  ),
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
                              icon: const Icon(
                                Icons.shopping_bag_outlined,
                                color: _GiftPalette.primary,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CartPage(),
                                  ),
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
                                    _cart.totalItems > 9
                                        ? '9+'
                                        : '${_cart.totalItems}',
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
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 24 : 80,
                        120,
                        isMobile ? 24 : 80,
                        0,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 1000;
                          final left = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                title: 'Elige el servicio a regalar',
                              ),
                              const SizedBox(height: 32),
                              _ServiceDropdown(
                                services: _services,
                                selectedServiceId: _selectedServiceId,
                                loading: _loadingServices,
                                error: _servicesError,
                                onSelected: (id) =>
                                    setState(() => _selectedServiceId = id),
                              ),
                              const SizedBox(height: 72),
                              _SectionTitle(title: 'Ritual de entrega'),
                              const SizedBox(height: 32),
                              _DeliverySelector(
                                physicalDelivery: _physicalDelivery,
                                onDigitalTap: () =>
                                    setState(() => _physicalDelivery = false),
                                onPhysicalTap: () =>
                                    setState(() => _physicalDelivery = true),
                              ),
                            ],
                          );
                          final right = _PersonalizationCard(
                            recipientController: _recipientController,
                            recipientPhoneController: _recipientPhoneController,
                            senderController: _senderController,
                            messageController: _messageController,
                            validFromDate: _validFromDate,
                            expiresOnDate: addGiftCardCalendarMonths(
                              _validFromDate,
                              3,
                            ),
                            sendCopyToBuyer: _sendCopyToBuyer,
                            termsAccepted: _termsAccepted,
                            totalLabel: _selectedPriceLabel,
                            addingToCart: _addingToCart,
                            onPickDate: _pickValidFromDate,
                            onCopyChanged: (value) =>
                                setState(() => _sendCopyToBuyer = value),
                            onTermsChanged: (value) =>
                                setState(() => _termsAccepted = value),
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
    final service = _selectedService;
    final price = service?.price ?? base.price;
    final serviceName = service?.name ?? base.name;
    final deliveryLabel = _physicalDelivery
        ? 'Entrega fisica premium'
        : 'Entrega digital inmediata';
    final message = sanitizeGiftCardDedication(_messageController.text);
    final recipient = _recipientController.text.trim();
    final recipientPhone = normalizeGiftCardPhoneE164(
      _recipientPhoneController.text,
    );
    final sender = _senderController.text.trim();
    final validFrom = giftCardDateParam(_validFromDate);

    return StoreProduct(
      id: '${base.id}-${service?.id ?? 'na'}-${_physicalDelivery ? 'physical' : 'digital'}',
      name: 'Gift card · $serviceName',
      slug: '${base.slug}-${service?.id ?? ''}',
      description: [
        'Gift card para 1 sesion de $serviceName.',
        'Entrega: $deliveryLabel.',
        if (recipient.isNotEmpty) 'Destinatario: $recipient.',
        if (sender.isNotEmpty) 'Remitente: $sender.',
        if (message.isNotEmpty) 'Dedicatoria: $message.',
      ].join(' '),
      shortDescription: base.shortDescription,
      price: price,
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
      checkoutMetadata: <String, dynamic>{
        'base_product_id': base.id,
        'product_type': 'gift_card',
        'gift_card_kind': 'service',
        if (service != null) 'service_id': service.id,
        'service_name': serviceName,
        'delivery_method': _physicalDelivery ? 'physical' : 'digital',
        'recipient_name': recipient,
        if (recipientPhone != null) 'recipient_phone': recipientPhone,
        'sender_name': sender,
        'dedication_message': message,
        'message': message,
        'valid_from': validFrom,
        'buyer_copy_requested': _sendCopyToBuyer,
        'purchase_channel': 'web',
        'terms_accepted': _termsAccepted,
      },
    );
  }

  Future<void> _pickValidFromDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDate: _validFromDate.isBefore(today) ? today : _validFromDate,
    );
    if (picked != null && mounted) {
      setState(() => _validFromDate = dateOnly(picked));
    }
  }

  void _handlePurchase() {
    if (shouldIgnoreGiftCardTap(submitting: _addingToCart)) return;

    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona el servicio que quieres regalar.'),
        ),
      );
      return;
    }

    final validation = validateGiftCardForm(
      GiftCardFormInput(
        recipientName: _recipientController.text,
        recipientPhone: _recipientPhoneController.text,
        senderName: _senderController.text,
        validFrom: _validFromDate,
        termsAccepted: _termsAccepted,
        dedicationMessage: _messageController.text,
        sendCopyToBuyer: _sendCopyToBuyer,
      ),
    );
    if (!validation.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            validation.message ?? 'Completa la gift card para continuar.',
          ),
        ),
      );
      return;
    }

    setState(() => _addingToCart = true);
    final product = _buildSelectedGiftCard();
    _cart.add(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${product.name} agregada al carrito por ${product.priceLabel}.',
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _addingToCart = false);
    });
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

class _GiftService {
  const _GiftService({
    required this.id,
    required this.name,
    required this.price,
  });

  final String id;
  final String name;
  final double price;

  String get priceLabel => '\$${price.toStringAsFixed(0)} MXN';
}

class _ServiceDropdown extends StatelessWidget {
  const _ServiceDropdown({
    required this.services,
    required this.selectedServiceId,
    required this.loading,
    required this.error,
    required this.onSelected,
  });

  final List<_GiftService> services;
  final String? selectedServiceId;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: _GiftPalette.primary),
        ),
      );
    }
    if (error != null) {
      return Text(
        'No pudimos cargar los servicios. Intenta de nuevo.',
        style: GoogleFonts.inter(color: _GiftPalette.textSoft, fontSize: 15),
      );
    }
    if (services.isEmpty) {
      return Text(
        'Por ahora no hay servicios disponibles para regalar.',
        style: GoogleFonts.inter(color: _GiftPalette.textSoft, fontSize: 15),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _GiftPalette.surfaceLow,
        border: Border.all(color: _GiftPalette.primary.withValues(alpha: 0.30)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedServiceId,
          dropdownColor: _GiftPalette.surfaceLow,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _GiftPalette.primary,
          ),
          hint: Text(
            'Selecciona un servicio',
            style: GoogleFonts.inter(
              color: _GiftPalette.textMuted,
              fontSize: 16,
            ),
          ),
          items: [
            for (final s in services)
              DropdownMenuItem<String>(
                value: s.id,
                child: Text(
                  '${s.name}  ·  ${s.priceLabel}',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: _GiftPalette.textStrong,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) onSelected(id);
          },
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
            children: [digital, const SizedBox(height: 20), physical],
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
            Icon(
              icon,
              color: selected ? _GiftPalette.primary : _GiftPalette.textMuted,
              size: 28,
            ),
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
    required this.recipientPhoneController,
    required this.senderController,
    required this.messageController,
    required this.validFromDate,
    required this.expiresOnDate,
    required this.sendCopyToBuyer,
    required this.termsAccepted,
    required this.totalLabel,
    required this.addingToCart,
    required this.onPickDate,
    required this.onCopyChanged,
    required this.onTermsChanged,
    required this.onPurchase,
  });

  final TextEditingController recipientController;
  final TextEditingController recipientPhoneController;
  final TextEditingController senderController;
  final TextEditingController messageController;
  final DateTime validFromDate;
  final DateTime expiresOnDate;
  final bool sendCopyToBuyer;
  final bool termsAccepted;
  final String totalLabel;
  final bool addingToCart;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onCopyChanged;
  final ValueChanged<bool> onTermsChanged;
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
            border: Border.all(
              color: _GiftPalette.primary.withValues(alpha: 0.05),
            ),
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
                    label: 'WhatsApp del destinatario',
                    hint: '+52 646 000 0000',
                    controller: recipientPhoneController,
                    keyboardType: TextInputType.phone,
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
                    hint:
                        'Porque me acorde de ti, quiero regalarte un momento especial para consentirte.',
                    controller: messageController,
                    maxLines: 4,
                    maxLength: kGiftCardDedicationMaxLength,
                  ),
                  const SizedBox(height: 26),
                  _GiftDateTile(
                    validFromDate: validFromDate,
                    expiresOnDate: expiresOnDate,
                    onTap: onPickDate,
                  ),
                  const SizedBox(height: 18),
                  _GiftCheckboxTile(
                    value: sendCopyToBuyer,
                    label: 'Enviar copia al comprador',
                    onChanged: onCopyChanged,
                  ),
                  _GiftCheckboxTile(
                    value: termsAccepted,
                    label: 'Acepto vigencia de 3 meses y cita previa',
                    onChanged: onTermsChanged,
                  ),
                  const SizedBox(height: 32),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 22,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: addingToCart ? null : onPurchase,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            addingToCart
                                ? 'AGREGANDO...'
                                : 'COMPRAR REGALO RITUAL',
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
    this.maxLength,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;

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
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: maxLength == null
              ? null
              : <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(maxLength),
                ],
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
              borderSide: BorderSide(
                color: _GiftPalette.primary.withValues(alpha: 0.40),
              ),
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

class _GiftDateTile extends StatelessWidget {
  const _GiftDateTile({
    required this.validFromDate,
    required this.expiresOnDate,
    required this.onTap,
  });

  final DateTime validFromDate;
  final DateTime expiresOnDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _GiftPalette.primary.withValues(alpha: 0.40),
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_available_rounded,
              color: _GiftPalette.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VIGENCIA',
                    style: GoogleFonts.inter(
                      color: _GiftPalette.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${giftCardDateLabel(validFromDate)} - ${giftCardDateLabel(expiresOnDate)}',
                    style: GoogleFonts.inter(
                      color: _GiftPalette.textStrong,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_calendar_rounded,
              color: _GiftPalette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftCheckboxTile extends StatelessWidget {
  const _GiftCheckboxTile({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (next) => onChanged(next ?? false),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: _GiftPalette.primary,
      checkColor: _GiftPalette.onPrimary,
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: _GiftPalette.textSoft,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
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
                colorFilter: const ColorFilter.mode(
                  Colors.black38,
                  BlendMode.darken,
                ),
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
