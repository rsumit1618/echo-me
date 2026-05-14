import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echo_me/data/model/message_model.dart';
import 'package:echo_me/domain/entity/chat.dart';

class ChatModel extends Chat {
  const ChatModel({
    required super.id,
    required super.participantIds,
    super.participantNames,
    super.participantPhones,
    super.participantImageUrls,
    super.typing,
    super.lastMessage,
    required super.updatedAt,
    super.unreadCounts,
  });

  factory ChatModel.fromMap(String id, Map<String, dynamic> data) {
    final last = data['lastMessage'] as Map<String, dynamic>?;
    return ChatModel(
      id: id,
      participantIds: List<String>.from(
        data['participantIds'] as List? ?? const [],
      ),
      participantNames: Map<String, String>.from(
        data['participantNames'] as Map? ?? const {},
      ),
      participantPhones: Map<String, String>.from(
        data['participantPhones'] as Map? ?? const {},
      ),
      participantImageUrls: Map<String, String>.from(
        data['participantImageUrls'] as Map? ?? const {},
      ),
      typing: Map<String, bool>.from(data['typing'] as Map? ?? const {}),
      lastMessage: last == null
          ? null
          : MessageModel.fromMap(last['id'] as String? ?? '', last),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      unreadCounts: Map<String, int>.from(
        data['unreadCounts'] as Map? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'participantNames': participantNames,
      'participantPhones': participantPhones,
      'participantImageUrls': participantImageUrls,
      'typing': typing,
      'lastMessage': lastMessage is MessageModel
          ? {'id': lastMessage!.id, ...(lastMessage! as MessageModel).toMap()}
          : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'unreadCounts': unreadCounts,
    };
  }
}
