import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/core/utils/phone_normalizer.dart';
import 'package:echo_me/data/model/contact_model.dart';
import 'package:echo_me/data/source/local/fqlite_service.dart';
import 'package:echo_me/data/source/remote/firestore_service.dart';
import 'package:echo_me/domain/entity/contact.dart';
import 'package:echo_me/domain/repository/auth_repository.dart';
import 'package:echo_me/domain/repository/contact_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactRepositoryImpl implements ContactRepository {
  final AuthRepository _auth;
  final FirestoreService _firestore;
  final FQLiteService _local;

  ContactRepositoryImpl(this._auth, this._firestore, this._local);

  @override
  Future<List<AppContact>> syncDeviceContacts() async {
    final user = _auth.firebaseUser;
    if (user == null)
      throw const AppException('Please login before syncing contacts.');
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      throw const AppException(
        'Contacts permission is needed to show friends and invites.',
      );
    }

    final rawContacts = await FlutterContacts.getContacts(withProperties: true);
    final unique = <String, ContactModel>{};
    for (final contact in rawContacts) {
      for (final phone in contact.phones) {
        final normalized10 = PhoneNormalizer.normalizeToIndian10DigitOrNull(
          phone.number,
        );
        if (normalized10 == null) continue;

        // Store as 10-digit normalized phone.
        // Also avoid adding the current user number if it's the same 10 digits.
        final currentUser10 = PhoneNormalizer.normalizeToIndian10DigitOrNull(
          user.phoneNumber ?? '',
        );
        if (currentUser10 != null && normalized10 == currentUser10) continue;

        final displayName = contact.displayName.trim();
        unique[normalized10] = ContactModel(
          id: normalized10,
          displayName: displayName.isEmpty
              ? AppContact.defaultDisplayName
              : displayName,
          normalizedPhone: normalized10,
          syncedAt: DateTime.now(),
        );
      }
    }

    final registered = await _lookupRegistered(unique.keys.toList());
    await _attachProfileImages(registered);
    final batch = _firestore.db.batch();
    final synced = <ContactModel>[];
    for (final entry in unique.entries) {
      final index = registered[entry.key];
      final contact = ContactModel(
        id: entry.key,
        displayName: entry.value.displayName,
        normalizedPhone: entry.key,
        registeredUserId: index?['uid'] as String?,
        profileImageUrl: index?['profileImageUrl'] as String?,
        canCall: index?['canCall'] as bool? ?? false,
        syncedAt: DateTime.now(),
      );
      batch.set(
        _firestore.userContacts(user.uid).doc(contact.id),
        contact.toMap(),
      );
      await _local.upsertContact({
        'id': contact.id,
        'displayName': contact.displayName,
        'normalizedPhone': contact.normalizedPhone,
        'registeredUserId': contact.registeredUserId,
        'canCall': contact.canCall ? 1 : 0,
        'syncedAt': contact.syncedAt.millisecondsSinceEpoch,
      });
      synced.add(contact);
    }
    await batch.commit();
    synced.sort((a, b) => a.displayName.compareTo(b.displayName));
    return synced;
  }

  @override
  Stream<List<AppContact>> watchContacts() async* {
    final user = _auth.firebaseUser;
    if (user == null) {
      yield const [];
      return;
    }
    yield* _firestore
        .userContacts(user.uid)
        .orderBy('displayName')
        .snapshots()
        .asyncMap((snapshot) async {
          final contacts = snapshot.docs
              .map((doc) => ContactModel.fromMap(doc.id, doc.data()))
              .toList();
          return _withProfileImages(contacts);
        })
        .handleError((error) {
          debugPrint('watchContacts error: ${AppErrorMapper.message(error)}');
        });
  }

  Future<List<ContactModel>> _withProfileImages(
    List<ContactModel> contacts,
  ) async {
    final registeredIds = contacts
        .where((contact) => contact.registeredUserId != null)
        .map((contact) => contact.registeredUserId!)
        .toSet()
        .toList();
    if (registeredIds.isEmpty) return contacts;

    final imageByUserId = <String, String>{};
    for (var i = 0; i < registeredIds.length; i += 10) {
      final chunk = registeredIds.skip(i).take(10).toList();
      final users = await _firestore.users
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in users.docs) {
        final imageUrl = doc.data()['profileImageUrl'] as String?;
        if (imageUrl != null && imageUrl.trim().isNotEmpty) {
          imageByUserId[doc.id] = imageUrl.trim();
        }
      }
    }

    return contacts.map((contact) {
      final userId = contact.registeredUserId;
      final imageUrl = userId == null ? null : imageByUserId[userId];
      if (imageUrl == null) return contact;
      return ContactModel(
        id: contact.id,
        displayName: contact.displayName,
        normalizedPhone: contact.normalizedPhone,
        registeredUserId: contact.registeredUserId,
        profileImageUrl: imageUrl,
        canCall: contact.canCall,
        syncedAt: contact.syncedAt,
      );
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _lookupRegistered(
    List<String> phones,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    final phoneLookup = <String, String>{};

    for (final phone in phones) {
      phoneLookup[phone] = phone;
      phoneLookup['+91$phone'] = phone;
    }

    final lookupKeys = phoneLookup.keys.toList();
    for (var i = 0; i < lookupKeys.length; i += 10) {
      final chunk = lookupKeys.skip(i).take(10).toList();
      final docs = await _firestore.phoneIndex
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in docs.docs) {
        final normalizedPhone = phoneLookup[doc.id];
        if (normalizedPhone != null) {
          result[normalizedPhone] = doc.data();
        }
      }
    }
    return result;
  }

  Future<void> _attachProfileImages(
    Map<String, Map<String, dynamic>> registered,
  ) async {
    final entries = registered.entries
        .where((entry) => entry.value['uid'] is String)
        .toList();

    for (var i = 0; i < entries.length; i += 10) {
      final chunk = entries.skip(i).take(10).toList();
      final userIds = chunk
          .map((entry) => entry.value['uid'] as String)
          .toSet()
          .toList();
      if (userIds.isEmpty) continue;

      final users = await _firestore.users
          .where(FieldPath.documentId, whereIn: userIds)
          .get();
      final imageByUserId = {
        for (final doc in users.docs)
          doc.id: doc.data()['profileImageUrl'] as String?,
      };

      for (final entry in chunk) {
        final uid = entry.value['uid'] as String;
        final imageUrl = imageByUserId[uid];
        if (imageUrl != null && imageUrl.trim().isNotEmpty) {
          entry.value['profileImageUrl'] = imageUrl.trim();
        }
      }
    }
  }
}
