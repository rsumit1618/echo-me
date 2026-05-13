import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echo_me/domain/entity/contact.dart';

class ContactModel extends AppContact {
  const ContactModel({
    required super.id,
    required super.displayName,
    required super.normalizedPhone,
    super.registeredUserId,
    super.canCall,
    required super.syncedAt,
  });

  factory ContactModel.fromMap(String id, Map<String, dynamic> data) {
    final displayName = (data['displayName'] as String?)?.trim();

    return ContactModel(
      id: id,
      displayName: displayName == null || displayName.isEmpty
          ? AppContact.defaultDisplayName
          : displayName,
      normalizedPhone: data['normalizedPhone'] as String? ?? '',
      registeredUserId: data['registeredUserId'] as String?,
      canCall: data['canCall'] as bool? ?? false,
      syncedAt: data['syncedAt'] is Timestamp
          ? (data['syncedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'normalizedPhone': normalizedPhone,
      'registeredUserId': registeredUserId,
      'canCall': canCall,
      'syncedAt': Timestamp.fromDate(syncedAt),
    };
  }
}
