import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/sahara_theme.dart';

// Tonight's Ritual Section
class TonightsRitualSection extends StatelessWidget {
  const TonightsRitualSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1810), Color(0xFF1A0F0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: SaharaTheme.gold.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background cinematic effect
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: AssetImage('assets/images/desert_night.jpg'), // Placeholder
                  fit: BoxFit.cover,
                  opacity: 0.3,
                ),
              ),
            ),
          ),

          // Content overlay
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "Tonight's Ritual",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: SaharaTheme.gold,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Desert Moon Meditation',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: SaharaTheme.beige,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A 45-minute immersive journey through ancient Saharan wisdom and deep relaxation.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SaharaTheme.gold,
                    foregroundColor: SaharaTheme.black,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text('Begin Ritual'),
                ),
              ],
            ),
          ),

          // Floating elements for cinematic effect
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SaharaTheme.gold.withOpacity(0.2),
              ),
              child: Icon(
                Icons.play_arrow,
                color: SaharaTheme.gold,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Meditations for the Soul Section
class MeditationsSection extends StatelessWidget {
  const MeditationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Meditations for the Soul',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: SaharaTheme.beige,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [SaharaTheme.burgundy.withOpacity(0.8), SaharaTheme.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SaharaTheme.gold.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        color: SaharaTheme.gold.withOpacity(0.1),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.self_improvement,
                          color: SaharaTheme.gold,
                          size: 40,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inner Peace',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: SaharaTheme.beige,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '15 min',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Deep Relaxation Sounds Section
class RelaxationSoundsSection extends StatelessWidget {
  const RelaxationSoundsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Deep Relaxation Sounds',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: SaharaTheme.beige,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: SaharaTheme.black.withOpacity(0.5),
                  border: Border.all(
                    color: SaharaTheme.gold.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SaharaTheme.goldGradient,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ocean Waves',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: SaharaTheme.beige,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2h 30m',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Exclusive Sahara Sessions Section
class ExclusiveSessionsSection extends StatelessWidget {
  const ExclusiveSessionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Exclusive Sahara Sessions',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: SaharaTheme.beige,
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.lock, color: SaharaTheme.gold, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [SaharaTheme.burgundy, SaharaTheme.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SaharaTheme.gold.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: SaharaTheme.gold.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: SaharaTheme.gold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'VIP',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: SaharaTheme.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Sacred Geometry Healing',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: SaharaTheme.beige,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Unlock with membership',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Icon(
                        Icons.lock,
                        color: SaharaTheme.gold,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Wellness Courses Section
class WellnessCoursesSection extends StatelessWidget {
  const WellnessCoursesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Wellness Courses',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: SaharaTheme.beige,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: SaharaTheme.black.withOpacity(0.3),
                  border: Border.all(
                    color: SaharaTheme.gold.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                        gradient: SaharaTheme.goldGradient,
                      ),
                      child: Icon(
                        Icons.school,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Mindful Living',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: SaharaTheme.beige,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '8 sessions • 2h each',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              height: 4,
                              decoration: BoxDecoration(
                                color: SaharaTheme.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: 0.6,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: SaharaTheme.gold,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Your Healing Journey Section
class HealingJourneySection extends StatelessWidget {
  const HealingJourneySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Your Healing Journey',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: SaharaTheme.beige,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [SaharaTheme.burgundy.withOpacity(0.6), SaharaTheme.black],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: SaharaTheme.gold.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SaharaTheme.goldGradient,
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Personalized for You',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: SaharaTheme.beige,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on your recent sessions and preferences',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: SaharaTheme.gold,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Continue Your Ritual Section
class ContinueRitualSection extends StatelessWidget {
  const ContinueRitualSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Continue Your Ritual',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: SaharaTheme.beige,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: SaharaTheme.black.withOpacity(0.4),
                  border: Border.all(
                    color: SaharaTheme.gold.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        color: SaharaTheme.gold.withOpacity(0.1),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_fill,
                            color: SaharaTheme.gold,
                            size: 40,
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: SaharaTheme.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: 0.7,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: SaharaTheme.gold,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Evening Calm',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SaharaTheme.beige,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Sahara Boutique Section - Luxury Wellness Shop
class SaharaBoutiqueSection extends StatefulWidget {
  const SaharaBoutiqueSection({super.key});

  @override
  State<SaharaBoutiqueSection> createState() => _SaharaBoutiqueSectionState();
}

class _SaharaBoutiqueSectionState extends State<SaharaBoutiqueSection> {
  static const List<_SensoryFilter> _sensoryFilters = [
    _SensoryFilter(
      id: 'all',
      label: 'Todo el ritual',
      blurb: 'La boutique completa en una sola atmósfera.',
    ),
    _SensoryFilter(
      id: 'relaxation',
      label: 'Calma profunda',
      blurb: 'Para bajar el pulso y suavizar el día.',
    ),
    _SensoryFilter(
      id: 'energy',
      label: 'Despertar',
      blurb: 'Texturas, aromas y rituales que activan.',
    ),
    _SensoryFilter(
      id: 'balance',
      label: 'Equilibrio',
      blurb: 'Una curaduría para volver al centro.',
    ),
    _SensoryFilter(
      id: 'skin',
      label: 'Piel en ritual',
      blurb: 'Experiencias corporales y faciales con presencia.',
    ),
    _SensoryFilter(
      id: 'home',
      label: 'Casa Sahara',
      blurb: 'Piezas para llevar la experiencia a casa.',
    ),
  ];

  static const List<_WellnessQuestion> _questions = [
    _WellnessQuestion(
      prompt: '¿Cómo quieres sentirte al terminar tu ritual?',
      options: [
        _WellnessAnswer(label: 'Profundamente relajada', mood: 'relaxation'),
        _WellnessAnswer(label: 'Con energía renovada', mood: 'energy'),
        _WellnessAnswer(label: 'Centrada y en equilibrio', mood: 'balance'),
      ],
    ),
    _WellnessQuestion(
      prompt: '¿Qué tipo de experiencia te llama hoy?',
      options: [
        _WellnessAnswer(label: 'Aromas suaves y descanso', mood: 'relaxation'),
        _WellnessAnswer(label: 'Activación y movimiento', mood: 'energy'),
        _WellnessAnswer(label: 'Armonía y contención', mood: 'balance'),
      ],
    ),
    _WellnessQuestion(
      prompt: '¿Dónde quieres sentir el mayor cambio?',
      options: [
        _WellnessAnswer(label: 'Sistema nervioso', mood: 'relaxation'),
        _WellnessAnswer(label: 'Ánimo y enfoque', mood: 'energy'),
        _WellnessAnswer(label: 'Cuerpo y emoción', mood: 'balance'),
      ],
    ),
  ];

  final Map<int, String> _answers = {};
  final Set<String> _ritualBag = <String>{};
  final ScrollController _filterScroll = ScrollController();

  List<_WellnessProduct> _products = [];
  bool _loading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _filterScroll.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('products')
          .select(
            'id, name, description, price, category, type, image, active, '
            'wellness_moods, wellness_benefits, ritual_badge',
          )
          .eq('active', true)
          .order('display_order', ascending: true)
          .order('created_at', ascending: false);

      final parsed = (data as List)
          .map((row) => _WellnessProduct.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      if (!mounted) return;
      setState(() {
        _products = parsed;
        _loading = false;
      });
    } catch (_) {
      try {
        final fallbackData = await Supabase.instance.client
            .from('products')
            .select('id, name, description, price, category, type, image, active')
            .eq('active', true)
            .order('display_order', ascending: true)
            .order('created_at', ascending: false);
        final parsed = (fallbackData as List)
            .map((row) => _WellnessProduct.fromMap(Map<String, dynamic>.from(row)))
            .toList();
        if (!mounted) return;
        setState(() {
          _products = parsed;
          _loading = false;
        });
      } catch (e) {
        debugPrint('Wellness boutique load error: $e');
        if (!mounted) return;
        setState(() => _loading = false);
      }
    }
  }

  Map<String, int> get _moodScores {
    final scores = <String, int>{
      'relaxation': 0,
      'energy': 0,
      'balance': 0,
    };
    for (final mood in _answers.values) {
      scores[mood] = (scores[mood] ?? 0) + 1;
    }
    return scores;
  }

  String? get _dominantMood {
    if (_answers.length < _questions.length) return null;
    final scores = _moodScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scores.first.key;
  }

  List<_WellnessProduct> get _recommendedProducts {
    final mood = _dominantMood;
    if (mood == null) return const [];
    final matches = _products.where((product) => product.moods.contains(mood)).toList();
    matches.sort((a, b) => b.boutiqueScore.compareTo(a.boutiqueScore));
    return matches.take(4).toList();
  }

  List<_WellnessProduct> get _filteredProducts {
    Iterable<_WellnessProduct> list = _products;
    if (_selectedFilter != 'all') {
      list = list.where((product) => product.sensations.contains(_selectedFilter));
    }
    final mood = _dominantMood;
    if (mood != null) {
      final preferred = list.where((product) => product.moods.contains(mood)).toList();
      final others = list.where((product) => !product.moods.contains(mood)).toList();
      preferred.sort((a, b) => b.boutiqueScore.compareTo(a.boutiqueScore));
      others.sort((a, b) => b.boutiqueScore.compareTo(a.boutiqueScore));
      return [...preferred, ...others];
    }
    final sorted = list.toList()
      ..sort((a, b) => b.boutiqueScore.compareTo(a.boutiqueScore));
    return sorted;
  }

  void _toggleRitual(_WellnessProduct product) {
    setState(() {
      if (_ritualBag.contains(product.id)) {
        _ritualBag.remove(product.id);
      } else {
        _ritualBag.add(product.id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _ritualBag.contains(product.id)
              ? '${product.name} se agregó a tu ritual'
              : '${product.name} se retiró de tu ritual',
        ),
        backgroundColor: SaharaTheme.gold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommended = _recommendedProducts;
    final products = _filteredProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF23130E),
                  SaharaTheme.burgundy.withValues(alpha: 0.88),
                  const Color(0xFF100B09),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: SaharaTheme.gold.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: SaharaTheme.gold.withValues(alpha: 0.08),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 940;
                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BoutiqueIntro(
                            ritualCount: _ritualBag.length,
                            dominantMood: _dominantMood,
                          ),
                          const SizedBox(height: 22),
                          _WellnessQuizCard(
                            questions: _questions,
                            answers: _answers,
                            onSelect: (index, mood) {
                              setState(() => _answers[index] = mood);
                            },
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _BoutiqueIntro(
                              ritualCount: _ritualBag.length,
                              dominantMood: _dominantMood,
                            ),
                          ),
                          const SizedBox(width: 22),
                          SizedBox(
                            width: 380,
                            child: _WellnessQuizCard(
                              questions: _questions,
                              answers: _answers,
                              onSelect: (index, mood) {
                                setState(() => _answers[index] = mood);
                              },
                            ),
                          ),
                        ],
                      );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 54,
          child: ListView.separated(
            controller: _filterScroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _sensoryFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final filter = _sensoryFilters[index];
              final selected = _selectedFilter == filter.id;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => _selectedFilter = filter.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: selected
                        ? SaharaTheme.gold.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: selected
                          ? SaharaTheme.gold.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        filter.label,
                        style: GoogleFonts.inter(
                          color: selected ? SaharaTheme.beige : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        filter.blurb,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.56),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        if (recommended.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _RecommendationsStrip(
              mood: _dominantMood!,
              products: recommended,
              onAdd: _toggleRitual,
              ritualBag: _ritualBag,
            ),
          ),
        if (recommended.isNotEmpty) const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: SaharaTheme.gold),
                  ),
                )
              : products.isEmpty
                  ? _EmptyBoutiqueState(onReset: () {
                      setState(() {
                        _selectedFilter = 'all';
                        _answers.clear();
                      });
                    })
                  : _WellnessMasonry(
                      products: products,
                      ritualBag: _ritualBag,
                      onAdd: _toggleRitual,
                    ),
          ),
      ],
    );
  }
}

class _BoutiqueIntro extends StatelessWidget {
  const _BoutiqueIntro({
    required this.ritualCount,
    required this.dominantMood,
  });

  final int ritualCount;
  final String? dominantMood;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sahara Boutique Wellness',
          style: GoogleFonts.playfairDisplay(
            color: SaharaTheme.beige,
            fontSize: 34,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Una selección editorial para llevar la experiencia Sahara más allá de la cabina. Sensaciones, texturas y rituales curados para tu estado de ánimo.',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.74),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoPill(
              icon: Icons.auto_awesome,
              label: dominantMood == null
                  ? 'Personalización en espera'
                  : 'Ánimo detectado: ${_moodLabel(dominantMood!)}',
            ),
            _InfoPill(
              icon: Icons.shopping_bag_outlined,
              label: ritualCount == 0
                  ? 'Tu ritual aún está vacío'
                  : '$ritualCount piezas dentro de tu ritual',
            ),
          ],
        ),
      ],
    );
  }
}

class _WellnessQuizCard extends StatelessWidget {
  const _WellnessQuizCard({
    required this.questions,
    required this.answers,
    required this.onSelect,
  });

  final List<_WellnessQuestion> questions;
  final Map<int, String> answers;
  final void Function(int index, String mood) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cuestionario de Bienestar',
            style: GoogleFonts.playfairDisplay(
              color: SaharaTheme.beige,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tres respuestas bastan para curar una recomendación más íntima.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          ...List.generate(questions.length, (index) {
            final question = questions[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index == questions.length - 1 ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${question.prompt}',
                    style: GoogleFonts.inter(
                      color: SaharaTheme.beige,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: question.options.map((option) {
                      final selected = answers[index] == option.mood;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => onSelect(index, option.mood),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: selected
                                ? SaharaTheme.gold.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.03),
                            border: Border.all(
                              color: selected
                                  ? SaharaTheme.gold.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            option.label,
                            style: GoogleFonts.inter(
                              color: selected ? SaharaTheme.beige : Colors.white70,
                              fontSize: 12.5,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RecommendationsStrip extends StatelessWidget {
  const _RecommendationsStrip({
    required this.mood,
    required this.products,
    required this.onAdd,
    required this.ritualBag,
  });

  final String mood;
  final List<_WellnessProduct> products;
  final Set<String> ritualBag;
  final void Function(_WellnessProduct product) onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            SaharaTheme.gold.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: SaharaTheme.gold.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rituales sugeridos para ${_moodLabel(mood)}',
            style: GoogleFonts.playfairDisplay(
              color: SaharaTheme.beige,
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Seleccionamos estas piezas porque dialogan mejor con la sensación que estás buscando hoy.',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, index) {
                final product = products[index];
                final added = ritualBag.contains(product.id);
                return Container(
                  width: 260,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.black.withValues(alpha: 0.26),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MoodBadge(label: _moodLabel(mood)),
                      const SizedBox(height: 14),
                      Text(
                        product.name,
                        style: GoogleFonts.playfairDisplay(
                          color: SaharaTheme.beige,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            product.priceLabel,
                            style: GoogleFonts.inter(
                              color: SaharaTheme.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => onAdd(product),
                            child: Text(
                              added ? 'En tu ritual' : 'Añadir al Ritual',
                              style: GoogleFonts.inter(
                                color: added ? SaharaTheme.gold : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WellnessMasonry extends StatelessWidget {
  const _WellnessMasonry({
    required this.products,
    required this.ritualBag,
    required this.onAdd,
  });

  final List<_WellnessProduct> products;
  final Set<String> ritualBag;
  final void Function(_WellnessProduct product) onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columnCount = width >= 1200 ? 3 : width >= 760 ? 2 : 1;
        final columns = List.generate(columnCount, (_) => <_WellnessProduct>[]);
        final heights = List<double>.filled(columnCount, 0);

        for (final product in products) {
          var target = 0;
          for (var i = 1; i < columnCount; i++) {
            if (heights[i] < heights[target]) target = i;
          }
          columns[target].add(product);
          heights[target] += product.estimatedCardHeight;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(columnCount, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 8,
                  right: index == columnCount - 1 ? 0 : 8,
                ),
                child: Column(
                  children: columns[index].map((product) {
                    final card = _WellnessProductCard(
                      product: product,
                      added: ritualBag.contains(product.id),
                      onAdd: () => onAdd(product),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: card,
                    );
                  }).toList(),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _WellnessProductCard extends StatelessWidget {
  const _WellnessProductCard({
    required this.product,
    required this.added,
    required this.onAdd,
  });

  final _WellnessProduct product;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + product.animationSeed),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: [
              product.accent.withValues(alpha: 0.28),
              const Color(0xFF130E0D),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: product.accent.withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MoodBadge(label: product.badge),
                      ...product.moods.take(2).map(
                        (mood) => _GhostBadge(label: _moodLabel(mood)),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: product.accent.withValues(alpha: 0.16),
                    border: Border.all(color: product.accent.withValues(alpha: 0.4)),
                  ),
                  child: Icon(product.icon, color: product.accent, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              product.name,
              style: GoogleFonts.playfairDisplay(
                color: SaharaTheme.beige,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.description,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: product.benefits
                  .map((benefit) => _BenefitChip(label: benefit))
                  .toList(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  product.priceLabel,
                  style: GoogleFonts.inter(
                    color: SaharaTheme.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: added
                        ? SaharaTheme.gold
                        : Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: added
                          ? SaharaTheme.gold
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: TextButton.icon(
                    onPressed: onAdd,
                    icon: Icon(
                      added ? Icons.check_rounded : Icons.add_rounded,
                      size: 16,
                      color: added ? SaharaTheme.black : SaharaTheme.beige,
                    ),
                    label: Text(
                      added ? 'Añadido' : 'Añadir al Ritual',
                      style: GoogleFonts.inter(
                        color: added ? SaharaTheme.black : SaharaTheme.beige,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoutiqueState extends StatelessWidget {
  const _EmptyBoutiqueState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.spa_outlined, color: SaharaTheme.gold, size: 36),
          const SizedBox(height: 14),
          Text(
            'No encontramos una combinación para este filtro',
            style: GoogleFonts.playfairDisplay(
              color: SaharaTheme.beige,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Restablece el filtro o responde el cuestionario con otra intención para abrir nuevas recomendaciones.',
            style: GoogleFonts.inter(color: Colors.white70, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onReset,
            child: Text(
              'Volver a explorar',
              style: GoogleFonts.inter(
                color: SaharaTheme.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SaharaTheme.gold),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodBadge extends StatelessWidget {
  const _MoodBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SaharaTheme.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: SaharaTheme.gold,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _GhostBadge extends StatelessWidget {
  const _GhostBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white70,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SensoryFilter {
  const _SensoryFilter({
    required this.id,
    required this.label,
    required this.blurb,
  });

  final String id;
  final String label;
  final String blurb;
}

class _WellnessQuestion {
  const _WellnessQuestion({
    required this.prompt,
    required this.options,
  });

  final String prompt;
  final List<_WellnessAnswer> options;
}

class _WellnessAnswer {
  const _WellnessAnswer({
    required this.label,
    required this.mood,
  });

  final String label;
  final String mood;
}

class _WellnessProduct {
  _WellnessProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.type,
    required this.image,
    required this.moods,
    required this.benefits,
    required this.badge,
  }) : sensations = _inferSensations(
          category: category,
          type: type,
          moods: moods,
          benefits: benefits,
          name: name,
          description: description,
        );

  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String type;
  final String? image;
  final List<String> moods;
  final List<String> benefits;
  final String badge;
  final Set<String> sensations;

  factory _WellnessProduct.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] as String? ?? '').trim();
    final description = (map['description'] as String? ?? '').trim();
    final category = (map['category'] as String? ?? 'general').trim().toLowerCase();
    final type = (map['type'] as String? ?? '').trim().toLowerCase();
    final moods = _readStringList(map['wellness_moods']);
    final benefits = _readStringList(map['wellness_benefits']);
    return _WellnessProduct(
      id: map['id'] as String,
      name: name.isEmpty ? 'Ritual Sahara' : name,
      description: description.isEmpty
          ? 'Una pieza curada para acompañar tu bienestar.'
          : description,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      category: category,
      type: type,
      image: map['image'] as String?,
      moods: moods.isEmpty ? _inferMoods(name, description, category, type) : moods,
      benefits: benefits.isEmpty
          ? _inferBenefits(name, description, category, type)
          : benefits,
      badge: ((map['ritual_badge'] as String?)?.trim().isNotEmpty ?? false)
          ? (map['ritual_badge'] as String).trim()
          : _inferBadge(name, category, type),
    );
  }

  String get priceLabel => '\$${price.toStringAsFixed(0)}';

  int get animationSeed => name.length * 17 % 180;

  double get estimatedCardHeight {
    final descriptionFactor = (description.length / 70).clamp(1, 3);
    return 240 + (benefits.length * 20) + (descriptionFactor * 44);
  }

  int get boutiqueScore => (benefits.length * 2) + moods.length + (price ~/ 100).toInt();

  Color get accent {
    if (moods.contains('energy')) return const Color(0xFFD18C39);
    if (moods.contains('balance')) return const Color(0xFF7DA38B);
    return const Color(0xFFB88A72);
  }

  IconData get icon {
    if (type.contains('membership')) return Icons.workspace_premium_rounded;
    if (category == 'vela') return Icons.local_fire_department_outlined;
    if (category == 'aceite') return Icons.water_drop_outlined;
    if (category == 'crema') return Icons.spa_outlined;
    if (category == 'suplemento') return Icons.bubble_chart_outlined;
    if (moods.contains('energy')) return Icons.wb_sunny_outlined;
    if (moods.contains('balance')) return Icons.self_improvement_outlined;
    return Icons.nightlight_round;
  }
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value
        .whereType<String>()
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
  return const [];
}

List<String> _inferMoods(
  String name,
  String description,
  String category,
  String type,
) {
  final haystack = '$name $description $category $type'.toLowerCase();
  final moods = <String>{};
  if (haystack.contains('relaj') ||
      haystack.contains('calma') ||
      haystack.contains('descans') ||
      haystack.contains('soul') ||
      haystack.contains('noche')) {
    moods.add('relaxation');
  }
  if (haystack.contains('energ') ||
      haystack.contains('vital') ||
      haystack.contains('amazing') ||
      haystack.contains('transform') ||
      haystack.contains('sol')) {
    moods.add('energy');
  }
  if (haystack.contains('balance') ||
      haystack.contains('equilib') ||
      haystack.contains('corazón') ||
      haystack.contains('corazon') ||
      haystack.contains('magia')) {
    moods.add('balance');
  }
  if (moods.isEmpty) moods.addAll(['relaxation', 'balance']);
  return moods.toList();
}

List<String> _inferBenefits(
  String name,
  String description,
  String category,
  String type,
) {
  final haystack = '$name $description $category $type'.toLowerCase();
  final benefits = <String>{
    if (category == 'aceite') 'Aromaterapia',
    if (category == 'vela') 'Hecho a mano',
    if (category == 'crema') 'Textura nutritiva',
    if (category == 'suplemento') 'Bienestar diario',
    if (haystack.contains('organic') || haystack.contains('orgán') || haystack.contains('organ')) 'Orgánico',
    if (haystack.contains('facial') || haystack.contains('piel')) 'Cuidado de la piel',
    if (haystack.contains('ritual')) 'Ritual guiado',
  };
  if (benefits.isEmpty) {
    benefits.addAll(['Curado por Sahara', 'Edición boutique']);
  }
  return benefits.take(3).toList();
}

String _inferBadge(String name, String category, String type) {
  final haystack = '$name $category $type'.toLowerCase();
  if (haystack.contains('vip') || haystack.contains('premium')) return 'Selección privada';
  if (haystack.contains('new') || haystack.contains('nuevo')) return 'Nuevo ritual';
  if (haystack.contains('soul') || haystack.contains('facial')) return 'Favorito del spa';
  if (category == 'vela' || category == 'aceite') return 'Casa Sahara';
  return 'Curaduría Sahara';
}

Set<String> _inferSensations({
  required String category,
  required String type,
  required List<String> moods,
  required List<String> benefits,
  required String name,
  required String description,
}) {
  final sensations = <String>{};
  final haystack = '$name $description $category $type ${benefits.join(' ')}'.toLowerCase();
  if (moods.contains('relaxation')) sensations.add('relaxation');
  if (moods.contains('energy')) sensations.add('energy');
  if (moods.contains('balance')) sensations.add('balance');
  if (haystack.contains('facial') || haystack.contains('piel') || category == 'crema') {
    sensations.add('skin');
  }
  if (category == 'vela' || category == 'aceite' || category == 'accesorio') {
    sensations.add('home');
  }
  if (sensations.isEmpty) sensations.add('all');
  return sensations;
}

String _moodLabel(String mood) {
  switch (mood) {
    case 'relaxation':
      return 'Relajación';
    case 'energy':
      return 'Energía';
    case 'balance':
      return 'Equilibrio';
    default:
      return 'Bienestar';
  }
}
