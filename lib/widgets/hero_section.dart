import 'package:flutter/material.dart';
import 'dart:ui_web' as ui;
import 'dart:html' as html;
import '../config/web_media_paths.dart';
import '../pages/wellness_platform_page.dart';

class HeroSection extends StatefulWidget {
  const HeroSection({super.key});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  static bool _videoViewRegistered = false;
  bool _isHoverPrimary = false;
  bool _isHoverSecondary = false;

  @override
  void initState() {
    super.initState();
    if (_videoViewRegistered) return;
    _videoViewRegistered = true;

    ui.platformViewRegistry.registerViewFactory(
      'hero-video-bg',
      (int viewId) => html.VideoElement()
        ..src = kHeroVideoWebUrl
        ..autoplay = true
        ..muted = true
        ..loop = true
        ..preload = 'metadata'
        ..setAttribute('playsinline', 'true')
        ..poster = kHeroPosterWebUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.border = 'none',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 850,
      child: Stack(
        children: [
          // 🌅 Background Video (with fallback poster image)
          Positioned.fill(
            child: HtmlElementView(viewType: 'hero-video-bg'),
          ),

          // Fallback static image in case video fails or to prevent white flash
          // (Wait, HtmlElementView already has poster attribute)


          // 🌑 Premium Overlay (Comentado a petición del usuario para ver el video original)
          /*
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          */

          // 🧠 Contenido
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 100),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tu cuerpo.\nTu mente.\nTu momento.",
                  style: TextStyle(
                    fontSize: 84, // Manteniendo el tamaño premium
                    color: Colors.white,
                    fontFamily: 'Playfair',
                    fontWeight: FontWeight.w200, // Manteniendo la elegancia
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Bienvenido de vuelta a tu ritual.\nTu cuerpo recuerda cómo descansar.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 56),

                // 🔥 BOTONES
                Row(
                  children: [
                    _primaryButton(),
                    const SizedBox(width: 32),
                    _wellnessButton(context),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🟡 BOTÓN PRINCIPAL
  Widget _primaryButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHoverPrimary = true),
      onExit: (_) => setState(() => _isHoverPrimary = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        decoration: BoxDecoration(
          color: _isHoverPrimary ? const Color(0xFFE8DCC8) : const Color(0xFFC6A76A),
          borderRadius: BorderRadius.circular(0), // Bordes rectos para Luxury
        ),
        child: const Text(
          "RESERVA TU RITUAL",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ⚪ BOTÓN SECUNDARIO
  Widget _secondaryButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHoverSecondary = true),
      onExit: (_) => setState(() => _isHoverSecondary = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        decoration: BoxDecoration(
          color: _isHoverSecondary ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(color: Colors.white54),
          borderRadius: BorderRadius.circular(0), // Bordes rectos para Luxury
        ),
        child: const Text(
          "CONOCE MÁS",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ✨ BOTÓN WELLNESS
  Widget _wellnessButton(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WellnessPlatformPage()),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: const Color(0xFFC6A76A)),
            borderRadius: BorderRadius.circular(0),
          ),
          child: const Text(
            "IR A WELLNESS",
            style: TextStyle(
              color: Color(0xFFC6A76A),
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
