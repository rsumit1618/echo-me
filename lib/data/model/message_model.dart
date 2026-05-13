import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echo_me/domain/entity/message.dart';

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    super.text,
    super.imageUrls,
    super.attachments,
    required super.type,
    required super.state,
    required super.createdAt,
    super.deliveredAt,
    super.readAt,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> data) {
    return MessageModel(
      id: id,
      chatId: data['chatId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String?,
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? const []),
      attachments: (data['attachments'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (attachment) => MessageAttachmentModel.fromMap(
              Map<String, dynamic>.from(attachment),
            ),
          )
          .toList(),
      type: MessageType.values.firstWhere(
        (type) => type.name == data['type'],
        orElse: () => MessageType.text,
      ),
      state: MessageState.values.firstWhere(
        (state) => state.name == data['state'],
        orElse: () => MessageState.sent,
      ),
      createdAt: _readDate(data['createdAt']),
      deliveredAt: _readNullableDate(data['deliveredAt']),
      readAt: _readNullableDate(data['readAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'imageUrls': imageUrls,
      'attachments': attachments
          .map((attachment) => MessageAttachmentModel.fromEntity(attachment).toMap())
          .toList(),
      'type': type.name,
      'state': state.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'deliveredAt':
          deliveredAt == null ? null : Timestamp.fromDate(deliveredAt!),
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
    };
  }

  MessageModel copyWith({
    MessageState? state,
    DateTime? deliveredAt,
    DateTime? readAt,
    List<MessageAttachment>? attachments,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      text: text,
      imageUrls: imageUrls,
      attachments: attachments ?? this.attachments,
      type: type,
      state: state ?? this.state,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.now();
  }

  static DateTime? _readNullableDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

class MessageAttachmentModel extends MessageAttachment {
  const MessageAttachmentModel({
    required super.id,
    required super.fileName,
    required super.contentType,
    required super.sizeBytes,
    super.compressed,
    super.chunkCount,
    super.base64Data,
  });

  factory MessageAttachmentModel.fromEntity(MessageAttachment attachment) {
    return MessageAttachmentModel(
      id: attachment.id,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      sizeBytes: attachment.sizeBytes,
      compressed: attachment.compressed,
      chunkCount: attachment.chunkCount,
      base64Data: attachment.base64Data,
    );
  }

  factory MessageAttachmentModel.fromMap(Map<String, dynamic> data) {
    return MessageAttachmentModel(
      id: data['id'] as String? ?? '',
      fileName: data['fileName'] as String? ?? 'Attachment',
      contentType: data['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: data['sizeBytes'] as int? ?? 0,
      compressed: data['compressed'] as bool? ?? false,
      chunkCount: data['chunkCount'] as int? ?? 0,
      base64Data: data['base64Data'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'compressed': compressed,
      'chunkCount': chunkCount,
    };
  }
}
