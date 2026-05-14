import 'package:echo_me/core/di/injector.dart';
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
import 'package:echo_me/domain/repository/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>(
      (_) => getIt<AuthRepository>(),
);

final contactRepositoryProvider = Provider<ContactRepository>(
      (_) => getIt<ContactRepository>(),
);

final chatRepositoryProvider = Provider<ChatRepository>(
      (_) => getIt<ChatRepository>(),
);

final callRepositoryProvider = Provider<CallRepository>(
      (_) => getIt<CallRepository>(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
      (_) => getIt<SettingsRepository>(),
);

/// AUTH STATE
final authStateProvider = StreamProvider.autoDispose<AppUser?>(
      (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// FIREBASE USER
final firebaseUserProvider = StreamProvider.autoDispose(
      (ref) => ref.watch(authRepositoryProvider).firebaseAuthStateChanges(),
);

/// CURRENT USER ID
final currentUserIdProvider = StreamProvider.autoDispose<String?>(
      (ref) => ref
      .watch(authRepositoryProvider)
      .firebaseAuthStateChanges()
      .map((user) => user?.uid),
);

/// CONTACTS
final contactsProvider = StreamProvider.autoDispose<List<AppContact>>(
      (ref) {
    final uid = ref.watch(currentUserIdProvider).valueOrNull;

    if (uid == null) {
      return Stream.value(const <AppContact>[]);
    }

    return ref.watch(contactRepositoryProvider).watchContacts();
  },
);

/// RECENT CHATS
final recentChatsProvider = StreamProvider.autoDispose<List<Chat>>(
      (ref) {
    final uid = ref.watch(currentUserIdProvider).valueOrNull;

    if (uid == null) {
      return Stream.value(const <Chat>[]);
    }

    return ref.watch(chatRepositoryProvider).watchRecentChats();
  },
);

/// SINGLE CHAT
final chatProvider = StreamProvider.autoDispose.family<Chat?, String>(
      (ref, chatId) {
    final uid = ref.watch(currentUserIdProvider).valueOrNull;

    if (uid == null) {
      return Stream.value(null);
    }

    return ref.watch(chatRepositoryProvider).watchChat(chatId);
  },
);

/// MESSAGES
final messagesProvider =
StreamProvider.autoDispose.family<List<Message>, String>(
      (ref, chatId) {
    final uid = ref.watch(currentUserIdProvider).valueOrNull;

    if (uid == null) {
      return Stream.value(const <Message>[]);
    }

    return ref.watch(chatRepositoryProvider).watchMessages(chatId);
  },
);

/// USER STATUS
final userStatusProvider =
StreamProvider.autoDispose.family<Map<String, dynamic>?, String>(
      (ref, userId) =>
      ref.watch(chatRepositoryProvider).watchUserStatus(userId),
);

/// CALL HISTORY
final callHistoryProvider =
StreamProvider.autoDispose<List<CallLogEntry>>(
      (ref) {
    final uid = ref.watch(currentUserIdProvider).valueOrNull;

    if (uid == null) {
      return Stream.value(const <CallLogEntry>[]);
    }

    return ref.watch(callRepositoryProvider).watchCallHistory();
  },
);

/// THEME (KEEP PERSISTENT)
final themeModeProvider =
StateNotifierProvider<ThemeModeController, AppThemeMode>(
      (ref) => ThemeModeController(
    ref.watch(settingsRepositoryProvider),
  ),
);

class ThemeModeController extends StateNotifier<AppThemeMode> {
  final SettingsRepository _settings;

  ThemeModeController(this._settings) : super(AppThemeMode.light) {
    _load();
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    await _settings.saveTheme(mode);
  }

  Future<void> _load() async {
    state = await _settings.loadTheme();
  }
}