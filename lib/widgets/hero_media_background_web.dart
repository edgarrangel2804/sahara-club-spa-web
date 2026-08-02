import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

import '../config/web_media_paths.dart';

class HeroMediaBackground extends StatefulWidget {
  const HeroMediaBackground({super.key});

  @override
  State<HeroMediaBackground> createState() => _HeroMediaBackgroundState();
}

class _HeroMediaBackgroundState extends State<HeroMediaBackground> {
  static bool _videoViewRegistered = false;

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
        // Sin poster: el póster anterior (portada.png) era la imagen vieja del
        // hero y "se amontonaba" sobre el video nuevo al cargar. Dejamos un
        // fondo oscuro de marca mientras el video arranca.
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = '#0E0E0E'
        ..style.border = 'none',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: 'hero-video-bg');
  }
}
