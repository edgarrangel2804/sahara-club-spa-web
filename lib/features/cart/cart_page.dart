import 'package:flutter/material.dart';
import '../../theme/sahara_theme.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaharaTheme.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'TU CARRITO',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: SaharaTheme.beige,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: SaharaTheme.beige),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _CartSection(
                  title: "PRODUCTOS FÍSICOS",
                  subtitle: "Recoger en Sahara Club (Pickup)",
                  items: [
                    _CartItem(
                      title: "Aceite Sahara",
                      type: "Skin Care",
                      price: "\$799",
                      icon: Icons.spa,
                    ),
                    _CartItem(
                      title: "Velas Ritual",
                      type: "Aromaterapia",
                      price: "\$599",
                      icon: Icons.local_fire_department,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _CartSection(
                  title: "PRODUCTOS DIGITALES",
                  subtitle: "Desbloqueo instantáneo en Mi Ritual",
                  items: [
                    _CartItem(
                      title: "Meditación Sueño Profundo",
                      type: "Audio Guiado",
                      price: "\$199",
                      icon: Icons.headphones,
                      isDigital: true,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _CartSection(
                  title: "MEMBRESÍA VIP",
                  subtitle: "Desbloquea toda la experiencia VIP",
                  items: [
                    _CartItem(
                      title: "SAHARA GOLD",
                      type: "Membresía Mensual",
                      price: "\$49/mes",
                      icon: Icons.star,
                      isMembership: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Checkout Bottom Bar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Estimado",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Text(
                        "\$1,646",
                        style: TextStyle(
                          color: SaharaTheme.gold,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SaharaTheme.gold,
                      foregroundColor: SaharaTheme.black,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "PROCEDER AL PAGO",
                      style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
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
}

class _CartSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> items;

  const _CartSection({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: SaharaTheme.beige,
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: SaharaTheme.gold.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }
}

class _CartItem extends StatelessWidget {
  final String title;
  final String type;
  final String price;
  final IconData icon;
  final bool isDigital;
  final bool isMembership;

  const _CartItem({
    required this.title,
    required this.type,
    required this.price,
    required this.icon,
    this.isDigital = false,
    this.isMembership = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMembership ? SaharaTheme.gold.withOpacity(0.05) : const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMembership ? SaharaTheme.gold.withOpacity(0.3) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: SaharaTheme.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: SaharaTheme.gold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  price,
                  style: TextStyle(
                    color: SaharaTheme.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
