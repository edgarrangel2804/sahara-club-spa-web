import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class AgendaSaleDraft {
  const AgendaSaleDraft({
    required this.bookingId,
    required this.customerName,
    required this.serviceName,
    required this.subtotal,
    required this.total,
    this.branchId,
    this.customerId,
    this.profileClientId,
    this.professionalId,
    this.serviceId,
    this.notes = '',
    this.currency = 'MXN',
    this.tax = 0,
    this.discount = 0,
    this.durationMinutes,
  });

  final String bookingId;
  final String customerName;
  final String serviceName;
  final double subtotal;
  final double total;
  final String? branchId;
  final String? customerId;
  final String? profileClientId;
  final String? professionalId;
  final String? serviceId;
  final String notes;
  final String currency;
  final double tax;
  final double discount;
  final int? durationMinutes;
}

class AgendaSaleRecord {
  const AgendaSaleRecord({
    required this.id,
    required this.total,
    required this.status,
    required this.paymentStatus,
    required this.saleStatus,
  });

  final String id;
  final double total;
  final String status;
  final String paymentStatus;
  final String saleStatus;

  factory AgendaSaleRecord.fromMap(Map<String, dynamic> map) {
    return AgendaSaleRecord(
      id: map['id']?.toString() ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0,
      status: map['status']?.toString() ?? 'pending',
      paymentStatus: map['payment_status']?.toString() ?? map['status']?.toString() ?? 'pending',
      saleStatus: map['sale_status']?.toString() ?? 'open',
    );
  }
}

class AgendaSalesService {
  const AgendaSalesService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<AgendaSaleRecord?> findSaleForBooking(String bookingId) async {
    try {
      final data = await _client
          .from('sales')
          .select('id, total, status, payment_status, sale_status')
          .eq('appointment_id', bookingId)
          .maybeSingle();
      if (data != null) {
        return AgendaSaleRecord.fromMap(Map<String, dynamic>.from(data));
      }
    } catch (_) {}

    try {
      final data = await _client
          .from('sales')
          .select('id, total, status')
          .ilike('notes', '%[AGENDA:$bookingId]%')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data != null) {
        return AgendaSaleRecord.fromMap(Map<String, dynamic>.from(data));
      }
    } catch (_) {}

