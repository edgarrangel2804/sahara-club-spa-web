import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/web_content/web_content_models.dart';
import '../features/web_content/web_content_repository.dart';

class FeaturedSection extends StatefulWidget {
  const FeaturedSection({super.key});

  @override
  State<FeaturedSection> createState() => _FeaturedSectionState();
}

class _FeaturedSectionState extends State<FeaturedSection> {
  final WebContentRepository _repository = WebContentRepository();
  late final Future<_FeaturedContentState> _future = _loadContent();

  Future<_FeaturedContentState> _loadContent() async {
    try {
      final items = await _repository.loadContent(activeOnly: true);
      final featured = items
          .where(
            (item) =>
                item.sectionKey == 'featured_posts' ||
                (item.isFeatured &&
                    (item.contentType == 'post' ||
                        item.contentType == 'promotion' ||
                        item.contentType == 'massage' ||
                        item.contentType == 'facial')),
          )
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      final promotions = items
          .where((item) => item.sectionKey == 'promotions')
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      return _FeaturedContentState(
        cards: featured.take(3).toList(),
        promo: promotions.isNotEmpty ? promotions.first : null,
      );
    } catch (_) {
      return const _FeaturedContentState(cards: <WebContentItem>[]);
    }
  }

  Future<void> _openCta(String rawUrl) async {
    final value = rawUrl.trim();
    if (value.isEmpty) return;
    final uri = value.startsWith('/') || value.startsWith('#')
        ? Uri.base.resolve(value)
        : Uri.tryParse(value.startsWith('http') ? value : 'https://$value');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FeaturedContentState>(
      future: _future,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const _FeaturedContentState(cards: <WebContentItem>[]);
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            return Container(
              color: const Color(0xFF0B0B0B),
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 64 : 120,
                horizontal: isMobile ? 24 : 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isMobile),
                  SizedBox(height: isMobile ? 48 : 72),
                  _buildCards(state.cards, isMobile),
                  if (state.promo != null) ...[
                    SizedBox(height: isMobile ? 48 : 80),
                    _buildPromoStrip(state.promo!, isMobile),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
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
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lo que mas\nte va a transformar',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 38,
                  color: const Color(0xFFE8DCC8),
                  fontWeight: FontWeight.w300,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Contenido destacado, promociones vivas y experiencias seleccionadas para mostrar lo mejor de Sahara Club Spa.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white54,
                  fontWeight: FontWeight.w300,
                  height: 1.7,
                ),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Lo que mas\nte va a transformar',
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
                  'Contenido destacado, promociones vivas y experiencias seleccionadas para mostrar lo mejor de Sahara Club Spa.',
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

  Widget _buildCards(List<WebContentItem> cards, bool isMobile) {
    if (cards.isEmpty) {
      return Text(
        'Aun no hay publicaciones destacadas activas.',
        style: GoogleFonts.inter(
          fontSize: 15,
          color: Colors.white54,
        ),
      );
    }

    if (isMobile) {
      return Column(
        children: List.generate(cards.length, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index < cards.length - 1 ? 28 : 0),
            child: _buildCard(cards[index]),
          );
        }),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(cards.length, (index) {
        final card = cards[index];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < cards.length - 1 ? 28 : 0),
            child: _buildCard(card),
          ),
        );
      }),
    );
  }

  Widget _buildCard(WebContentItem item) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF111111)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 280,
                width: double.infinity,
                child: _FeaturedImage(url: item.imageUrl),
              ),
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: const Color(0xFFC6A76A),
                  child: Text(
                    item.isFeatured ? 'DESTACADO' : item.sectionLabel.toUpperCase(),
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
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.subtitle.isNotEmpty)
                  Text(
                    item.subtitle.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFFC6A76A),
                      letterSpacing: 2.5,
                    ),
                  ),
                if (item.subtitle.isNotEmpty) const SizedBox(height: 10),
                Text(
                  item.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    color: const Color(0xFFE8DCC8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.shortDescription.isNotEmpty
                      ? item.shortDescription
                      : item.longDescription,
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
                        if (item.promoPriceLabel.isNotEmpty)
                          Text(
                            item.promoPriceLabel,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: const Color(0xFFC6A76A),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else if (item.priceLabel.isNotEmpty)
                          Text(
                            item.priceLabel,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: const Color(0xFFC6A76A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (item.priceLabel.isNotEmpty &&
                            item.promoPriceLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.priceLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white38,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.ctaText.trim().isNotEmpty && item.ctaUrl.trim().isNotEmpty)
                      _HoverButton(
                        label: item.ctaText.toUpperCase(),
                        onTap: () => _openCta(item.ctaUrl),
                      )
                    else
                      const _HoverButton(label: 'RESERVAR'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoStrip(WebContentItem promo, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 28 : 40,
        horizontal: isMobile ? 24 : 60,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC6A76A).withValues(alpha: 0.2)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _promoText(promo),
                const SizedBox(height: 24),
                _promoButton(promo),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _promoText(promo)),
                const SizedBox(width: 24),
                _promoButton(promo),
              ],
            ),
    );
  }

  Widget _promoText(WebContentItem promo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          promo.title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 32,
            color: const Color(0xFFE8DCC8),
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          promo.shortDescription.isNotEmpty
              ? promo.shortDescription
              : promo.longDescription,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: Colors.white54,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _promoButton(WebContentItem promo) {
    return _HoverButton(
      label: promo.ctaText.trim().isNotEmpty
          ? promo.ctaText.toUpperCase()
          : 'AGENDA TU CONSULTA',
      large: true,
      onTap: promo.ctaUrl.trim().isNotEmpty
          ? () => _openCta(promo.ctaUrl)
          : null,
    );
  }
}

class _FeaturedContentState {
  const _FeaturedContentState({
    required this.cards,
    this.promo,
  });

  final List<WebContentItem> cards;
  final WebContentItem? promo;
}

class _FeaturedImage extends StatelessWidget {
  const _FeaturedImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(color: const Color(0xFF1A1A1A)),
      );
    }
    if (url.trim().isNotEmpty) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(color: const Color(0xFF1A1A1A)),
      );
    }
    return Container(color: const Color(0xFF1A1A1A));
  }
}

class _HoverButton extends StatefulWidget {
  const _HoverButton({
    required this.label,
    this.large = false,
    this.onTap,
  });

  final String label;
  final bool large;
  final VoidCallback? onTap;

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: widget.large ? 22 : 16,
            vertical: widget.large ? 14 : 12,
          ),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFE1C88C) : const Color(0xFFC6A76A),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: const Color(0xFF1F170F),
            ),
          ),
        ),
      ),
    );
  }
}
