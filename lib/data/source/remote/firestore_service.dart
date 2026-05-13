import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echo_me/core/constants/firebase_paths.dart';

class FirestoreService {
  final FirebaseFirestore db;

  FirestoreService({FirebaseFirestore? db}) : db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users =>
      db.collection(FirebasePaths.users);

  CollectionReference<Map<String, dynamic>> get phoneIndex =>
      db.collection(FirebasePaths.phoneIndex);

  CollectionReference<Map<String, dynamic>> get chats =>
      db.collection(FirebasePaths.chats);

  CollectionReference<Map<String, dynamic>> get notificationRequests =>
      db.collection(FirebasePaths.notificationRequests);

  CollectionReference<Map<String, dynamic>> userContacts(String uid) =>
      users.doc(uid).collection(FirebasePaths.contacts);

  CollectionReference<Map<String, dynamic>> chatMessages(String chatId) =>
      chats.doc(chatId).collection(FirebasePaths.messages);

  CollectionReference<Map<String, dynamic>> messageChunks(
    String chatId,
    String messageId,
  ) =>
      chatMessages(chatId).doc(messageId).collection(FirebasePaths.chunks);

  CollectionReference<Map<String, dynamic>> userCalls(String uid) =>
      users.doc(uid).collection(FirebasePaths.calls);
}
