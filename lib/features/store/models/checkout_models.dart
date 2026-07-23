class CheckoutSessionResult {
  const CheckoutSessionResult({
    required this.orderId,
    required this.sessionId,
    required this.checkoutUrl,
  });

  final String orderId;
  final String sessionId;
  final String checkoutUrl;

  factory CheckoutSessionResult.fromMap(Map<String, dynamic> map) {
    return CheckoutSessionResult(
      orderId: map['order_id']?.toString() ?? '',
      sessionId: map['session_id']?.toString() ?? '',
      checkoutUrl: map['checkout_url']?.toString() ?? '',
    );
  }
}

class CheckoutConfirmationResult {
  const CheckoutConfirmationResult({
    required this.orderId,
    required this.status,
    required this.paymentStatus,
    this.giftCards = const <GiftCardCheckoutToken>[],
  });

  final String orderId;
  final String status;
  final String paymentStatus;
  final List<GiftCardCheckoutToken> giftCards;

  factory CheckoutConfirmationResult.fromMap(Map<String, dynamic> map) {
    return CheckoutConfirmationResult(
      orderId: map['order_id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      paymentStatus: map['payment_status']?.toString() ?? '',
      giftCards: (map['gift_cards'] is List)
          ? (map['gift_cards'] as List)
                .whereType<Map>()
                .map(
                  (item) => GiftCardCheckoutToken.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <GiftCardCheckoutToken>[],
    );
  }
}

class GiftCardCheckoutToken {
  const GiftCardCheckoutToken({
    required this.giftCardId,
    required this.downloadToken,
    required this.recipientName,
    required this.serviceName,
    required this.validFrom,
    required this.expiresOn,
    required this.assetStatus,
    required this.deliveryStatus,
    required this.status,
  });

  final String giftCardId;
  final String downloadToken;
  final String recipientName;
  final String serviceName;
  final String validFrom;
  final String expiresOn;
  final String assetStatus;
  final String deliveryStatus;
  final String status;

  factory GiftCardCheckoutToken.fromMap(Map<String, dynamic> map) {
    return GiftCardCheckoutToken(
      giftCardId: map['gift_card_id']?.toString() ?? '',
      downloadToken: map['download_token']?.toString() ?? '',
      recipientName: map['recipient_name']?.toString() ?? '',
      serviceName: map['service_name']?.toString() ?? '',
      validFrom: map['valid_from']?.toString() ?? '',
      expiresOn: map['expires_on']?.toString() ?? '',
      assetStatus: map['digital_asset_status']?.toString() ?? 'pending',
      deliveryStatus: map['delivery_status']?.toString() ?? 'pending',
      status: map['status']?.toString() ?? 'active',
    );
  }
}

class GiftCardDownloadResult {
  const GiftCardDownloadResult({
    required this.ok,
    required this.downloadUrl,
    required this.assetStatus,
    required this.deliveryStatus,
    required this.card,
  });

  final bool ok;
  final String downloadUrl;
  final String assetStatus;
  final String deliveryStatus;
  final GiftCardPublicCard card;

  factory GiftCardDownloadResult.fromMap(Map<String, dynamic> map) {
    final cardMap = map['card'] is Map
        ? Map<String, dynamic>.from(map['card'] as Map)
        : <String, dynamic>{};
    return GiftCardDownloadResult(
      ok: map['ok'] == true,
      downloadUrl: map['download_url']?.toString() ?? '',
      assetStatus: map['asset_status']?.toString() ?? 'pending',
      deliveryStatus: map['delivery_status']?.toString() ?? 'pending',
      card: GiftCardPublicCard.fromMap(cardMap),
    );
  }
}

class GiftCardPublicCard {
  const GiftCardPublicCard({
    required this.id,
    required this.code,
    required this.folio,
    required this.serviceName,
    required this.recipientName,
    required this.senderName,
    required this.dedicationMessage,
    required this.validFrom,
    required this.expiresOn,
    required this.status,
    required this.currency,
    required this.amount,
  });

  final String id;
  final String code;
  final String folio;
  final String serviceName;
  final String recipientName;
  final String senderName;
  final String dedicationMessage;
  final String validFrom;
  final String expiresOn;
  final String status;
  final String currency;
  final double amount;

  factory GiftCardPublicCard.fromMap(Map<String, dynamic> map) {
    return GiftCardPublicCard(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      folio: map['folio']?.toString() ?? '',
      serviceName: map['service_name']?.toString() ?? '',
      recipientName: map['recipient_name']?.toString() ?? '',
      senderName: map['sender_name']?.toString() ?? '',
      dedicationMessage: map['dedication_message']?.toString() ?? '',
      validFrom: map['valid_from']?.toString() ?? '',
      expiresOn: map['expires_on']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      currency: map['currency']?.toString() ?? 'MXN',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
