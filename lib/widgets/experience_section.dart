import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExperienceSection extends StatelessWidget {
  const ExperienceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return Column(
          children: [
            _buildPhilosophy(isMobile),
            _buildPillars(isMobile),
            _buildQuote(isMobile),
            _buildImageGrid(isMobile),
          ],
        );
      },
    );
  }

  Widget _buildPhilosophy(bool isMobile) {
    return Container(
      color: const Color(0xFF141414),
      padding: EdgeInsets.fromLTRB(
        isMobile ? 24 : 100,
        isMobile ? 64 : 120,
        isMobile ? 24 : 100,
        isMobile ? 48 : 100,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _philosophyLeft(isMobile),
                const SizedBox(height: 32),
                _philosophyRight(),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _philosophyLeft(isMobile)),
                const SizedBox(width: 80),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: _philosophyRight(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _philosophyLeft(bool isMobile) {
    return Column(
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
            fontSize: isMobile ? 40 : 60,
            color: const Color(0xFFE8DCC8),
            fontWeight: FontWeight.w300,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  Widget _philosophyRight() {
    return Column(
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
    );
  }

  Widget _buildPillars(bool isMobile) {
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
      padding: EdgeInsets.fromLTRB(
        isMobile ? 24 : 100,
        0,
        isMobile ? 24 : 100,
        isMobile ? 64 : 120,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: pillars
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: _buildPillar(p),
                    ),
                  )
                  .toList(),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(pillars.length, (i) {
                final p = pillars[i];
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: i < pillars.length - 1 ? 48 : 0,
                    ),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.asset(
              _pillarImageFor(p.number),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
        const SizedBox(height: 26),
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

  String _pillarImageFor(String number) {
    return switch (number) {
      '01' => 'assets/experiencia/01-presencia.png',
      '02' => 'assets/experiencia/02-conexion.png',
      '03' => 'assets/experiencia/03-transformacion.png',
      _ => 'assets/images/01.png',
    };
  }

  Widget _buildQuote(bool isMobile) {
    return Container(
      color: const Color(0xFF0B0B0B),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 64 : 100,
        horizontal: isMobile ? 32 : 180,
      ),
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
              fontSize: isMobile ? 26 : 38,
              color: const Color(0xFFE8DCC8),
              fontWeight: FontWeight.w300,
              height: 1.5,
              fontStyle: FontStyle.italic,
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

  Widget _buildImageGrid(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.asset(
              'assets/images/01.png',
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/images/02.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/images/03.png', fit: BoxFit.cover),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/images/04.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/images/05.png', fit: BoxFit.cover),
                ),
              ),
            ],
          ),
        ],
      );
    }

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
                  child: Image.asset(
                    'assets/images/02.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: Image.asset(
                    'assets/images/03.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
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
                  child: Image.asset(
                    'assets/images/04.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: Image.asset(
                    'assets/images/05.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
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

class _Pillar {
  final String number;
  final String title;
  final String description;
  const _Pillar(this.number, this.title, this.description);
}
