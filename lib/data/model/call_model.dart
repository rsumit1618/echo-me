import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echo_me/domain/entity/call.dart';

class CallModel extends CallLogEntry {
  const CallModel({
    required super.id,
    required super.peerUserId,
    required super.peerPhoneNumber,
    required super.direction,
    required super.type,
    required super.startedAt,
    super.duration,
  });

  factory CallModel.fromMap(String id, Map<String, dynamic> data) {
    return CallModel(
      id: id,
      peerUserId: data['peerUserId'] as String? ?? '',
      peerPhoneNumber: data['peerPhoneNumber'] as String? ?? '',
      direction: CallDirection.values.firstWhere(
        (direction) => direction.name == data['direction'],
        orElse: () => CallDirection.missed,
      ),
      type: CallType.values.firstWhere(
        (type) => type.name == data['type'],
        orElse: () => CallType.voice,
      ),
      startedAt: data['startedAt'] is Timestamp
          ? (data['startedAt'] as Timestamp).toDate()
          : DateTime.now(),
      duration: data['durationSeconds'] == null
          ? null
          : Duration(seconds: data['durationSeconds'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'peerUserId': peerUserId,
      'peerPhoneNumber': peerPhoneNumber,
      'direction': direction.name,
      'type': type.name,
      'startedAt': Timestamp.fromDate(startedAt),
      'durationSeconds': duration?.inSeconds,
    };
  }
}
