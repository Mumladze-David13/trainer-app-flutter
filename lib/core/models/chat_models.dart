// lib/core/models/chat_models.dart

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  Message copyWith({bool? isRead}) => Message(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    text: text,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    id: j['id'] ?? '',
    conversationId: j['conversationId'] ?? '',
    senderId: j['senderId'] ?? '',
    text: j['text'] ?? '',
    isRead: j['isRead'] ?? false,
    createdAt: j['createdAt'] != null
        ? DateTime.parse(j['createdAt'])
        : DateTime.now(),
  );
}

class Conversation {
  final String id;
  final String trainerId;
  final String clientId;
  final Map<String, dynamic>? trainer;
  final Map<String, dynamic>? client;
  final Message? lastMessage;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.trainerId,
    required this.clientId,
    this.trainer,
    this.client,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: j['id'] ?? '',
    trainerId: j['trainerId'] ?? '',
    clientId: j['clientId'] ?? '',
    trainer: j['trainer'],
    client: j['client'],
    lastMessage: j['lastMessage'] != null
        ? Message.fromJson(j['lastMessage'])
        : null,
    unreadCount: j['unreadCount'] ?? 0,
  );
}
