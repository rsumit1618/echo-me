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

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final firebaseUserProvider = StreamProvider(
  (ref) => ref.watch(authRepositoryProvider).firebaseAuthStateChanges(),
);

final contactsProvider = StreamProvider<List<AppContact>>(
  (ref) => ref.watch(contactRepositoryProvider).watchContacts(),
);

final recentChatsProvider = StreamProvider<List<Chat>>(
  (ref) => ref.watch(chatRepositoryProvider).watchRecentChats(),
);

final chatProvider = StreamProvider.family<Chat?, String>(
  (ref, chatId) => ref.watch(chatRepositoryProvider).watchChat(chatId),
);

final messagesProvider = StreamProvider.family<List<Message>, String>(
  (ref, chatId) => ref.watch(chatRepositoryProvider).watchMessages(chatId),
);

final userStatusProvider = StreamProvider.family<Map<String, dynamic>?, String>(
  (ref, userId) => ref.watch(chatRepositoryProvider).watchUserStatus(userId),
);

final callHistoryProvider = StreamProvider<List<CallLogEntry>>(
  (ref) => ref.watch(callRepositoryProvider).watchCallHistory(),
);

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, AppThemeMode>(
      (ref) => ThemeModeController(ref.watch(settingsRepositoryProvider)),
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
