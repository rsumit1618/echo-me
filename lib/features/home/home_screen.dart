import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/widgets/app_avatar_image.dart';
import 'package:echo_me/features/chats/chats_screen.dart';
import 'package:echo_me/features/contacts/contacts_screen.dart';
import 'package:echo_me/features/echo_ai/echo_ai_screen.dart';
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
    EchoAiScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final index = ref.watch(homeTabIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Echo Me',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              index == 2 ? 'AI advisors ready' : 'Stay close, chat smoothly',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Echo AI',
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
    return AppAvatarImage(
      imageUrl: imageUrl,
      radius: 18,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      fallback: const Icon(Icons.person, size: 22),
    );
  }
}
