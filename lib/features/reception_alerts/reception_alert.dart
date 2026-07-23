import 'package:flutter/material.dart';

/// Alerta interna para recepcion (tabla `reception_alerts`).
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
    this.orderId,
    this.orderItemId,
    this.giftCardId,
    this.paymentId,
    this.buyerName,
    this.buyerEmail,
    this.buyerPhone,
    this.productName,
    this.faceValue,
    this.amountPaid,
    this.currency,
    this.purchaseChannel,
    this.occurredAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String eventType;
  final String status;
  final String channel;
  final DateTime createdAt;
  final String? bookingId;
  final String? clientRecordId;
  final String? clientName;
  final String? clientPhone;
  final String? serviceName;
  final DateTime? bookingDate;
  final String? bookingTime;
  final String? message;
  final num? amountMxn;
  final String? orderId;
  final String? orderItemId;
  final String? giftCardId;
  final String? paymentId;
  final String? buyerName;
  final String? buyerEmail;
  final String? buyerPhone;
  final String? productName;
  final num? faceValue;
  final num? amountPaid;
  final String? currency;
  final String? purchaseChannel;
  final DateTime? occurredAt;
  final Map<String, dynamic> metadata;

  bool get isUnseen => status == 'unseen';
  bool get isResolved => status == 'resolved';
  bool get isGiftCardPurchase => eventType == 'gift_card_purchased';

  String get displayClientName {
    final candidate = isGiftCardPurchase ? buyerName : clientName;
    return _present(candidate) ??
        _present(clientName) ??
        (isGiftCardPurchase ? 'Comprador Gift Card' : 'Cliente WhatsApp');
  }

  String get recipientName =>
      _present(clientName) ??
      _present(metadata['recipient_name']) ??
      'Invitada Sahara';

  String? get displayProductName =>
      _present(productName) ?? _present(serviceName);

  String? get displayPhone {
    final raw = isGiftCardPurchase
        ? _present(metadata['recipient_phone_mask']) ?? _present(clientPhone)
        : _present(clientPhone);
    return maskDisplayPhone(raw);
  }

  String? get buyerPhoneMasked => maskDisplayPhone(buyerPhone);

  String? get giftCardCodeLast4 => _present(metadata['gift_card_code_last4']);

  String? get maskedGiftCardCode {
    final last4 = giftCardCodeLast4;
    if (last4 == null) return null;
    return '****$last4';
  }

  String? get validFrom => _present(metadata['valid_from']);
  String? get expiresOn => _present(metadata['expires_on']);
  String get deliveryStatus =>
      _present(metadata['delivery_status']) ?? 'pending';
  String get digitalAssetStatus =>
      _present(metadata['digital_asset_status']) ?? 'pending';
  String? get adminNotificationStatus =>
      _present(metadata['admin_notification_status']);
  bool get buyerCopyRequested =>
      _bool(metadata['buyer_copy_requested']) ||
      _present(metadata['buyer_copy_delivered_at']) != null;

  String get purchaseChannelLabel {
    final value = (_present(purchaseChannel) ?? channel).toLowerCase();
    switch (value) {
      case 'whatsapp':
        return 'WhatsApp';
      case 'web':
        return 'Pagina web';
      case 'reception':
        return 'Recepcion';
      case 'manual':
        return 'Venta manual';
      case 'admin':
        return 'Admin';
      case 'app':
        return 'App';
      case 'external':
        return 'Externo';
      default:
        return value.isEmpty ? 'Canal no identificado' : value;
    }
  }

  String? get validityLabel {
    final from = validFrom;
    final to = expiresOn;
    if (from == null && to == null) return null;
    if (from != null && to != null) return '$from a $to';
    return from ?? to;
  }

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

    num? parseNum(dynamic v) {
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '');
    }

    Map<String, dynamic> parseMetadata(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return const <String, dynamic>{};
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
      amountMxn: parseNum(m['amount_mxn']),
      orderId: m['order_id']?.toString(),
      orderItemId: m['order_item_id']?.toString(),
      giftCardId: m['gift_card_id']?.toString(),
      paymentId: m['payment_id']?.toString(),
      buyerName: m['buyer_name']?.toString(),
      buyerEmail: m['buyer_email']?.toString(),
      buyerPhone: m['buyer_phone']?.toString(),
      productName: m['product_name']?.toString(),
      faceValue: parseNum(m['face_value']),
      amountPaid: parseNum(m['amount_paid']),
      currency: m['currency']?.toString(),
      purchaseChannel: m['purchase_channel']?.toString(),
      occurredAt: parseDate(m['occurred_at']),
      metadata: parseMetadata(m['metadata']),
    );
  }

  String get title {
    switch (eventType) {
      case 'booking_pending_reception':
        return 'Cita nueva por validar';
      case 'booking_cancelled':
        return 'Cancelacion';
      case 'reschedule_requested':
        return 'Reagendamiento';
      case 'deposit_paid':
        return 'Pago de anticipo';
      case 'gift_card_purchased':
        return 'Gift Card adquirida';
      case 'requires_reception':
        return 'Requiere recepcion';
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
      case 'reschedule_requested':
        return Icons.update_outlined;
      case 'deposit_paid':
        return Icons.payments_outlined;
      case 'gift_card_purchased':
        return Icons.card_giftcard_outlined;
      case 'requires_reception':
        return Icons.priority_high_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get accent {
    switch (eventType) {
      case 'booking_pending_reception':
        return const Color(0xFF2D6CDF);
      case 'booking_cancelled':
        return const Color(0xFFD64545);
      case 'reschedule_requested':
        return const Color(0xFFE08A00);
      case 'deposit_paid':
        return const Color(0xFF1A9E65);
      case 'gift_card_purchased':
        return const Color(0xFFB7791F);
      case 'requires_reception':
        return const Color(0xFFB4232A);
      default:
        return Colors.black54;
    }
  }

  static String? _present(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }
}

String? maskDisplayPhone(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (raw.startsWith('***') || raw.startsWith('****')) return raw;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 4) return digits.isEmpty ? null : '****$digits';
  return '****${digits.substring(digits.length - 4)}';
}
