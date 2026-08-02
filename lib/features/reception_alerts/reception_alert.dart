import 'package:flutter/material.dart';

/// Alerta interna para recepción (tabla `reception_alerts`).
/// Eventos importantes originados por el cliente (sobre todo WhatsApp IA) que
/// recepción debe ver de inmediato en el panel.
class ReceptionAlert {
  const ReceptionAlert({
    required this.id,
    required this.eventType,
    required this.status,
    required this.channel,
    required this.createdAt,
    this.bookingId,
    this.clientRecordId,
    this.clientName,
    this.clientPhone,
    this.serviceName,
    this.bookingDate,
    this.bookingTime,
    this.message,
    this.amountMxn,
  });

  final String id;
  final String eventType; // booking_pending_reception | booking_cancelled | reschedule_requested | deposit_paid | requires_reception
  final String status; // unseen | seen | resolved
  final String channel;
  final DateTime createdAt;
  final String? bookingId;
  final String? clientRecordId;
  final String? clientName;
  final String? clientPhone;
  final String? serviceName;
  final DateTime? bookingDate;
  final String? bookingTime; // HH:MM
  final String? message;
  final num? amountMxn;

  bool get isUnseen => status == 'unseen';
  bool get isResolved => status == 'resolved';

  factory ReceptionAlert.fromMap(Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    String? parseTime(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return s.length >= 5 ? s.substring(0, 5) : s;
    }

    return ReceptionAlert(
      id: m['id'].toString(),
      eventType: (m['event_type'] ?? '').toString(),
      status: (m['status'] ?? 'unseen').toString(),
      channel: (m['channel'] ?? 'whatsapp').toString(),
      createdAt: parseDate(m['created_at']) ?? DateTime.now(),
      bookingId: m['booking_id']?.toString(),
      clientRecordId: m['client_record_id']?.toString(),
      clientName: m['client_name']?.toString(),
      clientPhone: m['client_phone']?.toString(),
      serviceName: m['service_name']?.toString(),
      bookingDate: parseDate(m['booking_date']),
      bookingTime: parseTime(m['booking_time']),
      message: m['message']?.toString(),
      amountMxn: m['amount_mxn'] is num
          ? m['amount_mxn'] as num
          : num.tryParse(m['amount_mxn']?.toString() ?? ''),
    );
  }

  /// Título legible del evento.
  String get title {
    switch (eventType) {
      case 'booking_pending_reception':
        return 'Cita nueva por validar';
      case 'booking_cancelled':
        return 'Cancelación';
      case 'cancel_requested':
        return 'Solicitud de cancelación';
      case 'reschedule_requested':
        return 'Reagendamiento';
      case 'deposit_paid':
        return 'Pago de anticipo';
      case 'requires_reception':
        return 'Requiere recepción';
      case 'gift_card_purchased':
        return 'Compra de gift card';
      default:
        return 'Evento';
    }
  }

  IconData get icon {
    switch (eventType) {
      case 'booking_pending_reception':
        return Icons.event_available_outlined;
      case 'booking_cancelled':
        return Icons.event_busy_outlined;
      case 'cancel_requested':
        return Icons.cancel_outlined;
      case 'reschedule_requested':
        return Icons.update_outlined;
      case 'deposit_paid':
        return Icons.payments_outlined;
      case 'requires_reception':
        return Icons.priority_high_rounded;
      case 'gift_card_purchased':
        return Icons.card_giftcard_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get accent {
    switch (eventType) {
      case 'booking_pending_reception':
        return const Color(0xFF2D6CDF); // azul (acción: validar + asignar)
      case 'booking_cancelled':
        return const Color(0xFFD64545); // rojo
      case 'cancel_requested':
        return const Color(0xFFE2571E); // naranja (solicitud: recepción ejecuta)
      case 'reschedule_requested':
        return const Color(0xFFE08A00); // ámbar
      case 'deposit_paid':
        return const Color(0xFF1A9E65); // verde
      case 'requires_reception':
        return const Color(0xFFB4232A); // rojo intenso (acción humana)
      case 'gift_card_purchased':
        return const Color(0xFF7C3AED); // violeta (compra en tienda web)
      default:
        return Colors.black54;
    }
  }
}
