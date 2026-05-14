import 'package:echo_me/core/di/injector.dart';
import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/routing/auth_gate.dart';
import 'package:echo_me/core/theme/app_theme.dart';
import 'package:echo_me/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      rethrow;
    }
    debugPrint(
      'Firebase default app already exists; continuing after hot restart.',
    );
  }
  setupDependencies();
  runApp(const ProviderScope(child: EchoMeApp()));
}

class EchoMeApp extends ConsumerWidget {
  const EchoMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = AppTheme.fromMode(mode);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Echo Me',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}
