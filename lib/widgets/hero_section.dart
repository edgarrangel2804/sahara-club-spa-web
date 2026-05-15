import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/web_content/web_content_models.dart';
import '../features/web_content/web_content_repository.dart';
import 'hero_media_background.dart';

class HeroSection extends StatefulWidget {
  const HeroSection({super.key});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  final WebContentRepository _repository = WebContentRepository();
  bool _isHoverPrimary = false;
  late final Future<WebContentItem?> _heroFuture = _loadHero();

  Future<WebContentItem?> _loadHero() async {
    try {
      final items = await _repository.loadContent(
        sectionKey: 'hero',
        activeOnly: true,
      );
      if (items.isNotEmpty) return items.first;
    } catch (_) {}
    return null;
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
    return FutureBuilder<WebContentItem?>(
      future: _heroFuture,
      builder: (context, snapshot) {
        final hero = snapshot.data;
        final title = hero?.title.trim().isNotEmpty == true
            ? hero!.title
            : 'Tu cuerpo.\nTu mente.\nTu momento.';
        final subtitle = hero?.shortDescription.trim().isNotEmpty == true
            ? hero!.shortDescription
            : 'Bienvenido de vuelta a tu ritual.\nTu cuerpo recuerda como descansar.';
        final ctaText = hero?.ctaText.trim().isNotEmpty == true
            ? hero!.ctaText
            : 'RESERVA TU RITUAL';
        final imageUrl = hero?.imageUrl.trim() ?? '';

        return SizedBox(
          width: double.infinity,
          height: 850,
          child: Stack(
            children: [
              const Positioned.fill(
                child: HeroMediaBackground(),
              ),
              if (imageUrl.isNotEmpty)
                Positioned.fill(
                  child: _HeroOverlayImage(url: imageUrl),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.52),
                        Colors.black.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 100),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 84,
                        color: Colors.white,
                        fontFamily: 'Playfair',
                        fontWeight: FontWeight.w200,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 56),
                    Row(
                      children: [
                        _primaryButton(
                          label: ctaText,
                          onTap: hero?.ctaUrl.trim().isNotEmpty == true
                              ? () => _openCta(hero!.ctaUrl)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _primaryButton({
    required String label,
    VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHoverPrimary = true),
      onExit: (_) => setState(() => _isHoverPrimary = false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          decoration: BoxDecoration(
            color: _isHoverPrimary ? const Color(0xFFE8DCC8) : const Color(0xFFC6A76A),
            borderRadius: BorderRadius.circular(0),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroOverlayImage extends StatelessWidget {
  const _HeroOverlayImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
