import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

abstract class AppFailure implements Exception {
  final String message;
  final Object? cause;

  const AppFailure(this.message, [this.cause]);

  @override
  String toString() => message;
}

class AppException extends AppFailure {
  const AppException(super.message, [super.cause]);
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([Object? cause])
    : super(
        'No internet connection. Please check your network and try again.',
        cause,
      );
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, [super.cause]);
}

class PermissionFailure extends AppFailure {
  const PermissionFailure([Object? cause])
    : super('Permission is required to complete this action.', cause);
}

class ServerFailure extends AppFailure {
  const ServerFailure([Object? cause])
    : super(
        'Service is temporarily unavailable. Please try again shortly.',
        cause,
      );
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([Object? cause])
    : super('Something went wrong. Please try again.', cause);
}

class AppErrorMapper {
  const AppErrorMapper._();

  static AppFailure map(Object error) {
    if (error is AppFailure) return error;
    if (error is TimeoutException || error is SocketException) {
      return NetworkFailure(error);
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      if (code.contains('network') || message.contains('network')) {
        return NetworkFailure(error);
      }
      if (code.contains('permission') || message.contains('permission')) {
        return PermissionFailure(error);
      }
      return UnknownFailure(error);
    }
    if (error is fb.FirebaseAuthException) {
      return AuthFailure(_authMessage(error), error);
    }
    if (error is FirebaseException) {
      return _mapFirebase(error);
    }
    return UnknownFailure(error);
  }

  static String message(Object error) => map(error).message;

  static AppFailure _mapFirebase(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return NetworkFailure(error);
      case 'permission-denied':
        return const PermissionFailure();
      case 'unauthenticated':
        return const AuthFailure('Please login again to continue.');
      case 'resource-exhausted':
      case 'aborted':
      case 'internal':
      case 'unknown':
        return ServerFailure(error);
      case 'failed-precondition':
        return ServerFailure(error);
      default:
        return UnknownFailure(error);
    }
  }

  static String _authMessage(fb.FirebaseAuthException error) {
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
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' =>
        'No internet connection. Please check your network and try again.',
      _ => 'Authentication failed. Please try again.',
    };
  }
}
