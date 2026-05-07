import 'package:flutter/material.dart';
import '../data/services_data.dart';

class ServicesSection extends StatefulWidget {
  const ServicesSection({super.key});

  @override
  State<ServicesSection> createState() => _ServicesSectionState();
}

class _ServicesSectionState extends State<ServicesSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 80),
      color: const Color(0xFF0B0B0B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Rituales & Experiencias",
            style: TextStyle(
              fontSize: 48,
              color: Color(0xFFE8DCC8),
              fontFamily: 'Playfair',
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Selecciona una categoría para explorar nuestros servicios y descubrir tu próximo momento de calma.",
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 60),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: servicesData.length,
            itemBuilder: (context, index) {
              final category = servicesData[index];
              return _buildCategoryTile(category);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(ServiceCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          iconColor: const Color(0xFFC6A76A),
          collapsedIconColor: Colors.white54,
          tilePadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 0),
          title: Text(
            category.title.toUpperCase(),
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontFamily: 'Playfair',
              letterSpacing: 2,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.subtitle,
                    style: const TextStyle(
                      color: Color(0xFFE8DCC8),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ...category.services.map((service) => _buildServiceItem(service)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(SpaService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(0), // Luxury rects
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontFamily: 'Playfair',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  service.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.6,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DETALLES",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFC6A76A),
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  service.details,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
