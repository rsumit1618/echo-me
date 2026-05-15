import 'dart:convert';

import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/features/calls/call_history_screen.dart';
import 'package:echo_me/features/chats/chats_screen.dart';
import 'package:echo_me/features/contacts/contacts_screen.dart';
import 'package:echo_me/features/profile/profile_screen.dart';
import 'package:echo_me/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeTabIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _screens = [
    ChatsScreen(),
    ContactsScreen(),
    CallHistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final index = ref.watch(homeTabIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Echo Me'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.tertiary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _HomeProfileImage(
                  imageUrl: currentUser?.profileImageUrl,
                ),
              ),
            ),
          ),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey(themeMode),
        child: IndexedStack(index: index, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            ref.read(homeTabIndexProvider.notifier).state = value,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Call History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _HomeProfileImage extends StatelessWidget {
  final String? imageUrl;

  const _HomeProfileImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final image = _imageProvider(imageUrl);
    if (image == null) {
      return const Icon(Icons.person, color: Colors.white, size: 22);
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: CircleAvatar(
        backgroundImage: image,
        backgroundColor: Colors.transparent,
      ),
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
}
