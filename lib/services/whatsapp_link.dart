// Sahara Club Spa - Helper único para abrir WhatsApp desde la landing.
// Centraliza número real, mensaje precargado y modo de apertura (web/mobile/desktop).

import 'package:url_launcher/url_launcher.dart';

class SaharaWhatsApp {
  /// Número oficial de Sahara Club Spa en formato wa.me (sin "+", sin espacios).
  /// 52 (país) + 6464961145 (número). El "1" intermedio de móviles MX NO se usa en wa.me.
  static const String phone = '526464961145';

  /// Mensaje por defecto que se precarga en el chat al abrir desde la landing.
  static const String defaultMessage =
      'Hola, me gustaría recibir información y reservar una experiencia en Sahara Club Spa ✨';

  /// Construye el URL wa.me con mensaje codificado.
  static Uri buildUri({String? message}) {
    final text = (message?.trim().isEmpty ?? true) ? defaultMessage : message!.trim();
    final encoded = Uri.encodeComponent(text);
    return Uri.parse('https://wa.me/$phone?text=$encoded');
  }

  /// Abre WhatsApp. En web abre en nueva pestaña; en mobile/desktop usa el handler nativo.
  /// Devuelve true si se intentó la apertura, false si url_launcher rechazó.
  static Future<bool> openWhatsApp({String? message}) async {
    final uri = buildUri(message: message);
    // platformDefault funciona bien tanto en mobile (intent) como web (nueva pestaña).
    return launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}
