import 'package:flutter/material.dart';
import '../../theme/sahara_theme.dart';

class MyRitualPage extends StatelessWidget {
  const MyRitualPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaharaTheme.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'MI RITUAL',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: SaharaTheme.beige,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: SaharaTheme.beige),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User progress & rewards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: SaharaTheme.burgundy.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SaharaTheme.gold.withOpacity(0.3)),
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
                      child: const Icon(Icons.self_improvement, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Has completado 7 rituales",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: SaharaTheme.beige,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tu energía esta semana mejoró ✨",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            _sectionTitle(context, "Continuar Ritual"),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  _DigitalItemCard(
                    title: "Meditación Guiada",
                    subtitle: "Quedan 10 min",
                    icon: Icons.headphones,
                    progress: 0.6,
                  ),
                  _DigitalItemCard(
                    title: "ASMR Spa",
                    subtitle: "Sonidos Profundos",
                    icon: Icons.waves,
                    progress: 0.2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _sectionTitle(context, "Descargas Offline"),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  _DigitalItemCard(
                    title: "Sonido del Desierto",
                    subtitle: "Audio 4K",
                    icon: Icons.download_done,
                    progress: 1.0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            _sectionTitle(context, "Favoritos & Playlists"),
            // List of favorites
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: 3,
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: SaharaTheme.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.play_arrow, color: SaharaTheme.gold),
                  ),
                  title: Text(
                    "Playlist Sahara ${index + 1}",
                    style: TextStyle(color: SaharaTheme.beige),
                  ),
                  subtitle: Text(
                    "Música Curada",
                    style: TextStyle(color: Colors.white54),
                  ),
                  trailing: Icon(Icons.favorite, color: SaharaTheme.gold, size: 20),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: SaharaTheme.beige,
              fontWeight: FontWeight.w400,
            ),
      ),
    );
  }
}

class _DigitalItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final double progress;

  const _DigitalItemCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: SaharaTheme.black,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Icon(icon, color: SaharaTheme.gold, size: 30),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: SaharaTheme.gold, fontSize: 11),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(SaharaTheme.gold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
