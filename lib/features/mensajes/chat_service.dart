import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.conversationType,
    required this.customerId,
    required this.customerName,
    required this.receptionistId,
    required this.receptionistName,
    required this.professionalId,
    required this.professionalName,
    required this.adminId,
    required this.adminName,
    required this.reservationId,
    required this.reservationStatus,
    required this.subject,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String id;
  final String conversationType;
  final String? customerId;
  final String customerName;
  final String? receptionistId;
  final String receptionistName;
  final String? professionalId;
  final String professionalName;
  final String? adminId;
  final String adminName;
  final String? reservationId;
  final String reservationStatus;
  final String subject;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;

  ChatConversation copyWith({int? unreadCount}) {
    return ChatConversation(
      id: id,
      conversationType: conversationType,
      customerId: customerId,
      customerName: customerName,
      receptionistId: receptionistId,
      receptionistName: receptionistName,
      professionalId: professionalId,
      professionalName: professionalName,
      adminId: adminId,
      adminName: adminName,
      reservationId: reservationId,
      reservationStatus: reservationStatus,
      subject: subject,
      lastMessagePreview: lastMessagePreview,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  // Returns the display title for a conversation given the current user's role.
  String titleForRole(String role) {
    switch (_normalizeRole(role)) {
      case 'client':
        return 'Recepcion Sahara';
      case 'therapist':
        if (receptionistName.isNotEmpty) return receptionistName;
        if (adminName.isNotEmpty) return adminName;
        return subject.isNotEmpty ? subject : 'Recepcion';
      case 'admin':
      case 'super_admin':
      case 'reception':
        if (customerName.trim().isNotEmpty && customerName != 'Cliente') {
          return customerName;
        }
        if (professionalName.trim().isNotEmpty && professionalName != 'Terapeuta') {
          return professionalName;
        }
        if (adminName.trim().isNotEmpty) return adminName;
        if (receptionistName.trim().isNotEmpty) return receptionistName;
        return subject.isNotEmpty ? subject : 'Conversacion';
      default:
        return subject.isNotEmpty ? subject : 'Conversacion';
    }
  }

  String subtitleForRole(String role) {
    final normalized = _normalizeRole(role);
    if (normalized == 'client') {
      return subject.isNotEmpty ? subject : 'Atencion de reservas';
    }
    if (professionalName.isNotEmpty && normalized != 'therapist') {
      return professionalName;
    }
    if (customerName.isNotEmpty && normalized == 'therapist') {
      return 'Coordina con recepcion';
    }
    if (subject.isNotEmpty) {
      return subject;
    }
    return 'Chat interno';
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.messageText,
    required this.messageType,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole;
  final String messageText;
  final String messageType;
  final bool isRead;
  final DateTime createdAt;
}

class NewConversationDraft {
  const NewConversationDraft({
    required this.subject,
    this.customerId,
    this.professionalId,
    this.reservationId,
  });

  final String subject;
  final String? customerId;
  final String? professionalId;
  final String? reservationId;
}

class ChatService {
  const ChatService();

  SupabaseClient get _client => Supabase.instance.client;

  String? get _myId => _client.auth.currentUser?.id;

  Future<String> currentUserRole() async {
    final userId = _myId;
    if (userId == null) return 'guest';
    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    return _normalizeRole(profile?['role']?.toString());
  }

  Future<List<ChatConversation>> loadConversations() async {
    final userId = _myId;
    if (userId == null) return const [];

    // 1. Load all chats where the current user is a participant.
    final chatsRaw = await _client
        .from('chats')
        .select('id, participant_1, participant_2, created_at')
        .or('participant_1.eq.$userId,participant_2.eq.$userId');

    final chatsList = chatsRaw as List;
    if (chatsList.isEmpty) return const [];

    // 2. Collect all unique participant IDs and load their profiles in one query.
    final profileIds = <String>{};
    for (final c in chatsList) {
      profileIds.add(c['participant_1'] as String);
      profileIds.add(c['participant_2'] as String);
    }

    final profilesRaw = await _client
        .from('profiles')
        .select('id, full_name, role')
        .inFilter('id', profileIds.toList());

    final profileById = <String, Map<String, dynamic>>{};
    for (final p in profilesRaw as List) {
      final map = Map<String, dynamic>.from(p as Map);
      profileById[map['id'] as String] = map;
    }

    // 3. Load recent messages for all chats to derive last-message preview and unread count.
    final chatIds = chatsList.map((c) => c['id'] as String).toList();
    final msgsRaw = await _client
        .from('messages')
        .select('id, chat_id, sender_id, content, read_at, created_at')
        .inFilter('chat_id', chatIds)
        .order('created_at', ascending: false)
        .limit(500);

    final msgsByChat = <String, List<Map<String, dynamic>>>{};
    for (final m in msgsRaw as List) {
      final cid = m['chat_id'] as String;
      msgsByChat.putIfAbsent(cid, () => []).add(Map<String, dynamic>.from(m as Map));
    }

    // 4. Build ChatConversation objects.
    final conversations = chatsList.map((chat) {
      final chatId    = chat['id'] as String;
      final p1Id      = chat['participant_1'] as String;
      final p2Id      = chat['participant_2'] as String;
      final otherId   = (p1Id == userId) ? p2Id : p1Id;

      final myProfile    = profileById[userId];
      final otherProfile = profileById[otherId];
      final myRole       = myProfile?['role'] as String? ?? '';
      final otherRole    = otherProfile?['role'] as String? ?? '';
      final otherName    = otherProfile?['full_name'] as String? ?? 'Usuario';

      final msgs    = msgsByChat[chatId] ?? [];
      final lastMsg = msgs.isNotEmpty ? msgs.first : null;
      final unread  = msgs.where((m) =>
          m['sender_id'] != userId && m['read_at'] == null,
      ).length;

      String? customerId, receptionistId, professionalId, adminId;
      String customerName = '', receptionistName = '', professionalName = '', adminName = '';

      void assign(String? id, String? name, String? role) {
        switch (_normalizeRole(role)) {
          case 'client':
            customerId = id;
            customerName = name ?? '';
          case 'reception':
            receptionistId = id;
            receptionistName = name ?? '';
          case 'therapist':
            professionalId = id;
            professionalName = name ?? '';
          case 'admin':
          case 'super_admin':
            adminId = id;
            adminName = name ?? '';
        }
      }

      assign(userId, myProfile?['full_name'] as String?, myRole);
      assign(otherId, otherName, otherRole);

      return ChatConversation(
        id: chatId,
        conversationType: _convType(myRole, otherRole),
        customerId: customerId,
        customerName: customerName,
        receptionistId: receptionistId,
        receptionistName: receptionistName,
        professionalId: professionalId,
        professionalName: professionalName,
        adminId: adminId,
        adminName: adminName,
        reservationId: null,
        reservationStatus: '',
        subject: '',
        lastMessagePreview: lastMsg?['content'] as String? ?? '',
        lastMessageAt: lastMsg != null
            ? DateTime.tryParse(lastMsg['created_at'] as String? ?? '')
            : null,
        unreadCount: unread,
      );
    }).toList();

    conversations.sort((a, b) =>
        (b.lastMessageAt ?? DateTime(0)).compareTo(a.lastMessageAt ?? DateTime(0)));
    return conversations;
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    // Load participant roles so we can label each message bubble by role.
    final chatRow = await _client
        .from('chats')
        .select('participant_1, participant_2')
        .eq('id', conversationId)
        .maybeSingle();

    final roleById = <String, String>{};
    if (chatRow != null) {
      final pIds = [chatRow['participant_1'] as String, chatRow['participant_2'] as String];
      final profiles = await _client
          .from('profiles')
          .select('id, role')
          .inFilter('id', pIds);
      for (final p in profiles as List) {
        roleById[p['id'] as String] = p['role'] as String? ?? '';
      }
    }

    final rows = await _client
        .from('messages')
        .select('id, chat_id, sender_id, content, read_at, created_at')
        .eq('chat_id', conversationId)
        .order('created_at', ascending: true);

    final messages = (rows as List).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return ChatMessage(
        id:             m['id'] as String,
        conversationId: m['chat_id'] as String,
        senderId:       m['sender_id'] as String,
        senderRole:     roleById[m['sender_id'] as String] ?? '',
        messageText:    m['content'] as String? ?? '',
        messageType:    'text',
        isRead:         m['read_at'] != null,
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();

    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  Future<ChatConversation> createConversation(NewConversationDraft draft) async {
    final userId = _myId;
    if (userId == null) throw const ChatException('No hay sesion activa.');

    final otherId = (draft.customerId?.isNotEmpty == true)
        ? draft.customerId
        : draft.professionalId;
    if (otherId == null || otherId.isEmpty) {
      throw const ChatException('Debe seleccionar un contacto.');
    }

    // Reuse an existing chat between the same two participants.
    final existing = await _client
        .from('chats')
        .select('id')
        .or('and(participant_1.eq.$userId,participant_2.eq.$otherId),'
            'and(participant_1.eq.$otherId,participant_2.eq.$userId)')
        .maybeSingle();

    final String chatId;
    if (existing != null) {
      chatId = existing['id'] as String;
    } else {
      try {
        final created = await _client
            .from('chats')
            .insert({'participant_1': userId, 'participant_2': otherId})
            .select('id')
            .single();
        chatId = created['id'] as String;
      } on PostgrestException catch (e) {
        throw ChatException('No se pudo crear la conversacion: ${e.message}');
      }
    }

    final conversations = await loadConversations();
    try {
      return conversations.firstWhere((c) => c.id == chatId);
    } catch (_) {
      throw const ChatException('No se pudo cargar la conversacion creada.');
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String messageType = 'text',
  }) async {
    final userId = _myId;
    if (userId == null) throw const ChatException('No hay sesion activa.');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await _client.from('messages').insert({
        'chat_id':   conversationId,
        'sender_id': userId,
        'content':   trimmed,
      });
    } on PostgrestException catch (e) {
      throw ChatException('No se pudo enviar el mensaje: ${e.message}');
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    try {
      await _client
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('chat_id', conversationId)
          .isFilter('read_at', null);
    } catch (e) {
      debugPrint('markConversationRead (non-fatal): $e');
    }
  }

  Future<int> unreadCount() async {
    final userId = _myId;
    if (userId == null) return 0;
    try {
      final chatsRaw = await _client
          .from('chats')
          .select('id')
          .or('participant_1.eq.$userId,participant_2.eq.$userId');
      final chatIds = (chatsRaw as List).map((c) => c['id'] as String).toList();
      if (chatIds.isEmpty) return 0;
      final rows = await _client
          .from('messages')
          .select('id')
          .inFilter('chat_id', chatIds)
          .isFilter('read_at', null)
          .neq('sender_id', userId);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  RealtimeChannel subscribeToConversations({required VoidCallback onChanged}) {
    return _client
        .channel('chats-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToMessages({required VoidCallback onChanged}) {
    return _client
        .channel('messages-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => onChanged(),
        )
        .subscribe();
  }
}

String _convType(String myRole, String otherRole) {
  if (_normalizeRole(myRole) == 'client' || _normalizeRole(otherRole) == 'client') {
    return 'customer_support';
  }
  return 'staff_coordination';
}

String _normalizeRole(String? role) {
  final value = (role ?? '').trim().toLowerCase();
  if (value == 'receptionist') return 'reception';
  return value.isEmpty ? 'guest' : value;
}

String _reservationLabel(String status) {
  switch (status) {
    case 'pending':         return 'pendiente';
    case 'confirmed':       return 'confirmada';
    case 'checked_in':      return 'check-in';
    case 'in_progress':     return 'en proceso';
    case 'completed':       return 'completada';
    case 'awaiting_payment': return 'pendiente de cobro';
    case 'paid':            return 'pagada';
    case 'cancelled':       return 'cancelada';
    case 'rescheduled':     return 'reagendada';
    case 'no_show':         return 'no show';
    default:                return status;
  }
}
