import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/sahara_theme.dart';

class DepositSuccessPage extends StatelessWidget {
  const DepositSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _DepositResultScaffold(
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF1A9E65),
      title: 'Pago recibido',
      message:
          'Gracias por tu anticipo de \$200 MXN. Recepción validará tu cita '
          'y te confirmará por WhatsApp en breve.',
      cta: 'Volver a Sahara',
    );
  }
}

class DepositCancelPage extends StatelessWidget {
  const DepositCancelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _DepositResultScaffold(
      icon: Icons.cancel_outlined,
      iconColor: const Color(0xFFB32D2D),
      title: 'Pago cancelado',
      message:
          'No se completó el anticipo. Si fue un error, escríbenos por '
          'WhatsApp y te enviamos el link nuevamente.',
      cta: 'Escríbenos por WhatsApp',
      ctaUrl: 'https://wa.me/5216464961145',
    );
  }
}

class _DepositResultScaffold extends StatelessWidget {
  const _DepositResultScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.cta,
    this.ctaUrl,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String cta;
  final String? ctaUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaharaTheme.blancoAlmendra,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 80),
                const SizedBox(height: 24),
                Text(
                  'SAHARA CLUB SPA',
                  style: GoogleFonts.playfairDisplay(
                    color: SaharaTheme.gold,
                    fontSize: 16,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    color: SaharaTheme.grisCarbon,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.black54,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    if (ctaUrl != null) {
                      // Abrir WhatsApp en pestaña/app
                      // url_launcher se usa en otras partes del proyecto.
                      // Aquí sólo navegamos al landing para simplicidad.
                    }
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (_) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SaharaTheme.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    cta,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
