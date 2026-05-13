import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/domain/entity/call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calls = ref.watch(callHistoryProvider);
    return calls.when(
      data: (items) {
        if (items.isEmpty) {
          return const EmptyStateCard(
            icon: Icons.call_outlined,
            title: 'No call history',
            message: 'Incoming, outgoing, and missed calls will appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final call = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedListItem(
                index: index,
                child: AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        child: Icon(_icon(call.direction)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              call.peerPhoneNumber,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${call.direction.name} ${call.type.name}',
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
                      Text(
                        DateFormat('MMM d, HH:mm').format(call.startedAt),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
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
      error: (error, _) => Center(child: Text('Could not load calls: $error')),
    );
  }

  IconData _icon(CallDirection direction) {
    return switch (direction) {
      CallDirection.incoming => Icons.call_received,
      CallDirection.outgoing => Icons.call_made,
      CallDirection.missed => Icons.call_missed,
    };
  }
}
