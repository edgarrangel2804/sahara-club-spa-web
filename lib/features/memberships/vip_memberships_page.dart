import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/sahara_theme.dart';

class VipMembershipsPage extends StatefulWidget {
  const VipMembershipsPage({super.key});

  @override
  State<VipMembershipsPage> createState() => _VipMembershipsPageState();
}

class _VipMembershipsPageState extends State<VipMembershipsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaharaTheme.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'VIP CLUB',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: SaharaTheme.gold,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
              ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: SaharaTheme.beige),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Tu Entrada al\nOasis Exclusivo",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: SaharaTheme.beige,
                    fontWeight: FontWeight.w300,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              "Mucho más que un spa. Un estilo de vida.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                  ),
            ),
            const SizedBox(height: 40),

            // Sahara Gold Card
            const _MembershipCard(
              title: "SAHARA GOLD",
              type: MembershipType.gold,
              price: "\$49",
              period: "/ mes",
              benefits: [
                "Meditaciones Premium",
                "15% Descuento en Boutique",
                "Playlist Exclusivas del Club",
                "Ritual Digital Mensual",
                "1 Bebida Wellness en Visita",
              ],
            ),

            const SizedBox(height: 40),

            // Sahara Black Card
            const _MembershipCard(
              title: "SAHARA BLACK",
              type: MembershipType.black,
              price: "\$149",
              period: "/ mes",
              benefits: [
                "Todo lo incluido en Gold",
                "Contenido y Rituales Secretos",
                "Eventos VIP Privados",
                "Prioridad Máxima de Citas",
                "30% Descuento en Spa",
                "Regalo Físico Mensual",
              ],
            ),
            
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

enum MembershipType { gold, black }

class _MembershipCard extends StatelessWidget {
  final String title;
  final MembershipType type;
  final String price;
  final String period;
  final List<String> benefits;

  const _MembershipCard({
    required this.title,
    required this.type,
    required this.price,
    required this.period,
    required this.benefits,
  });

  @override
  Widget build(BuildContext context) {
    final isBlack = type == MembershipType.black;

    return Column(
      children: [
        // The Physical Card UI
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isBlack
                ? const LinearGradient(
                    colors: [Color(0xFF1E1E1E), Color(0xFF000000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFE5C98B), Color(0xFF8B6C34)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: [
              BoxShadow(
                color: isBlack
                    ? Colors.black.withOpacity(0.8)
                    : SaharaTheme.gold.withOpacity(0.3),
                blurRadius: 25,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isBlack ? SaharaTheme.gold.withOpacity(0.3) : Colors.white24,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Glassmorphism reflection
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBlack ? SaharaTheme.gold.withOpacity(0.05) : Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "SAHARA CLUB",
                          style: TextStyle(
                            color: isBlack ? SaharaTheme.gold : Colors.white,
                            fontSize: 14,
                            letterSpacing: 3,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Icons.nfc,
                          color: isBlack ? SaharaTheme.gold.withOpacity(0.5) : Colors.white60,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isBlack ? Colors.white : Colors.white,
                            fontSize: 24,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "MEMBER SINCE 2026",
                          style: TextStyle(
                            color: isBlack ? Colors.white54 : Colors.white70,
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Pricing & Benefits
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: SaharaTheme.beige,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0, left: 4.0),
              child: Text(
                period,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...benefits.map((benefit) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    isBlack ? Icons.diamond : Icons.star,
                    color: SaharaTheme.gold,
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      benefit,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: isBlack ? SaharaTheme.black : SaharaTheme.gold,
            foregroundColor: isBlack ? SaharaTheme.gold : SaharaTheme.black,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: isBlack ? BorderSide(color: SaharaTheme.gold, width: 1) : BorderSide.none,
            ),
            elevation: isBlack ? 0 : 5,
          ),
          child: Text(
            "ÚNETE A $title",
            style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
