import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/gift_cards/gift_card_form_helpers.dart';
import '../features/store/models/checkout_models.dart';
import '../features/store/services/store_checkout_service.dart';
import '../theme/sahara_theme.dart';

class GiftCardViewPage extends StatefulWidget {
  const GiftCardViewPage({super.key});

  @override
  State<GiftCardViewPage> createState() => _GiftCardViewPageState();
}

class _GiftCardViewPageState extends State<GiftCardViewPage> {
  final StoreCheckoutService _checkoutService = const StoreCheckoutService();
  bool _loading = true;
  bool _notFound = false;
  bool _downloading = false;
  String _loadingText = 'Confirmando tu pago...';
  String? _downloadToken;
  GiftCardDownloadResult? _result;
  int _attempts = 0;
  static const int _maxAttempts = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final params = Uri.base.queryParameters;
    final token = (params['gift_card_token'] ?? params['token'] ?? '').trim();
    final sessionId = (params['session_id'] ?? '').trim();

    if (token.isNotEmpty) {
      _downloadToken = token;
      await _loadWithToken(token);
      return;
    }

    if (sessionId.isEmpty || sessionId.contains('{')) {
      _markNotFound();
      return;
    }

    await _loadFromSession(sessionId);
  }

  Future<void> _loadFromSession(String sessionId) async {
    try {
      setState(() => _loadingText = 'Validando el pago con Stripe...');
      final confirmation = await _checkoutService.confirmOrderPayment(
        sessionId: sessionId,
      );
      final giftCard = confirmation.giftCards.isNotEmpty
          ? confirmation.giftCards.first
          : null;
      if (confirmation.paymentStatus != 'paid' ||
          giftCard == null ||
          giftCard.downloadToken.isEmpty) {
        await _retryOrFail();
        return;
      }
      _downloadToken = giftCard.downloadToken;
      await _loadWithToken(giftCard.downloadToken);
    } catch (_) {
      await _retryOrFail();
    }
  }

  Future<void> _loadWithToken(String token) async {
    try {
      setState(() => _loadingText = 'Preparando tu tarjeta digital...');
      final result = await _checkoutService.downloadGiftCard(
        downloadToken: token,
      );
      if (!result.ok || result.downloadUrl.isEmpty) {
        await _retryOrFail();
        return;
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
        _notFound = false;
      });
    } catch (_) {
      await _retryOrFail();
    }
  }

  Future<void> _retryOrFail() async {
    _attempts++;
    if (_attempts >= _maxAttempts) {
      _markNotFound();
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _loadingText = 'Generando la tarjeta digital...';
      });
    }
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final token = _downloadToken;
      if (token != null && token.isNotEmpty) {
        _loadWithToken(token);
      } else {
        _load();
      }
    });
  }

  void _markNotFound() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _notFound = true;
    });
  }

  Future<void> _openPdf() async {
    final url = _result?.downloadUrl ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    setState(() => _downloading = true);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return giftCardDateLabel(parsed);
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
        _loadingText,
        style: GoogleFonts.inter(color: const Color(0xFFD1C5B4), fontSize: 15),
      ),
    ],
  );

  Widget _buildNotFound() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(
        Icons.card_giftcard_rounded,
        color: SaharaTheme.gold,
        size: 48,
      ),
      const SizedBox(height: 16),
      Text(
        'No encontramos esta tarjeta de regalo',
        textAlign: TextAlign.center,
        style: GoogleFonts.playfairDisplay(
          color: const Color(0xFFE5E2E1),
          fontSize: 22,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Si acabas de pagar, espera un momento y reintenta.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: const Color(0xFF9A8F80), fontSize: 14),
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _loading = true;
            _notFound = false;
            _attempts = 0;
          });
          _load();
        },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reintentar'),
      ),
    ],
  );

  Widget _buildCard() {
    final result = _result!;
    final card = result.card;
    final redeemed = card.status == 'redeemed';
    final expired = card.status == 'expired';
    final validFrom = _formatDate(card.validFrom);
    final expiresOn = _formatDate(card.expiresOn);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C1B1B), Color(0xFF0E0E0E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: card.code,
                version: QrVersions.auto,
                size: 176,
                gapless: false,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              card.code,
              style: GoogleFonts.robotoMono(
                color: SaharaTheme.gold,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 22),
            if (card.recipientName.isNotEmpty) ...[
              _eyebrow('A nombre de'),
              const SizedBox(height: 2),
              Text(
                card.recipientName,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  color: const Color(0xFFE5E2E1),
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 16),
            ],
            _experienceBox(card.serviceName),
            const SizedBox(height: 14),
            if (card.senderName.isNotEmpty)
              Text(
                'De parte de ${card.senderName}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD1C5B4),
                  fontSize: 13,
                ),
              ),
            if (card.dedicationMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                card.dedicationMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFFD1C5B4),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
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
                'Valida del $validFrom al $expiresOn',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9A8F80),
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _downloading ? null : _openPdf,
              style: FilledButton.styleFrom(
                backgroundColor: SaharaTheme.gold,
                foregroundColor: const Color(0xFF131313),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              icon: Icon(
                _downloading
                    ? Icons.hourglass_empty_rounded
                    : Icons.download_rounded,
              ),
              label: Text(_downloading ? 'Abriendo...' : 'Descargar PDF'),
            ),
            const SizedBox(height: 12),
            Text(
              result.deliveryStatus == 'sent'
                  ? 'WhatsApp enviado'
                  : 'WhatsApp pendiente de confirmacion',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF6F665B),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _experienceBox(String service) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      color: SaharaTheme.gold.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: SaharaTheme.gold.withValues(alpha: 0.30)),
    ),
    child: Column(
      children: [
        _eyebrow('Experiencia'),
        const SizedBox(height: 4),
        Text(
          service.isEmpty ? 'Experiencia Sahara' : service,
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            color: SaharaTheme.gold,
            fontSize: 20,
          ),
        ),
      ],
    ),
  );

  Widget _eyebrow(String text) => Text(
    text,
    style: GoogleFonts.inter(
      color: const Color(0xFF9A8F80),
      fontSize: 11,
      letterSpacing: 1.5,
    ),
  );

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
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
