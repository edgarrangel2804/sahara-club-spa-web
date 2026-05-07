import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeaturedSection extends StatelessWidget {
  const FeaturedSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0B0B),
      padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 72),
          _buildCards(),
          const SizedBox(height: 80),
          _buildPromoStrip(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RITUALES DESTACADOS',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFFC6A76A),
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Lo que más\nte va a transformar',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 56,
                  color: const Color(0xFFE8DCC8),
                  fontWeight: FontWeight.w300,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 60),
            Expanded(
              child: Text(
                'Servicios seleccionados por nuestras terapeutas como los rituales que más impacto generan en quienes los reciben.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white54,
                  fontWeight: FontWeight.w300,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCards() {
    final cards = [
      _FeaturedCard(
        image: 'assets/images/06.png',
        tag: 'EL MÁS SOLICITADO',
        tagColor: const Color(0xFFC6A76A),
        title: 'Sahara Soul',
        subtitle: 'Masaje de la casa',
        description:
            'El ritual que abrió la puerta entre cuerpo y alma. Maniobras envolventes, respiración consciente y ritmo terapéutico profundo.',
        price: 'Desde \$1,089',
        duration: '60 · 90 · 120 min',
      ),
      _FeaturedCard(
        image: 'assets/images/07.png',
        tag: 'EXCLUSIVO',
        tagColor: const Color(0xFF8B7355),
        title: 'Amazing Experience',
        subtitle: 'Creado por Jochebed',
        description:
            'Un método propio. Un encuentro completo con el cuerpo. Cada toque tiene un propósito: recordarle que ya no tiene que sostener nada.',
        price: '\$1,777',
        duration: '90 min',
      ),
      _FeaturedCard(
        image: 'assets/images/08.png',
        tag: 'MÁS RESERVADO',
        tagColor: const Color(0xFF6B7B5E),
        title: 'Faciales Sahara',
        subtitle: 'Piel que respira',
        description:
            'Desde el Sahara Soul Facial hasta tratamientos con LED y neuro yoga facial. Tu piel también necesita un ritual de presencia.',
        price: 'Desde \$900',
        duration: '60 · 90 min',
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(cards.length, (i) {
        final c = cards[i];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < cards.length - 1 ? 28 : 0),
            child: _buildCard(c),
          ),
        );
      }),
    );
  }

  Widget _buildCard(_FeaturedCard c) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF111111)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              SizedBox(
                height: 280,
                width: double.infinity,
                child: Image.asset(c.image, fit: BoxFit.cover),
              ),
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: c.tagColor,
                  child: Text(
                    c.tag,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.black,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.subtitle.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFFC6A76A),
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  c.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    color: const Color(0xFFE8DCC8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  c.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white54,
                    height: 1.7,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 24),
                Container(height: 0.5, color: Colors.white10),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.price,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: const Color(0xFFC6A76A),
                              fontWeight: FontWeight.w500,
                            )),
                        const SizedBox(height: 4),
                        Text(c.duration,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white38,
                              letterSpacing: 0.5,
                            )),
                      ],
                    ),
                    _HoverButton(label: 'RESERVAR'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 60),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC6A76A).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Primera visita',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  color: const Color(0xFFE8DCC8),
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cuéntanos dónde carga tu cuerpo y diseñamos tu ritual.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white54,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
          _HoverButton(label: 'AGENDA TU CONSULTA', large: true),
        ],
      ),
    );
  }
}

class _HoverButton extends StatefulWidget {
  final String label;
  final bool large;
  const _HoverButton({required this.label, this.large = false});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: widget.large ? 40 : 20,
          vertical: widget.large ? 18 : 12,
        ),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFC6A76A) : Colors.transparent,
          border: Border.all(
            color: _hovered
                ? const Color(0xFFC6A76A)
                : const Color(0xFFC6A76A).withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: _hovered ? Colors.black : const Color(0xFFC6A76A),
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard {
  final String image;
  final String tag;
  final Color tagColor;
  final String title;
  final String subtitle;
  final String description;
  final String price;
  final String duration;

  const _FeaturedCard({
    required this.image,
    required this.tag,
    required this.tagColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.price,
    required this.duration,
  });
}
