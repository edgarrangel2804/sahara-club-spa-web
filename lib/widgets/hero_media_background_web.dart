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
        ..poster = kHeroPosterWebUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.border = 'none',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: 'hero-video-bg');
  }
}
