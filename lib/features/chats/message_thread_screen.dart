import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/core/widgets/app_avatar_image.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/core/widgets/app_state_widgets.dart';
import 'package:echo_me/domain/entity/chat.dart';
import 'package:echo_me/domain/entity/message.dart';
import 'package:echo_me/features/chats/message_thread_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

const int _messagePageSize = 30;

class MessageThreadScreen extends ConsumerStatefulWidget {
  final String chatId;

  const MessageThreadScreen({super.key, required this.chatId});

  @override
  ConsumerState<MessageThreadScreen> createState() =>
      _MessageThreadScreenState();
}

class _MessageThreadScreenState extends ConsumerState<MessageThreadScreen> {
  static const _attachmentsChannel = MethodChannel('echo_me/attachments');

  final _text = TextEditingController();
  final _picker = ImagePicker();
  final _scrollController = ScrollController();
  String? _latestMessageId;
  String? _latestReadMessageId;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(
      messageThreadControllerProvider(widget.chatId),
    );
    final chat = ref.watch(chatProvider(widget.chatId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: chat.when(
          data: (value) => _ChatTitle(chat: value),
          loading: () => const Text('Chat'),
          error: (_, __) => const Text('Chat'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .035),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final messages = ref.watch(messagesProvider(widget.chatId));
                  final uiState =
                      ref
                          .watch(messageThreadListUiProvider(widget.chatId))
                          .valueOrNull ??
                      controller.listState;

                  return messages.when(
                    data: (items) {
                      _handleMessageStreamUpdate(items, controller);
                      final allMessages = _mergeMessages(items, uiState);
                      final timelineItems = _buildTimelineItems(allMessages);
                      final canLoadOlder =
                          uiState.hasMoreOlder &&
                          (items.length >= _messagePageSize ||
                              uiState.olderMessages.isNotEmpty);
                      return allMessages.isEmpty
                          ? const EmptyStateCard(
                              icon: Icons.waving_hand_outlined,
                              title: 'Say hello',
                              message:
                                  'Send a message or attach an image or PDF.',
                            )
                          : ListView.builder(
                              reverse: true,
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              cacheExtent: 640,
                              padding: const EdgeInsets.all(12),
                              itemCount: timelineItems.length + 1,
                              itemBuilder: (_, index) {
                                if (index == timelineItems.length) {
                                  return _LoadOlderButton(
                                    visible: canLoadOlder,
                                    loading: uiState.loadingOlder,
                                    onPressed: () => _loadOlder(allMessages),
                                  );
                                }
                                final item = timelineItems[index];
                                if (item is _DateTimelineItem) {
                                  return _DateSeparator(label: item.label);
                                }
                                final message =
                                    (item as _MessageTimelineItem).message;
                                return _MessageBubble(
                                  key: ValueKey(message.id),
                                  message: message,
                                );
                              },
                            );
                    },
                    loading: () => const AppLoadingView(),
                    error: (error, _) => AppErrorView(
                      error: error,
                      onRetry: () =>
                          ref.invalidate(messagesProvider(widget.chatId)),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Consumer(
                builder: (context, ref, _) {
                  final uiState =
                      ref
                          .watch(messageThreadUiProvider(widget.chatId))
                          .valueOrNull ??
                      controller.state;
                  return AppCard(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: .55),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Attach image or PDF',
                          onPressed: uiState.sending ? null : _pickFiles,
                          icon: const Icon(Icons.attach_file),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 4,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              height: 1.25,
                            ),
                            cursorColor: Theme.of(context).colorScheme.primary,
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: uiState.sending
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : Container(
                                  key: const ValueKey('send'),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.tertiary,
                                      ],
                                    ),
                                  ),
                                  child: IconButton(
                                    tooltip: 'Send',
                                    onPressed: _sendText,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    icon: const Icon(Icons.send_rounded),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Message> _mergeMessages(
    List<Message> streamMessages,
    MessageThreadListUiState uiState,
  ) {
    final matchedOptimisticIds = <String>{};
    for (final local in uiState.optimisticMessages) {
      if (streamMessages.any((remote) => _matchesOptimistic(local, remote))) {
        matchedOptimisticIds.add(local.id);
      }
    }

    if (matchedOptimisticIds.isNotEmpty) {
      Future.microtask(
        () => ref
            .read(messageThreadControllerProvider(widget.chatId))
            .removeOptimisticMessages(matchedOptimisticIds),
      );
    }

    final olderIds = streamMessages.map((message) => message.id).toSet();
    return [
      ...uiState.optimisticMessages.where(
        (message) => !matchedOptimisticIds.contains(message.id),
      ),
      ...streamMessages,
      ...uiState.olderMessages.where((older) => olderIds.add(older.id)),
    ];
  }

  List<_TimelineItem> _buildTimelineItems(List<Message> messages) {
    final items = <_TimelineItem>[];
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      items.add(_MessageTimelineItem(message));

      final nextMessage = i + 1 < messages.length ? messages[i + 1] : null;
      final shouldShowDate =
          nextMessage == null ||
          !_sameDay(message.createdAt, nextMessage.createdAt);
      if (shouldShowDate) {
        items.add(_DateTimelineItem(_dateSeparatorLabel(message.createdAt)));
      }
    }
    return items;
  }

  bool _matchesOptimistic(Message local, Message remote) {
    if (!local.id.startsWith('local-')) return false;
    if (local.senderId != remote.senderId) return false;
    if ((local.text ?? '').trim() != (remote.text ?? '').trim()) return false;
    final delta = remote.createdAt.difference(local.createdAt).abs();
    return delta < const Duration(minutes: 2);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateSeparatorLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMMM yyyy').format(value);
  }

  void _handleMessageStreamUpdate(
    List<Message> messages,
    MessageThreadController controller,
  ) {
    if (messages.isEmpty) return;

    final newest = messages.first;
    if (_latestMessageId == newest.id) return;

    final hadMessages = _latestMessageId != null;
    _latestMessageId = newest.id;

    if (_latestReadMessageId != newest.id) {
      _latestReadMessageId = newest.id;
      Future.microtask(() => controller.markRead());
    }

    final currentUid = ref.read(authRepositoryProvider).firebaseUser?.uid;
    final isMine = newest.senderId == currentUid;
    final isNearLatest =
        !_scrollController.hasClients ||
        _scrollController.position.pixels < 160;
    if (!hadMessages || (!isMine && !isNearLatest)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  Future<void> _scrollToLatest() async {
    if (!mounted || !_scrollController.hasClients) return;
    await _scrollController.animateTo(
      _scrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadOlder(List<Message> currentMessages) async {
    try {
      await ref
          .read(messageThreadControllerProvider(widget.chatId))
          .loadOlder(currentMessages);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMapper.message(error))));
      }
    }
  }

  Future<void> _sendText() async {
    final message = _text.text;
    if (message.trim().isEmpty) return;
    _text.clear();
    Future<void>.delayed(const Duration(milliseconds: 80), _scrollToLatest);
    try {
      await ref
          .read(messageThreadControllerProvider(widget.chatId))
          .sendText(message);
    } catch (error) {
      _text.text = message;
      _showError(error);
    }
  }

  void _onTextChanged() {
    ref
        .read(messageThreadControllerProvider(widget.chatId))
        .textChanged(_text.text);
  }

  Future<void> _pickFiles() async {
    final type = await showModalBottomSheet<_AttachmentPickType>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Images'),
                onTap: () =>
                    Navigator.of(context).pop(_AttachmentPickType.images),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF'),
                onTap: () => Navigator.of(context).pop(_AttachmentPickType.pdf),
              ),
            ],
          ),
        );
      },
    );
    if (type == null) return;

    final files = switch (type) {
      _AttachmentPickType.images => await _pickImages(),
      _AttachmentPickType.pdf => await _pickPdf(),
    };
    if (files.isEmpty) return;

    try {
      await ref
          .read(messageThreadControllerProvider(widget.chatId))
          .sendFiles(files);
    } catch (error) {
      _showError(error);
    }
  }

  Future<List<File>> _pickImages() async {
    final selected = await _picker.pickMultiImage(limit: 5);
    return selected.take(5).map((image) => File(image.path)).toList();
  }

  Future<List<File>> _pickPdf() async {
    final path = await _attachmentsChannel.invokeMethod<String>('pickPdf');
    if (path == null || path.isEmpty) return const [];
    return [File(path)];
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppErrorMapper.message(error))));
  }
}

