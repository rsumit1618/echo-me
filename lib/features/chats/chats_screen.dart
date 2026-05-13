import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/widgets/app_card.dart';
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
    final currentUid = ref.watch(authRepositoryProvider).firebaseUser?.uid;

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
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedListItem(
                index: index,
                child: AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MessageThreadScreen(chatId: chat.id),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                        child: const Icon(Icons.person),
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _lastMessageText(message),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _chatDate(chat.updatedAt),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load chats: $error')),
    );
  }

  String _peerId(Chat chat, String? currentUid) {
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
