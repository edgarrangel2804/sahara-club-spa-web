import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/sahara_theme.dart';
import 'reception_alert.dart';

const _giftCardActionsFunction = 'gift_card_reception_actions';

bool isValidGiftCardId(String? value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch((value ?? '').trim());
}

Map<String, String> giftCardReceptionActionPayload({
  required String giftCardId,
  required String action,
}) {
  final cleanId = giftCardId.trim();
  if (!isValidGiftCardId(cleanId)) {
    throw ArgumentError('invalid_gift_card_id');
  }
  final cleanAction = action.trim();
  if (!{
    'view',
    'download_link',
    'resend_recipient',
    'send_buyer_copy',
  }.contains(cleanAction)) {
    throw ArgumentError('invalid_gift_card_action');
  }
  return {'gift_card_id': cleanId, 'action': cleanAction};
}

bool isSafeGiftCardAssetUrl(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty || raw.length > 4096) return false;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  final local = host == 'localhost' || host == '127.0.0.1';
  if (local) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  } else if (uri.scheme != 'https') {
    return false;
  }
  return host == 'saharaclubspa.com' ||
      host == 'www.saharaclubspa.com' ||
      host.endsWith('.supabase.co') ||
      local;
}

String sanitizeGiftCardReceptionActionError(Object? error) {
  final raw = error?.toString().toLowerCase() ?? '';
  if (raw.contains('invalid_gift_card_id')) {
    return 'La Gift Card no tiene un identificador valido.';
  }
  if (raw.contains('invalid_action')) {
    return 'La accion solicitada no esta disponible.';
  }
  if (raw.contains('buyer_copy_not_requested')) {
    return 'Esta compra no solicito copia para el comprador.';
  }
  if (raw.contains('caller_not_authorized') || raw.contains('403')) {
    return 'Tu usuario no tiene permiso para operar esta Gift Card.';
  }
  if (raw.contains('missing_bearer') ||
      raw.contains('invalid_token') ||
      raw.contains('401')) {
    return 'Tu sesion expiro. Vuelve a iniciar sesion.';
  }
  if (raw.contains('not_found') || raw.contains('404')) {
    return 'No encontramos la Gift Card solicitada.';
  }
  if (raw.contains('network') || raw.contains('fetch')) {
    return 'No se pudo conectar con Supabase. Intenta de nuevo.';
  }
  return 'No se pudo completar la accion de la Gift Card.';
}

class GiftCardReceptionSnapshot {
  const GiftCardReceptionSnapshot({
    required this.giftCardId,
    this.recipientPhoneMasked,
    this.purchaserPhoneMasked,
    this.purchaserName,
    this.recipientName,
    this.serviceName,
    this.validFrom,
    this.expiresOn,
    this.digitalAssetStatus,
    this.deliveryStatus,
    this.buyerCopyRequested = false,
    this.status,
  });

  final String giftCardId;
  final String? recipientPhoneMasked;
  final String? purchaserPhoneMasked;
  final String? purchaserName;
  final String? recipientName;
  final String? serviceName;
  final String? validFrom;
  final String? expiresOn;
  final String? digitalAssetStatus;
  final String? deliveryStatus;
  final bool buyerCopyRequested;
  final String? status;

  factory GiftCardReceptionSnapshot.fromMap(Map<String, dynamic> map) {
    String? text(String key) {
      final value = map[key]?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }

    return GiftCardReceptionSnapshot(
      giftCardId: text('gift_card_id') ?? '',
      recipientPhoneMasked: text('recipient_phone_masked'),
      purchaserPhoneMasked: text('purchaser_phone_masked'),
      purchaserName: text('purchaser_name'),
      recipientName: text('recipient_name'),
      serviceName: text('service_name'),
      validFrom: text('valid_from'),
      expiresOn: text('expires_on'),
      digitalAssetStatus: text('digital_asset_status'),
      deliveryStatus: text('delivery_status'),
      buyerCopyRequested: map['buyer_copy_requested'] == true,
      status: text('status'),
    );
  }
}

class GiftCardReceptionActionResponse {
  const GiftCardReceptionActionResponse({
    required this.ok,
    required this.action,
    this.downloadUrl,
    this.downloadTokenReceived = false,
    this.assetStatus,
    this.deliveryStatus,
    this.error,
    this.reception,
  });

  final bool ok;
  final String action;
  final String? downloadUrl;
  final bool downloadTokenReceived;
  final String? assetStatus;
  final String? deliveryStatus;
  final String? error;
  final GiftCardReceptionSnapshot? reception;

