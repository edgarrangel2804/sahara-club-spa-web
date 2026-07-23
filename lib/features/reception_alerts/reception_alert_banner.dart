import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'reception_alert.dart';

class ReceptionAlertBanner extends StatefulWidget {
  const ReceptionAlertBanner({
    super.key,
    required this.alert,
    required this.onOpen,
    required this.onDismiss,
  });

  final ReceptionAlert alert;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  State<ReceptionAlertBanner> createState() => _ReceptionAlertBannerState();
}

class _ReceptionAlertBannerState extends State<ReceptionAlertBanner>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _pulse;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_leaving) return;
    _leaving = true;
    _pulse.stop();
    await _enter.reverse();
    if (mounted) widget.onDismiss();
  }

  String _money(num value, String? currency) {
    return '\$${value.toStringAsFixed(2)} ${(currency ?? 'MXN').toUpperCase()}';
  }

  String _dateLine(ReceptionAlert alert) {
    if (alert.isGiftCardPurchase) {
      return [
        alert.displayProductName,
        if (alert.validityLabel != null) 'Vigencia ${alert.validityLabel}',
      ].whereType<String>().where((value) => value.isNotEmpty).join('   |   ');
    }
    return [
      if (alert.serviceName != null) alert.serviceName,
      if (alert.bookingDate != null)
        '${alert.bookingDate!.day.toString().padLeft(2, '0')}/'
            '${alert.bookingDate!.month.toString().padLeft(2, '0')}'
            '${alert.bookingTime != null ? ' | ${alert.bookingTime}' : ''}',
    ].whereType<String>().join('   |   ');
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final accent = alert.accent;
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width - 32 < 460.0 ? width - 32 : 460.0;
    final dateLine = _dateLine(alert);

    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _pulse]),
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_enter.value.clamp(0.0, 1.0));
        final glow = 0.18 + 0.22 * _pulse.value;
        return Opacity(
          opacity: _enter.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -24),
            child: Transform.scale(
              scale: 0.92 + 0.08 * t,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: glow),
                      blurRadius: 28,
                      spreadRadius: 1,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardWidth,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 6, color: accent),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(alert.icon, color: accent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      alert.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alert.displayClientName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _close,
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (dateLine.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        dateLine,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                    if (alert.isGiftCardPurchase) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(
                            label: 'Destinataria',
                            value: alert.recipientName,
                          ),
                          if (alert.displayPhone != null)
                            _InfoChip(
                              label: 'Telefono',
                              value: alert.displayPhone!,
                            ),
                          if (alert.amountPaid != null)
                            _InfoChip(
                              label: 'Pagado',
                              value: _money(alert.amountPaid!, alert.currency),
                            ),
                          _InfoChip(
                            label: 'Entrega',
                            value: alert.deliveryStatus,
                          ),
                        ],
                      ),
                    ] else if ((alert.message ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        alert.message!,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _ChannelChip(
                          channel: alert.isGiftCardPurchase
                              ? (alert.purchaseChannel ?? alert.channel)
                              : alert.channel,
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            _leaving = true;
                            widget.onOpen();
                          },
                          icon: Icon(
                            alert.isGiftCardPurchase
                                ? Icons.card_giftcard_outlined
                                : Icons.event_available_rounded,
                            size: 18,
                          ),
                          label: Text(
                            alert.bookingId != null
                                ? 'Ver en agenda'
                                : (alert.isGiftCardPurchase
                                      ? 'Ver Gift Card'
                                      : 'Ver'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.channel});
  final String channel;

  @override
  Widget build(BuildContext context) {
    final normalized = channel.toLowerCase();
    final (label, icon) = switch (normalized) {
      'whatsapp' => ('WhatsApp', Icons.chat_outlined),
      'web' => ('Pagina web', Icons.language_outlined),
      'reception' => ('Recepcion', Icons.storefront_outlined),
      'manual' => ('Venta manual', Icons.point_of_sale_outlined),
      'admin' => ('Admin', Icons.admin_panel_settings_outlined),
      'app' => ('App', Icons.phone_iphone_outlined),
      'external' => ('Externo', Icons.public_outlined),
      _ => (channel, Icons.notifications_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.black45),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
