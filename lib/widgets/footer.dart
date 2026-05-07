import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          _buildMain(),
          _buildDivider(),
          _buildBottom(),
        ],
      ),
    );
  }

  Widget _buildMain() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(100, 80, 100, 64),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand column
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAHARA CLUB',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    color: const Color(0xFFC6A76A),
                    letterSpacing: 4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'SPA & BIENESTAR',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white24,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Este es tu momento.\nTu cuerpo recuerda\ncómo descansar.',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    color: Colors.white38,
                    fontWeight: FontWeight.w300,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 36),
                // Social icons
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
                      url: 'https://wa.me/526461234567',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 60),
          // Navigation column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _footerHeading('NAVEGACIÓN'),
                const SizedBox(height: 24),
                _footerLink('Inicio'),
                _footerLink('Servicios'),
                _footerLink('Experiencia'),
                _footerLink('Noticias'),
                _footerLink('Contacto'),
              ],
            ),
          ),
          // Services column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _footerHeading('SERVICIOS'),
                const SizedBox(height: 24),
                _footerLink('Masajes'),
                _footerLink('Metodología Sahara'),
                _footerLink('Faciales'),
                _footerLink('Moldeo Consciente'),
                _footerLink('Experiencias Fusionadas'),
              ],
            ),
          ),
          // Contact column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _footerHeading('CONTACTO'),
                const SizedBox(height: 24),
                _footerText('Ensenada, Baja California'),
                const SizedBox(height: 10),
                _footerText('+52 (646) 123-4567'),
                const SizedBox(height: 10),
                _footerText('hola@saharaclubspa.mx'),
                const SizedBox(height: 24),
                _footerText('Lun–Vie: 9 am – 9 pm'),
                _footerText('Sáb: 9 am – 8 pm'),
                _footerText('Dom: 10 am – 6 pm'),
              ],
            ),
          ),
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

  Widget _footerLink(String text) {
    return _FooterLinkItem(text: text);
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

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 100),
      height: 0.5,
      color: Colors.white.withValues(alpha: 0.07),
    );
  }

  Widget _buildBottom() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 100),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© 2026 SAHARA CLUB SPA. TODOS LOS DERECHOS RESERVADOS.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.18),
              letterSpacing: 1,
            ),
          ),
          Text(
            'ENSENADA, BAJA CALIFORNIA · MÉXICO',
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
}

class _FooterLinkItem extends StatefulWidget {
  final String text;
  const _FooterLinkItem({required this.text});

  @override
  State<_FooterLinkItem> createState() => _FooterLinkItemState();
}

class _FooterLinkItemState extends State<_FooterLinkItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
    );
  }
}

class _SocialIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final String url;
  const _SocialIcon({required this.icon, required this.label, required this.url});

  @override
  State<_SocialIcon> createState() => _SocialIconState();
}

class _SocialIconState extends State<_SocialIcon> {
  bool _hovered = false;

  Future<void> _open() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
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
          decoration: BoxDecoration(
            color: const Color(0xFFC6A76A),
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
