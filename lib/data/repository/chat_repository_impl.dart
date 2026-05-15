import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/core/utils/image_optimizer.dart';
import 'package:echo_me/data/model/chat_model.dart';
import 'package:echo_me/data/model/message_model.dart';
import 'package:echo_me/data/source/local/fqlite_service.dart';
import 'package:echo_me/data/source/remote/firestore_service.dart';
import 'package:echo_me/domain/entity/chat.dart';
import 'package:echo_me/domain/entity/message.dart';
import 'package:echo_me/domain/repository/auth_repository.dart';
import 'package:echo_me/domain/repository/chat_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

const int _attachmentBase64ChunkSize = 700 * 1024;

class ChatRepositoryImpl implements ChatRepository {
  static const int _maxAttachmentBytes = 10 * 1024 * 1024;

  final AuthRepository _auth;
  final FirestoreService _firestore;
  final FQLiteService _local;
  final ImageOptimizer _optimizer;
  final Uuid _uuid = const Uuid();

  ChatRepositoryImpl(this._auth, this._firestore, this._local, this._optimizer);

  @override
  Stream<List<Chat>> watchRecentChats() {
    final uid = _auth.firebaseUser?.uid;
    if (uid == null) return Stream.value(const []);

    return _firestore.chats
        .where('participantIds', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snapshot) async {
          final chats = snapshot.docs
              .map((doc) {
                final data = doc.data();
                return ChatModel.fromMap(doc.id, data);
              })
              .where((chat) => chat.lastMessage != null)
              .toList();
          return _withParticipantImages(chats);
        })
        .handleError((error, stack) {
          debugPrint('watchRecentChats error: ${AppErrorMapper.message(error)}');
        });
  }

  @override
  Stream<Chat?> watchChat(String chatId) {
    return _firestore.chats.doc(chatId).snapshots().asyncMap((doc) async {
      final data = doc.data();
      if (data == null) return null;
      final chats = await _withParticipantImages([
        ChatModel.fromMap(doc.id, data),
      ]);
      return chats.first;
    });
  }

  @override
  Stream<Map<String, dynamic>?> watchUserStatus(String userId) {
    return _firestore.users.doc(userId).snapshots().map((doc) => doc.data());
  }

  @override
  Future<void> setActiveChat(String? chatId) async {
    final uid = _auth.firebaseUser?.uid;
    if (uid == null) return;
    await _firestore.users.doc(uid).set({
      'activeChatId': chatId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setTyping(String chatId, bool isTyping) async {
    final uid = _auth.firebaseUser?.uid;
    if (uid == null) return;
    await _firestore.chats.doc(chatId).set({
      'typing.$uid': isTyping,
      'typingUpdatedAt.$uid': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<List<Message>> watchMessages(String chatId, {int limit = 30}) {
    return _firestore
        .chatMessages(chatId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          await _markIncomingDelivered(snapshot.docs);
          final messages = <Message>[];
          for (final doc in snapshot.docs) {
            final message = MessageModel.fromMap(doc.id, doc.data());
            messages.add(await _withAttachmentData(message));
          }
          return messages;
        });
  }

  @override
  Future<List<Message>> fetchMessagesBefore(
    String chatId,
    DateTime before, {
    int limit = 30,
  }) async {
    final snapshot = await _firestore
        .chatMessages(chatId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();

    final messages = <Message>[];
    for (final doc in snapshot.docs) {
      final message = MessageModel.fromMap(doc.id, doc.data());
      messages.add(await _withAttachmentData(message));
    }
    return messages;
  }

  @override
  Future<String> getOrCreateOneToOneChat(
    String peerUserId, {
    String? peerDisplayName,
    String? peerPhoneNumber,
    String? peerProfileImageUrl,
  }) async {
    final currentUser = _auth.firebaseUser;
    if (currentUser == null) {
      throw const AppException('Please login before starting a chat.');
    }

    final uid = currentUser.uid;
    final ids = [uid, peerUserId]..sort();
    final chatId = ids.join('_');
    final currentUserDoc = await _firestore.users.doc(uid).get();
    final currentProfileImageUrl =
        currentUserDoc.data()?['profileImageUrl'] as String?;
    await _firestore.chats.doc(chatId).set({
      'participantIds': ids,
      'participantNames': {
        uid: currentUser.phoneNumber ?? 'You',
        if (peerDisplayName != null && peerDisplayName.trim().isNotEmpty)
          peerUserId: peerDisplayName.trim(),
      },
      'participantPhones': {
        if (currentUser.phoneNumber != null) uid: currentUser.phoneNumber,
        if (peerPhoneNumber != null) peerUserId: peerPhoneNumber,
      },
      'participantImageUrls': {
        if (currentProfileImageUrl != null &&
            currentProfileImageUrl.trim().isNotEmpty)
          uid: currentProfileImageUrl.trim(),
        if (peerProfileImageUrl != null &&
            peerProfileImageUrl.trim().isNotEmpty)
          peerUserId: peerProfileImageUrl.trim(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts': {uid: 0, peerUserId: 0},
    }, SetOptions(merge: true));
    return chatId;
  }

  @override
  Future<void> sendTextMessage(String chatId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _sendMessage(chatId: chatId, text: trimmed, attachments: const []);
  }

  @override
  Future<void> sendImageMessage(String chatId, List<File> images) {
    return sendFilesMessage(chatId, images);
  }

  @override
  Future<void> sendFilesMessage(String chatId, List<File> files) async {
    if (files.isEmpty) return;
    if (files.length > 5) {
      throw const AppException('You can attach up to 5 files per message.');
    }

    final attachments = <_PreparedAttachment>[];
    for (final file in files) {
      attachments.add(await _prepareAttachment(file));
    }

    await _sendMessage(
      chatId: chatId,
      attachments: attachments
          .map((attachment) => attachment.metadata)
          .toList(growable: false),
      attachmentChunks: {
        for (final attachment in attachments)
          attachment.metadata.id: attachment.chunks,
      },
    );
  }

  @override
  Future<void> markRead(String chatId) async {
    final uid = _auth.firebaseUser?.uid;
    if (uid == null) return;

    final snapshot = await _firestore
        .chatMessages(chatId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    final batch = _firestore.db.batch();
    var hasWrites = false;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['senderId'] == uid || data['state'] == MessageState.read.name) {
        continue;
      }
      batch.set(doc.reference, {
        'state': MessageState.read.name,
        'readAt': FieldValue.serverTimestamp(),
        'deliveredAt': data['deliveredAt'] ?? FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      hasWrites = true;
    }

    batch.set(_firestore.chats.doc(chatId), {
      'unreadCounts.$uid': 0,
    }, SetOptions(merge: true));
    hasWrites = true;

    if (hasWrites) await batch.commit();
  }

  Future<void> _sendMessage({
    required String chatId,
    String? text,
    required List<MessageAttachment> attachments,
    Map<String, List<String>> attachmentChunks = const {},
  }) async {
    final uid = _auth.firebaseUser?.uid;
    if (uid == null) {
      throw const AppException('Please login before sending a message.');
    }

    final chatDoc = await _firestore.chats.doc(chatId).get();
    final participantIds = List<String>.from(
      chatDoc.data()?['participantIds'] as List? ?? const [],
    );
    final recipients = participantIds.where((id) => id != uid).toList();
    final id = _uuid.v4();
    final message = MessageModel(
      id: id,
      chatId: chatId,
      senderId: uid,
      text: text,
      attachments: attachments,
      type: _messageType(text, attachments),
      state: MessageState.sent,
      createdAt: DateTime.now(),
    );
    final batch = _firestore.db.batch();
    final messageRef = _firestore.chatMessages(chatId).doc(id);
    batch.set(messageRef, message.toMap());

    for (final entry in attachmentChunks.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        batch.set(_firestore.messageChunks(chatId, id).doc('${entry.key}_$i'), {
          'attachmentId': entry.key,
          'index': i,
          'data': entry.value[i],
        });
      }
    }

    final unreadUpdates = {
      for (final recipient in recipients)
        'unreadCounts.$recipient': FieldValue.increment(1),
      'unreadCounts.$uid': 0,
    };
    batch.set(_firestore.chats.doc(chatId), {
      'lastMessage': {'id': id, ...message.toMap()},
      'updatedAt': FieldValue.serverTimestamp(),
      ...unreadUpdates,
    }, SetOptions(merge: true));
    await batch.commit();
    await _queueOfflineNotifications(
      chatId: chatId,
      messageId: id,
      recipients: recipients,
      text: _notificationPreview(message),
    );
    await _local.cacheMessage({
      'id': id,
      'chatId': chatId,
      'senderId': uid,
      'text': text,
      'imageUrls': '',
      'type': message.type.name,
      'state': message.state.name,
      'createdAt': message.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<void> _queueOfflineNotifications({
    required String chatId,
    required String messageId,
    required List<String> recipients,
    required String text,
  }) async {
    final sender = _auth.firebaseUser;
    if (sender == null || recipients.isEmpty) return;

    for (final recipient in recipients) {
      try {
        final userDoc = await _firestore.users.doc(recipient).get();
        final data = userDoc.data();
        final isOnline = data?['isOnline'] as bool? ?? false;
        final activeChatId = data?['activeChatId'] as String?;
        final fcmToken = data?['fcmToken'] as String?;
        if ((isOnline && activeChatId == chatId) ||
            fcmToken == null ||
            fcmToken.isEmpty) {
          continue;
        }

        await _firestore.notificationRequests.add({
          'recipientUserId': recipient,
          'senderUserId': sender.uid,
          'senderName': sender.phoneNumber ?? 'Echo Me',
          'chatId': chatId,
          'messageId': messageId,
          'title': sender.phoneNumber ?? 'New message',
          'body': text,
          'fcmToken': fcmToken,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (error) {
        debugPrint(
          'notification request failed: ${AppErrorMapper.message(error)}',
        );
      }
    }
  }

  Future<List<ChatModel>> _withParticipantImages(List<ChatModel> chats) async {
    final userIds = <String>{};
    for (final chat in chats) {
      userIds.addAll(chat.participantIds);
    }
    if (userIds.isEmpty) return chats;

    final imageByUserId = <String, String>{};
    final ids = userIds.toList();
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final users = await _firestore.users
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in users.docs) {
        final imageUrl = doc.data()['profileImageUrl'] as String?;
        if (imageUrl != null && imageUrl.trim().isNotEmpty) {
          imageByUserId[doc.id] = imageUrl.trim();
        }
      }
    }

    return chats.map((chat) {
      final imageUrls = {...chat.participantImageUrls};
      for (final id in chat.participantIds) {
        final imageUrl = imageByUserId[id];
        if (imageUrl != null) imageUrls[id] = imageUrl;
      }
      return ChatModel(
        id: chat.id,
        participantIds: chat.participantIds,
        participantNames: chat.participantNames,
        participantPhones: chat.participantPhones,
        participantImageUrls: imageUrls,
        typing: chat.typing,
        lastMessage: chat.lastMessage,
        updatedAt: chat.updatedAt,
        unreadCounts: chat.unreadCounts,
      );
    }).toList();
  }

  String _notificationPreview(Message message) {
    final text = message.text?.trim();
    if (text != null && text.isNotEmpty) return text;
    if (message.attachments.any((attachment) => attachment.isImage)) {
      return 'Photo';
    }
    if (message.attachments.any((attachment) => attachment.isPdf)) {
      return 'PDF';
    }
    return 'New message';
  }

  Future<_PreparedAttachment> _prepareAttachment(File file) async {
    if (!await file.exists()) {
      throw const AppException('Selected file does not exist.');
    }
    final originalSize = await file.length();
    if (originalSize > _maxAttachmentBytes) {
      throw const AppException(
        'Only image and PDF files under 10 MB are allowed.',
      );
    }

    final extension = p.extension(file.path).toLowerCase();
    final isImage = [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.heic',
    ].contains(extension);
    final isPdf = extension == '.pdf';
    if (!isImage && !isPdf) {
      throw const AppException('Only image and PDF files are allowed.');
    }

    final id = _uuid.v4();
    final fileName = p.basename(file.path);
    var contentType = isPdf ? 'application/pdf' : 'image/jpeg';
    var compressed = false;
    late List<int> bytes;

    if (isImage) {
      final optimized = await _optimizer.compressToUnder100Kb(file);
      bytes = await optimized.readAsBytes();
      compressed = true;
    } else {
      final prepared = await compute(
        _preparePdfBytes,
        await file.readAsBytes(),
      );
      bytes = prepared.bytes;
      compressed = prepared.compressed;
    }

    final chunks = await compute(_base64Chunks, bytes);

    return _PreparedAttachment(
      metadata: MessageAttachmentModel(
        id: id,
        fileName: fileName,
        contentType: contentType,
        sizeBytes: bytes.length,
        compressed: compressed,
        chunkCount: chunks.length,
      ),
      chunks: chunks,
    );
  }

  Future<MessageModel> _withAttachmentData(MessageModel message) async {
    if (message.attachments.isEmpty) return message;

    final chunksSnapshot = await _firestore
        .messageChunks(message.chatId, message.id)
        .orderBy('index')
        .get();
    final chunksByAttachment = <String, List<String>>{};
    for (final doc in chunksSnapshot.docs) {
      final data = doc.data();
      final attachmentId = data['attachmentId'] as String?;
      final chunk = data['data'] as String?;
      if (attachmentId == null || chunk == null) continue;
      chunksByAttachment.putIfAbsent(attachmentId, () => []).add(chunk);
    }

    return message.copyWith(
      attachments: message.attachments.map((attachment) {
        final data = chunksByAttachment[attachment.id]?.join();
        return MessageAttachmentModel(
          id: attachment.id,
          fileName: attachment.fileName,
          contentType: attachment.contentType,
          sizeBytes: attachment.sizeBytes,
          compressed: attachment.compressed,
          chunkCount: attachment.chunkCount,
          base64Data: data,
        );
      }).toList(),
    );
  }

  Future<void> _markIncomingDelivered(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final uid = _auth.firebaseUser?.uid;
    if (uid == null) return;

    final batch = _firestore.db.batch();
    var hasWrites = false;
    for (final doc in docs) {
      final data = doc.data();
      if (data['senderId'] == uid || data['state'] != MessageState.sent.name) {
        continue;
      }
      batch.set(doc.reference, {
        'state': MessageState.delivered.name,
        'deliveredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      hasWrites = true;
    }
    if (hasWrites) await batch.commit();
  }

  MessageType _messageType(String? text, List<MessageAttachment> attachments) {
    if (attachments.isEmpty) return MessageType.text;
    if (attachments.every((attachment) => attachment.isImage)) {
      return MessageType.image;
    }
    return MessageType.pdf;
  }
}

_AttachmentBytes _preparePdfBytes(Uint8List originalBytes) {
  final gzipped = gzip.encode(originalBytes);
  if (gzipped.length < originalBytes.length) {
    return _AttachmentBytes(Uint8List.fromList(gzipped), compressed: true);
  }
  return _AttachmentBytes(originalBytes, compressed: false);
}

List<String> _base64Chunks(List<int> bytes) {
  final base64Data = base64Encode(bytes);
  final chunks = <String>[];
  for (
    var start = 0;
    start < base64Data.length;
    start += _attachmentBase64ChunkSize
  ) {
    final end = start + _attachmentBase64ChunkSize;
    chunks.add(
      base64Data.substring(
        start,
        end > base64Data.length ? base64Data.length : end,
      ),
    );
  }
  return chunks;
}

class _AttachmentBytes {
  final Uint8List bytes;
  final bool compressed;

  const _AttachmentBytes(this.bytes, {required this.compressed});
}

class _PreparedAttachment {
  final MessageAttachment metadata;
  final List<String> chunks;

  const _PreparedAttachment({required this.metadata, required this.chunks});
}
