// Sahara Club Spa - "Base de Conocimiento Sahara"
// Wrapper único para los 4 paneles que alimentan al agente recepcionista IA.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/sahara_theme.dart';
import 'business_hours_panel.dart';
import 'faqs_panel.dart';
import 'services_ai_fields_panel.dart';
import 'staff_ai_profile_panel.dart';

class KnowledgeBasePanel extends StatelessWidget {
  const KnowledgeBasePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF7F1E7), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECE9E4)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SaharaTheme.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_outlined, color: Color(0xFFC6A76A)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base de Conocimiento Sahara',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: SaharaTheme.grisCarbon,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Captura aquí los datos que el agente recepcionista usará para responder. '
                      'Mientras estos datos no estén completos, el agente NO se activa.',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionWrapper(
          icon: Icons.access_time_outlined,
          title: '1. Horario y días cerrados',
          child: const BusinessHoursPanel(),
        ),
        const SizedBox(height: 32),
        _SectionWrapper(
          icon: Icons.spa_outlined,
          title: '2. Beneficios y contraindicaciones por servicio',
          child: const ServicesAiFieldsPanel(),
        ),
        const SizedBox(height: 32),
        _SectionWrapper(
          icon: Icons.people_outline,
          title: '3. Perfil profesional de terapeutas',
          child: const StaffAiProfilePanel(),
        ),
        const SizedBox(height: 32),
        _SectionWrapper(
          icon: Icons.help_outline,
          title: '4. FAQs (preguntas frecuentes)',
          child: const FaqsPanel(),
        ),
      ],
    );
  }
}

class _SectionWrapper extends StatelessWidget {
  const _SectionWrapper({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFC6A76A), size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SaharaTheme.grisCarbon,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }
}
