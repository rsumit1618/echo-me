import 'dart:io';

import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/theme/app_theme.dart';
import 'package:echo_me/domain/entity/app_user.dart';
import 'package:echo_me/domain/entity/call.dart';
import 'package:echo_me/domain/entity/chat.dart';
import 'package:echo_me/domain/entity/contact.dart';
import 'package:echo_me/domain/entity/message.dart';
import 'package:echo_me/domain/repository/auth_repository.dart';
import 'package:echo_me/domain/repository/call_repository.dart';
import 'package:echo_me/domain/repository/chat_repository.dart';
import 'package:echo_me/domain/repository/contact_repository.dart';
import 'package:echo_me/features/chats/message_thread_screen.dart';
import 'package:echo_me/features/contacts/contacts_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app themes are buildable', () {
    expect(AppTheme.light().useMaterial3, isTrue);
    expect(
      AppTheme.dark().brightness,
      equals(AppTheme.dark().colorScheme.brightness),
    );
    expect(AppTheme.elite().colorScheme.primary, isNotNull);
  });

  for (final size in const [Size(360, 780), Size(430, 900), Size(820, 1180)]) {
    testWidgets('contacts screen fits at ${size.width.toInt()}px width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contactRepositoryProvider.overrideWithValue(
              _FakeContactRepository(),
            ),
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ContactsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Chat Now'), findsWidgets);
      expect(find.text('Invite'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('message thread disposes without reading ref after unmount', (
    tester,
  ) async {
    final chatRepository = _FakeChatRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          chatRepositoryProvider.overrideWithValue(chatRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MessageThreadScreen(chatId: 'chat-1'),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(chatRepository.activeChatIds.last, isNull);
    expect(tester.takeException(), isNull);
  });
}

class _FakeContactRepository implements ContactRepository {
  @override
  Future<List<AppContact>> syncDeviceContacts() async => _contacts;

  @override
  Stream<List<AppContact>> watchContacts() => Stream.value(_contacts);

  static final _contacts = [
    AppContact(
      id: '1',
      displayName: 'Test1 With Very Long Name',
      normalizedPhone: '1234567890',
      registeredUserId: 'peer-1',
      syncedAt: DateTime(2026),
    ),
    AppContact(
      id: '2',
      displayName: 'Test Moto Device With Long Name',
      normalizedPhone: '1234567892',
      registeredUserId: 'peer-2',
      syncedAt: DateTime(2026),
    ),
    AppContact(
      id: '3',
      displayName: '+91 99713 31493',
      normalizedPhone: '9971331493',
      syncedAt: DateTime(2026),
    ),
  ];
}

class _FakeAuthRepository implements AuthRepository {
  final _user = AppUser(
    uid: 'user-1',
    phoneNumber: '+911234567890',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  @override
  AppUser? get currentUser => _user;

  @override
  fb.User? get firebaseUser => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(_user);

  @override
  Stream<fb.User?> firebaseAuthStateChanges() => Stream.value(null);

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) failed,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> updateProfile({String? email, String? profileImageUrl}) async {}

  @override
  Future<AppUser> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async => _user;

  @override
  Future<AppUser> verifyOtpAndLinkPhone({
    required String verificationId,
    required String smsCode,
  }) async => _user;
}

class _FakeChatRepository implements ChatRepository {
  final activeChatIds = <String?>[];
  final typingStates = <bool>[];

  @override
  Future<List<Message>> fetchMessagesBefore(
    String chatId,
    DateTime before, {
    int limit = 30,
  }) async => const [];

  @override
  Future<String> getOrCreateOneToOneChat(
    String peerUserId, {
    String? peerDisplayName,
    String? peerPhoneNumber,
    String? peerProfileImageUrl,
  }) async => 'chat-1';

  @override
  Future<void> markRead(String chatId) async {}

  @override
  Future<void> sendFilesMessage(String chatId, List<File> files) async {}

  @override
  Future<void> sendImageMessage(String chatId, List<File> images) async {}

  @override
  Future<void> sendTextMessage(String chatId, String text) async {}

  @override
  Future<void> setActiveChat(String? chatId) async {
    activeChatIds.add(chatId);
  }

  @override
  Future<void> setTyping(String chatId, bool isTyping) async {
    typingStates.add(isTyping);
  }

  @override
  Stream<Chat?> watchChat(String chatId) => Stream.value(
    Chat(
      id: chatId,
      participantIds: const ['user-1', 'peer-1'],
      participantNames: const {'peer-1': 'Test1'},
      updatedAt: DateTime(2026),
    ),
  );

  @override
  Stream<List<Message>> watchMessages(String chatId, {int limit = 30}) =>
      Stream.value(const []);

  @override
  Stream<List<Chat>> watchRecentChats() => Stream.value(const []);

  @override
  Stream<Map<String, dynamic>?> watchUserStatus(String userId) =>
      Stream.value(const {'isOnline': true});
}

class _FakeCallRepository implements CallRepository {
  @override
  Future<void> recordCall(CallLogEntry call) async {}

  @override
  Stream<List<CallLogEntry>> watchCallHistory() => Stream.value(const []);
}
