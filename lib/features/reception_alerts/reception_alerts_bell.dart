import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/sahara_theme.dart';
import 'reception_alert.dart';

/// Campana de alertas para recepción + panel desplegable.
/// Visible en la barra de navegación global (todos los módulos).
class ReceptionAlertsBell extends StatefulWidget {
  const ReceptionAlertsBell({
    super.key,
    required this.unseenCount,
    required this.alerts,
    required this.onMarkSeen,
    required this.onMarkResolved,
    required this.onMarkAllSeen,
    required this.onOpenAlert,
    this.compact = false,
  });

  final int unseenCount;
  final List<ReceptionAlert> alerts;
  final ValueChanged<String> onMarkSeen;
  final ValueChanged<String> onMarkResolved;
  final VoidCallback onMarkAllSeen;
  final ValueChanged<ReceptionAlert> onOpenAlert;
  final bool compact;

  @override
  State<ReceptionAlertsBell> createState() => _ReceptionAlertsBellState();
}

class _ReceptionAlertsBellState extends State<ReceptionAlertsBell> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  @override
  void didUpdateWidget(covariant ReceptionAlertsBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si llegan alertas nuevas mientras el panel está abierto, redibuja.
    _entry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _removePanel();
    super.dispose();
  }

  void _togglePanel() {
    if (_entry != null) {
      _removePanel();
    } else {
      _showPanel();
    }
  }

  void _removePanel() {
    _entry?.remove();
    _entry = null;
  }

  void _showPanel() {
    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Capa para cerrar al hacer clic fuera.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removePanel,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Align(
                alignment: Alignment.topRight,
                child: _AlertsPanel(
                  alerts: widget.alerts,
                  onClose: _removePanel,
                  onMarkAllSeen: () {
                    widget.onMarkAllSeen();
                    _entry?.markNeedsBuild();
                  },
                  onMarkResolved: (id) {
                    widget.onMarkResolved(id);
                    _entry?.markNeedsBuild();
                  },
                  onOpenAlert: (a) {
                    _removePanel();
                    widget.onOpenAlert(a);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Tooltip(
        message: 'Alertas de recepción',
        child: InkWell(
          onTap: _togglePanel,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  widget.unseenCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: 22,
                  color: widget.unseenCount > 0
                      ? SaharaTheme.gold
                      : Colors.black54,
                ),
                if (widget.unseenCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD64545),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        widget.unseenCount > 99 ? '99+' : '${widget.unseenCount}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
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

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({
    required this.alerts,
    required this.onClose,
    required this.onMarkAllSeen,
    required this.onMarkResolved,
    required this.onOpenAlert,
  });

  final List<ReceptionAlert> alerts;
  final VoidCallback onClose;
  final VoidCallback onMarkAllSeen;
  final ValueChanged<String> onMarkResolved;
  final ValueChanged<ReceptionAlert> onOpenAlert;

  @override
  Widget build(BuildContext context) {
    // Pendientes (no resueltas) arriba; las resueltas como historial debajo.
    final pending = alerts.where((a) => !a.isResolved).toList();
    final resolved = alerts.where((a) => a.isResolved).toList();
    final unseen = alerts.where((a) => a.isUnseen).length;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0DDD8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Text(
                    'Alertas',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (unseen > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD64545),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unseen sin ver',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (unseen > 0)
                    TextButton(
                      onPressed: onMarkAllSeen,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        'Marcar todas vistas',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SaharaTheme.gold,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.black45,
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0DDD8)),
            // Lista
            Flexible(
              child: alerts.isEmpty
                  ? _empty()
                  : ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        ...pending.map(
                          (a) => _AlertTile(
                            alert: a,
                            onMarkResolved: () => onMarkResolved(a.id),
                            onTap: () => onOpenAlert(a),
                          ),
                        ),
                        if (resolved.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Text(
                              'ATENDIDAS',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                          ...resolved.map(
                            (a) => _AlertTile(
                              alert: a,
                              onMarkResolved: null,
                              onTap: () => onOpenAlert(a),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 40, color: Colors.black.withValues(alpha: 0.18)),
            const SizedBox(height: 10),
            Text(
              'Sin alertas por ahora',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      );
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.onMarkResolved,
    required this.onTap,
  });

  final ReceptionAlert alert;
  final VoidCallback? onMarkResolved;
  final VoidCallback onTap;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final dateLine = [
      if (alert.serviceName != null) alert.serviceName,
      if (alert.bookingDate != null)
        '${alert.bookingDate!.day.toString().padLeft(2, '0')}/'
            '${alert.bookingDate!.month.toString().padLeft(2, '0')}'
            '${alert.bookingTime != null ? ' · ${alert.bookingTime}' : ''}',
    ].whereType<String>().join('  ·  ');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: alert.isUnseen
              ? alert.accent.withValues(alpha: 0.05)
              : Colors.white,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFEFece8)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Punto sin ver + icono
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: alert.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(alert.icon, size: 16, color: alert.accent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (alert.isUnseen) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD64545),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        alert.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(alert.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.clientName ?? 'Cliente WhatsApp',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (dateLine.isNotEmpty)
                    Text(
                      dateLine,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  if (alert.amountMxn != null)
                    Text(
                      'Monto: \$${alert.amountMxn} MXN',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A9E65),
                      ),
                    ),
                  if ((alert.message ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        alert.message!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.chat_outlined,
                          size: 11, color: Colors.black38),
                      const SizedBox(width: 3),
                      Text(
                        alert.channel == 'whatsapp' ? 'WhatsApp' : alert.channel,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.black38,
                        ),
                      ),
                      const Spacer(),
                      if (onMarkResolved != null)
                        TextButton(
                          onPressed: onMarkResolved,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 28),
                            backgroundColor: alert.accent.withValues(alpha: 0.10),
                          ),
                          child: Text(
                            'Atendida',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: alert.accent,
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 12,
                                color: const Color(0xFF1A9E65)
                                    .withValues(alpha: 0.7)),
                            const SizedBox(width: 3),
                            Text(
                              'Atendida',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
