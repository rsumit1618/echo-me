import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/features/auth/email_login_screen.dart';
import 'package:echo_me/features/auth/otp_login_screen.dart';
import 'package:echo_me/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void _logError(Object? error, StackTrace stackTrace) {
  // Ensures the real Firestore permission exception is visible in console.
  // Helps debug rule mismatches.
  // ignore: avoid_print
  debugPrint('AuthGate error: $error');
  // ignore: avoid_print
  debugPrint('AuthGate stackTrace: $stackTrace');
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseUser = ref.watch(firebaseUserProvider);
    return firebaseUser.when(
      data: (user) {
        if (user == null) return const EmailLoginScreen();
        if (user.phoneNumber == null) return const MobileVerificationScreen();

        // Always show a UI while profile is loading; never risk a blank screen.
        final profile = ref.watch(authStateProvider);
        return profile.when(
          data: (appUser) {
            // If Firestore profile/doc isn't linked/bootstrapped yet, force phone verification linking flow.
            if (appUser == null) return const MobileVerificationScreen();
            return const HomeScreen();
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) {
            _logError(error, stackTrace);
            return const MobileVerificationScreen();
          },
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) {
        _logError(error, stackTrace);
        return _AuthError(message: error.toString());
      },
    );
  }
}

class _AuthError extends StatelessWidget {
  final String message;

  const _AuthError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not start session: $message',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
