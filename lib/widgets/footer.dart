import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/web_content/web_content_models.dart';
import '../features/web_content/web_content_repository.dart';

class Footer extends StatefulWidget {
  const Footer({super.key});

  @override
  State<Footer> createState() => _FooterState();
}

class _FooterState extends State<Footer> {
  final WebContentRepository _repository = WebContentRepository();

  late Future<_FooterViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FooterViewData> _load() async {
    final results = await Future.wait([
      _repository.loadBusinessProfile(),
      _repository.loadContent(sectionKey: 'footer_brand', activeOnly: true),
      _repository.loadContent(sectionKey: 'footer_navigation', activeOnly: true),
      _repository.loadContent(sectionKey: 'footer_services', activeOnly: true),
      _repository.loadContent(sectionKey: 'footer_legal', activeOnly: true),
    ]);

    return _FooterViewData(
      profile: results[0] as WebBusinessProfile,
      brandItem: (results[1] as List<WebContentItem>).isNotEmpty
          ? (results[1] as List<WebContentItem>).first
          : null,
      navigationItems: results[2] as List<WebContentItem>,
      serviceItems: results[3] as List<WebContentItem>,
      legalItem: (results[4] as List<WebContentItem>).isNotEmpty
          ? (results[4] as List<WebContentItem>).first
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FooterViewData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _FooterViewData.fallback();
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            return Container(
              color: Colors.black,
              child: Column(
                children: [
                  _buildMain(data, isMobile),
                  _buildDivider(isMobile),
                  _buildBottom(data, isMobile),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMain(_FooterViewData data, bool isMobile) {
    final brandItem = data.brandItem;
    final navItems = data.navigationItems;
    final serviceItems = data.serviceItems;
    final profile = data.profile;

    final brandCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.name.isNotEmpty ? profile.name.toUpperCase() : 'SAHARA CLUB',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            color: const Color(0xFFC6A76A),
            letterSpacing: 4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          brandItem?.subtitle.isNotEmpty == true
              ? brandItem!.subtitle.toUpperCase()
              : 'SPA & BIENESTAR',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white24,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          brandItem?.shortDescription.isNotEmpty == true
              ? brandItem!.shortDescription
              : 'Este es tu momento.\nTu cuerpo recuerda\ncómo descansar.',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            color: Colors.white38,
            fontWeight: FontWeight.w300,
            height: 1.6,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            _SocialIcon(
              icon: Icons.camera_alt_outlined,
              label: 'Instagram',
              url: 'https://www.instagram.com/saharaclubmx/',
            ),
            const SizedBox(width: 16),
            _SocialIcon(
              icon: Icons.facebook_rounded,
              label: 'Facebook',
              url: 'https://www.facebook.com/SaharaClub/',
            ),
            const SizedBox(width: 16),
            _SocialIcon(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'WhatsApp',
              url: _whatsAppUrl(profile.whatsapp),
            ),
          ],
        ),
      ],
    );

    final navCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _footerHeading('NAVEGACIÓN'),
        const SizedBox(height: 24),
        ...(navItems.isEmpty
            ? _defaultNavigation()
            : navItems.map((item) => _footerLink(item.title, url: item.ctaUrl))),
      ],
    );

