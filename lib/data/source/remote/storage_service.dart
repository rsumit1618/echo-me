import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage storage;

  StorageService({FirebaseStorage? storage}) : storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadFile({
    required File file,
    required String path,
    required String contentType,
  }) async {
    final ref = storage.ref(path);
    await ref.putFile(file, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
