import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echo_me/domain/entity/app_user.dart';

class UserModel extends AppUser {
  const UserModel({
    required super.uid,
    required super.phoneNumber,
    super.email,
    super.profileImageUrl,
    super.fcmToken,
    super.isOnline,
    super.lastSeen,
    required super.createdAt,
    required super.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel.fromMap(doc.id, data);
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      phoneNumber: data['phoneNumber'] as String? ?? '',
      email: data['email'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      fcmToken: data['fcmToken'] as String?,
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: _readNullableDate(data['lastSeen']),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'fcmToken': fcmToken,
      'isOnline': isOnline,
      'lastSeen': lastSeen == null ? null : Timestamp.fromDate(lastSeen!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _readNullableDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
