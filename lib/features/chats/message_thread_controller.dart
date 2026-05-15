import 'dart:async';
import 'dart:io';

import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/domain/entity/message.dart';
import 'package:echo_me/domain/repository/chat_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

final messageThreadControllerProvider = Provider.autoDispose
    .family<MessageThreadController, String>((ref, chatId) {
      final controller = MessageThreadController(ref, chatId);
      ref.onDispose(controller.dispose);
      return controller;
    });

final messageThreadUiProvider = StreamProvider.autoDispose
    .family<MessageThreadUiState, String>((ref, chatId) {
      return ref.watch(messageThreadControllerProvider(chatId)).stateStream;
    });

final messageThreadListUiProvider = StreamProvider.autoDispose
    .family<MessageThreadListUiState, String>((ref, chatId) {
      return ref.watch(messageThreadControllerProvider(chatId)).listStateStream;
    });

class MessageThreadUiState {
  final bool sending;
  final bool loadingOlder;
  final bool hasMoreOlder;
  final List<Message> olderMessages;
  final List<Message> optimisticMessages;

  const MessageThreadUiState({
    this.sending = false,
    this.loadingOlder = false,
    this.hasMoreOlder = true,
    this.olderMessages = const [],
    this.optimisticMessages = const [],
  });

  MessageThreadUiState copyWith({
    bool? sending,
    bool? loadingOlder,
    bool? hasMoreOlder,
    List<Message>? olderMessages,
    List<Message>? optimisticMessages,
  }) {
    return MessageThreadUiState(
      sending: sending ?? this.sending,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      olderMessages: olderMessages ?? this.olderMessages,
      optimisticMessages: optimisticMessages ?? this.optimisticMessages,
    );
  }
}

class MessageThreadListUiState {
  final bool loadingOlder;
  final bool hasMoreOlder;
  final List<Message> olderMessages;
  final List<Message> optimisticMessages;

  const MessageThreadListUiState({
    required this.loadingOlder,
    required this.hasMoreOlder,
    required this.olderMessages,
    required this.optimisticMessages,
  });
}

class MessageThreadController {
  final Ref _ref;
  final String _chatId;
  final ChatRepository _chatRepository;
  final BehaviorSubject<MessageThreadUiState> _stateSubject;
  final BehaviorSubject<String> _typingSubject;
  late final StreamSubscription<String> _typingSubscription;
  Timer? _activityTimer;
  bool _disposed = false;

