import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/services_data.dart';
import '../features/web_content/web_content_models.dart';
import '../features/web_content/web_content_repository.dart';

class ServicesSection extends StatefulWidget {
  const ServicesSection({super.key});

  @override
  State<ServicesSection> createState() => _ServicesSectionState();
}

class _ServicesSectionState extends State<ServicesSection> {
  final WebContentRepository _repository = WebContentRepository();
  late final Future<List<_ServiceCategoryView>> _future = _loadCategories();

  Future<List<_ServiceCategoryView>> _loadCategories() async {
    try {
      final items = await _repository.loadContent(activeOnly: true);
      final allowedSections = <String>{
        'facials',
        'massages',
        'memberships',
        'digital_products',
        'physical_products',
        'gift_cards',
      };
      final filtered = items.where((item) => allowedSections.contains(item.sectionKey)).toList();
      if (filtered.isNotEmpty) {
        return WebContentItem.sections
            .where((section) => allowedSections.contains(section.key))
            .map((section) {
              final entries = filtered
                  .where((item) => item.sectionKey == section.key)
                  .toList()
                ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
              return _ServiceCategoryView(
                title: section.label,
                subtitle: section.description,
                items: entries,
              );
            })
            .where((category) => category.items.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    return servicesData.map((category) {
      return _ServiceCategoryView(
        title: category.title,
        subtitle: category.subtitle,
        items: category.services.map((service) {
          return WebContentItem.empty(
            sectionKey: category.title.toLowerCase(),
            contentType: category.title.toLowerCase().contains('facial')
                ? 'facial'
                : 'massage',
          ).copyWith(
            title: service.name,
            shortDescription: service.description,
            longDescription: service.details,
          );
        }).toList(),
      );
    }).toList();
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
    return FutureBuilder<List<_ServiceCategoryView>>(
      future: _future,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <_ServiceCategoryView>[];
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            return Container(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 64 : 120,
                horizontal: isMobile ? 24 : 80,
              ),
              color: const Color(0xFF0B0B0B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rituales & Experiencias',
                    style: TextStyle(
                      fontSize: isMobile ? 36 : 48,
                      color: const Color(0xFFE8DCC8),
                      fontFamily: 'Playfair',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Selecciona una categoria para explorar nuestros servicios, productos y experiencias disponibles en la web.',
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 18,
                      color: Colors.white70,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 60),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      categories.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return _buildCategoryTile(category, isMobile);
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryTile(_ServiceCategoryView category, bool isMobile) {
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
            style: TextStyle(
              fontSize: isMobile ? 18 : 24,
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
                  ...category.items.map((service) => _buildServiceItem(service, isMobile)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(WebContentItem item, bool isMobile) {
    final content = Container(
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: isMobile
          ? _buildServiceItemMobile(item)
          : _buildServiceItemDesktop(item),
    );
    return content;
  }

  Widget _buildServiceItemDesktop(WebContentItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildServiceInfo(item),
        ),
        const SizedBox(width: 40),
        Expanded(
          flex: 1,
          child: _buildServiceDetails(item),
        ),
      ],
    );
  }

  Widget _buildServiceItemMobile(WebContentItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildServiceInfo(item),
        const SizedBox(height: 24),
        Container(height: 0.5, color: Colors.white12),
        const SizedBox(height: 20),
        _buildServiceDetails(item),
      ],
    );
  }

  Widget _buildServiceInfo(WebContentItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.subtitle.trim().isNotEmpty)
          Text(
            item.subtitle.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFFC6A76A),
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (item.subtitle.trim().isNotEmpty) const SizedBox(height: 8),
        Text(
          item.title,
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontFamily: 'Playfair',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          item.shortDescription.isNotEmpty
              ? item.shortDescription
              : item.longDescription,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
            height: 1.6,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceDetails(WebContentItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DETALLES',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFFC6A76A),
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (item.longDescription.isNotEmpty)
          Text(
            item.longDescription,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        if (item.priceLabel.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            item.promoPriceLabel.isNotEmpty
                ? '${item.promoPriceLabel} · antes ${item.priceLabel}'
                : item.priceLabel,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFFE8DCC8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (item.ctaText.trim().isNotEmpty && item.ctaUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => _openCta(item.ctaUrl),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC6A76A),
              side: const BorderSide(color: Color(0xFFC6A76A)),
            ),
            child: Text(item.ctaText),
          ),
        ],
      ],
    );
  }
}

class _ServiceCategoryView {
  const _ServiceCategoryView({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<WebContentItem> items;
}
