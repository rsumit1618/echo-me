import 'package:echo_me/domain/entity/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Stream<fb.User?> firebaseAuthStateChanges();
  AppUser? get currentUser;
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  });
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) failed,
  });
  Future<AppUser> verifyOtp({
    required String verificationId,
    required String smsCode,
  });
  Future<AppUser> verifyOtpAndLinkPhone({
    required String verificationId,
    required String smsCode,
  });
  Future<void> updateProfile({String? email, String? profileImageUrl});
  Future<void> signOut();
  fb.User? get firebaseUser;
}
