import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _gold = Color(0xFFC6A76A);

String depositReceiptFolio(String bookingId) {
  final compact = bookingId.replaceAll('-', '');
  if (compact.length < 8) return 'SAHARA';
  return 'SAHARA-${compact.substring(0, 8).toUpperCase()}';
}

bool isValidBookingId(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value.trim());
}

bool isSafeReceiptUrl(String? value) {
  final uri = Uri.tryParse((value ?? '').trim());
  if (uri == null || !uri.hasAbsolutePath || value!.trim().length > 4096) {
    return false;
  }
  final host = uri.host.toLowerCase();
  final local = host == 'localhost' || host == '127.0.0.1';
  if (local) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  } else if (uri.scheme != 'https') {
    return false;
  }
  if (uri.host.isEmpty) return false;
  if (uri.userInfo.isNotEmpty) return false;
  if (!isAllowedReceiptHost(host)) return false;
  final voucherToken = uri.queryParameters['voucher_token'];
  if (voucherToken != null && !isValidVoucherTokenString(voucherToken)) {
    return false;
  }
  return true;
}

bool isAllowedReceiptHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'saharaclubspa.com' ||
      normalized == 'www.saharaclubspa.com' ||
      normalized == 'fkbyxhwdcsgrrixalzwf.supabase.co' ||
      normalized.endsWith('.supabase.co') ||
      normalized == 'localhost' ||
      normalized == '127.0.0.1';
}

bool isValidVoucherTokenString(String? value) {
  return RegExp(
    r'^[A-Za-z0-9_-]{40,1800}\.[A-Za-z0-9_-]{32,220}$',
  ).hasMatch((value ?? '').trim());
}

Map<String, String> sendDepositReceiptPayload(String bookingId) {
  if (!isValidBookingId(bookingId)) {
    throw ArgumentError('invalid_booking_id');
  }
  return {'booking_id': bookingId};
}

String redactReceiptToken(String? value) {
  final raw = (value ?? '').trim();
  final uri = Uri.tryParse(raw);
  if (uri == null) return '[invalid-url]';
  final params = Map<String, String>.from(uri.queryParameters);
  if (params.containsKey('voucher_token')) {
    params['voucher_token'] = '[redacted]';
  }
  if (params.containsKey('token')) {
    params['token'] = '[redacted]';
  }
  return uri
      .replace(queryParameters: params.isEmpty ? null : params)
      .toString();
}

Uri? buildAuthorizedReceiptPageUri({
  required Uri pageBaseUri,
  required String voucherToken,
}) {
  final token = voucherToken.trim();
  if (!isValidVoucherTokenString(token)) return null;
  final uri = pageBaseUri.replace(
    queryParameters: {'voucher_token': token},
    fragment: null,
  );
  return isSafeReceiptUrl(uri.toString()) ? uri : null;
}

String sanitizeReceiptError(Object? error) {
  final raw = error?.toString().toLowerCase() ?? '';
  if (raw.contains('booking') && raw.contains('required')) {
    return 'Falta identificar la cita.';
  }
  if (raw.contains('invalid_booking')) {
    return 'La cita no tiene un identificador valido.';
  }
  if (raw.contains('not_paid') ||
      raw.contains('payment_required') ||
      raw.contains('deposit_not_paid')) {
    return 'El anticipo aun no esta confirmado como pagado.';
  }
  if (raw.contains('not_found')) {
    return 'No encontramos comprobante para esta cita.';
  }
  if (raw.contains('network') || raw.contains('fetch')) {
    return 'No se pudo conectar con Supabase. Intenta de nuevo.';
  }
  return 'No se pudo completar la accion del comprobante.';
}

class DepositReceiptResponse {
  const DepositReceiptResponse({
    required this.ok,
    this.folio,
    this.signedUrl,
    this.whatsappSent = false,
    this.error,
  });

  final bool ok;
  final String? folio;
  final String? signedUrl;
  final bool whatsappSent;
  final String? error;

  factory DepositReceiptResponse.fromMap(Map<String, dynamic> map) {
    return DepositReceiptResponse(
      ok: map['ok'] == true,
      folio: map['folio']?.toString(),
      signedUrl: map['signed_url']?.toString(),
      whatsappSent: map['whatsapp_sent'] == true,
      error: map['error']?.toString(),
    );
  }

  factory DepositReceiptResponse.fromFunctionData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return DepositReceiptResponse.fromMap(data);
    }
    if (data is Map) {
      return DepositReceiptResponse.fromMap(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return const DepositReceiptResponse(ok: false, error: 'invalid_response');
  }
}

class AuthorizedReceiptLinkResponse {
  const AuthorizedReceiptLinkResponse({required this.ok, this.url, this.error});