enum _AttachmentPickType { images, pdf }

sealed class _TimelineItem {
  const _TimelineItem();
}

class _MessageTimelineItem extends _TimelineItem {
  final Message message;

  const _MessageTimelineItem(this.message);
}

class _DateTimelineItem extends _TimelineItem {
  final String label;

  const _DateTimelineItem(this.label);
}

class _DateSeparator extends StatelessWidget {
  final String label;

  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: .7),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: .06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ChatTitle extends ConsumerWidget {
  final Chat? chat;

  const _ChatTitle({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid =
        ref.watch(authStateProvider).valueOrNull?.uid ??
        ref.watch(authRepositoryProvider).firebaseUser?.uid;
    final peerId = chat?.participantIds.firstWhere(
      (id) => id != currentUid,
      orElse: () =>
          chat!.participantIds.length > 1 ? chat!.participantIds.last : '',
    );
    if (chat == null || peerId == null || peerId.isEmpty) {
      return const Text('Chat');
    }

    final title =
        chat!.participantNames[peerId] ??
        chat!.participantPhones[peerId] ??
        'Unknown Contact';
    final status = ref.watch(userStatusProvider(peerId));
    final isTyping =
        chat!.participantIds.contains(peerId) &&
        (chat!.typing[peerId] ?? false);

    return status.when(
      data: (data) {
        final isOnline = data?['isOnline'] as bool? ?? false;
        final lastSeen = _readDate(data?['lastSeen']);
        final lastActivity = lastSeen ?? _readDate(data?['updatedAt']);
        final recentlyActive = _isRecentlyActive(isOnline, lastActivity);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatarImage(
              imageUrl: chat!.participantImageUrls[peerId],
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              fallback: const Icon(Icons.person, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    isTyping && recentlyActive
                        ? 'typing...'
                        : recentlyActive
                        ? 'online'
                        : _lastSeenText(lastActivity),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => Text(title),
      error: (_, __) => Text(title),
    );
  }

  DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate() as DateTime;
    }
    return null;
  }

  String _lastSeenText(DateTime? value) {
    if (value == null) return 'offline';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    if (date == today) {
      return 'last seen today at ${DateFormat('h:mm a').format(value)}';
    }
    if (date == today.subtract(const Duration(days: 1))) {
      return 'last seen yesterday at ${DateFormat('h:mm a').format(value)}';
    }
    return 'last seen ${DateFormat('d MMM yyyy, h:mm a').format(value)}';
  }

  bool _isRecentlyActive(bool isOnline, DateTime? lastSeen) {
    if (!isOnline) return false;
    if (lastSeen == null) return true;
    final inactiveFor = DateTime.now().difference(lastSeen);
    return inactiveFor <= const Duration(minutes: 5);
  }
}

class _MessageBubble extends ConsumerWidget {
  final Message message;

  const _MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authRepositoryProvider).firebaseUser?.uid;
    final isMe = currentUid == message.senderId;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isMe
        ? colorScheme.primaryContainer
        : colorScheme.surface;
    final textColor = isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final metaColor = isMe
        ? colorScheme.onPrimaryContainer.withValues(alpha: .72)
        : colorScheme.onSurfaceVariant;
    final receiptColor = isMe
        ? colorScheme.onPrimaryContainer.withValues(
            alpha: message.state == MessageState.read ? .92 : .66,
          )
        : message.state == MessageState.read
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final borderColor = isMe
        ? colorScheme.primary.withValues(alpha: isDark ? .34 : .22)
        : colorScheme.outlineVariant.withValues(alpha: isDark ? .36 : .6);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: isDark ? .22 : .07),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMe)
                  Container(
                    width: 26,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 7),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: .42),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                if (message.text != null)
                  Text(
                    message.text!,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      height: 1.32,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (message.attachments.isNotEmpty)
                  ...message.attachments.map(
                    (attachment) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _AttachmentPreview(attachment: attachment),
                    ),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat.Hm().format(message.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: metaColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          _stateIcon(message.state),
                          size: 15,
                          color: receiptColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _stateIcon(MessageState state) {
    return switch (state) {
      MessageState.sending => Icons.schedule,
      MessageState.sent => Icons.check,
      MessageState.delivered => Icons.done_all,
      MessageState.read => Icons.done_all,
      MessageState.failed => Icons.error_outline,
    };
  }
}

class _LoadOlderButton extends StatelessWidget {
  final bool visible;
  final bool loading;
  final VoidCallback onPressed;

  const _LoadOlderButton({
    required this.visible,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(height: 8);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: OutlinedButton.icon(
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.history),
          label: Text(loading ? 'Loading...' : 'Load older messages'),
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final MessageAttachment attachment;

  const _AttachmentPreview({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final base64Data = attachment.base64Data;
    if (attachment.isImage && base64Data != null) {
      try {
        final bytes = base64Decode(base64Data);
        final bytesUint8 = Uint8List.fromList(bytes);
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _FullImageScreen(
                bytes: bytesUint8,
                title: attachment.fileName,
              ),
            ),
          ),
          child: Hero(
            tag: attachment.id,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                bytesUint8,
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    _AttachmentError(label: attachment.fileName),
              ),
            ),
          ),
        );
      } catch (_) {
        return _AttachmentError(label: attachment.fileName);
      }
    }

    if (attachment.isImage) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        width: 220,
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return _PdfAttachmentPreview(attachment: attachment);
  }
}

class _AttachmentError extends StatelessWidget {
  final String label;

  const _AttachmentError({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullImageScreen extends StatelessWidget {
  final Uint8List bytes;
  final String title;

  const _FullImageScreen({required this.bytes, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _PdfAttachmentPreview extends StatelessWidget {
  final MessageAttachment attachment;

  const _PdfAttachmentPreview({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final base64Data = attachment.base64Data;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: base64Data == null ? null : () => _openPdf(context, attachment),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf, size: 34, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _formatBytes(attachment.sizeBytes),
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPdf(
    BuildContext context,
    MessageAttachment attachment,
  ) async {
    try {
      final base64Data = attachment.base64Data;
      if (base64Data == null) return;

      List<int> bytes = base64Decode(base64Data);
      if (attachment.isPdf && attachment.compressed) {
        bytes = gzip.decode(bytes);
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${attachment.fileName}');
      await file.writeAsBytes(bytes, flush: true);
      await const MethodChannel(
        'echo_me/attachments',
      ).invokeMethod<void>('openFile', file.path);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMapper.message(error))));
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}
