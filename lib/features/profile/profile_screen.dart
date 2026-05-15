import 'dart:io';
import 'dart:convert';

import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/core/utils/image_optimizer.dart';
import 'package:echo_me/core/widgets/app_avatar_image.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/core/widgets/app_state_widgets.dart';
import 'package:echo_me/domain/entity/app_user.dart';
import 'package:echo_me/features/profile/developer_contact_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

final profileSavingProvider = StateProvider.autoDispose<bool>((ref) => false);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final saving = ref.watch(profileSavingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: auth.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please login again.'));
          }
          _email.text = user.email ?? '';
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AppCard(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    const Color(0xFF0EA5E9),
                    Theme.of(context).colorScheme.tertiary,
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .18)),
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    _Avatar(user: user, saving: saving, onTap: _changeImage),
                    const SizedBox(height: 14),
                    Text(
                      user.phoneNumber,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap photo to update profile image',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: .86),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppCard(
                child: Column(
                  children: [
                    TextField(
                      readOnly: true,
                      controller: TextEditingController(text: user.phoneNumber),
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        prefixIcon: Icon(Icons.phone_iphone),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      readOnly: true,
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email optional',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeveloperContactScreen(),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            const Color(0xFF0EA5E9),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.engineering_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Developer Contact',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'View app developer details and links',
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
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingView(),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(authStateProvider),
        ),
      ),
    );
  }

  Future<void> _changeImage() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Camera'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );
      if (source == null) return;

      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust profile image',
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Adjust profile image',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (cropped == null) return;
      ref.read(profileSavingProvider.notifier).state = true;

      final uid = ref.read(authRepositoryProvider).firebaseUser?.uid;
      if (uid == null) throw const AppException('Please login again.');
      final optimized = await ImageOptimizer().compressToUnder100Kb(
        File(cropped.path),
      );
      final bytes = await optimized.readAsBytes();
      final url = await compute(_encodeProfileImageDataUrl, bytes);
      await ref
          .read(authRepositoryProvider)
          .updateProfile(profileImageUrl: url)
          .timeout(const Duration(seconds: 20));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile image updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMapper.message(error))));
      }
    } finally {
      if (mounted) ref.read(profileSavingProvider.notifier).state = false;
    }
  }
}

String _encodeProfileImageDataUrl(List<int> bytes) {
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

class _Avatar extends StatelessWidget {
  final AppUser user;
  final bool saving;
  final VoidCallback onTap;

  const _Avatar({
    required this.user,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = user.profileImageUrl;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: saving ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.white.withValues(alpha: .72)],
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .24),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppAvatarImage(
              imageUrl: imageUrl,
              radius: 56,
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.primary,
              fallback: const Icon(Icons.add_a_photo, size: 32),
            ),
            if (saving)
              Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .28),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
