import 'package:flutter/material.dart';
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
class SaharaBoutiqueSection extends StatelessWidget {
  const SaharaBoutiqueSection({super.key});

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
                'Sahara Boutique',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: SaharaTheme.beige,
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.shopping_bag, color: SaharaTheme.gold, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 5,
            itemBuilder: (context, index) {
              final products = [
                {
                  'name': 'VIP Annual Membership',
                  'price': '\$999',
                  'description': 'Unlimited access to all premium content',
                  'icon': Icons.star,
                  'badge': 'BEST SELLER'
                },
                {
                  'name': 'Desert Rose Essential Oil',
                  'price': '\$89',
                  'description': 'Pure organic oil for meditation rituals',
                  'icon': Icons.spa,
                  'badge': 'POPULAR'
                },
                {
                  'name': 'Crystal Healing Set',
                  'price': '\$149',
                  'description': 'Complete set of healing crystals',
                  'icon': Icons.diamond,
                  'badge': 'LIMITED'
                },
                {
                  'name': 'Luxury Wellness Retreat',
                  'price': '\$2,499',
                  'description': '7-day exclusive desert experience',
                  'icon': Icons.hotel,
                  'badge': 'PREMIUM'
                },
                {
                  'name': 'Personal Meditation Guide',
                  'price': '\$299',
                  'description': '1-on-1 sessions with master teachers',
                  'icon': Icons.person,
                  'badge': 'EXCLUSIVE'
                },
              ];

              final product = products[index];

              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [SaharaTheme.burgundy.withOpacity(0.8), SaharaTheme.black],
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
                    // Product badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: SaharaTheme.gold.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product['badge'] as String,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SaharaTheme.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product icon
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SaharaTheme.goldGradient,
                            ),
                            child: Icon(
                              product['icon'] as IconData,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Product name
                          Text(
                            product['name'] as String,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: SaharaTheme.beige,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Product description
                          Text(
                            product['description'] as String,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),

                          const Spacer(),

                          // Price and buy button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                product['price'] as String,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: SaharaTheme.gold,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SaharaTheme.gold,
                                  foregroundColor: SaharaTheme.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text(
                                  'Add to Cart',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
          ),
        ),

        // Shopping cart summary
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [SaharaTheme.burgundy.withOpacity(0.3), SaharaTheme.black.withOpacity(0.5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: SaharaTheme.gold.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SaharaTheme.goldGradient,
                ),
                child: const Icon(
                  Icons.shopping_cart,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Luxury Cart',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: SaharaTheme.beige,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Exclusive wellness products await',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: SaharaTheme.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '0 items',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SaharaTheme.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}