import 'package:flutter/material.dart';
import '../widgets/navbar.dart';
import '../widgets/hero_section.dart';
import '../widgets/animated_section.dart';
import '../widgets/services_section.dart';
import '../widgets/experience_section.dart';
import '../widgets/featured_section.dart';
import '../widgets/contact_section.dart';
import '../widgets/footer.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  final GlobalKey _heroKey       = GlobalKey();
  final GlobalKey _servicesKey   = GlobalKey();
  final GlobalKey _experienceKey = GlobalKey();
  final GlobalKey _newsKey       = GlobalKey();
  final GlobalKey _contactKey    = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final scrolled = _scrollController.offset > 80;
      if (scrolled != _isScrolled) setState(() => _isScrolled = scrolled);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero ─────────────────────────────────────────────────────
                HeroSection(key: _heroKey),

                // ── Servicios ─────────────────────────────────────────────────
                AnimatedSection(
                  delay: 0,
                  child: Container(
                    key: _servicesKey,
                    child: const ServicesSection(),
                  ),
                ),

                // ── Experiencia ───────────────────────────────────────────────
                AnimatedSection(
                  delay: 100,
                  child: Container(
                    key: _experienceKey,
                    child: const ExperienceSection(),
                  ),
                ),

                // ── Rituales Destacados (Noticias) ────────────────────────────
                AnimatedSection(
                  delay: 200,
                  child: Container(
                    key: _newsKey,
                    child: const FeaturedSection(),
                  ),
                ),

                // ── Contacto ──────────────────────────────────────────────────
                AnimatedSection(
                  delay: 300,
                  child: Container(
                    key: _contactKey,
                    child: const ContactSection(),
                  ),
                ),

                const Footer(),
              ],
            ),
          ),

          // ── Navbar flotante ───────────────────────────────────────────────
          Navbar(
            isScrolled: _isScrolled,
            onTap: (index) {
              switch (index) {
                case 0: _scrollTo(_heroKey);
                case 1: _scrollTo(_servicesKey);
                case 2: _scrollTo(_experienceKey);
                case 3: _scrollTo(_newsKey);
                case 4: _scrollTo(_contactKey);
              }
            },
          ),
        ],
      ),
    );
  }
}
