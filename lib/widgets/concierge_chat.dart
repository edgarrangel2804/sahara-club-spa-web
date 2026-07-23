import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final ValueNotifier<bool> conciergeChatOpen = ValueNotifier<bool>(false);

const _gold = Color(0xFFC6A76A);
const _goldSoft = Color(0xFFE8DCC8);
const _panelBg = Color(0xFF141414);
const _inputBg = Color(0xFF0A0A0A);
const _maxMessagesToSend = 16;
const _maxMessageChars = 1200;

class _ConciergeMessage {
  const _ConciergeMessage(this.role, this.text);

  final String role;
  final String text;
}

class ConciergeChat extends StatefulWidget {
  const ConciergeChat({super.key});

  @override
  State<ConciergeChat> createState() => _ConciergeChatState();
}

class _ConciergeChatState extends State<ConciergeChat> {
  bool _open = false;
  bool _sending = false;
  final String _welcome =
      'Hola, soy el concierge de Sahara Club Spa. Te ayudo a elegir una experiencia o iniciar una reserva.';
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final List<_ConciergeMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    conciergeChatOpen.addListener(_onExternalOpen);
  }

  @override
  void dispose() {
    conciergeChatOpen.removeListener(_onExternalOpen);
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onExternalOpen() {
    if (!conciergeChatOpen.value || !mounted) return;
    setState(() {
      _open = true;
      _ensureWelcome();
    });
    conciergeChatOpen.value = false;
    _refocus();
    _scrollDown();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) _ensureWelcome();
    });
    if (_open) _refocus();
  }

  void _ensureWelcome() {
    if (_messages.isEmpty) {
      _messages.add(_ConciergeMessage('assistant', _welcome));
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ');
    setState(() {
      _messages.add(
        _ConciergeMessage(
          'user',
          normalizedText.length > _maxMessageChars
              ? normalizedText.substring(0, _maxMessageChars)
              : normalizedText,
        ),
      );
      _sending = true;
      _input.clear();
    });
    _refocus();
    _scrollDown();

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'web_concierge',
        body: {
          'messages': _messages
              .takeLast(_maxMessagesToSend)
              .map((message) => {'role': message.role, 'content': message.text})
              .toList(),
        },
      );
      final data = response.data;
      final reply = data is Map && data['reply'] is String
          ? data['reply'] as String
          : 'No pude responder en este momento. Escribenos por WhatsApp y te ayudamos.';
      if (mounted) {
        setState(() => _messages.add(_ConciergeMessage('assistant', reply)));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _messages.add(
            const _ConciergeMessage(
              'assistant',
              'Tuve un problema para responder. Escribenos por WhatsApp y te ayudamos.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _refocus();
      _scrollDown();
    }
  }

  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _inputFocus.requestFocus();
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 480;
    return Positioned(
      right: narrow ? 12 : 24,
      bottom: narrow ? 12 : 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_open) _panel(narrow),
          const SizedBox(height: 12),
          _launcher(),
        ],
      ),
    );
  }

  Widget _launcher() {
    return Material(
      color: _gold,
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        onTap: _toggle,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(
            _open ? Icons.close : Icons.chat_bubble_outline,
            color: Colors.black,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _panel(bool narrow) {
    final width = narrow ? MediaQuery.of(context).size.width - 24 : 360.0;
    return Container(
      width: width,
      height: 480,
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _header(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, index) {
                if (index == _messages.length) {
                  return _messageBubble('assistant', '...');
                }
                final message = _messages[index];
                return _messageBubble(message.role, message.text);
              },
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      color: Colors.black,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: _gold,
            child: Icon(Icons.spa_outlined, size: 18, color: Colors.black),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Concierge Sahara',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _goldSoft,
                  ),
                ),
                Text(
                  'Reserva asistida',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _toggle,
            child: const Icon(Icons.close, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _inputFocus,
              autofocus: true,
              maxLength: _maxMessageChars,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Escribe tu mensaje...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white38,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                filled: true,
                fillColor: _inputBg,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: _gold.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: _gold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _gold,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _send,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.send_rounded, color: Colors.black, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(String role, String text) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isUser ? _gold : _inputBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _LinkableText(text: text, isUser: isUser),
      ),
    );
  }
}

class _LinkableText extends StatefulWidget {
  const _LinkableText({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  State<_LinkableText> createState() => _LinkableTextState();
}

class _LinkableTextState extends State<_LinkableText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _spans() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)');
    var last = 0;
    for (final match in urlRegex.allMatches(widget.text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, match.start)));
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            color: _gold,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
          recognizer: recognizer,
        ),
      );
      last = match.end;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        style: GoogleFonts.inter(
          fontSize: 13.5,
          height: 1.4,
          color: widget.isUser
              ? Colors.black
              : Colors.white.withValues(alpha: 0.92),
        ),
        children: _spans(),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final items = toList(growable: false);
    if (items.length <= count) return items;
    return items.skip(items.length - count);
  }
}
