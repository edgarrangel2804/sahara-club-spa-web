import 'package:flutter/material.dart';
import '../theme/sahara_theme.dart';
import '../widgets/wellness_sections.dart';
import '../widgets/floating_smoke.dart';

class WellnessPlatformPage extends StatefulWidget {
  const WellnessPlatformPage({super.key});

  @override
  State<WellnessPlatformPage> createState() => _WellnessPlatformPageState();
}

class _WellnessPlatformPageState extends State<WellnessPlatformPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaharaTheme.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: SaharaTheme.darkGradient,
        ),
        child: Stack(
          children: [
            // Floating smoke effects for atmosphere
            Positioned(
              top: 100,
              left: 50,
              child: const FloatingSmoke(),
            ),
            Positioned(
              top: 300,
              right: 80,
              child: const FloatingSmoke(),
            ),
            Positioned(
              bottom: 200,
              left: 100,
              child: const FloatingSmoke(),
            ),

            // Main content
            FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    expandedHeight: 120,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        'Sahara Club',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: SaharaTheme.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      centerTitle: true,
                    ),
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: SaharaTheme.beige),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.search, color: SaharaTheme.beige),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.person, color: SaharaTheme.beige),
                        onPressed: () {},
                      ),
                    ],
                  ),

                  // Content Sections
                  SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),

                      // Tonight's Ritual
                      const TonightsRitualSection(),

                      const SizedBox(height: 40),

                      // Meditations for the Soul
                      const MeditationsSection(),

                      const SizedBox(height: 40),

                      // Deep Relaxation Sounds
                      const RelaxationSoundsSection(),

                      const SizedBox(height: 40),

                      // Exclusive Sahara Sessions
                      const ExclusiveSessionsSection(),

                      const SizedBox(height: 40),

                      // Wellness Courses
                      const WellnessCoursesSection(),

                      const SizedBox(height: 40),

                      // Your Healing Journey
                      const HealingJourneySection(),

                      const SizedBox(height: 40),

                      // Continue Your Ritual
                      const ContinueRitualSection(),

                      const SizedBox(height: 40),

                      // Sahara Boutique - Luxury Shop
                      const SaharaBoutiqueSection(),

                      const SizedBox(height: 60),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}