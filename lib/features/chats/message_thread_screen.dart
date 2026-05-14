import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/domain/entity/chat.dart';
import 'package:echo_me/domain/entity/message.dart';
import 'package:echo_me/domain/repository/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

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
  late final ChatRepository _chatRepository;
  Timer? _typingTimer;
  bool _sending = false;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  String? _latestMessageId;
  final List<Message> _olderMessages = [];

  @override
  void initState() {
    super.initState();
    _chatRepository = ref.read(chatRepositoryProvider);
    _text.addListener(_onTextChanged);
    Future.microtask(() async {
      await _chatRepository.setActiveChat(widget.chatId);
      await _chatRepository.markRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatRepository.setTyping(widget.chatId, false);
    _chatRepository.setActiveChat(null);
    _scrollController.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider(widget.chatId));
    final messages = ref.watch(messagesProvider(widget.chatId));

    return Scaffold(
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
            child: messages.when(
              data: (items) {
                Future.microtask(
                  () =>
                      ref.read(chatRepositoryProvider).markRead(widget.chatId),
                );
                final allMessages = [
                  ...items,
                  ..._olderMessages.where(
                    (older) => !items.any((item) => item.id == older.id),
                  ),
                ];
                _scheduleScrollForNewMessage(items);
                return allMessages.isEmpty
                    ? const EmptyStateCard(
                        icon: Icons.waving_hand_outlined,
                        title: 'Say hello',
                        message: 'Send a message or attach an image or PDF.',
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
                        itemCount: allMessages.length + 1,
                        itemBuilder: (_, index) {
                          if (index == allMessages.length) {
                            return _LoadOlderButton(
                              visible: _hasMoreOlder,
                              loading: _loadingOlder,
                              onPressed: () => _loadOlder(allMessages),
                            );
                          }
                          return _MessageBubble(
                            key: ValueKey(allMessages[index].id),
                            message: allMessages[index],
                          );
                        },
                      );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Could not load messages: $error')),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Attach image or PDF',
                      onPressed: _sending ? null : _pickFiles,
                      icon: const Icon(Icons.attach_file),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Message',
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
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Send',
                              onPressed: _sendText,
                              icon: const Icon(Icons.send_rounded),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleScrollForNewMessage(List<Message> messages) {
    if (messages.isEmpty) return;

    final newest = messages.first;
    if (_latestMessageId == newest.id) return;

    final hadMessages = _latestMessageId != null;
    _latestMessageId = newest.id;
    if (!hadMessages) return;

    final currentUid = ref.read(authRepositoryProvider).firebaseUser?.uid;
    final isMine = newest.senderId == currentUid;
    final isNearLatest =
        !_scrollController.hasClients ||
        _scrollController.position.pixels < 160;
    if (!isMine && !isNearLatest) return;

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
    if (_loadingOlder || currentMessages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final oldest = currentMessages.last.createdAt;
      final older = await ref
          .read(chatRepositoryProvider)
          .fetchMessagesBefore(widget.chatId, oldest)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() {
        _olderMessages.addAll(
          older.where(
            (message) => !_olderMessages.any((item) => item.id == message.id),
          ),
        );
        _hasMoreOlder = older.isNotEmpty;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load older messages: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _sendText() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendTextMessage(widget.chatId, _text.text)
          .timeout(const Duration(seconds: 30));
      _text.clear();
      await ref.read(chatRepositoryProvider).setTyping(widget.chatId, false);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onTextChanged() {
    final isTyping = _text.text.trim().isNotEmpty;
    ref.read(chatRepositoryProvider).setTyping(widget.chatId, isTyping);
    _typingTimer?.cancel();
    if (!isTyping) return;
    _typingTimer = Timer(const Duration(seconds: 3), () {
      ref.read(chatRepositoryProvider).setTyping(widget.chatId, false);
    });
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

    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendFilesMessage(widget.chatId, files)
          .timeout(const Duration(seconds: 45));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
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
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

enum _AttachmentPickType { images, pdf }

class _ChatTitle extends ConsumerWidget {
  final Chat? chat;

  const _ChatTitle({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authRepositoryProvider).firebaseUser?.uid;
    final peerId = chat?.participantIds.firstWhere(
      (id) => id != currentUid,
      orElse: () => '',
    );
    if (chat == null || peerId == null || peerId.isEmpty) {
      return const Text('Chat');
    }

    final title =
        chat!.participantNames[peerId] ??
        chat!.participantPhones[peerId] ??
        'Unknown Contact';
    final image = _imageProvider(chat!.participantImageUrls[peerId]);
    final status = ref.watch(userStatusProvider(peerId));
    final isTyping =
        chat!.participantIds.contains(peerId) &&
        (chat!.typing[peerId] ?? false);

    return status.when(
      data: (data) {
        final isOnline = data?['isOnline'] as bool? ?? false;
        final lastSeen = _readDate(data?['lastSeen']);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundImage: image,
              child: image == null
                  ? Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    isTyping
                        ? 'typing...'
                        : isOnline
                        ? 'online'
                        : _lastSeenText(lastSeen),
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

  ImageProvider? _imageProvider(String? value) {
    try {
      final image = value?.trim();
      if (image == null || image.isEmpty) return null;
      if (image.startsWith('data:image')) {
        final commaIndex = image.indexOf(',');
        if (commaIndex == -1) return null;
        return MemoryImage(base64Decode(image.substring(commaIndex + 1)));
      }
      return NetworkImage(image);
    } catch (_) {
      return null;
    }
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
    return 'last seen ${DateFormat('d MMM yyyy, h:mm a').format(value)}';
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
    final bubbleColor = isMe
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final textColor = isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final receiptColor = message.state == MessageState.read
        ? colorScheme.primary
        : textColor.withValues(alpha: .65);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(isMe ? 12 * (1 - value) : -12 * (1 - value), 0),
              child: child,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              border: Border.all(
                color: isMe
                    ? colorScheme.primary.withValues(alpha: .18)
                    : colorScheme.outlineVariant.withValues(alpha: .45),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? .16
                        : .08,
                  ),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.text != null)
                    Text(
                      message.text!,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        height: 1.25,
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: textColor.withValues(alpha: .7),
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
                bytes,
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
      return Container(
        width: 220,
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: base64Data == null ? null : () => _openPdf(context, attachment),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(_formatBytes(attachment.sizeBytes)),
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
        ).showSnackBar(SnackBar(content: Text('Could not open PDF: $error')));
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
