// lib/features/chat/chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/chat_models.dart';
import '../../core/services/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final bool embedded;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.embedded = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _conversationId;
  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _currentUserId;
  final _timeFmt = DateFormat('HH:mm');
  final _dateFmt = DateFormat('dd MMM', 'ru_RU');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    _currentUserId = auth.user?.id;

    try {
      final conv = await auth.api.findOrCreateConversation(widget.otherUserId);
      _conversationId = conv['id'];
      await _loadMessages();
      _startPolling();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMessages() async {
    final api = context.read<AuthProvider>().api;
    final messages = await api.getMessages(_conversationId!);
    if (mounted) {
      final hadNew = messages.length > _messages.length;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      if (hadNew) _scrollToBottom();
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _conversationId != null) _loadMessages();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    _textCtrl.clear();
    setState(() => _sending = true);

    try {
      final api = context.read<AuthProvider>().api;
      await api.sendMessage(_conversationId!, text);
      await _loadMessages();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [

        Expanded(
          child: _messages.isEmpty
              ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('Нет сообщений',
                    style: TextStyle(color: Colors.grey)),
                SizedBox(height: 4),
                Text('Начните переписку',
                    style:
                    TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          )
              : ListView.builder(
            controller: _scrollCtrl,
            reverse: true,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final msg = _messages[i];
              final isMine = msg.senderId == _currentUserId;
              final showDate = i == _messages.length - 1 ||
                  !_isSameDay(_messages[i].createdAt,
                      _messages[i + 1].createdAt);
              return Column(
                children: [
                  if (showDate)
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _dateFmt.format(msg.createdAt),
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  _MessageBubble(
                    message: msg,
                    isMine: isMine,
                    timeFmt: _timeFmt,
                  ),
                ],
              );
            },
          ),
        ),

        // Поле ввода
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Сообщение...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF8B0000),
                ),
                child: IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sending ? null : _send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildBody();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF8B0000),
              child: Text(
                widget.otherUserName.isNotEmpty
                    ? widget.otherUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherUserName,
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final DateFormat timeFmt;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.timeFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
        isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey[300],
              child:
              const Icon(Icons.person, size: 16, color: Colors.grey),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMine
                    ? const Color(0xFF8B0000)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMine ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeFmt.format(message.createdAt),
                        style: TextStyle(
                          color: isMine
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead
                              ? Icons.done_all
                              : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 6),
        ],
      ),
    );
  }
}