  Uri? get safeDownloadUri {
    if (!isSafeGiftCardAssetUrl(downloadUrl)) return null;
    return Uri.tryParse(downloadUrl!);
  }

  factory GiftCardReceptionActionResponse.fromMap(Map<String, dynamic> map) {
    GiftCardReceptionSnapshot? snapshot;
    final rawReception = map['reception'];
    if (rawReception is Map<String, dynamic>) {
      snapshot = GiftCardReceptionSnapshot.fromMap(rawReception);
    } else if (rawReception is Map) {
      snapshot = GiftCardReceptionSnapshot.fromMap(
        rawReception.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    return GiftCardReceptionActionResponse(
      ok: map['ok'] == true,
      action: map['action']?.toString() ?? '',
      downloadUrl: map['download_url']?.toString(),
      downloadTokenReceived:
          (map['download_token']?.toString().trim().isNotEmpty ?? false),
      assetStatus: map['asset_status']?.toString(),
      deliveryStatus: map['delivery_status']?.toString(),
      error: map['error']?.toString(),
      reception: snapshot,
    );
  }

  factory GiftCardReceptionActionResponse.fromFunctionData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return GiftCardReceptionActionResponse.fromMap(data);
    }
    if (data is Map) {
      return GiftCardReceptionActionResponse.fromMap(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return const GiftCardReceptionActionResponse(
      ok: false,
      action: '',
      error: 'invalid_response',
    );
  }
}

class GiftCardReceptionActionGate {
  bool _busy = false;
  bool _disposed = false;

  bool get busy => _busy;
  bool get disposed => _disposed;

  void dispose() {
    _disposed = true;
    _busy = false;
  }

  Future<T?> run<T>(Future<T> Function() action) async {
    if (_busy || _disposed) return null;
    _busy = true;
    try {
      final result = await action();
      return _disposed ? null : result;
    } finally {
      if (!_disposed) _busy = false;
    }
  }
}

Future<GiftCardReceptionActionResponse> runGiftCardReceptionAction(
  SupabaseClient client, {
  required String giftCardId,
  required String action,
}) async {
  final dynamic response = await client.functions.invoke(
    _giftCardActionsFunction,
    body: giftCardReceptionActionPayload(
      giftCardId: giftCardId,
      action: action,
    ),
  );
  return GiftCardReceptionActionResponse.fromFunctionData(response.data);
}

Future<void> showGiftCardReceptionDialog(
  BuildContext context,
  ReceptionAlert alert,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _GiftCardReceptionDialog(alert: alert),
  );
}

class _GiftCardReceptionDialog extends StatefulWidget {
  const _GiftCardReceptionDialog({required this.alert});

  final ReceptionAlert alert;

  @override
  State<_GiftCardReceptionDialog> createState() =>
      _GiftCardReceptionDialogState();
}

class _GiftCardReceptionDialogState extends State<_GiftCardReceptionDialog> {
  final GiftCardReceptionActionGate _gate = GiftCardReceptionActionGate();
  GiftCardReceptionActionResponse? _lastResult;
  String? _busyAction;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _gate.dispose();
    super.dispose();
  }

  ReceptionAlert get _alert => widget.alert;
  GiftCardReceptionSnapshot? get _snapshot => _lastResult?.reception;
  bool get _busy => _busyAction != null;

  String get _recipientName => _snapshot?.recipientName ?? _alert.recipientName;
  String get _buyerName => _snapshot?.purchaserName ?? _alert.displayClientName;
  String get _productName =>
      _snapshot?.serviceName ?? _alert.displayProductName ?? 'Gift Card Sahara';
  String get _validity => [
    _snapshot?.validFrom ?? _alert.validFrom,
    _snapshot?.expiresOn ?? _alert.expiresOn,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' a ');
  String get _deliveryStatus =>
      _snapshot?.deliveryStatus ??
      _lastResult?.deliveryStatus ??
      _alert.deliveryStatus;
  String get _assetStatus =>
      _snapshot?.digitalAssetStatus ??
      _lastResult?.assetStatus ??
      _alert.digitalAssetStatus;
  bool get _buyerCopyRequested =>
      _snapshot?.buyerCopyRequested ?? _alert.buyerCopyRequested;
  String? get _recipientPhone =>
      maskDisplayPhone(_snapshot?.recipientPhoneMasked) ?? _alert.displayPhone;
  String? get _buyerPhone =>
      maskDisplayPhone(_snapshot?.purchaserPhoneMasked) ??
      _alert.buyerPhoneMasked;

