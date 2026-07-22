import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _gold = Color(0xFFC6A76A);

String _folio(String id) =>
    'SAHARA-${id.replaceAll('-', '').substring(0, 8).toUpperCase()}';

/// Muestra el comprobante PDF del anticipo de una cita para que recepción lo
/// abra/descargue y se lo reenvíe al cliente por WhatsApp.
///
/// Lee el PDF directamente del bucket privado `receipts` (lo generó el webhook
/// de Stripe al confirmarse el pago) mediante una URL firmada. Evita llamar a
/// la edge function desde el navegador (que fallaba en el build web).
Future<void> showDepositReceiptDialog(BuildContext context, String bookingId) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: _gold)),
  );

  String? url;
  try {
    url = await Supabase.instance.client.storage
        .from('receipts')
        .createSignedUrl('$bookingId.pdf', 60 * 60 * 24 * 7);
  } catch (_) {
    url = null;
  }

  if (!context.mounted) return;
  Navigator.of(context).pop(); // cierra el loading

  if (url == null) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Comprobante'),
        content: const Text(
          'Aún no hay comprobante generado para esta cita.\n\n'
          'El comprobante se crea automáticamente cuando el cliente paga el '
          'anticipo. Si la cita se confirmó sin anticipo (cliente frecuente, '
          'gift card o membresía), no genera comprobante.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Comprobante de anticipo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Folio: ${_folio(bookingId)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Text(
            'Para enviárselo al cliente:\n'
            '1) Toca "Ver / Descargar PDF" (se abre/descarga).\n'
            '2) Abre el chat del cliente (botón "Abrir chat") y adjunta el PDF.\n\n'
            'Nota: al pagar, el comprobante ya se le envió automáticamente por '
            'WhatsApp; esto es por si necesitas reenviárselo.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.picture_as_pdf, color: _gold),
          label: const Text('Ver / Descargar PDF'),
          onPressed: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    ),
  );
}
