import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/sahara_theme.dart';

class VipMembershipsPage extends StatefulWidget {
  const VipMembershipsPage({super.key});

  @override
  State<VipMembershipsPage> createState() => _VipMembershipsPageState();
}

class _VipMembershipsPageState extends State<VipMembershipsPage> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'CLUB PRIVADO',
          style: TextStyle(
            color: SaharaTheme.gold.withOpacity(0.8),
            letterSpacing: 6,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Cinematic Background Layer
          Positioned.fill(
            child: Image.asset(
              'assets/images/hero.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Dark Luxury Overlay for background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SaharaTheme.black.withOpacity(0.85),
                    const Color(0xFF050102).withOpacity(0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          // Ambient Glows
          Positioned(
            top: -100,
            left: -100,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2B0A0E).withOpacity(_glowAnimation.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              }
            ),
          ),
          Positioned(
            bottom: -200,
            right: -100,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 600,
                  height: 600,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        SaharaTheme.gold.withOpacity(_glowAnimation.value * 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              }
            ),
          ),

          // Content Layer
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Editorial Typography Header
                  Text(
                    "Más que una membresía.\nTu acceso privado al ritual.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      fontSize: 48,
                      color: Colors.white,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [SaharaTheme.gold, Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Asymmetrical layout for cards
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 80,
                      runSpacing: 80,
                      children: [
                        const _MembershipCard(
                          title: "SAHARA GOLD",
                          type: MembershipType.gold,
                          price: "\$49",
                          period: "/ mes",
                          imageUri: 'https://images.unsplash.com/photo-1600334089648-b0d9d3028eb2?q=80&w=800&auto=format&fit=crop',
                          subtitle: "El inicio del bienestar.",
                          benefits: [
                            "Acceso privado a rituales exclusivos",
                            "Prioridad absoluta en reservas",
                            "Biblioteca wellness premium",
                            "Experiencias desbloqueables",
                            "Beneficios reservados para miembros",
                          ],
                        ),
                        // Offset the black card slightly for asymmetry if possible, done via Padding in Wrap
                        Padding(
                          padding: const EdgeInsets.only(top: 60.0), // Creates cinematic staggered effect on desktop
                          child: const _MembershipCard(
                            title: "SAHARA BLACK",
                            type: MembershipType.black,
                            price: "\$149",
                            period: "/ mes",
                            imageUri: 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?q=80&w=800&auto=format&fit=crop',
                            subtitle: "El círculo más exclusivo.",
                            benefits: [
                              "Todo lo incluido en Sahara Gold",
                              "Concierge privado de bienestar 24/7",
                              "Acceso a The Secret Spa Lounge",
                              "Cortesía de tratamientos Signature",
                              "Regalos físicos de edición limitada",
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum MembershipType { gold, black }

class _MembershipCard extends StatefulWidget {
  final String title;
  final MembershipType type;
  final String price;
  final String period;
  final List<String> benefits;
  final String imageUri;
  final String subtitle;

  const _MembershipCard({
    required this.title,
    required this.type,
    required this.price,
    required this.period,
    required this.benefits,
    required this.imageUri,
    required this.subtitle,
  });

  @override
  State<_MembershipCard> createState() => _MembershipCardState();
}

class _MembershipCardState extends State<_MembershipCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isBlack = widget.type == MembershipType.black;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
        transform: Matrix4.identity()
          ..translate(0.0, isHovered ? -15.0 : 0.0)
          ..scale(isHovered ? 1.02 : 1.0),
        child: SizedBox(
          width: 420, // Slightly wider for premium feel
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Image Header
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: NetworkImage(widget.imageUri),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(isBlack ? 0.4 : 0.2), 
                      BlendMode.darken,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontFamily: 'Playfair',
                      fontStyle: FontStyle.italic,
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

              // The Physical Card UI (Amex Black / High-end Gold aesthetic)
              Container(
                height: 250, // Realistic ratio
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: isBlack
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF383838),
                            Color(0xFF1C1C1C),
                            Color(0xFF0A0A0A),
                            Color(0xFF141414),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [0.0, 0.4, 0.8, 1.0],
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFFF9D423),
                            Color(0xFFD4AF37),
                            Color(0xFFAA771C),
                            Color(0xFF8B6C34),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [0.0, 0.3, 0.7, 1.0],
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: isBlack
                          ? Colors.black.withOpacity(0.9)
                          : SaharaTheme.gold.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: isHovered ? 10 : 2,
                      offset: const Offset(0, 20),
                    ),
                  ],
                  border: Border.all(
                    color: isBlack 
                        ? SaharaTheme.gold.withOpacity(0.3) 
                        : Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Metallic reflections / foil effect
                      Positioned(
                        top: -100,
                        right: -50,
                        child: Transform.rotate(
                          angle: 0.5,
                          child: Container(
                            width: 300,
                            height: 600,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(isBlack ? 0.05 : 0.3),
                                  Colors.white.withOpacity(0.0),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Card Content
                      Padding(
                        padding: const EdgeInsets.all(28.0),
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
                                    letterSpacing: 6,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Icon(
                                  Icons.contactless,
                                  color: isBlack ? SaharaTheme.gold.withOpacity(0.8) : Colors.white.withOpacity(0.8),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: isBlack 
                                        ? [SaharaTheme.gold, Colors.white, SaharaTheme.gold]
                                        : [Colors.white, Colors.white, Colors.white70],
                                  ).createShader(bounds),
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      letterSpacing: 4,
                                      fontFamily: 'Playfair',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "MEMBER SINCE 2026",
                                  style: TextStyle(
                                    color: isBlack ? Colors.white54 : Colors.black45,
                                    fontSize: 10,
                                    letterSpacing: 3,
                                    fontWeight: FontWeight.w600,
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
              ),
              const SizedBox(height: 40),
              
              // Pricing
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.price,
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      color: SaharaTheme.beige,
                      fontWeight: FontWeight.w400,
                      fontSize: 48,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0, left: 8.0),
                    child: Text(
                      widget.period,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Benefits
              ...widget.benefits.map((benefit) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Icon(
                            isBlack ? Icons.diamond_outlined : Icons.check_circle_outline,
                            color: SaharaTheme.gold,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            benefit,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 15,
                              height: 1.4,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 40),
              
              // Premium Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isHovered ? [
                    BoxShadow(
                      color: SaharaTheme.gold.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ] : [],
                ),
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlack ? Colors.black : SaharaTheme.gold,
                    foregroundColor: isBlack ? SaharaTheme.gold : Colors.black,
                    minimumSize: const Size(double.infinity, 65),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: isBlack 
                          ? BorderSide(color: SaharaTheme.gold.withOpacity(0.5), width: 1) 
                          : BorderSide.none,
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "ADQUIRIR ${widget.title}",
                    style: const TextStyle(
                      letterSpacing: 3, 
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
