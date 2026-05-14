import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_service.dart';

class MensajesModule extends StatefulWidget {
  const MensajesModule({
    super.key,
    this.initialConversationId,
    this.embedded = false,
  });

  final String? initialConversationId;
  final bool embedded;

  @override
  State<MensajesModule> createState() => _MensajesModuleState();
}

class _MensajesModuleState extends State<MensajesModule> {
  final ChatService _chatService = const ChatService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();

  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _messagesChannel;
  Timer? _reloadDebounce;

  String _role = 'guest';
  String? _currentUserId;
  bool _loading = true;
  bool _messagesLoading = false;
  bool _sending = false;
  String? _error;
  String _search = '';

  List<ChatConversation> _conversations = [];
  ChatConversation? _selectedConversation;
  List<ChatMessage> _messages = [];

  bool get _canCreateConversation {
    return _role == 'admin' || _role == 'super_admin' || _role == 'reception';
  }

  int get _totalUnread =>
      _conversations.fold(0, (total, item) => total + item.unreadCount);

  List<ChatConversation> get _filteredConversations {
    if (_search.trim().isEmpty) {
      return _conversations;
    }
    final query = _search.trim().toLowerCase();
    return _conversations.where((conversation) {
      return conversation.titleForRole(_role).toLowerCase().contains(query) ||
          conversation.subtitleForRole(_role).toLowerCase().contains(query) ||
          conversation.lastMessagePreview.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    _messagesScrollController.dispose();
    _reloadDebounce?.cancel();
    if (_conversationsChannel != null) {
      Supabase.instance.client.removeChannel(_conversationsChannel!);
    }
    if (_messagesChannel != null) {
      Supabase.instance.client.removeChannel(_messagesChannel!);
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = await _chatService.currentUserRole();
      final conversations = await _chatService.loadConversations();
      if (!mounted) {
        return;
      }
      final selected = _resolveSelection(
        conversations,
        widget.initialConversationId ?? _selectedConversation?.id,
      );
      setState(() {
        _role = role;
        _conversations = conversations;
        _selectedConversation = selected;
        _loading = false;
      });
      _subscribeRealtime();
      if (selected != null) {
        await _loadMessages(selected.id);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo cargar el chat interno: $error';
        _loading = false;
      });
    }
  }

  void _subscribeRealtime() {
    _conversationsChannel ??= _chatService.subscribeToConversations(
      onChanged: _scheduleRefresh,
    );
    _messagesChannel ??= _chatService.subscribeToMessages(
      onChanged: _scheduleRefresh,
    );
  }

  void _scheduleRefresh() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _refreshConversations(preserveSelection: true);
      if (_selectedConversation != null) {
        await _loadMessages(_selectedConversation!.id, quiet: true);
      }
    });
  }

  ChatConversation? _resolveSelection(
    List<ChatConversation> conversations,
    String? selectedId,
  ) {
    if (conversations.isEmpty) {
      return null;
    }
    if (selectedId == null) {
      return conversations.first;
    }
    for (final conversation in conversations) {
      if (conversation.id == selectedId) {
        return conversation;
      }
    }
    return conversations.first;
  }

  Future<void> _refreshConversations({bool preserveSelection = false}) async {
    try {
      final conversations = await _chatService.loadConversations();
      if (!mounted) {
        return;
      }
      final selectedId =
          preserveSelection ? _selectedConversation?.id : null;
      setState(() {
        _conversations = conversations;
        _selectedConversation = _resolveSelection(conversations, selectedId);
      });
    } catch (_) {}
  }

  Future<void> _loadMessages(String conversationId, {bool quiet = false}) async {
    if (!quiet) {
      setState(() => _messagesLoading = true);
    }
    try {
      final messages = await _chatService.loadMessages(conversationId);
      await _chatService.markConversationRead(conversationId);
      final conversations = await _chatService.loadConversations();
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = messages;
        _conversations = conversations;
        _selectedConversation =
            _resolveSelection(conversations, conversationId);
        _messagesLoading = false;
      });
      _scrollMessagesToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messagesLoading = false;
        _error = 'No se pudo cargar la conversacion: $error';
      });
    }
  }

  Future<void> _handleSelectConversation(ChatConversation conversation) async {
    setState(() {
      _selectedConversation = conversation;
      _messages = const [];
    });
    await _loadMessages(conversation.id);
  }

  Future<void> _handleSendMessage() async {
    final conversation = _selectedConversation;
    final text = _messageController.text.trim();
    if (conversation == null || text.isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      await _chatService.sendMessage(
        conversationId: conversation.id,
        text: text,
      );
      _messageController.clear();
      await _loadMessages(conversation.id, quiet: true);
      _scrollMessagesToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar el mensaje: $error'),
          backgroundColor: const Color(0xFFB32D2D),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _scrollMessagesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScrollController.hasClients) {
        return;
      }
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openNewConversationDialog() async {
    final created = await showDialog<ChatConversation>(
      context: context,
      builder: (_) => const _NewConversationDialog(),
    );
    if (created == null || !mounted) {
      return;
    }
    await _refreshConversations(preserveSelection: false);
    await _handleSelectConversation(created);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return _ChatEmptyState(
        icon: Icons.wifi_tethering_error_rounded,
        title: 'Chat interno no disponible',
        message: _error!,
      );
    }

    if (widget.embedded) {
      return _selectedConversation == null
          ? const _ChatEmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'Conversacion no disponible',
              message:
                  'No se encontro una conversacion valida para esta reserva.',
            )
          : Column(
              children: [
                _ConversationHeader(
                  conversation: _selectedConversation!,
                  role: _role,
                ),
                Expanded(
                  child: _messagesLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _messages.isEmpty
                          ? const _ChatEmptyState(
                              icon: Icons.forum_outlined,
                              title: 'Sin mensajes',
                              message:
                                  'Esta conversacion ya existe, pero todavia no tiene mensajes.',
                            )
                          : ListView.builder(
                              controller: _messagesScrollController,
                              reverse: false,
                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final mine = message.senderId == _currentUserId;
                                return _MessageBubble(
                                  message: message,
                                  mine: mine,
                                );
                              },
                            ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFEAE6DF))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Escribe un mensaje interno',
                            filled: true,
                            fillColor: const Color(0xFFF7F3EC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _sending ? null : _handleSendMessage,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A9E65),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(112, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Enviar',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
    }

    return Row(
      children: [
        SizedBox(
          width: 340,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFEAE6DF))),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFEAE6DF))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Mensajes internos',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1D1A17),
                            ),
                          ),
                          const Spacer(),
                          if (_totalUnread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC6A76A).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$_totalUnread',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF8A672D),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cliente, recepcion, terapeutas y admin sincronizados en Supabase.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.45,
                          color: const Color(0xFF7B746B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _search = value),
                        decoration: InputDecoration(
                          hintText: 'Buscar conversacion',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF7F3EC),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (_canCreateConversation) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _openNewConversationDialog,
                            icon: const Icon(Icons.add_comment_outlined, size: 18),
                            label: Text(
                              'Nueva conversacion',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFC6A76A),
                              foregroundColor: const Color(0xFF20170E),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredConversations.isEmpty
                      ? const _ChatEmptyState(
                          icon: Icons.mark_chat_unread_outlined,
                          title: 'Sin conversaciones',
                          message:
                              'Cuando un cliente o el equipo escriban aqui apareceran sus conversaciones.',
                        )
                      : ListView.builder(
                          itemCount: _filteredConversations.length,
                          itemBuilder: (context, index) {
                            final conversation = _filteredConversations[index];
                            final selected =
                                _selectedConversation?.id == conversation.id;
                            return _ConversationTile(
                              conversation: conversation,
                              role: _role,
                              selected: selected,
                              onTap: () => _handleSelectConversation(conversation),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _selectedConversation == null
              ? const _ChatEmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'Selecciona una conversacion',
                  message:
                      'Elige un chat de la izquierda para ver mensajes, cambios de reserva y coordinacion interna.',
                )
              : Column(
                  children: [
                    _ConversationHeader(
                      conversation: _selectedConversation!,
                      role: _role,
                    ),
                    Expanded(
                      child: _messagesLoading
                          ? const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _messages.isEmpty
                              ? const _ChatEmptyState(
                                  icon: Icons.forum_outlined,
                                  title: 'Sin mensajes',
                                  message:
                                      'Esta conversacion ya existe, pero todavia no tiene mensajes.',
                                )
                              : ListView.builder(
                                  controller: _messagesScrollController,
                                  reverse: false,
                                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _messages[index];
                                    final mine =
                                        message.senderId == _currentUserId;
                                    return _MessageBubble(
                                      message: message,
                                      mine: mine,
                                    );
                                  },
                                ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFEAE6DF))),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              style: GoogleFonts.inter(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Escribe un mensaje interno',
                                filled: true,
                                fillColor: const Color(0xFFF7F3EC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _sending ? null : _handleSendMessage,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1A9E65),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(112, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Enviar',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final ChatConversation conversation;
  final String role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = conversation.titleForRole(role);
    final subtitle = conversation.lastMessagePreview.trim().isNotEmpty
        ? conversation.lastMessagePreview
        : conversation.subtitleForRole(role);
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF8EE) : Colors.white,
          border: Border(
            left: BorderSide(
              color: selected ? const Color(0xFFC6A76A) : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: Color(0xFFF0ECE6)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: const Color(0xFFE8D5B7),
              child: Text(
                title.isEmpty ? '?' : title[0].toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xFF6C5632),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D1A17),
                          ),
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _messageTime(conversation.lastMessageAt!),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF9B948A),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.45,
                      color: const Color(0xFF736D65),
                    ),
                  ),
                  if (conversation.unreadCount > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A9E65).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${conversation.unreadCount} sin leer',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF14734B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.conversation,
    required this.role,
  });

  final ChatConversation conversation;
  final String role;

  @override
  Widget build(BuildContext context) {
    final title = conversation.titleForRole(role);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEAE6DF))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE8D5B7),
            child: Text(
              title.isEmpty ? '?' : title[0].toUpperCase(),
              style: GoogleFonts.inter(
                color: const Color(0xFF6C5632),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D1A17),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.subtitleForRole(role),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF7B746B),
                  ),
                ),
              ],
            ),
          ),
          if (conversation.reservationStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC6A76A).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _reservationChipLabel(conversation.reservationStatus),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8A672D),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
  });

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        mine ? const Color(0xFFC6A76A) : const Color(0xFFF7F3EC);
    final textColor = mine ? const Color(0xFF20170E) : const Color(0xFF1D1A17);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              _senderLabel(message.senderRole),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message.messageText,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.55,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _messageDateTime(message.createdAt),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: const Color(0xFFD7C7AC)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2B241C),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.55,
                color: const Color(0xFF7B746B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewConversationDialog extends StatefulWidget {
  const _NewConversationDialog();

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  final ChatService _chatService = const ChatService();
  final TextEditingController _subjectController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _targetType = 'customer';
  String? _selectedCustomerId;
  String? _selectedProfessionalId;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _professionals = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('profiles')
            .select('id, full_name')
            .eq('role', 'client')
            .order('full_name')
            .limit(120),
        Supabase.instance.client
            .from('profiles')
            .select('id, full_name')
            .eq('role', 'therapist')
            .eq('is_active', true)
            .order('full_name')
            .limit(120),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _clients = (results[0] as List).cast<Map<String, dynamic>>();
        _professionals = (results[1] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_targetType == 'customer' && (_selectedCustomerId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un cliente.')),
      );
      return;
    }
    if (_targetType == 'professional' && (_selectedProfessionalId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un terapeuta.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await _chatService.createConversation(
        NewConversationDraft(
          subject: _subjectController.text.trim().isEmpty
              ? (_targetType == 'customer'
                  ? 'Atencion al cliente'
                  : 'Coordinacion interna')
              : _subjectController.text.trim(),
          customerId: _targetType == 'customer' ? _selectedCustomerId : null,
          professionalId:
              _targetType == 'professional' ? _selectedProfessionalId : null,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo crear la conversacion: $error'),
          backgroundColor: const Color(0xFFB32D2D),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Nueva conversacion',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1D1A17),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea un chat interno entre recepcion, clientes, terapeutas o administracion.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: const Color(0xFF7B746B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'customer',
                          icon: Icon(Icons.person_outline),
                          label: Text('Cliente'),
                        ),
                        ButtonSegment(
                          value: 'professional',
                          icon: Icon(Icons.spa_outlined),
                          label: Text('Terapeuta'),
                        ),
                      ],
                      selected: {_targetType},
                      onSelectionChanged: (value) {
                        setState(() => _targetType = value.first);
                      },
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        labelText: 'Asunto del chat',
                        hintText: 'Cambio de horario, seguimiento, coordinacion...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_targetType == 'customer')
                      DropdownButtonFormField<String>(
                        value: _selectedCustomerId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Cliente',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _clients
                            .map(
                              (client) => DropdownMenuItem<String>(
                                value: client['id']?.toString(),
                                child: Text(
                                  client['full_name']?.toString() ?? 'Cliente',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedCustomerId = value);
                        },
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedProfessionalId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Terapeuta',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _professionals
                            .map(
                              (professional) => DropdownMenuItem<String>(
                                value: professional['id']?.toString(),
                                child: Text(
                                  professional['full_name']?.toString() ??
                                      'Terapeuta',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedProfessionalId = value);
                        },
                      ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _create,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFC6A76A),
                              foregroundColor: const Color(0xFF20170E),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Crear chat'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

String _messageTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _messageDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month ${hour}:$minute';
}

String _reservationChipLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pendiente';
    case 'confirmed':
      return 'Confirmada';
    case 'checked_in':
      return 'Check-in';
    case 'in_progress':
      return 'En proceso';
    case 'completed':
      return 'Completada';
    case 'awaiting_payment':
      return 'Pendiente de cobro';
    case 'paid':
      return 'Pagada';
    case 'cancelled':
      return 'Cancelada';
    case 'rescheduled':
      return 'Reagendada';
    case 'no_show':
      return 'No show';
    default:
      return status;
  }
}

String _senderLabel(String role) {
  switch (role) {
    case 'admin':
    case 'super_admin':
      return 'Admin';
    case 'reception':
    case 'receptionist':
      return 'Recepcion';
    case 'therapist':
      return 'Terapeuta';
    case 'client':
      return 'Cliente';
    default:
      return role;
  }
}
