import 'package:flutter/material.dart';

import '../services/whatsapp_link.dart';

class RitualCard extends StatelessWidget {
  final String title;

  const RitualCard({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.spa_outlined, color: Color(0xFFC6A76A), size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE8DCC8),
              fontSize: 22,
              fontFamily: 'Playfair',
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Un ritual diseñado para armonizar tu energía y restaurar tu paz interior.",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => SaharaWhatsApp.openWhatsApp(
              message: 'Hola, me interesa reservar el ritual "$title" en Sahara Club Spa ✨',
            ),
            child: const Text("RESERVAR", style: TextStyle(color: Color(0xFFC6A76A), letterSpacing: 1)),
          )
        ],
      ),
    );
  }
}
