import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/core/widgets/app_avatar_image.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/core/widgets/app_state_widgets.dart';
import 'package:echo_me/domain/entity/contact.dart';
import 'package:echo_me/features/chats/message_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final contactsSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final contactsSyncingProvider = StateProvider.autoDispose<bool>((ref) => false);

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(contactsSearchQueryProvider.notifier).state = _searchController
          .text
          .trim();
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
    final syncing = ref.watch(contactsSyncingProvider);
    final searchQuery = ref.watch(contactsSearchQueryProvider);

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
                onPressed: syncing ? null : _sync,
                icon: const Icon(Icons.sync),
                label: Text(syncing ? 'Syncing...' : 'Sync contacts'),
              ),
            );
          }

          final visibleContacts = _filterAndSortContacts(items, searchQuery);

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
                          suffixIcon: searchQuery.isEmpty
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
                      onPressed: syncing ? null : _sync,
                      icon: syncing
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
        loading: () => const AppLoadingView(),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(contactsProvider),
        ),
      ),
    );
  }

  List<AppContact> _filterAndSortContacts(
    List<AppContact> contacts,
    String searchQuery,
  ) {
    final query = searchQuery.toLowerCase();
    final filtered = contacts.where((contact) {
      if (query.isEmpty) return true;
      return contact.displayName.toLowerCase().contains(query) ||
          contact.normalizedPhone.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final priority = _contactSortPriority(
        a,
      ).compareTo(_contactSortPriority(b));
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
    ref.read(contactsSyncingProvider.notifier).state = true;
    try {
      await ref
          .read(contactRepositoryProvider)
          .syncDeviceContacts()
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMapper.message(error))));
      }
    } finally {
      if (mounted) {
        ref.read(contactsSyncingProvider.notifier).state = false;
      }
    }
  }
}

class _ContactTile extends ConsumerWidget {
  final AppContact contact;

  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final actionStyle = _ContactActionStyle.from(context, contact.action);
    final compact = MediaQuery.sizeOf(context).width < 390;
    final buttonWidth = compact ? 112.0 : 132.0;

    return AppCard(
      onTap: () => _handleAction(context, ref),
      child: Row(
        children: [
          _ContactAvatar(
            displayName: contact.displayName,
            imageUrl: contact.profileImageUrl,
            backgroundColor: actionStyle.avatarColor,
            foregroundColor: actionStyle.avatarForeground,
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
                    color: colorScheme.onSurface,
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
          SizedBox(
            width: buttonWidth,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: actionStyle.buttonColor,
                foregroundColor: actionStyle.buttonForeground,
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
                minimumSize: Size(buttonWidth, compact ? 48 : 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () => _handleAction(context, ref),
              icon: Icon(_getIcon(contact.action), size: compact ? 17 : 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _getLabel(contact.action),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

  IconData _getIcon(ContactAction action) {
    switch (action) {
      case ContactAction.invite:
        return Icons.person_add_alt_1;
      case ContactAction.chatNow:
        return Icons.chat_bubble;
      case ContactAction.call:
        return Icons.call;
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
            peerProfileImageUrl: contact.profileImageUrl,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMapper.message(error))));
      }
    }
  }
}

class _ContactAvatar extends StatelessWidget {
  final String displayName;
  final String? imageUrl;
  final Color backgroundColor;
  final Color foregroundColor;

  const _ContactAvatar({
    required this.displayName,
    required this.imageUrl,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppAvatarImage(
      imageUrl: imageUrl,
      radius: MediaQuery.sizeOf(context).width < 390 ? 25 : 28,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      fallback: Text(
        _initials(displayName),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _initials(String displayName) {
    final name = displayName.trim();
    if (name.isEmpty || name == AppContact.defaultDisplayName) return '?';
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

class _ContactActionStyle {
  final Color avatarColor;
  final Color avatarForeground;
  final Color buttonColor;
  final Color buttonForeground;

  const _ContactActionStyle({
    required this.avatarColor,
    required this.avatarForeground,
    required this.buttonColor,
    required this.buttonForeground,
  });

  factory _ContactActionStyle.from(BuildContext context, ContactAction action) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return switch (action) {
      ContactAction.chatNow => _ContactActionStyle(
        avatarColor: colorScheme.primaryContainer,
        avatarForeground: colorScheme.onPrimaryContainer,
        buttonColor: colorScheme.primaryContainer,
        buttonForeground: colorScheme.onPrimaryContainer,
      ),
      ContactAction.invite => _ContactActionStyle(
        avatarColor: isDark ? const Color(0xFF5C3F15) : const Color(0xFFFFE1B8),
        avatarForeground: isDark
            ? const Color(0xFFFFD9A3)
            : const Color(0xFF4A2A00),
        buttonColor: isDark ? const Color(0xFF6B4314) : const Color(0xFFFFD29A),
        buttonForeground: isDark
            ? const Color(0xFFFFE6C7)
            : const Color(0xFF3D2500),
      ),
      ContactAction.call => _ContactActionStyle(
        avatarColor: colorScheme.tertiaryContainer,
        avatarForeground: colorScheme.onTertiaryContainer,
        buttonColor: colorScheme.tertiaryContainer,
        buttonForeground: colorScheme.onTertiaryContainer,
      ),
    };
  }
}
