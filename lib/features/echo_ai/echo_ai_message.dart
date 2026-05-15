enum EchoAiMessageRole { user, assistant }

String sanitizeEchoAiText(String value) {
  final buffer = StringBuffer();

  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    final isHighSurrogate = unit >= 0xD800 && unit <= 0xDBFF;
    final isLowSurrogate = unit >= 0xDC00 && unit <= 0xDFFF;

    if (isHighSurrogate) {
      if (i + 1 < value.length) {
        final next = value.codeUnitAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          buffer.writeCharCode(unit);
          buffer.writeCharCode(next);
          i++;
        }
      }
      continue;
    }

    if (isLowSurrogate) continue;
    buffer.writeCharCode(unit);
  }

  return buffer.toString();
}

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
    return {
      'role': isUser ? 'user' : 'assistant',
      'content': sanitizeEchoAiText(text),
    };
  }
}
