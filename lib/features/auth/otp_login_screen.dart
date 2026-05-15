import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/core/utils/phone_normalizer.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/domain/repository/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

final otpStateProvider = StateNotifierProvider<OtpController, OtpState>((ref) {
  return OtpController(ref.watch(authRepositoryProvider));
});

class OtpState {
  final bool loading;
  final String? verificationId;
  final String? error;

  const OtpState({this.loading = false, this.verificationId, this.error});

  OtpState copyWith({bool? loading, String? verificationId, String? error}) {
    return OtpState(
      loading: loading ?? this.loading,
      verificationId: verificationId ?? this.verificationId,
      error: error,
    );
  }
}

class OtpController extends StateNotifier<OtpState> {
  final AuthRepository _authRepository;

  OtpController(this._authRepository) : super(const OtpState());

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(loading: true, error: null);
    try {
      if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
        throw const AppException('Enter a valid 10 digit mobile number.');
      }
      await _authRepository.sendOtp(
        phoneNumber: PhoneNormalizer.normalize(phone),
        codeSent: (verificationId, _) {
          state = OtpState(verificationId: verificationId);
        },
        failed: (message) {
          state = OtpState(error: message);
        },
      );
    } catch (error) {
      state = OtpState(error: AppErrorMapper.message(error));
    }
  }

  Future<void> verify(String code) async {
    final verificationId = state.verificationId;
    if (verificationId == null) return;
    state = state.copyWith(loading: true, error: null);
    try {
      await _authRepository.verifyOtpAndLinkPhone(
        verificationId: verificationId,
        smsCode: code,
      );
      state = const OtpState();
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: AppErrorMapper.message(error),
      );
    }
  }
}

class MobileVerificationScreen extends ConsumerStatefulWidget {
  const MobileVerificationScreen({super.key});

  @override
  ConsumerState<MobileVerificationScreen> createState() =>
      _MobileVerificationScreenState();
}

class _MobileVerificationScreenState
    extends ConsumerState<MobileVerificationScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpStateProvider);
    final controller = ref.read(otpStateProvider.notifier);
    final waitingForOtp = state.verificationId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify mobile'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - value)),
                  child: child,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          const Color(0xFF0EA5E9),
                          Theme.of(context).colorScheme.tertiary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .24),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    waitingForOtp
                        ? 'Enter verification code'
                        : 'Add your mobile number',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    waitingForOtp
                        ? 'Use the 6 digit OTP sent to your mobile number.'
                        : 'Mobile verification is required before using Echo Me.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AppCard(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .62),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: !waitingForOtp
                    ? Column(
                        key: const ValueKey('phone'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mobile number',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.number,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: const InputDecoration(
                              counterText: '',
                              prefixIcon: Icon(Icons.phone_iphone),
                              prefixText: '+91  ',
                              hintText: '9999999901',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Only Indian 10 digit mobile numbers are accepted.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('otp'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verification',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _otp,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: const InputDecoration(
                              counterText: '',
                              prefixIcon: Icon(Icons.lock_outline),
                              hintText: '123456',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.loading
                  ? null
                  : () => waitingForOtp
                        ? controller.verify(_otp.text)
                        : controller.sendOtp(_phone.text),
              child: state.loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(waitingForOtp ? 'Verify' : 'Send OTP'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
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
