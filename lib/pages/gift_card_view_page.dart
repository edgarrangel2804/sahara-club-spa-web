import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/sahara_theme.dart';

/// Tarjeta de regalo DIGITAL con QR. Se abre tras pagar una gift card de
/// servicio (o desde el link que se envía por WhatsApp).
/// Lee `code` o `session_id` de la URL y consulta el RPC público
/// `get_gift_card_public`. Como la tarjeta la crea el webhook de Stripe de
/// forma asíncrona, reintenta unos segundos hasta que aparece.
class GiftCardViewPage extends StatefulWidget {
  const GiftCardViewPage({super.key});

  @override
  State<GiftCardViewPage> createState() => _GiftCardViewPageState();
}

class _GiftCardViewPageState extends State<GiftCardViewPage> {
  bool _loading = true;
  bool _notFound = false;
  Map<String, dynamic>? _card;
  int _attempts = 0;
  static const _maxAttempts = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final params = Uri.base.queryParameters;
    final code = (params['code'] ?? '').trim();
    final sessionId = (params['session_id'] ?? '').trim();
    if (code.isEmpty && (sessionId.isEmpty || sessionId.contains('{'))) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }

    try {
      final res = await Supabase.instance.client.rpc(
        'get_gift_card_public',
        params: {
          'p_code': code.isNotEmpty ? code : null,
          'p_session_id': sessionId.isNotEmpty ? sessionId : null,
        },
      );
      final map = (res is Map) ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      if (map['found'] == true) {
        setState(() {
          _card = map;
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // sigue reintentando: el webhook puede tardar unos segundos
    }

    _attempts++;
    if (_attempts >= _maxAttempts) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    Timer(const Duration(seconds: 2), _load);
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
          child: _loading
              ? _buildLoading()
              : _notFound
                  ? _buildNotFound()
                  : _buildCard(),
        ),
      ),
    );
  }

  Widget _buildLoading() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: SaharaTheme.gold),
          const SizedBox(height: 20),
          Text(
            'Generando tu tarjeta de regalo…',
            style: GoogleFonts.inter(color: const Color(0xFFD1C5B4), fontSize: 15),
          ),
        ],
      );

  Widget _buildNotFound() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.card_giftcard_rounded,
              color: SaharaTheme.gold, size: 48),
          const SizedBox(height: 16),
          Text(
            'No encontramos esta tarjeta de regalo',
            style: GoogleFonts.playfairDisplay(
                color: const Color(0xFFE5E2E1), fontSize: 22),
          ),
          const SizedBox(height: 10),
          Text(
            'Si acabas de pagar, espera un momento y recarga.\n'
            'Si tienes el código, recepción puede ayudarte.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: const Color(0xFF9A8F80), fontSize: 14),
          ),
        ],
      );

  Widget _buildCard() {
    final card = _card!;
    final code = (card['code'] ?? '').toString();
    final service = (card['service_name'] ?? 'Servicio Sahara').toString();
    final recipient = (card['recipient_name'] ?? '').toString();
    final sender = (card['sender_name'] ?? '').toString();
    final message = (card['message'] ?? '').toString();
    final expires = _formatDate(card['expires_at']?.toString());
    final status = (card['status'] ?? 'active').toString();
    final redeemed = status == 'redeemed';
    final expired = status == 'expired';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C1B1B), Color(0xFF0E0E0E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SaharaTheme.gold.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: SaharaTheme.gold.withValues(alpha: 0.10),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SAHARA CLUB SPA',
              style: GoogleFonts.playfairDisplay(
                color: SaharaTheme.gold,
                fontSize: 16,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'TARJETA DE REGALO',
              style: GoogleFonts.inter(
                color: const Color(0xFFD1C5B4),
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            // QR
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: code,
                version: QrVersions.auto,
                size: 180,
                gapless: false,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: GoogleFonts.robotoMono(
                color: SaharaTheme.gold,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            if (recipient.isNotEmpty) ...[
              Text(
                'A nombre de',
                style: GoogleFonts.inter(
                    color: const Color(0xFF9A8F80), fontSize: 11, letterSpacing: 1.5),
              ),
              const SizedBox(height: 2),
              Text(
                recipient,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFFE5E2E1), fontSize: 24),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: SaharaTheme.gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SaharaTheme.gold.withValues(alpha: 0.30)),
              ),
              child: Column(
                children: [
                  Text(
                    'Servicio de regalo',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF9A8F80), fontSize: 11, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                        color: SaharaTheme.gold, fontSize: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (sender.isNotEmpty)
              Text(
                'De parte de $sender',
                style: GoogleFonts.inter(
                    color: const Color(0xFFD1C5B4), fontSize: 13),
              ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '“$message”',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFFD1C5B4),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2A2826)),
            const SizedBox(height: 12),
            if (redeemed)
              _statusPill('Ya canjeada', const Color(0xFF9A8F80))
            else if (expired)
              _statusPill('Vencida', const Color(0xFFD64545))
            else
              Text(
                expires.isNotEmpty ? 'Válida hasta $expires' : 'Válida',
                style: GoogleFonts.inter(
                    color: const Color(0xFF9A8F80), fontSize: 12),
              ),
            const SizedBox(height: 14),
            Text(
              'Presenta este código o QR en recepción para agendar tu servicio 🌿',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: const Color(0xFF6F665B), fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
              color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
}