  Future<void> _runAction(String action, {bool openDownload = false}) async {
    final giftCardId = _alert.giftCardId;
    if (!isValidGiftCardId(giftCardId)) {
      setState(() {
        _error = sanitizeGiftCardReceptionActionError('invalid_gift_card_id');
        _message = null;
      });
      return;
    }

    setState(() {
      _busyAction = action;
      _error = null;
      _message = null;
    });

    final result = await _gate.run(
      () => runGiftCardReceptionAction(
        Supabase.instance.client,
        giftCardId: giftCardId!,
        action: action,
      ),
    );
    if (!mounted) return;
    setState(() {
      _busyAction = null;
      if (result != null) _lastResult = result;
    });
    if (result == null) return;

    if (!result.ok) {
      setState(() {
        _error = sanitizeGiftCardReceptionActionError(result.error);
        _message = null;
      });
      return;
    }

    if (openDownload) {
      final uri = result.safeDownloadUri;
      if (uri == null) {
        setState(() {
          _error = 'El enlace de la tarjeta no es valido.';
          _message = null;
        });
        return;
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() {
        _message = opened
            ? 'Tarjeta abierta en una ventana segura.'
            : 'No se pudo abrir la tarjeta.';
        _error = opened ? null : _message;
      });
      return;
    }

    setState(() {
      _message = switch (action) {
        'view' => 'Estado actualizado.',
        'resend_recipient' => 'Reenvio solicitado para la destinataria.',
        'send_buyer_copy' => 'Copia solicitada para el comprador.',
        _ => 'Accion completada.',
      };
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = _alert.accent;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      title: Row(
        children: [
          Icon(Icons.card_giftcard_outlined, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gift Card',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusStrip(),
            const SizedBox(height: 14),
            _DetailRow(label: 'Comprador', value: _buyerName),
            _DetailRow(label: 'Destinataria', value: _recipientName),
            if (_recipientPhone != null)
              _DetailRow(
                label: 'Telefono destinataria',
                value: _recipientPhone!,
              ),
            if (_buyerPhone != null)
              _DetailRow(label: 'Telefono comprador', value: _buyerPhone!),
            _DetailRow(label: 'Experiencia', value: _productName),
            if (_alert.amountPaid != null)
              _DetailRow(
                label: 'Monto',
                value:
                    '\$${_alert.amountPaid!.toStringAsFixed(2)} ${(_alert.currency ?? 'MXN').toUpperCase()}',
              ),
            if (_validity.isNotEmpty)
              _DetailRow(label: 'Vigencia', value: _validity),
            _DetailRow(label: 'Tarjeta digital', value: _assetStatus),
            _DetailRow(label: 'Entrega', value: _deliveryStatus),
            if (_alert.adminNotificationStatus != null)
              _DetailRow(
                label: 'Aviso admin',
                value: _alert.adminNotificationStatus!,
              ),
            _DetailRow(
              label: 'Copia comprador',
              value: _buyerCopyRequested ? 'Solicitada' : 'No solicitada',
            ),
            if (_message != null || _error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (_error == null
                              ? const Color(0xFF1A9E65)
                              : const Color(0xFFD64545))
                          .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error ?? _message!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _error == null
                        ? const Color(0xFF1A9E65)
                        : const Color(0xFFD64545),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        TextButton.icon(
          onPressed: _busy ? null : () => _runAction('view'),
          icon: _busyAction == 'view'
              ? _spinner()
              : const Icon(Icons.refresh_outlined),
          label: Text(_busyAction == 'view' ? 'Actualizando...' : 'Actualizar'),
        ),
        TextButton.icon(
          onPressed: _busy
              ? null
              : () => _runAction('download_link', openDownload: true),
          icon: _busyAction == 'download_link'
              ? _spinner()
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            _busyAction == 'download_link' ? 'Abriendo...' : 'Abrir PDF',
          ),
        ),
        TextButton.icon(
          onPressed: _busy ? null : () => _runAction('resend_recipient'),
          icon: _busyAction == 'resend_recipient'
              ? _spinner()
              : const Icon(Icons.send_outlined),
          label: Text(
            _busyAction == 'resend_recipient' ? 'Enviando...' : 'Reenviar',
          ),
        ),
        TextButton.icon(
          onPressed: _busy || !_buyerCopyRequested
              ? null
              : () => _runAction('send_buyer_copy'),
          icon: _busyAction == 'send_buyer_copy'
              ? _spinner()
              : const Icon(Icons.content_copy_outlined),
          label: Text(
            _busyAction == 'send_buyer_copy' ? 'Enviando...' : 'Copia',
          ),
        ),
      ],
    );
  }

  Widget _statusStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SaharaTheme.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _alert.purchaseChannelLabel,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: SaharaTheme.gold,
        ),
      ),
    );
  }

  Widget _spinner() {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
