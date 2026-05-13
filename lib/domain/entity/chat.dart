import 'message.dart';

class Chat {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String> participantPhones;
  final Map<String, bool> typing;
  final Message? lastMessage;
  final DateTime updatedAt;
  final Map<String, int> unreadCounts;

  const Chat({
    required this.id,
    required this.participantIds,
    this.participantNames = const {},
    this.participantPhones = const {},
    this.typing = const {},
    this.lastMessage,
    required this.updatedAt,
    this.unreadCounts = const {},
  });
}
