import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/domain/entity/contact.dart';
import 'package:echo_me/features/chats/message_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _syncing = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final contacts = ref.watch(contactsProvider);

    return Scaffold(
      body: contacts.when(
        data: (items) {
          if (items.isEmpty) {
            return EmptyStateCard(
              icon: Icons.contacts_outlined,
              title: 'Bring your contacts in',
              message:
                  'We normalize and deduplicate contacts before checking who is already on Echo Me.',
              action: FilledButton.icon(
                onPressed: _syncing ? null : _sync,
                icon: const Icon(Icons.sync),
                label: Text(_syncing ? 'Syncing...' : 'Sync contacts'),
              ),
            );
          }

          final visibleContacts = _filterAndSortContacts(items);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search name or number',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _searchController.clear,
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Clear search',
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: _syncing ? null : _sync,
                      icon: _syncing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      tooltip: 'Sync contacts',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleContacts.isEmpty
                    ? Center(
                        child: Text(
                          'No contacts found',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _sync,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          itemCount: visibleContacts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            return _ContactTile(
                              contact: visibleContacts[index],
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load contacts: $error')),
      ),
    );
  }

  List<AppContact> _filterAndSortContacts(List<AppContact> contacts) {
    final query = _searchQuery.toLowerCase();
    final filtered = contacts.where((contact) {
      if (query.isEmpty) return true;
      return contact.displayName.toLowerCase().contains(query) ||
          contact.normalizedPhone.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final priority = _contactSortPriority(a).compareTo(
        _contactSortPriority(b),
      );
      if (priority != 0) return priority;

      if (a.registeredUserId != null && b.registeredUserId != null) {
        final timestamp = b.syncedAt.compareTo(a.syncedAt);
        if (timestamp != 0) return timestamp;
      }

      final name = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
      if (name != 0) return name;

      return a.normalizedPhone.compareTo(b.normalizedPhone);
    });

    return filtered;
  }

  int _contactSortPriority(AppContact contact) {
    if (contact.registeredUserId != null) return 0;
    if (_hasRealDisplayName(contact)) return 1;
    return 2;
  }

  bool _hasRealDisplayName(AppContact contact) {
    final name = contact.displayName.trim();
    return name.isNotEmpty && name != AppContact.defaultDisplayName;
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      await ref
          .read(contactRepositoryProvider)
          .syncDeviceContacts()
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}

class _ContactTile extends ConsumerWidget {
  final AppContact contact;

  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionColor = switch (contact.action) {
      ContactAction.invite => Theme.of(context).colorScheme.secondaryContainer,
      ContactAction.chatNow => Theme.of(context).colorScheme.primaryContainer,
      ContactAction.call => Theme.of(context).colorScheme.tertiaryContainer,
    };

    return AppCard(
      onTap: () => _handleAction(context, ref),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: actionColor,
            child: Text(
              _initials(contact.displayName),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.normalizedPhone,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FilledButton.tonal(
              onPressed: () => _handleAction(context, ref),
              child: Text(_getLabel(contact.action)),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String displayName) {
    final name = displayName.trim();
    if (name.isEmpty || name == AppContact.defaultDisplayName) return '??';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '??';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }

  String _getLabel(ContactAction action) {
    switch (action) {
      case ContactAction.invite:
        return 'Invite';
      case ContactAction.chatNow:
        return 'Chat Now';
      case ContactAction.call:
        return 'Call';
    }
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref) async {
    try {
      if (contact.action == ContactAction.invite) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invite link ready for ${contact.displayName}.'),
          ),
        );
        return;
      }

      final peerId = contact.registeredUserId;
      if (peerId == null) return;

      final chatId = await ref
          .read(chatRepositoryProvider)
          .getOrCreateOneToOneChat(
            peerId,
            peerDisplayName: contact.displayName,
            peerPhoneNumber: contact.normalizedPhone,
          )
          .timeout(const Duration(seconds: 20));

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MessageThreadScreen(chatId: chatId),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $error')),
        );
      }
    }
  }
}
