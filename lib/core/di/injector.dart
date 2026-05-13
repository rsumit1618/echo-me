import 'package:echo_me/core/utils/image_optimizer.dart';
import 'package:echo_me/data/repository/auth_repository_impl.dart';
import 'package:echo_me/data/repository/call_repository_impl.dart';
import 'package:echo_me/data/repository/chat_repository_impl.dart';
import 'package:echo_me/data/repository/contact_repository_impl.dart';
import 'package:echo_me/data/repository/settings_repository_impl.dart';
import 'package:echo_me/data/source/local/fqlite_service.dart';
import 'package:echo_me/data/source/remote/firebase_auth_service.dart';
import 'package:echo_me/data/source/remote/firestore_service.dart';
import 'package:echo_me/data/source/remote/notification_service.dart';
import 'package:echo_me/data/source/remote/storage_service.dart';
import 'package:echo_me/domain/repository/auth_repository.dart';
import 'package:echo_me/domain/repository/call_repository.dart';
import 'package:echo_me/domain/repository/chat_repository.dart';
import 'package:echo_me/domain/repository/contact_repository.dart';
import 'package:echo_me/domain/repository/settings_repository.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  getIt.registerLazySingleton<FirebaseAuthService>(() => FirebaseAuthService());
  getIt.registerLazySingleton<FirestoreService>(() => FirestoreService());
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  getIt.registerLazySingleton<FQLiteService>(() => FQLiteService());
  getIt.registerLazySingleton<ImageOptimizer>(() => ImageOptimizer());

  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      getIt<FirebaseAuthService>(),
      getIt<FirestoreService>(),
      getIt<NotificationService>(),
      getIt<FQLiteService>(),
    ),
  );
  getIt.registerLazySingleton<ContactRepository>(
    () => ContactRepositoryImpl(
      getIt<AuthRepository>(),
      getIt<FirestoreService>(),
      getIt<FQLiteService>(),
    ),
  );
  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      getIt<AuthRepository>(),
      getIt<FirestoreService>(),
      getIt<FQLiteService>(),
      getIt<ImageOptimizer>(),
    ),
  );
  getIt.registerLazySingleton<CallRepository>(
    () => CallRepositoryImpl(getIt<AuthRepository>(), getIt<FirestoreService>()),
  );
  getIt.registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl());
}