    return null;
  }

  Future<AgendaSaleRecord> ensureSaleForBooking(AgendaSaleDraft draft) async {
    final existing = await findSaleForBooking(draft.bookingId);
    if (existing != null) return existing;

    final saleId = _genUuid();
    final currentUserId = _client.auth.currentUser?.id;
    final legacyNote = [
      '[AGENDA:${draft.bookingId}]',
      'Venta generada automaticamente desde agenda.',
      if (draft.notes.trim().isNotEmpty) draft.notes.trim(),
    ].join(' ');

    try {
      await _client.from('sales').insert({
        'id': saleId,
        'branch_id': draft.branchId,
        'appointment_id': draft.bookingId,
        'customer_id': draft.customerId,
        'professional_id': draft.professionalId,
        'subtotal': draft.subtotal,
        'discount': draft.discount,
        'tax': draft.tax,
        'total': draft.total,
        'payment_status': 'pending',
        'sale_status': 'open',
        'created_by': currentUserId,
        'client_id': draft.profileClientId,
        'payment_method': 'pendiente',
        'status': 'pending',
        'notes': legacyNote,
      });
    } catch (_) {
      await _client.from('sales').insert({
        'id': saleId,
        'client_id': draft.profileClientId,
        'total': draft.total,
        'payment_method': 'pendiente',
        'status': 'pending',
        'notes': legacyNote,
      });
    }

    try {
      await _client.from('sale_items').insert({
        'id': _genUuid(),
        'sale_id': saleId,
        'service_id': draft.serviceId,
        'product_id': null,
        'description': draft.serviceName,
        'quantity': 1,
        'unit_price': draft.subtotal,
        'total_price': draft.total,
        'name': draft.serviceName,
        'price': draft.subtotal,
        'discount_pct': draft.subtotal <= 0
            ? 0
            : ((draft.discount / draft.subtotal) * 100).clamp(0, 100),
      });
    } catch (_) {
      await _client.from('sale_items').insert({
        'id': _genUuid(),
        'sale_id': saleId,
        'name': draft.serviceName,
        'price': draft.subtotal,
        'quantity': 1,
        'discount_pct': draft.subtotal <= 0
            ? 0
            : ((draft.discount / draft.subtotal) * 100).clamp(0, 100),
      });
    }

    await _insertPendingPayment(
      saleId: saleId,
      amount: draft.total,
      currency: draft.currency,
      notes: 'Pendiente de cobro generado desde agenda.',
    );

    return AgendaSaleRecord(
      id: saleId,
      total: draft.total,
      status: 'pending',
      paymentStatus: 'pending',
      saleStatus: 'open',
    );
  }

  // Canjea el gift card (vale de un solo uso) del cliente para el servicio de la
  // cita. Marca la tarjeta como redeemed vía RPC atómico. Lanza si no hay una
  // tarjeta válida, para abortar el cobro.
  Future<void> _redeemServiceGiftCard({
    String? bookingId,
    required double amount,
  }) async {
    final id = bookingId?.trim() ?? '';
    if (id.isEmpty) {
      throw Exception(
          'No se puede pagar con gift card: la venta no tiene una cita asociada.');
    }
    final booking = await _client
        .from('bookings')
        .select('client_record_id, service_id')
        .eq('id', id)
        .maybeSingle();
    final clientId = (booking?['client_record_id'] as String?)?.trim();
    final serviceId = (booking?['service_id'] as String?)?.trim();
    if (clientId == null || clientId.isEmpty ||
        serviceId == null || serviceId.isEmpty) {
      throw Exception(
          'La cita no tiene cliente o servicio para canjear el gift card.');
    }
    final res = await _client.rpc('redeem_service_gift_card', params: {
      'p_client_id': clientId,
      'p_service_id': serviceId,
      'p_booking_id': id,
      'p_amount': amount,
    });
    final map = Map<String, dynamic>.from(res as Map);
    if (map['ok'] != true) {
      throw Exception(map['error']?.toString() ?? 'No se pudo canjear el gift card.');
    }
  }

  Future<void> collectPayment({
    required String saleId,
    required String paymentMethod,
    required double baseTotal,
    String? bookingId,
    double tip = 0,
    double discount = 0,
    String notes = '',
  }) async {
    final double finalTotal = max(0.0, baseTotal - discount + tip).toDouble();
    final currentUserId = _client.auth.currentUser?.id;

    // Gift card de un solo uso por servicio: se canjea ANTES de marcar la venta
    // para poder abortar el cobro si el cliente no tiene una tarjeta válida para
    // este servicio. Si el canje falla, lanza y no se registra nada del cobro.
    if (paymentMethod == 'gift_card') {
      await _redeemServiceGiftCard(bookingId: bookingId, amount: finalTotal);
    }

    String existingNotes = '';

    try {
      final currentSale = await _client
          .from('sales')
          .select('notes')
          .eq('id', saleId)
          .maybeSingle();
      existingNotes = currentSale?['notes']?.toString() ?? '';
    } catch (_) {}

    final mergedNotes = [
      existingNotes.trim(),
      notes.trim(),
    ].where((value) => value.isNotEmpty).join('\n');

    try {
      await _client.from('sales').update({
        'subtotal': baseTotal,
        'discount': discount,
        'tax': 0,
        'total': finalTotal,
        'payment_method': paymentMethod,
        'payment_status': 'paid',
        'sale_status': 'completed',
        'status': 'paid',
        'created_by': currentUserId,
        'notes': mergedNotes,
      }).eq('id', saleId);
    } catch (_) {
      await _client.from('sales').update({
        'total': finalTotal,
        'payment_method': paymentMethod,
        'status': 'paid',
        'notes': mergedNotes,
      }).eq('id', saleId);
    }

    await _insertPaidPayment(
      saleId: saleId,
      amount: finalTotal,
      currency: 'MXN',
      paymentMethod: paymentMethod,
      notes: mergedNotes,
    );

    await _registerCashCollection(
      saleId: saleId,
      amount: finalTotal,
      paymentMethod: paymentMethod,
    );

    final linkedBookingId = bookingId?.trim();
    if (linkedBookingId != null && linkedBookingId.isNotEmpty) {
      try {
        await _client.from('bookings').update({
          'status': 'paid',
          'updated_by': currentUserId,
          'source_platform': 'pos_checkout',
        }).eq('id', linkedBookingId);
      } catch (_) {}
    }
  }

  Future<void> _insertPendingPayment({
    required String saleId,
    required double amount,
    required String currency,
    required String notes,
  }) async {
    try {
      await _client.from('payments').insert({
        'id': _genUuid(),
        'sale_id': saleId,
        'provider': 'internal',
        'status': 'pending',
        'amount': amount,
        'currency': currency,
        'raw_response': {
          'notes': notes,
          'source': 'agenda',
        },
      });
    } catch (_) {}
  }

  Future<void> _insertPaidPayment({
    required String saleId,
    required double amount,
    required String currency,
    required String paymentMethod,
    required String notes,
  }) async {
    try {
      await _client.from('payments').insert({
        'id': _genUuid(),
        'sale_id': saleId,
        'provider': paymentMethod,
        'status': 'paid',
        'amount': amount,
        'currency': currency,
        'raw_response': {
          'notes': notes,
          'source': 'pos',
          'payment_method': paymentMethod,
        },
      });
    } catch (_) {}
  }

  Future<void> _registerCashCollection({
    required String saleId,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      final sale = await _client
          .from('sales')
          .select('branch_id')
          .eq('id', saleId)
          .maybeSingle();
      final branchId = sale?['branch_id']?.toString();

      dynamic query = _client
          .from('cash_register_sessions')
          .select('id, expected_amount, notes')
          .eq('status', 'open');
      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('branch_id', branchId);
      }

      final session = await query
          .order('opened_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (session == null) return;

      final currentExpected =
          (session['expected_amount'] as num?)?.toDouble() ?? 0;
      final existingNotes = session['notes']?.toString().trim() ?? '';
      final newNote = 'Cobro registrado desde agenda/POS (${paymentMethod.trim()}).';
      await _client.from('cash_register_sessions').update({
        'expected_amount': currentExpected + amount,
        'notes': existingNotes.isEmpty ? newNote : '$existingNotes\n$newNote',
      }).eq('id', session['id']);
    } catch (_) {}
  }
}

String _genUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int n) => n.toRadixString(16).padLeft(2, '0');
  return '${h(b[0])}${h(b[1])}${h(b[2])}${h(b[3])}-'
      '${h(b[4])}${h(b[5])}-${h(b[6])}${h(b[7])}-'
      '${h(b[8])}${h(b[9])}-'
      '${h(b[10])}${h(b[11])}${h(b[12])}${h(b[13])}${h(b[14])}${h(b[15])}';
}
