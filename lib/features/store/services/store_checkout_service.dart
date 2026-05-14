import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';
import '../models/store_product.dart';

class StoreCheckoutService {
  const StoreCheckoutService();

  Future<CheckoutSessionResult> createCheckoutSession({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String notes,
    required List<CartItem> items,
    required CheckoutPricing pricing,
    required String successUrl,
    required String cancelUrl,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'create_checkout_session',
      body: <String, dynamic>{
        'customer_name': customerName,
        'customer_email': customerEmail,
        'customer_phone': customerPhone,
        'notes': notes,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
        'pricing': pricing.toJson(),
        'items': items.map(_serializeCartItem).toList(growable: false),
      },
    );

    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    if (response.status >= 400) {
      throw CheckoutException(
        data['error']?.toString() ?? 'No se pudo crear la sesion de pago.',
      );
    }

    return CheckoutSessionResult.fromMap(data);
  }

  Future<CheckoutConfirmationResult> confirmOrderPayment({
    String? orderId,
    String? sessionId,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'confirm_order_payment',
      body: <String, dynamic>{
        if (orderId != null && orderId.isNotEmpty) 'order_id': orderId,
        if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
      },
    );

    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    if (response.status >= 400) {
      throw CheckoutException(
        data['error']?.toString() ?? 'No se pudo confirmar el pago.',
      );
    }

    return CheckoutConfirmationResult.fromMap(data);
  }

  Map<String, dynamic> _serializeCartItem(CartItem item) {
    return <String, dynamic>{
      'product_id': item.product.id,
      'base_product_id': item.product.checkoutMetadata['base_product_id']?.toString(),
      'name': item.product.name,
      'description': item.product.description,
      'short_description': item.product.shortDescription,
      'unit_price': item.product.price,
      'currency': item.product.currency,
      'quantity': item.quantity,
      'product_type': _typeKey(item.product.type),
      'image_url': item.product.imageUrl,
      'duration_minutes': item.product.durationMinutes,
      'category_key': item.product.categoryKey,
      'category_label': item.product.categoryLabel,
      'metadata': item.product.checkoutMetadata,
    };
  }

  String _typeKey(StoreProductType type) {
    switch (type) {
      case StoreProductType.service:
        return 'service';
      case StoreProductType.digital:
        return 'digital';
      case StoreProductType.physical:
        return 'physical';
      case StoreProductType.membership:
        return 'membership';
      case StoreProductType.giftCard:
        return 'gift_card';
    }
  }
}

class CheckoutPricing {
  const CheckoutPricing({
    required this.subtotal,
    required this.memberCredit,
    required this.serviceCharge,
    required this.total,
  });

  final double subtotal;
  final double memberCredit;
  final double serviceCharge;
  final double total;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'subtotal': subtotal,
      'member_credit': memberCredit,
      'service_charge': serviceCharge,
      'total': total,
    };
  }
}

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
  });

  final String orderId;
  final String status;
  final String paymentStatus;

  factory CheckoutConfirmationResult.fromMap(Map<String, dynamic> map) {
    return CheckoutConfirmationResult(
      orderId: map['order_id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      paymentStatus: map['payment_status']?.toString() ?? '',
    );
  }
}

class CheckoutException implements Exception {
  const CheckoutException(this.message);

  final String message;

  @override
  String toString() => message;
}
