import 'package:flutter/material.dart';

import '../services/whatsapp_link.dart';

class FloatingWhatsAppButton extends StatefulWidget {
  const FloatingWhatsAppButton({super.key});

  static const Color whatsAppGreen = Color(0xFF25D366);
  static const Color whatsAppGreenDark = Color(0xFF128C7E);

  @override
  State<FloatingWhatsAppButton> createState() => _FloatingWhatsAppButtonState();
}

class _FloatingWhatsAppButtonState extends State<FloatingWhatsAppButton> {
  bool _hovered = false;
  bool _pressed = false;

  Future<void> _open() async {
    setState(() => _pressed = true);
    try {
      await SaharaWhatsApp.openWhatsApp();
    } finally {
      if (mounted) setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Positioned(
      bottom: isMobile ? 80 : 24,
      right: isMobile ? 20 : 24,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: 'Hablar con Sahara Concierge ✨',
          waitDuration: const Duration(milliseconds: 400),
          child: Semantics(
            label: 'Abrir conversación de WhatsApp con Sahara Club Spa',
            button: true,
            child: GestureDetector(
              onTap: _open,
              child: AnimatedScale(
                scale: _pressed ? 0.92 : (_hovered ? 1.05 : 1.0),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hovered
                        ? FloatingWhatsAppButton.whatsAppGreenDark
                        : FloatingWhatsAppButton.whatsAppGreen,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: _hovered ? 0.32 : 0.22),
                        blurRadius: _hovered ? 18 : 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chat_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
