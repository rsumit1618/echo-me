import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/domain/repository/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final emailAuthProvider =
    StateNotifierProvider<EmailAuthController, EmailAuthState>((ref) {
      return EmailAuthController(ref.watch(authRepositoryProvider));
    });

class EmailAuthState {
  final bool loading;
  final bool registerMode;
  final String? message;
  final String? error;

  const EmailAuthState({
    this.loading = false,
    this.registerMode = false,
    this.message,
    this.error,
  });

  EmailAuthState copyWith({
    bool? loading,
    bool? registerMode,
    String? message,
    String? error,
  }) {
    return EmailAuthState(
      loading: loading ?? this.loading,
      registerMode: registerMode ?? this.registerMode,
      message: message,
      error: error,
    );
  }
}

class EmailAuthController extends StateNotifier<EmailAuthState> {
  final AuthRepository _authRepository;

  EmailAuthController(this._authRepository) : super(const EmailAuthState());

  void toggleMode() {
    state = EmailAuthState(registerMode: !state.registerMode);
  }

  Future<void> submit(String email, String password) async {
    state = state.copyWith(loading: true, error: null, message: null);
    try {
      if (state.registerMode) {
        await _authRepository.createAccountWithEmail(
          email: email,
          password: password,
        );
      } else {
        await _authRepository.signInWithEmail(email: email, password: password);
      }
      state = state.copyWith(loading: false);
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: AppErrorMapper.message(error),
      );
    }
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(loading: true, error: null, message: null);
    try {
      await _authRepository.sendPasswordResetEmail(email);
      state = state.copyWith(
        loading: false,
        message: 'Password reset link sent to your email.',
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: AppErrorMapper.message(error),
      );
    }
  }
}

class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emailAuthProvider);
    final controller = ref.read(emailAuthProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Echo Me')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 42),
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: const Icon(Icons.mark_email_unread_outlined, size: 30),
            ),
            const SizedBox(height: 22),
            Text(
              state.registerMode ? 'Create your account' : 'Welcome back',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              'Login with email first. Every new account must verify a mobile number next.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            AppCard(
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: state.loading
                          ? null
                          : () => controller.forgotPassword(_email.text),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.loading
                  ? null
                  : () => controller.submit(_email.text, _password.text),
              child: state.loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(state.registerMode ? 'Create account' : 'Login'),
            ),
            TextButton(
              onPressed: state.loading ? null : controller.toggleMode,
              child: Text(
                state.registerMode
                    ? 'Already have an account? Login'
                    : 'New here? Create account',
              ),
            ),
            if (state.message != null) ...[
              const SizedBox(height: 12),
              Text(
                state.message!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
