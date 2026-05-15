import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/features/echo_ai/echo_ai_advisor.dart';
import 'package:echo_me/features/echo_ai/echo_ai_message.dart';
import 'package:echo_me/features/echo_ai/echo_ai_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

final echoAiRepositoryProvider = Provider.autoDispose<EchoAiRepository>((ref) {
  final repository = EchoAiRepository(ref.watch(authRepositoryProvider));
  ref.onDispose(repository.close);
  return repository;
});

final echoAiControllerProvider = Provider.autoDispose
    .family<EchoAiController, EchoAiAdvisor>((ref, advisor) {
      final controller = EchoAiController(
        advisor: advisor,
        repository: ref.watch(echoAiRepositoryProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

final echoAiStateProvider = StreamProvider.autoDispose
    .family<EchoAiState, EchoAiAdvisor>((ref, advisor) {
      final controller = ref.watch(echoAiControllerProvider(advisor));
      return controller.stateStream;
    });

class EchoAiState {
  final List<EchoAiMessage> messages;
  final bool sending;
  final String? error;

  const EchoAiState({required this.messages, this.sending = false, this.error});

  EchoAiState copyWith({
    List<EchoAiMessage>? messages,
    bool? sending,
    String? error,
  }) {
    return EchoAiState(
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      error: error,
    );
  }
}

class EchoAiController {
  final EchoAiAdvisor advisor;
  final EchoAiRepository _repository;
  final _uuid = const Uuid();
  late final BehaviorSubject<EchoAiState> _stateSubject;

  EchoAiController({
    required this.advisor,
    required EchoAiRepository repository,
  }) : _repository = repository {
    _stateSubject = BehaviorSubject.seeded(
      EchoAiState(
        messages: [
          EchoAiMessage(
            id: 'welcome-${advisor.id}',
            role: EchoAiMessageRole.assistant,
            text: 'Hi, I am ${advisor.name}. ${advisor.description}',
            createdAt: DateTime.now(),
          ),
        ],
      ),
    );
  }

  Stream<EchoAiState> get stateStream => _stateSubject.stream.distinct();

  EchoAiState get state => _stateSubject.value;

  Future<void> sendText(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || state.sending) return;

    final userMessage = EchoAiMessage(
      id: _uuid.v4(),
      role: EchoAiMessageRole.user,
      text: sanitizeEchoAiText(cleanText),
      createdAt: DateTime.now(),
    );

    final nextMessages = [...state.messages, userMessage];
    _emit(state.copyWith(messages: nextMessages, sending: true));

    try {
      final reply = await _repository.sendMessage(
        advisorId: advisor.id,
        messages: nextMessages,
      );
      final assistantMessage = EchoAiMessage(
        id: _uuid.v4(),
        role: EchoAiMessageRole.assistant,
        text: reply,
        createdAt: DateTime.now(),
      );
      _emit(
        state.copyWith(
          messages: [...state.messages, assistantMessage],
          sending: false,
        ),
      );
    } catch (error) {
      _emit(
        state.copyWith(sending: false, error: AppErrorMapper.message(error)),
      );
    }
  }

  void clearError() {
    if (state.error == null) return;
    _emit(state.copyWith());
  }

  void reset() {
    _emit(
      EchoAiState(
        messages: [
          EchoAiMessage(
            id: 'welcome-${advisor.id}-${DateTime.now().microsecondsSinceEpoch}',
            role: EchoAiMessageRole.assistant,
            text: 'Hi, I am ${advisor.name}. ${advisor.description}',
            createdAt: DateTime.now(),
          ),
        ],
      ),
    );
  }

  void _emit(EchoAiState nextState) {
    if (!_stateSubject.isClosed) _stateSubject.add(nextState);
  }

  void dispose() {
    _stateSubject.close();
  }
}
