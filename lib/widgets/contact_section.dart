import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ContactSection extends StatelessWidget {
  const ContactSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF141414),
      child: Column(
        children: [
          _buildMain(),
          _buildBottomStrip(),
        ],
      ),
    );
  }

  Widget _buildMain() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(100, 120, 100, 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: contact info
          Expanded(
            flex: 5,
            child: _buildContactInfo(),
          ),
          const SizedBox(width: 100),
          // Right: schedule
          Expanded(
            flex: 4,
            child: _buildSchedule(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTACTO',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFFC6A76A),
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Encuéntranos',
          style: GoogleFonts.playfairDisplay(
            fontSize: 60,
            color: const Color(0xFFE8DCC8),
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Estamos en Ensenada, Baja California, listos para recibir tu cuerpo y devolverle la calma que merece.',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white54,
            fontWeight: FontWeight.w300,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 56),
        _contactRow(Icons.location_on_outlined, 'Ensenada, Baja California, México'),
        const SizedBox(height: 28),
        _contactRow(Icons.phone_outlined, '+52 (646) 123-4567'),
        const SizedBox(height: 28),
        _contactRow(Icons.mail_outline_rounded, 'hola@saharaclubspa.mx'),
        const SizedBox(height: 56),
        Row(
          children: [
            _WhatsAppButton(),
            const SizedBox(width: 20),
            _ReserveButton(),
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
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white70,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 100),
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
        _scheduleRow('Lunes — Viernes', '9:00 am · 9:00 pm'),
        _divider(),
        _scheduleRow('Sábados', '9:00 am · 8:00 pm'),
        _divider(),
        _scheduleRow('Domingos', '10:00 am · 6:00 pm'),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(
                color: const Color(0xFFC6A76A).withValues(alpha: 0.15)),
            color: const Color(0xFFC6A76A).withValues(alpha: 0.04),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFC6A76A), size: 16),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Las citas se asignan con confirmación del equipo. Te contactamos en menos de 2 horas.',
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

  Widget _buildBottomStrip() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 100),
      child: Row(
        children: [
          const Icon(Icons.spa_outlined,
              color: Color(0xFFC6A76A), size: 16),
          const SizedBox(width: 14),
          Text(
            'Cada visita a Sahara Club es confidencial, sin juicios, sin prisa.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white38,
              fontWeight: FontWeight.w300,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppButton extends StatefulWidget {
  @override
  State<_WhatsAppButton> createState() => _WhatsAppButtonState();
}

class _WhatsAppButtonState extends State<_WhatsAppButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        decoration: BoxDecoration(
          color: _hovered
              ? const Color(0xFFC6A76A)
              : Colors.transparent,
          border: Border.all(color: const Color(0xFFC6A76A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: _hovered ? Colors.black : const Color(0xFFC6A76A),
            ),
            const SizedBox(width: 12),
            Text(
              'WHATSAPP',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _hovered ? Colors.black : const Color(0xFFC6A76A),
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReserveButton extends StatefulWidget {
  @override
  State<_ReserveButton> createState() => _ReserveButtonState();
}

class _ReserveButtonState extends State<_ReserveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        decoration: BoxDecoration(
          color: _hovered
              ? const Color(0xFFE8DCC8)
              : const Color(0xFFC6A76A),
        ),
        child: Text(
          'RESERVA TU RITUAL',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.black,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
