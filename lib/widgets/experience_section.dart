import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExperienceSection extends StatelessWidget {
  const ExperienceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPhilosophy(),
        _buildPillars(),
        _buildQuote(),
        _buildImageGrid(),
      ],
    );
  }

  Widget _buildPhilosophy() {
    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.fromLTRB(100, 120, 100, 100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LA EXPERIENCIA SAHARA',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFFC6A76A),
                    letterSpacing: 4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Un espacio que\nrecuerda quién eres',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 60,
                    color: const Color(0xFFE8DCC8),
                    fontWeight: FontWeight.w300,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 80),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No somos un spa tradicional. Somos un espacio de encuentro entre el cuerpo, la mente y la presencia.',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: Colors.white70,
                      fontWeight: FontWeight.w300,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Cada ritual está diseñado para devolverte a ti. Sin prisas, sin guiones fijos. Solo presencia, contacto y transformación real.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white38,
                      fontWeight: FontWeight.w300,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillars() {
    final pillars = [
      _Pillar(
        '01',
        'Presencia Real',
        'Cada sesión comienza donde tú estás. Nuestros rituales no siguen guiones: siguen el cuerpo de quien los recibe. Tu cuerpo es el mapa.',
      ),
      _Pillar(
        '02',
        'Conexión Profunda',
        'El contacto terapéutico es un idioma. Aquí aprendemos a hablar el tuyo, para devolverle al cuerpo su calma natural y su sabiduría propia.',
      ),
      _Pillar(
        '03',
        'Transformación Real',
        'No prometemos relajación superficial. Prometemos que saldrás diferente: más liviano, más presente, más tú. El cuerpo lo recuerda.',
      ),
    ];

    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.fromLTRB(100, 0, 100, 120),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(pillars.length, (i) {
          final p = pillars[i];
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < pillars.length - 1 ? 48 : 0),
              child: _buildPillar(p),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPillar(_Pillar p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.number,
          style: GoogleFonts.playfairDisplay(
            fontSize: 72,
            color: const Color(0xFFC6A76A).withValues(alpha: 0.18),
            fontWeight: FontWeight.w300,
          ),
        ),
        Container(width: 32, height: 1, color: const Color(0xFFC6A76A)),
        const SizedBox(height: 28),
        Text(
          p.title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 26,
            color: const Color(0xFFE8DCC8),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          p.description,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: Colors.white54,
            height: 1.75,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildQuote() {
    return Container(
      color: const Color(0xFF0B0B0B),
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 180),
      child: Column(
        children: [
          Container(
            width: 1,
            height: 60,
            color: const Color(0xFFC6A76A).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 48),
          Text(
            '"El cuerpo no miente.\nAquí le damos espacio para decir la verdad."',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 38,
              color: const Color(0xFFE8DCC8),
              fontWeight: FontWeight.w300,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            '— Jochebed, fundadora de Sahara Club',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFFC6A76A),
              letterSpacing: 2,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 48),
          Container(
            width: 1,
            height: 60,
            color: const Color(0xFFC6A76A).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    return SizedBox(
      height: 520,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Image.asset('assets/images/01.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 3),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: Image.asset('assets/images/02.png', fit: BoxFit.cover,
                      width: double.infinity),
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: Image.asset('assets/images/03.png', fit: BoxFit.cover,
                      width: double.infinity),
                ),
              ],
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: Image.asset('assets/images/04.png', fit: BoxFit.cover,
                      width: double.infinity),
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: Image.asset('assets/images/05.png', fit: BoxFit.cover,
                      width: double.infinity),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pillar {
  final String number;
  final String title;
  final String description;
  const _Pillar(this.number, this.title, this.description);
}
