import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echo_me/core/constants/firebase_paths.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/core/utils/phone_normalizer.dart';
import 'package:echo_me/data/model/user_model.dart';
import 'package:echo_me/data/source/local/fqlite_service.dart';
import 'package:echo_me/data/source/remote/firebase_auth_service.dart';
import 'package:echo_me/data/source/remote/firestore_service.dart';
import 'package:echo_me/data/source/remote/notification_service.dart';
import 'package:echo_me/domain/entity/app_user.dart';
import 'package:echo_me/domain/repository/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthService _auth;
  final FirestoreService _firestore;
  final NotificationService _notifications;
  final FQLiteService _local;

  AuthRepositoryImpl(
    this._auth,
    this._firestore,
    this._notifications,
    this._local,
  );

  @override
  fb.User? get firebaseUser => _auth.currentUser;

  @override
  Stream<fb.User?> firebaseAuthStateChanges() => _auth.authStateChanges();

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null || user.phoneNumber == null) return null;
    final now = DateTime.now();
    return AppUser(
      uid: user.uid,
      phoneNumber: user.phoneNumber!,
      email: user.email,
      profileImageUrl: user.photoURL,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncExpand((user) async* {
      if (user == null || user.phoneNumber == null) {
        yield null;
        return;
      }

      final doc = await _firestore.users.doc(user.uid).get();
      if (!doc.exists) {
        yield await _ensureProfile(user);
      }

      yield* _firestore.users.doc(user.uid).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (data == null) return null;
        return UserModel.fromMap(snapshot.id, data);
      });
    });
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmail(email: email.trim(), password: password);
    } on fb.FirebaseAuthException catch (error) {
      throw AppException(_authMessage(error), error);
    }
  }

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createAccountWithEmail(
        email: email.trim(),
        password: password,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw AppException(_authMessage(error), error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email.trim());
    } on fb.FirebaseAuthException catch (error) {
      throw AppException(_authMessage(error), error);
    }
  }

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) failed,
  }) {
    if (!phoneNumber.startsWith('+')) {
      throw const AppException(
        'Use phone number with country code, for example +919876543210.',
      );
    }
    return _auth.sendOtp(
      phoneNumber: phoneNumber,
      codeSent: codeSent,
      failed: failed,
    );
  }

  @override
  Future<AppUser> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final fbUser = await _auth.verifyOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return _ensureProfile(fbUser);
    } on fb.FirebaseAuthException catch (error) {
      throw AppException(
        error.message ?? 'Invalid OTP. Please try again.',
        error,
      );
    }
  }

  @override
  Future<AppUser> verifyOtpAndLinkPhone({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final fbUser = await _auth.linkPhoneCredential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return _ensureProfile(fbUser);
    } on fb.FirebaseAuthException catch (error) {
      throw AppException(_authMessage(error), error);
    }
  }

  @override
  Future<void> updateProfile({String? email, String? profileImageUrl}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AppException('Please login again to update your profile.');
    }
    final updates = <String, dynamic>{
      if (email != null) 'email': email.trim().isEmpty ? null : email.trim(),
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _firestore.users.doc(user.uid).set(updates, SetOptions(merge: true));

    if (profileImageUrl != null) {
      final phone = user.phoneNumber;
      final phoneIndex = _firestore.db.collection(FirebasePaths.phoneIndex);
      final phoneIndexData = {
        'profileImageUrl': profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (phone != null && phone.isNotEmpty) {
        await phoneIndex.doc(phone).set(phoneIndexData, SetOptions(merge: true));
        final normalizedPhone = PhoneNormalizer.normalizeToIndian10DigitOrNull(
          phone,
        );
        if (normalizedPhone != null) {
          await phoneIndex
              .doc(normalizedPhone)
              .set(phoneIndexData, SetOptions(merge: true));
        }
      }
    }
  }

  @override
  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.users.doc(user.uid).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await _local.clearAll();
    await _auth.signOut();
  }

  Future<AppUser> _ensureProfile(fb.User fbUser) async {
    final phone = fbUser.phoneNumber;
    if (phone == null) {
      throw const AppException('Firebase did not return a mobile number.');
    }
    final token = await _notifications.prepareDeviceToken();
    final ref = _firestore.users.doc(fbUser.uid);
    final snapshot = await ref.get();
    final now = DateTime.now();
    final model = snapshot.exists
        ? UserModel(
            uid: fbUser.uid,
            phoneNumber: phone,
            email: UserModel.fromFirestore(snapshot).email,
            profileImageUrl: UserModel.fromFirestore(snapshot).profileImageUrl,
            fcmToken: token,
            isOnline: true,
            lastSeen: null,
            createdAt: UserModel.fromFirestore(snapshot).createdAt,
            updatedAt: now,
          )
        : UserModel(
            uid: fbUser.uid,
            phoneNumber: phone,
            email: fbUser.email,
            profileImageUrl: fbUser.photoURL,
            fcmToken: token,
            isOnline: true,
            lastSeen: null,
            createdAt: now,
            updatedAt: now,
          );
    await ref.set(model.toMap(), SetOptions(merge: true));
    final phoneIndexData = {
      'uid': fbUser.uid,
      'phoneNumber': phone,
      'profileImageUrl': model.profileImageUrl,
      'canCall': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final phoneIndex = _firestore.db.collection(FirebasePaths.phoneIndex);
    await phoneIndex.doc(phone).set(phoneIndexData);

    final normalizedPhone = PhoneNormalizer.normalizeToIndian10DigitOrNull(
      phone,
    );
    if (normalizedPhone != null) {
      await phoneIndex.doc(normalizedPhone).set(phoneIndexData);
    }
    return model;
  }

  String _authMessage(fb.FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' =>
        'This email is already registered. Please login instead.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Password should be at least 6 characters.',
      'user-not-found' => 'No account found with this email.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'invalid-credential' => 'Invalid email or password.',
      'credential-already-in-use' =>
        'This mobile number is already linked to another account.',
      'provider-already-linked' =>
        'This account already has a mobile number linked.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }
}