  final bool ok;
  final String? url;
  final String? error;

  Uri? get safeUri {
    final value = url;
    if (!isSafeReceiptUrl(value)) return null;
    return Uri.tryParse(value!);
  }

  factory AuthorizedReceiptLinkResponse.fromMap(Map<String, dynamic> map) {
    return AuthorizedReceiptLinkResponse(
      ok: map['ok'] == true,
      url: map['url']?.toString() ?? map['receipt_url']?.toString(),
      error: map['error']?.toString(),
    );
  }

  factory AuthorizedReceiptLinkResponse.fromFunctionData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return AuthorizedReceiptLinkResponse.fromMap(data);
    }
    if (data is Map) {
      return AuthorizedReceiptLinkResponse.fromMap(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return const AuthorizedReceiptLinkResponse(
      ok: false,
      error: 'invalid_response',
    );
  }
}

class DepositReceiptActionGate {
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

Future<String?> loadSignedDepositReceiptUrl(
  SupabaseClient client,
  String bookingId,
) async {
  if (!isValidBookingId(bookingId)) {
    throw ArgumentError('invalid_booking_id');
  }
  final url = await client.storage
      .from('receipts')
      .createSignedUrl('$bookingId.pdf', 60 * 60 * 24 * 7);
  return isSafeReceiptUrl(url) ? url : null;
}

Future<DepositReceiptResponse> sendDepositReceipt(
  SupabaseClient client,
  String bookingId,
) async {
  if (!isValidBookingId(bookingId)) {
    return const DepositReceiptResponse(ok: false, error: 'invalid_booking_id');
  }
  final dynamic response = await client.functions.invoke(
    'send_deposit_receipt',
    body: sendDepositReceiptPayload(bookingId),
  );
  return DepositReceiptResponse.fromFunctionData(response.data);
}

Future<void> showDepositReceiptDialog(BuildContext context, String bookingId) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DepositReceiptDialog(bookingId: bookingId),
  );
}

class _DepositReceiptDialog extends StatefulWidget {
  const _DepositReceiptDialog({required this.bookingId});

  final String bookingId;

  @override
  State<_DepositReceiptDialog> createState() => _DepositReceiptDialogState();
}

class _DepositReceiptDialogState extends State<_DepositReceiptDialog> {
  final DepositReceiptActionGate _gate = DepositReceiptActionGate();
  bool _loading = true;
  bool _sending = false;
  String? _signedUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _gate.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final url = await loadSignedDepositReceiptUrl(
        Supabase.instance.client,
        widget.bookingId,
      );
      if (!mounted) return;
      setState(() {
        _signedUrl = url;
        _loading = false;
        _error = url == null
            ? 'No encontramos comprobante para esta cita.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = sanitizeReceiptError(error);
      });
    }
  }

  Future<void> _openReceipt() async {
    final url = _signedUrl;
    if (!isSafeReceiptUrl(url)) {
      _showMessage('El enlace del comprobante no es valido.');
      return;
    }
    final opened = await launchUrl(
      Uri.parse(url!),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showMessage('No se pudo abrir el comprobante.');
    }
  }

  Future<void> _sendExplicitly() async {
    setState(() => _sending = true);
    final result = await _gate.run(
      () => sendDepositReceipt(Supabase.instance.client, widget.bookingId),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (result == null) return;
    if (!result.ok) {
      _showMessage(sanitizeReceiptError(result.error));
      return;
    }
    final signedUrl = result.signedUrl;
    setState(() {
      if (isSafeReceiptUrl(signedUrl)) {
        _signedUrl = signedUrl;
        _error = null;
      }
    });
    _showMessage(
      result.whatsappSent
          ? 'Comprobante enviado por WhatsApp.'
          : 'Comprobante generado. WhatsApp no confirmado; puedes descargarlo.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Comprobante de anticipo'),
      content: SizedBox(
        width: 380,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: _gold)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Folio: ${depositReceiptFolio(widget.bookingId)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (_signedUrl != null)
                    const Text(
                      'El comprobante existe y puede abrirse de forma segura. '
                      'Para reenviarlo por WhatsApp usa la accion explicita.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    )
                  else
                    Text(
                      _error ??
                          'Aun no hay comprobante generado para esta cita.',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        if (_signedUrl != null)
          TextButton.icon(
            icon: const Icon(Icons.picture_as_pdf, color: _gold),
            label: const Text('Ver / Descargar'),
            onPressed: _sending ? null : _openReceipt,
          ),
        TextButton.icon(
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined, color: _gold),
          label: Text(_sending ? 'Procesando...' : 'Reenviar WhatsApp'),
          onPressed: _sending ? null : _sendExplicitly,
        ),
      ],
    );
  }
}
