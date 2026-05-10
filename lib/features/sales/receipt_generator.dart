import 'package:flutter/services.dart' show rootBundle;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

Future<void> printSaharaReceipt({
  required String saleId,
  required String clientName,
  required DateTime date,
  required String paymentMethod,
  required double total,
  required List<Map<String, dynamic>> items, // {name, qty, price, subtotal}
  required String status,
}) async {
  final fontRegular = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();
  
  // You can load your logo here if you have it in assets
  // final Uint8List logoBytes = (await rootBundle.load('assets/images/logo_black.png')).buffer.asUint8List();
  // final logo = pw.MemoryImage(logoBytes);

  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80, // 80mm thermal paper format, perfect for receipts
      margin: const pw.EdgeInsets.all(16),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Header
            pw.Text('SAHARA',
                style: pw.TextStyle(font: fontBold, fontSize: 24, letterSpacing: 2)),
            pw.Text('CLUB & SPA',
                style: pw.TextStyle(font: fontRegular, fontSize: 10, letterSpacing: 4)),
            pw.SizedBox(height: 12),
            pw.Text('Av. Reforma 123, Ensenada, B.C.',
                style: pw.TextStyle(font: fontRegular, fontSize: 8), textAlign: pw.TextAlign.center),
            pw.Text('Tel: (646) 123-4567',
                style: pw.TextStyle(font: fontRegular, fontSize: 8), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 12),

            // Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Recibo:', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                pw.Text('#${saleId.substring(0, 8).toUpperCase()}', style: pw.TextStyle(font: fontBold, fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Fecha:', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(date), style: pw.TextStyle(font: fontRegular, fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Cliente:', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                pw.Text(clientName, style: pw.TextStyle(font: fontBold, fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 12),

            // Items Header
            pw.Row(
              children: [
                pw.Expanded(flex: 2, child: pw.Text('CANT', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                pw.Expanded(flex: 5, child: pw.Text('DESCRIPCIÓN', style: pw.TextStyle(font: fontBold, fontSize: 8))),
                pw.Expanded(flex: 3, child: pw.Text('IMPORTE', style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.right)),
              ],
            ),
            pw.SizedBox(height: 8),

            // Items
            ...items.map((item) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 2, child: pw.Text('${item['qty']}', style: pw.TextStyle(font: fontRegular, fontSize: 9))),
                    pw.Expanded(flex: 5, child: pw.Text(item['name'], style: pw.TextStyle(font: fontRegular, fontSize: 9))),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('\$${(item['subtotal'] as num).toStringAsFixed(2)}',
                          style: pw.TextStyle(font: fontRegular, fontSize: 9), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 12),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.Text('\$${total.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 14)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Método de pago:', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                pw.Text(paymentMethod.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 9)),
              ],
            ),
            if (status == 'pending') ...[
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Estado:', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                  pw.Text('PENDIENTE', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.red800)),
                ],
              ),
            ],

            pw.SizedBox(height: 24),
            pw.Text('¡Gracias por su preferencia!',
                style: pw.TextStyle(font: fontBold, fontSize: 10), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Text('Este documento es un comprobante de venta. Consérvelo para cualquier aclaración.',
                style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 16),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => doc.save(),
    name: 'Sahara_Venta_${saleId.substring(0, 8)}',
  );
}