  MessageThreadController(this._ref, this._chatId)
    : _chatRepository = _ref.read(chatRepositoryProvider),
      _stateSubject = BehaviorSubject.seeded(const MessageThreadUiState()),
      _typingSubject = BehaviorSubject.seeded('') {
    _typingSubscription = _typingSubject
        .map((text) => text.trim())
        .distinct()
        .debounceTime(const Duration(milliseconds: 350))
        .listen((text) => _setTyping(text.isNotEmpty));
    unawaited(_activateThread());
    _activityTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_chatRepository.setActiveChat(_chatId)),
    );
  }

  Stream<MessageThreadUiState> get stateStream => _stateSubject.stream;

  Stream<MessageThreadListUiState> get listStateStream => stateStream
      .map(
        (state) => MessageThreadListUiState(
          loadingOlder: state.loadingOlder,
          hasMoreOlder: state.hasMoreOlder,
          olderMessages: state.olderMessages,
          optimisticMessages: state.optimisticMessages,
        ),
      )
      .distinct((previous, next) {
        return previous.loadingOlder == next.loadingOlder &&
            previous.hasMoreOlder == next.hasMoreOlder &&
            identical(previous.olderMessages, next.olderMessages) &&
            identical(previous.optimisticMessages, next.optimisticMessages);
      });

  MessageThreadUiState get state => _stateSubject.value;

  MessageThreadListUiState get listState {
    final value = state;
    return MessageThreadListUiState(
      loadingOlder: value.loadingOlder,
      hasMoreOlder: value.hasMoreOlder,
      olderMessages: value.olderMessages,
      optimisticMessages: value.optimisticMessages,
    );
  }

  void textChanged(String text) {
    if (_disposed) return;
    _typingSubject.add(text);
  }

  Future<void> loadOlder(List<Message> currentMessages) async {
    if (state.loadingOlder || currentMessages.isEmpty) return;
    await _requireInternet();
    _emit(state.copyWith(loadingOlder: true));
    try {
      final oldest = currentMessages.last.createdAt;
      final older = await _chatRepository
          .fetchMessagesBefore(_chatId, oldest)
          .timeout(const Duration(seconds: 30));
      final knownIds = {
        ...state.olderMessages.map((message) => message.id),
        ...currentMessages.map((message) => message.id),
      };
      final mergedOlder = [
        ...state.olderMessages,
        ...older.where((message) => knownIds.add(message.id)),
      ];
      _emit(
        state.copyWith(
          olderMessages: mergedOlder,
          hasMoreOlder: older.isNotEmpty,
        ),
      );
    } catch (error) {
      throw AppErrorMapper.map(error);
    } finally {
      _emit(state.copyWith(loadingOlder: false));
    }
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;
    await _requireInternet();

    final optimistic = _optimisticTextMessage(trimmed);
    _emit(
      state.copyWith(
        sending: true,
        optimisticMessages: [optimistic, ...state.optimisticMessages],
      ),
    );
    try {
      await _chatRepository
          .sendTextMessage(_chatId, trimmed)
          .timeout(const Duration(seconds: 30));
      await _setTyping(false);
      _replaceOptimistic(optimistic, MessageState.sent);
    } catch (error) {
      _replaceOptimistic(optimistic, MessageState.failed);
      throw AppErrorMapper.map(error);
    } finally {
      _emit(state.copyWith(sending: false));
    }
  }

  Future<void> sendFiles(List<File> files) async {
    if (files.isEmpty || state.sending) return;
    await _requireInternet();
    _emit(state.copyWith(sending: true));
    try {
      await _chatRepository
          .sendFilesMessage(_chatId, files)
          .timeout(const Duration(seconds: 45));
    } catch (error) {
      throw AppErrorMapper.map(error);
    } finally {
      _emit(state.copyWith(sending: false));
    }
  }

  Future<void> markRead() async {
    try {
      await _chatRepository.markRead(_chatId);
    } catch (_) {
      // Read receipts are best effort and should not block the thread.
    }
  }

  void dispose() {
    _disposed = true;
    _activityTimer?.cancel();
    unawaited(_typingSubscription.cancel());
    unawaited(_chatRepository.setTyping(_chatId, false));
    unawaited(_chatRepository.setActiveChat(null));
    unawaited(_stateSubject.close());
    unawaited(_typingSubject.close());
  }

  Future<void> _activateThread() async {
    try {
      await _chatRepository.setActiveChat(_chatId);
      await _chatRepository.markRead(_chatId);
    } catch (_) {
      // The visible message stream will surface important load failures.
    }
  }

  Future<void> _requireInternet() async {
    final online = await _ref.read(connectivityServiceProvider).isOnline();
    if (!online) throw const NetworkFailure();
  }

  Future<void> _setTyping(bool isTyping) {
    return _chatRepository.setTyping(_chatId, isTyping);
  }

  Message _optimisticTextMessage(String text) {
    final uid = _ref.read(authRepositoryProvider).firebaseUser?.uid;
    return Message(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      chatId: _chatId,
      senderId: uid ?? '',
      text: text,
      type: MessageType.text,
      state: MessageState.sending,
      createdAt: DateTime.now(),
    );
  }

  void removeOptimisticMessages(Set<String> ids) {
    _emit(
      state.copyWith(
        optimisticMessages: state.optimisticMessages
            .where((message) => !ids.contains(message.id))
            .toList(growable: false),
      ),
    );
  }

  void _replaceOptimistic(Message message, MessageState nextState) {
    _emit(
      state.copyWith(
        optimisticMessages: state.optimisticMessages
            .map((item) {
              if (item.id != message.id) return item;
              return Message(
                id: item.id,
                chatId: item.chatId,
                senderId: item.senderId,
                text: item.text,
                imageUrls: item.imageUrls,
                attachments: item.attachments,
                type: item.type,
                state: nextState,
                createdAt: item.createdAt,
                deliveredAt: item.deliveredAt,
                readAt: item.readAt,
              );
            })
            .toList(growable: false),
      ),
    );
  }

  void _emit(MessageThreadUiState nextState) {
    if (_disposed || _stateSubject.isClosed) return;
    _stateSubject.add(nextState);
  }
}
