import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../store/store_page.dart';
import '../../theme/sahara_theme.dart';

class VipMembershipsPage extends StatelessWidget {
  const VipMembershipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _VipPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _VipBackdrop()),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: _VipPalette.surface.withValues(alpha: 0.78),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: _VipPalette.primary),
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: Text(
                  'SAHARA CLUB',
                  style: GoogleFonts.playfairDisplay(
                    color: _VipPalette.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined, color: _VipPalette.primary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StorePage()),
                      );
                    },
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
                    const _HeroSection(),
                    const _MembershipTiersSection(),
                    const _MembershipStorySection(),
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
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    return SizedBox(
      height: isMobile ? 720 : 760,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1519823551278-64ac92734fb1?auto=format&fit=crop&w=1600&q=80',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xA6000000),
                  Color(0x6B151312),
                  Color(0xFF131313),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 48,
                vertical: 48,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Membresia Elite',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: _VipPalette.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4.5,
                        textStyle: const TextStyle(
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Acceso exclusivo a un mundo\nde bienestar sin limites.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: _VipPalette.textStrong,
                        fontSize: isMobile ? 42 : 78,
                        fontWeight: FontWeight.w500,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 36),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _VipPalette.primary,
                        foregroundColor: _VipPalette.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Beneficios de membresia disponibles pronto.')),
                        );
                      },
                      child: Text(
                        'DESCUBRIR BENEFICIOS',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                        ),
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

