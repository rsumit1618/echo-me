enum EchoAiMessageRole { user, assistant }

class EchoAiMessage {
  final String id;
  final EchoAiMessageRole role;
  final String text;
  final DateTime createdAt;

  const EchoAiMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  bool get isUser => role == EchoAiMessageRole.user;

  Map<String, String> toApiJson() {
    return {'role': isUser ? 'user' : 'assistant', 'content': text};
  }
}
