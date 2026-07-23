import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/web_content/web_content_models.dart';
import '../features/web_content/web_content_repository.dart';
import '../services/whatsapp_link.dart';
import 'concierge_chat.dart';

class ContactSection extends StatefulWidget {
  const ContactSection({super.key});

  @override
  State<ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<ContactSection> {
  final WebContentRepository _repository = WebContentRepository();

  late Future<_ContactSectionViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ContactSectionViewData> _load() async {
    final results = await Future.wait([
      _repository.loadBusinessProfile(),
      _repository.loadContent(sectionKey: 'contact_info', activeOnly: true),
      _repository.loadContent(sectionKey: 'contact_hours', activeOnly: true),
    ]);

    final profile = results[0] as WebBusinessProfile;
    final contactItems = results[1] as List<WebContentItem>;
    final hourItems = results[2] as List<WebContentItem>;

    return _ContactSectionViewData(
      profile: profile,
      contactItem: contactItems.isNotEmpty ? contactItems.first : null,
      hourItems: hourItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ContactSectionViewData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _ContactSectionViewData.fallback();
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            return Container(
              color: const Color(0xFF141414),
              child: Column(
                children: [
                  _buildMain(data, isMobile),
                  _buildBottomStrip(data, isMobile),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMain(_ContactSectionViewData data, bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 24 : 100,
        isMobile ? 64 : 120,
        isMobile ? 24 : 100,
        isMobile ? 48 : 80,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildContactInfo(data, isMobile),
                const SizedBox(height: 56),
                _buildSchedule(data, isMobile),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildContactInfo(data, isMobile)),
                const SizedBox(width: 100),
                Expanded(flex: 4, child: _buildSchedule(data, isMobile)),
              ],
            ),
    );
  }

  Widget _buildContactInfo(_ContactSectionViewData data, bool isMobile) {
    final item = data.contactItem;
    final profile = data.profile;
    final sectionTag = item?.subtitle.isNotEmpty == true
        ? item!.subtitle
        : 'CONTACTO';
    final title = item?.title.isNotEmpty == true ? item!.title : 'Encuéntranos';
    final intro = item?.shortDescription.isNotEmpty == true
        ? item!.shortDescription
        : 'Estamos en Ensenada, Baja California, listos para recibir tu cuerpo y devolverle la calma que merece.';
    final reserveText = item?.ctaText.isNotEmpty == true
        ? item!.ctaText
        : 'CONCIERGE RESERVAS';
    // Si el CMS no trae una URL válida (o pone "#contacto"), caemos a WhatsApp
    // para que el botón "RESERVAR" SIEMPRE haga algo útil.
    final rawCtaUrl = (item?.ctaUrl ?? '').trim();
    final reserveUrl = (rawCtaUrl.isEmpty || rawCtaUrl.startsWith('#'))
        ? SaharaWhatsApp.buildUri(
            message:
                'Hola, me gustaría reservar mi ritual en Sahara Club Spa ✨',
          ).toString()
        : rawCtaUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTag.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFFC6A76A),
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: isMobile ? 44 : 60,
            color: const Color(0xFFE8DCC8),
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          intro,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white54,
            fontWeight: FontWeight.w300,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 56),
        _contactRow(
          Icons.location_on_outlined,
          profile.address.isNotEmpty
              ? profile.address
              : 'Ensenada, Baja California, México',
        ),
        const SizedBox(height: 28),
        _contactRow(
          Icons.phone_outlined,
          profile.phone.isNotEmpty ? profile.phone : '+52 (646) 123-4567',
        ),
        const SizedBox(height: 28),
        _contactRow(
          Icons.mail_outline_rounded,
          profile.email.isNotEmpty ? profile.email : 'hola@saharaclubspa.mx',
        ),
        const SizedBox(height: 56),
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ActionButton(
                    label: 'WHATSAPP',
                    icon: Icons.chat_bubble_outline_rounded,
                    filled: false,
                    url: _buildWhatsAppUrl(profile.whatsapp),
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: reserveText.toUpperCase(),
                    filled: true,
                    url: reserveUrl,
                    onTap: () => conciergeChatOpen.value = true,
                  ),
                ],
              )
            : Row(
                children: [
                  _ActionButton(
                    label: 'WHATSAPP',
                    icon: Icons.chat_bubble_outline_rounded,
                    filled: false,
                    url: _buildWhatsAppUrl(profile.whatsapp),
                  ),
                  const SizedBox(width: 20),
                  _ActionButton(
                    label: reserveText.toUpperCase(),
                    filled: true,
                    url: reserveUrl,
                    onTap: () => conciergeChatOpen.value = true,
                  ),
                ],
              ),
      ],
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFC6A76A), size: 20),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchedule(_ContactSectionViewData data, bool isMobile) {
    final scheduleItems = data.scheduleItems;
    final note =
        data.note ??
        'Las citas se asignan con confirmación del equipo. Te contactamos en menos de 2 horas.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile) const SizedBox(height: 100),
        Text(
          'HORARIOS',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFFC6A76A),
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 40),
        ...scheduleItems.expand(
          (item) => [
            _scheduleRow(item.title, item.shortDescription),
            _divider(),
          ],
        ),
        if (scheduleItems.isEmpty) ...[
          _scheduleRow('Lunes — Viernes', '9:00 am · 9:00 pm'),
          _divider(),
          _scheduleRow('Sábados', '9:00 am · 8:00 pm'),
          _divider(),
          _scheduleRow('Domingos', '10:00 am · 6:00 pm'),
        ] else
          const SizedBox(height: 24),
        if (scheduleItems.isEmpty) const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFC6A76A).withValues(alpha: 0.15),
            ),
            color: const Color(0xFFC6A76A).withValues(alpha: 0.04),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFC6A76A),
                size: 16,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  note,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white54,
                    fontWeight: FontWeight.w300,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scheduleRow(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white60,
              fontWeight: FontWeight.w300,
            ),
          ),
          Text(
            hours,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFFE8DCC8),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(height: 0.5, color: Colors.white.withValues(alpha: 0.07));

  Widget _buildBottomStrip(_ContactSectionViewData data, bool isMobile) {
    final note = data.contactItem?.longDescription.isNotEmpty == true
        ? data.contactItem!.longDescription
        : 'Cada visita a Sahara Club es confidencial, sin juicios, sin prisa.';

    return Container(
      width: double.infinity,
      color: const Color(0xFF0A0A0A),
      padding: EdgeInsets.symmetric(
        vertical: 32,
        horizontal: isMobile ? 24 : 100,
      ),
      child: Row(
        children: [
          const Icon(Icons.spa_outlined, color: Color(0xFFC6A76A), size: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              note,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white38,
                fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildWhatsAppUrl(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      // Fallback al número real de Sahara con mensaje precargado.
      return SaharaWhatsApp.buildUri().toString();
    }
    // Si el CMS define un teléfono, lo respetamos pero seguimos agregando el mensaje.
    final encoded = Uri.encodeComponent(SaharaWhatsApp.defaultMessage);
    return 'https://wa.me/$digits?text=$encoded';
  }
}

class _ContactSectionViewData {
  const _ContactSectionViewData({
    required this.profile,
    required this.contactItem,
    required this.hourItems,
  });

  final WebBusinessProfile profile;
  final WebContentItem? contactItem;
  final List<WebContentItem> hourItems;

  factory _ContactSectionViewData.fallback() => _ContactSectionViewData(
    profile: WebBusinessProfile.empty(),
    contactItem: null,
    hourItems: const <WebContentItem>[],
  );

  List<WebContentItem> get scheduleItems =>
      hourItems
          .where((item) => item.category.trim().toLowerCase() != 'note')
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  String? get note {
    for (final item in hourItems) {
      if (item.category.trim().toLowerCase() == 'note' &&
          item.shortDescription.isNotEmpty) {
        return item.shortDescription;
      }
    }
    return null;
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.url,
    this.icon,
    this.onTap,
    required this.filled,
  });

  final String label;
  final String url;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  Future<void> _open() async {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    final uri = _resolveUrl(widget.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoveredFill = widget.filled
        ? const Color(0xFFE8DCC8)
        : const Color(0xFFC6A76A);
    final idleFill = widget.filled
        ? const Color(0xFFC6A76A)
        : Colors.transparent;
    final textColor = widget.filled ? Colors.black : const Color(0xFFC6A76A);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          decoration: BoxDecoration(
            color: _hovered ? hoveredFill : idleFill,
            border: widget.filled
                ? null
                : Border.all(color: const Color(0xFFC6A76A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: _hovered ? Colors.black : textColor,
                ),
                const SizedBox(width: 12),
              ],
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _hovered ? Colors.black : textColor,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Uri? _resolveUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.tryParse(value);
    }
    if (value.startsWith('/')) {
      return Uri.base.resolve(value);
    }
    if (value.startsWith('#')) {
      return Uri.base.resolve(Uri.base.path + value);
    }
    return Uri.tryParse(value);
  }
}
