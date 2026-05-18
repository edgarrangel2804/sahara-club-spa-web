import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingSyncException implements Exception {
  const BookingSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BookingValidationResult {
  const BookingValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warningMessage,
  });

  final bool isValid;
  final String? errorMessage;
  final String? warningMessage;
}

class BookingUpsertData {
  const BookingUpsertData({
    this.bookingId,
    this.clientProfileId,
    this.clientRecordId,
    required this.clientName,
    required this.therapistId,
    required this.serviceId,
    required this.serviceName,
    required this.bookingDate,
    required this.bookingTime,
    required this.durationMinutes,
    required this.status,
    required this.notes,
    required this.sourcePlatform,
    this.branchId,
  });

  final String? bookingId;
  final String? clientProfileId;
  final String? clientRecordId;
  final String clientName;
  final String therapistId;
  final String serviceId;
  final String serviceName;
  final DateTime bookingDate;
  final String bookingTime;
  final int durationMinutes;
  final String status;
  final String notes;
  final String sourcePlatform;
  final String? branchId;
}

class BookingSyncService {
  const BookingSyncService();

  SupabaseClient get _client => Supabase.instance.client;

  RealtimeChannel subscribeToBookings({
    required String channelName,
    required VoidCallback onChanged,
  }) {
    return _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> fetchBookings({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? therapistId,
    String? branchId,
    String statusFilter = 'active',
  }) async {
    dynamic query = _client
        .from('bookings')
        .select('''
          id, client_id, client_record_id, service_id, sucursal_id, booking_date, booking_time,
          duration_min, status, therapist_id, client_notes, source_platform,
          client:profiles!bookings_client_id_fkey(full_name, phone),
          client_record:clients!bookings_client_record_id_fkey(full_name, phone),
          therapist:staff(full_name),
          services(name, price),
          sucursales(nombre, direccion_completa, link_maps)
        ''')
        .gte('booking_date', _yyyyMMdd(rangeStart))
        .lte('booking_date', _yyyyMMdd(rangeEnd));

    if (branchId != null && branchId.isNotEmpty) {
      query = query.eq('sucursal_id', branchId);
    }
    if (therapistId != null && therapistId.isNotEmpty) {
      query = query.eq('therapist_id', therapistId);
    }

    if (statusFilter == 'active') {
      query = query.or(
        'status.eq.scheduled,status.eq.pending,status.eq.confirmed,'
        'status.eq.checked_in,status.eq.in_progress,'
        'status.eq.completed,status.eq.awaiting_payment',
      );
    } else if (statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    final data = await query.order('booking_date').order('booking_time');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<String?> findClientRecordIdByName(String fullName) async {
    final normalized = fullName.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final row = await _client
        .from('clients')
        .select('id')
        .eq('full_name', normalized)
        .maybeSingle();
    return row?['id']?.toString();
  }

  Future<String?> _resolveValidClientRecordId({
    String? clientRecordId,
    String? clientName,
  }) async {
    final normalizedId = clientRecordId?.trim() ?? '';
    if (normalizedId.isNotEmpty) {
      try {
        final row = await _client
            .from('clients')
            .select('id')
            .eq('id', normalizedId)
            .maybeSingle();
        if (row != null) {
          return row['id']?.toString() ?? normalizedId;
        }
      } catch (_) {
        // If validation against clients fails, fall through to name lookup.
      }
    }
    final normalizedName = clientName?.trim() ?? '';
    if (normalizedName.isEmpty) {
      return null;
    }
    return findClientRecordIdByName(normalizedName);
  }

  Future<BookingValidationResult> validateBookingDraft(
    BookingUpsertData data,
  ) async {
    if ((data.clientRecordId ?? '').trim().isEmpty &&
        (data.clientProfileId ?? '').trim().isEmpty) {
      return const BookingValidationResult(
        isValid: false,
        errorMessage: 'Selecciona o crea un cliente antes de guardar la reserva.',
      );
    }
    if (data.therapistId.trim().isEmpty) {
      return const BookingValidationResult(
        isValid: false,
        errorMessage: 'Selecciona un terapeuta o profesional.',
      );
    }
    if (data.serviceId.trim().isEmpty) {
      return const BookingValidationResult(
        isValid: false,
        errorMessage: 'Selecciona un servicio para continuar.',
      );
    }
    if (data.bookingTime.trim().isEmpty || !_isValidTime(data.bookingTime)) {
      return const BookingValidationResult(
        isValid: false,
        errorMessage: 'La hora de la reserva no es valida.',
      );
    }
    if (data.durationMinutes <= 0) {
      return const BookingValidationResult(
        isValid: false,
        errorMessage: 'La duracion del servicio debe ser mayor a cero.',
      );
    }

    String? warning;
    final clientRecordId = data.clientRecordId?.trim();
    if (clientRecordId != null && clientRecordId.isNotEmpty) {
      try {
        final client = await _client
            .from('clients')
            .select('phone')
            .eq('id', clientRecordId)
            .maybeSingle();
        final phone = client?['phone']?.toString().trim() ?? '';
        if (phone.isEmpty) {
          warning =
              'El cliente no tiene telefono registrado. La reserva se puede guardar, pero conviene completar ese dato.';
        }
      } catch (_) {
        warning = 'No se pudo validar el telefono del cliente.';
      }
    }

    try {
      final existing = await _client
          .from('bookings')
          .select('id, booking_time, duration_min, status')
          .eq('booking_date', _yyyyMMdd(data.bookingDate))
          .eq('therapist_id', data.therapistId)
          .not('status', 'in', '(cancelled,no_show)')
          .order('booking_time');

      final start = _minutesFromTime(data.bookingTime);
      final end = start + data.durationMinutes;

      for (final raw in (existing as List)) {
        final row = Map<String, dynamic>.from(raw as Map);
        final existingId = row['id']?.toString() ?? '';
        if (existingId.isNotEmpty && existingId == data.bookingId) {
          continue;
        }
        final otherStart =
            _minutesFromTime(row['booking_time']?.toString() ?? '00:00:00');
        final otherDuration = (row['duration_min'] as num?)?.toInt() ?? 60;
        final otherEnd = otherStart + otherDuration;
        final overlaps = start < otherEnd && end > otherStart;
        if (overlaps) {
          return BookingValidationResult(
            isValid: false,
            errorMessage:
                'Ya existe una cita en conflicto para este terapeuta en ese horario.',
            warningMessage: warning,
          );
        }
      }
    } on PostgrestException catch (error) {
      return BookingValidationResult(
        isValid: false,
        errorMessage:
            'No se pudo validar el horario contra Supabase: ${error.message}',
        warningMessage: warning,
      );
    } catch (_) {
      return BookingValidationResult(
        isValid: false,
        errorMessage:
            'No se pudo validar el horario. Revisa tu conexion e intenta de nuevo.',
        warningMessage: warning,
      );
    }

    return BookingValidationResult(
      isValid: true,
      warningMessage: warning,
    );
  }

  Future<Map<String, dynamic>?> upsertBooking(BookingUpsertData data) async {
    final normalizedClientRecordId = await _resolveValidClientRecordId(
      clientRecordId: data.clientRecordId,
      clientName: data.clientName,
    );
    final normalizedData = BookingUpsertData(
      bookingId: data.bookingId,
      clientProfileId: data.clientProfileId?.trim().isEmpty == true
          ? null
          : data.clientProfileId?.trim(),
      clientRecordId: normalizedClientRecordId,
      clientName: data.clientName,
      therapistId: data.therapistId,
      serviceId: data.serviceId,
      serviceName: data.serviceName,
      bookingDate: data.bookingDate,
      bookingTime: data.bookingTime,
      durationMinutes: data.durationMinutes,
      status: data.status,
      notes: data.notes,
      sourcePlatform: data.sourcePlatform,
      branchId: data.branchId,
    );
    final validation = await validateBookingDraft(normalizedData);
    if (!validation.isValid) {
      throw BookingSyncException(validation.errorMessage ?? 'Reserva invalida.');
    }

    final currentUserId = _client.auth.currentUser?.id;
    final payload = {
      'client_id': normalizedData.clientProfileId,
      'client_record_id': normalizedData.clientRecordId,
      'therapist_id': normalizedData.therapistId,
      'sucursal_id': normalizedData.branchId,
      'service_id': normalizedData.serviceId,
      'booking_date': _yyyyMMdd(normalizedData.bookingDate),
      'booking_time': normalizedData.bookingTime,
      'duration_min': normalizedData.durationMinutes,
      'status': normalizedData.status,
      'client_notes': normalizedData.notes.trim(),
      'service_name': normalizedData.serviceName,
      'source_platform': normalizedData.sourcePlatform,
      'updated_by': currentUserId,
    };

    try {
      if (normalizedData.bookingId != null && normalizedData.bookingId!.isNotEmpty) {
        return await _client
            .from('bookings')
            .update(payload)
            .eq('id', normalizedData.bookingId!)
            .select('''
              id, client_id, client_record_id, service_id, sucursal_id, booking_date, booking_time,
              duration_min, status, therapist_id, client_notes, source_platform,
              client:profiles!bookings_client_id_fkey(full_name, phone),
              client_record:clients!bookings_client_record_id_fkey(full_name, phone),
              therapist:staff(full_name),
              services(name, price),
              sucursales(nombre, direccion_completa, link_maps)
            ''')
            .maybeSingle();
      }

      return await _client
          .from('bookings')
          .insert({
            ...payload,
            'created_by': currentUserId,
          })
          .select('''
            id, client_id, client_record_id, service_id, sucursal_id, booking_date, booking_time,
            duration_min, status, therapist_id, client_notes, source_platform,
            client:profiles!bookings_client_id_fkey(full_name, phone),
            client_record:clients!bookings_client_record_id_fkey(full_name, phone),
            therapist:staff(full_name),
            services(name, price),
            sucursales(nombre, direccion_completa, link_maps)
          ''')
          .maybeSingle();
    } on PostgrestException catch (error) {
      throw BookingSyncException(_mapPostgrestError(error));
    } on TimeoutException {
      throw const BookingSyncException(
        'Supabase no respondio a tiempo. Intenta de nuevo en unos segundos.',
      );
    } catch (_) {
      throw const BookingSyncException(
        'No se pudo guardar la reserva. Revisa tu conexion e intenta de nuevo.',
      );
    }
  }

  String _mapPostgrestError(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('duplicate') || message.contains('unique')) {
      return 'Ya existe una reserva similar con esos datos.';
    }
    if (message.contains('permission') || message.contains('policy')) {
      return 'Tu usuario no tiene permiso para modificar esta reserva.';
    }
    if (message.contains('network') || message.contains('fetch')) {
      return 'No hay conexion con Supabase en este momento.';
    }
    return 'Supabase reporto un error al guardar la reserva: ${error.message}';
  }

  static bool _isValidTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) {
      return false;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return false;
    }
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  static int _minutesFromTime(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return hour * 60 + minute;
  }

  static String _yyyyMMdd(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