class _MembershipTiersSection extends StatelessWidget {
  const _MembershipTiersSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 110,
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: const [
              _TierCard(
                title: 'Oasis Plata',
                subtitle: 'Lujo de entrada',
                price: '\$250',
                period: '/mes',
                tone: _TierTone.silver,
                cta: 'SELECCIONAR MEMBRESIA',
                benefits: [
                  _TierBenefit(label: 'Reserva prioritaria de rituales', included: true),
                  _TierBenefit(label: 'Esenciales de ritual de cortesia', included: true),
                  _TierBenefit(label: 'Concierge digital de bienestar', included: false),
                  _TierBenefit(label: 'Acceso privado al santuario', included: false),
                ],
              ),
              _TierCard(
                title: 'Duna Dorada',
                subtitle: 'La experiencia de autor',
                price: '\$550',
                period: '/mes',
                tone: _TierTone.gold,
                badge: 'Mas popular',
                cta: 'SOLICITAR ACCESO',
                benefits: [
                  _TierBenefit(label: 'Reserva prioritaria de rituales', included: true),
                  _TierBenefit(label: 'Esenciales de ritual de cortesia', included: true),
                  _TierBenefit(label: 'Concierge digital de bienestar', included: true),
                  _TierBenefit(label: 'Acceso privado al santuario', included: false),
                ],
              ),
              _TierCard(
                title: 'Sahara Black',
                subtitle: 'El nivel mas alto',
                price: '\$1,200',
                period: '/mes',
                tone: _TierTone.black,
                cta: 'SELECCIONAR MEMBRESIA',
                benefits: [
                  _TierBenefit(label: 'Reserva prioritaria de rituales', included: true),
                  _TierBenefit(label: 'Esenciales de ritual de cortesia', included: true),
                  _TierBenefit(label: 'Concierge digital de bienestar', included: true),
                  _TierBenefit(label: 'Acceso privado al santuario', included: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('La comparacion completa de beneficios estara disponible en una siguiente fase.')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: _VipPalette.primary),
            label: Text(
              'COMPARAR BENEFICIOS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.8,
              ),
            ),
            icon: const Icon(Icons.keyboard_arrow_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _MembershipStorySection extends StatelessWidget {
  const _MembershipStorySection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 20,
      ),
      child: Wrap(
        spacing: 48,
        runSpacing: 40,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 520,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Colors.black26, BlendMode.darken),
                child: Image.network(
                  'https://images.unsplash.com/photo-1507652313519-d4e9174996dd?auto=format&fit=crop&w=1200&q=80',
                  fit: BoxFit.cover,
                  height: isMobile ? 420 : 620,
                  width: isMobile ? double.infinity : 520,
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Un refugio disenado para su espiritu.',
                  style: GoogleFonts.playfairDisplay(
                    color: _VipPalette.textStrong,
                    fontSize: isMobile ? 36 : 52,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Nuestras membresias no son solo servicios, son llaves a un santuario privado donde el tiempo se detiene. Disfrute de acceso preferencial a terapeutas maestros, suites de tratamiento privadas y eventos exclusivos del club.',
                  style: GoogleFonts.inter(
                    color: _VipPalette.textSoft,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 36),
                const _StoryBenefit(
                  icon: Icons.workspace_premium_outlined,
                  title: 'MEMBRESIA TRANSFERIBLE',
                  description: 'Comparta su estatus con invitados seleccionados mensualmente.',
                ),
                const SizedBox(height: 24),
                const _StoryBenefit(
                  icon: Icons.public_outlined,
                  title: 'ACCESO GLOBAL',
                  description: 'Privilegios en todas nuestras ubicaciones de desierto y ciudad.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatefulWidget {
  const _TierCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.period,
    required this.benefits,
    required this.cta,
    required this.tone,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String price;
  final String period;
  final List<_TierBenefit> benefits;
  final String cta;
  final _TierTone tone;
  final String? badge;

  @override
  State<_TierCard> createState() => _TierCardState();
}

class _TierCardState extends State<_TierCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.tone == _TierTone.gold;
    final accent = switch (widget.tone) {
      _TierTone.silver => _VipPalette.secondary,
      _TierTone.gold => _VipPalette.primary,
      _TierTone.black => _VipPalette.textStrong,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: 360,
        transform: Matrix4.identity()
          ..translate(0.0, _hovered ? -8.0 : 0.0)
          ..scale(widget.tone == _TierTone.gold ? 1.02 : 1.0),
        decoration: BoxDecoration(
          color: widget.tone == _TierTone.black
              ? _VipPalette.surfaceLowest.withValues(alpha: 0.86)
              : _VipPalette.card.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary
                ? _VipPalette.primary.withValues(alpha: 0.5)
                : _VipPalette.primary.withValues(alpha: _hovered ? 0.3 : 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? _VipPalette.primary.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.28),
              blurRadius: isPrimary ? 40 : 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: const SizedBox.expand(),
                ),
              ),
              if (widget.badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    color: _VipPalette.primary,
                    child: Text(
                      widget.badge!.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: _VipPalette.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      widget.title,
                      style: GoogleFonts.playfairDisplay(
                        color: accent,
                        fontSize: 34,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: _VipPalette.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.3,
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (final benefit in widget.benefits) ...[
                      _TierBenefitRow(
                        benefit: benefit,
                        tone: widget.tone,
                      ),
                      const SizedBox(height: 18),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.price,
                          style: GoogleFonts.playfairDisplay(
                            color: isPrimary ? _VipPalette.primary : _VipPalette.textStrong,
                            fontSize: 40,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            widget.period,
                            style: GoogleFonts.inter(
                              color: _VipPalette.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: widget.tone == _TierTone.gold
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _VipPalette.primary,
                                foregroundColor: _VipPalette.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _showMembershipIntent(context, widget.title),
                              child: Text(
                                widget.cta,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.6,
                                ),
                              ),
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: widget.tone == _TierTone.black
                                      ? _VipPalette.textStrong.withValues(alpha: 0.2)
                                      : _VipPalette.primary.withValues(alpha: 0.45),
                                ),
                                foregroundColor: widget.tone == _TierTone.black
                                    ? _VipPalette.textStrong
                                    : _VipPalette.primary,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _showMembershipIntent(context, widget.title),
                              child: Text(
                                widget.cta,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.6,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMembershipIntent(BuildContext context, String membershipName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Seleccionaste $membershipName. La activacion quedara conectada en la fase de checkout.')),
    );
  }
}

class _TierBenefitRow extends StatelessWidget {
  const _TierBenefitRow({
    required this.benefit,
    required this.tone,
  });

  final _TierBenefit benefit;
  final _TierTone tone;

  @override
  Widget build(BuildContext context) {
    final activeColor = tone == _TierTone.gold
        ? _VipPalette.primary
        : tone == _TierTone.black
            ? _VipPalette.primary
            : _VipPalette.textSoft;

    if (!benefit.included) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: _VipPalette.textFaded,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              benefit.label,
              style: GoogleFonts.inter(
                color: _VipPalette.textFaded,
                fontSize: 15,
                decoration: TextDecoration.lineThrough,
                decorationColor: _VipPalette.textFaded,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            tone == _TierTone.black ? Icons.auto_awesome_rounded : Icons.check_rounded,
            size: 18,
            color: activeColor,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            benefit.label,
            style: GoogleFonts.inter(
              color: _VipPalette.textSoft,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryBenefit extends StatelessWidget {
  const _StoryBenefit({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _VipPalette.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _VipPalette.primary.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: _VipPalette.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _VipPalette.textStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.inter(
                  color: _VipPalette.textMuted,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VipBackdrop extends StatelessWidget {
  const _VipBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _VipPalette.background),
        Positioned(
          top: -120,
          right: -120,
          child: Container(
            width: 440,
            height: 440,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _VipPalette.primary.withValues(alpha: 0.05),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          left: -120,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SaharaTheme.bronceOscuro.withValues(alpha: 0.08),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GrainPainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _VipPalette.primary.withValues(alpha: 0.028)
      ..strokeWidth = 1;

    const spacing = 16.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _TierTone { silver, gold, black }

class _TierBenefit {
  const _TierBenefit({
    required this.label,
    required this.included,
  });

  final String label;
  final bool included;
}

class _VipPalette {
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF151312);
  static const Color surfaceLowest = Color(0xFF0E0E0E);
  static const Color card = Color(0xFF1F1A17);
  static const Color primary = SaharaTheme.gold;
  static const Color secondary = Color(0xFFD7C3B0);
  static const Color onPrimary = Color(0xFF412D00);
  static const Color textStrong = Color(0xFFE5E2E1);
  static const Color textSoft = Color(0xFFD1C5B4);
  static const Color textMuted = Color(0xFF9A8F80);
  static const Color textFaded = Color(0x665B564F);
}
