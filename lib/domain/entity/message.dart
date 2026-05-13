enum MessageType { text, image, pdf }
enum MessageState { sending, sent, delivered, read, failed }

class MessageAttachment {
  final String id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final bool compressed;
  final int chunkCount;
  final String? base64Data;

  const MessageAttachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.compressed = false,
    this.chunkCount = 0,
    this.base64Data,
  });

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String? text;
  final List<String> imageUrls;
  final List<MessageAttachment> attachments;
  final MessageType type;
  final MessageState state;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text,
    this.imageUrls = const [],
    this.attachments = const [],
    required this.type,
    required this.state,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
  });
}
