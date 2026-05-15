enum CallDirection { incoming, outgoing, missed }

enum CallType { voice, video }

class CallLogEntry {
  final String id;
  final String peerUserId;
  final String peerPhoneNumber;
  final CallDirection direction;
  final CallType type;
  final DateTime startedAt;
  final Duration? duration;

  const CallLogEntry({
    required this.id,
    required this.peerUserId,
    required this.peerPhoneNumber,
    required this.direction,
    required this.type,
    required this.startedAt,
    this.duration,
  });
}
