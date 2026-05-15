import 'dart:convert';

import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/core/widgets/app_state_widgets.dart';
import 'package:echo_me/domain/entity/chat.dart';
import 'package:echo_me/domain/entity/message.dart';
import 'package:echo_me/features/chats/message_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(recentChatsProvider);
    final currentUid =
        ref.watch(authStateProvider).valueOrNull?.uid ??
        ref.watch(authRepositoryProvider).firebaseUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeKey = Object.hash(
      colorScheme.brightness,
      colorScheme.primary,
      colorScheme.surface,
    );

    return chats.when(
      data: (items) {
        if (items.isEmpty) {
          return const EmptyStateCard(
            icon: Icons.forum_outlined,
            title: 'No chat history',
            message: 'You do not have any messages yet.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final chat = items[index];
            final message = chat.lastMessage;
            final peerId = _peerId(chat, currentUid);
            final imageUrl = chat.participantImageUrls[peerId];
            final unreadCount = currentUid == null
                ? 0
                : chat.unreadCounts[currentUid] ?? 0;
            final hasUnread = unreadCount > 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedListItem(
                key: ValueKey('${chat.id}-$themeKey'),
                index: index,
                child: AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MessageThreadScreen(chatId: chat.id),
                    ),
                  ),
                  child: Row(
                    children: [
                      _ChatAvatar(
                        title: _chatTitle(chat, peerId),
                        imageUrl: imageUrl,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _chatTitle(chat, peerId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: hasUnread
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _lastMessageText(message),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                color: hasUnread
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ChatMeta(
                        date: _chatDate(chat.updatedAt),
                        unreadCount: unreadCount,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const AppLoadingView(),
      error: (error, _) => AppErrorView(
        error: error,
        onRetry: () => ref.invalidate(recentChatsProvider),
      ),
    );
  }

  String _peerId(Chat chat, String? currentUid) {
    if (currentUid == null || currentUid.isEmpty) {
      return chat.participantIds.length > 1
          ? chat.participantIds.last
          : chat.participantIds.isEmpty
          ? ''
          : chat.participantIds.first;
    }
    return chat.participantIds.firstWhere(
      (id) => id != currentUid,
      orElse: () => '',
    );
  }

  String _chatTitle(Chat chat, String peerId) {
    return chat.participantNames[peerId] ??
        chat.participantPhones[peerId] ??
        'Unknown Contact';
  }

  String _lastMessageText(Message? message) {
    if (message == null) return 'No messages yet';
    if (message.text != null && message.text!.trim().isNotEmpty) {
      return message.text!;
    }
    if (message.attachments.any((attachment) => attachment.isImage)) {
      return 'Photo';
    }
    if (message.attachments.any((attachment) => attachment.isPdf)) {
      return 'PDF';
    }
    return 'Message';
  }

  String _chatDate(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    if (date == today) return DateFormat.Hm().format(value);
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMMM yyyy').format(value);
  }
}

class _ChatMeta extends StatelessWidget {
  final String date;
  final int unreadCount;

  const _ChatMeta({required this.date, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasUnread = unreadCount > 0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            date,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: hasUnread
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: hasUnread
                ? Padding(
                    key: ValueKey(unreadCount),
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: .28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), height: 0),
          ),
        ],
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  final String title;
  final String? imageUrl;

  const _ChatAvatar({required this.title, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final image = _imageProvider(imageUrl);
    return CircleAvatar(
      radius: 30,
      backgroundColor: colorScheme.primaryContainer,
      foregroundImage: image,
      child: image == null
          ? Text(
              _initials(title),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
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

  String _initials(String title) {
    final name = title.trim();
    if (name.isEmpty || name == 'Unknown Contact') return '?';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }
}