    final servicesCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _footerHeading('SERVICIOS'),
        const SizedBox(height: 24),
        ...(serviceItems.isEmpty
            ? _defaultServices()
            : serviceItems.map((item) => _footerLink(item.title, url: item.ctaUrl))),
      ],
    );

    final contactCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _footerHeading('CONTACTO'),
        const SizedBox(height: 24),
        _footerText(
          profile.address.isNotEmpty
              ? profile.address
              : 'Ensenada, Baja California',
        ),
        const SizedBox(height: 10),
        _footerText(
          profile.phone.isNotEmpty ? profile.phone : '+52 (646) 123-4567',
        ),
        const SizedBox(height: 10),
        _footerText(
          profile.email.isNotEmpty
              ? profile.email
              : 'hola@saharaclubspa.mx',
        ),
        const SizedBox(height: 24),
        ...data.scheduleLines.map(_footerText),
      ],
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            brandCol,
            const SizedBox(height: 48),
            Container(height: 0.5, color: Colors.white.withValues(alpha: 0.07)),
            const SizedBox(height: 40),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: navCol),
                const SizedBox(width: 32),
                Expanded(child: servicesCol),
              ],
            ),
            const SizedBox(height: 40),
            contactCol,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(100, 80, 100, 64),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: brandCol),
          const SizedBox(width: 60),
          Expanded(flex: 2, child: navCol),
          Expanded(flex: 2, child: servicesCol),
          Expanded(flex: 2, child: contactCol),
        ],
      ),
    );
  }

  Widget _footerHeading(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: const Color(0xFFC6A76A),
        letterSpacing: 3,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _footerLink(String text, {String? url}) {
    return _FooterLinkItem(text: text, url: url);
  }

  Widget _footerText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white38,
          fontWeight: FontWeight.w300,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 100),
      height: 0.5,
      color: Colors.white.withValues(alpha: 0.07),
    );
  }

  Widget _buildBottom(_FooterViewData data, bool isMobile) {
    final legalItem = data.legalItem;
    final copyright =
        legalItem?.shortDescription.isNotEmpty == true
            ? legalItem!.shortDescription
            : '© 2026 SAHARA CLUB SPA. TODOS LOS DERECHOS RESERVADOS.';
    final location =
        legalItem?.longDescription.isNotEmpty == true
            ? legalItem!.longDescription
            : 'ENSENADA, BAJA CALIFORNIA · MÉXICO';

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copyright.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.18),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              location.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.18),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 100),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            copyright.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.18),
              letterSpacing: 1,
            ),
          ),
          Text(
            location.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.18),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Iterable<Widget> _defaultNavigation() {
    return const [
      _FooterLinkItem(text: 'Inicio', url: '#home'),
      _FooterLinkItem(text: 'Servicios', url: '#services'),
      _FooterLinkItem(text: 'Experiencia', url: '#experience'),
      _FooterLinkItem(text: 'Noticias', url: '#news'),
      _FooterLinkItem(text: 'Contacto', url: '#contact'),
    ];
  }

  Iterable<Widget> _defaultServices() {
    return const [
      _FooterLinkItem(text: 'Masajes'),
      _FooterLinkItem(text: 'Metodología Sahara'),
      _FooterLinkItem(text: 'Faciales'),
      _FooterLinkItem(text: 'Moldeo Consciente'),
      _FooterLinkItem(text: 'Experiencias Fusionadas'),
    ];
  }

  String _whatsAppUrl(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'https://wa.me/526461234567';
    return 'https://wa.me/$digits';
  }
}

class _FooterViewData {
  const _FooterViewData({
    required this.profile,
    required this.brandItem,
    required this.navigationItems,
    required this.serviceItems,
    required this.legalItem,
  });

  final WebBusinessProfile profile;
  final WebContentItem? brandItem;
  final List<WebContentItem> navigationItems;
  final List<WebContentItem> serviceItems;
  final WebContentItem? legalItem;

  factory _FooterViewData.fallback() => _FooterViewData(
        profile: WebBusinessProfile.empty(),
        brandItem: null,
        navigationItems: const <WebContentItem>[],
        serviceItems: const <WebContentItem>[],
        legalItem: null,
      );

  List<String> get scheduleLines {
    if (legalItem?.category.isNotEmpty == true) {
      return legalItem!.category
          .split('|')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }
    return const <String>[
      'Lun–Vie: 9 am – 9 pm',
      'Sáb: 9 am – 8 pm',
      'Dom: 10 am – 6 pm',
    ];
  }
}

class _FooterLinkItem extends StatefulWidget {
  const _FooterLinkItem({
    required this.text,
    this.url,
  });

  final String text;
  final String? url;

  @override
  State<_FooterLinkItem> createState() => _FooterLinkItemState();
}

class _FooterLinkItemState extends State<_FooterLinkItem> {
  bool _hovered = false;

  Future<void> _open() async {
    final raw = widget.url?.trim() ?? '';
    if (raw.isEmpty) return;
    Uri? uri;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      uri = Uri.tryParse(raw);
    } else if (raw.startsWith('/')) {
      uri = Uri.base.resolve(raw);
    } else if (raw.startsWith('#')) {
      uri = Uri.base.resolve(Uri.base.path + raw);
    }
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.url?.isNotEmpty == true
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.url?.isNotEmpty == true ? _open : null,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _hovered ? const Color(0xFFC6A76A) : Colors.white38,
              fontWeight: FontWeight.w300,
            ),
            child: Text(widget.text),
          ),
        ),
      ),
    );
  }
}

class _SocialIcon extends StatefulWidget {
  const _SocialIcon({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  @override
  State<_SocialIcon> createState() => _SocialIconState();
}

class _SocialIconState extends State<_SocialIcon> {
  bool _hovered = false;

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _open,
        child: Tooltip(
          message: widget.label,
          textStyle: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.black,
            letterSpacing: 1,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFC6A76A),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0xFFC6A76A).withValues(alpha: 0.15)
                  : Colors.transparent,
              border: Border.all(
                color: _hovered
                    ? const Color(0xFFC6A76A)
                    : const Color(0xFFC6A76A).withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _hovered
                  ? const Color(0xFFC6A76A)
                  : const Color(0xFFC6A76A).withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
