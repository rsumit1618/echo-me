import 'dart:io';

import 'package:echo_me/domain/entity/chat.dart';
import 'package:echo_me/domain/entity/message.dart';

abstract class ChatRepository {
  Stream<List<Chat>> watchRecentChats();
  Stream<Chat?> watchChat(String chatId);
  Stream<List<Message>> watchMessages(String chatId, {int limit = 30});
  Future<List<Message>> fetchMessagesBefore(
    String chatId,
    DateTime before, {
    int limit = 30,
  });
  Stream<Map<String, dynamic>?> watchUserStatus(String userId);
  Future<void> setActiveChat(String? chatId);
  Future<void> setTyping(String chatId, bool isTyping);
  Future<String> getOrCreateOneToOneChat(
    String peerUserId, {
    String? peerDisplayName,
    String? peerPhoneNumber,
  });
  Future<void> sendTextMessage(String chatId, String text);
  Future<void> sendImageMessage(String chatId, List<File> images);
  Future<void> sendFilesMessage(String chatId, List<File> files);
  Future<void> markRead(String chatId);
}
