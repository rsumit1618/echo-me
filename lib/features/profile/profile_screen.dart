import 'dart:io';
import 'dart:convert';

import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/utils/image_optimizer.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/domain/entity/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _email = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
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
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    _Avatar(user: user, onTap: _changeImage),
                    const SizedBox(height: 14),
                    Text(
                      user.phoneNumber,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap photo to update profile image',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load profile: $error')),
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
      if (mounted) setState(() => _saving = true);

      final uid = ref.read(authRepositoryProvider).firebaseUser?.uid;
      if (uid == null) throw Exception('Please login again.');
      final optimized = await ImageOptimizer().compressToUnder100Kb(
        File(cropped.path),
      );
      final bytes = await optimized.readAsBytes();
      final url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await ref
          .read(authRepositoryProvider)
          .updateProfile(profileImageUrl: url)
          .timeout(const Duration(seconds: 20));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update profile image. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

}

class _Avatar extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;

  const _Avatar({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = user.profileImageUrl;
    final imageProvider = _imageProvider(imageUrl);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.all(4),
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
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 56,
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? const Icon(Icons.add_a_photo, size: 32)
              : null,
        ),
      ),
    );
  }

  ImageProvider? _imageProvider(String? value) {
    try {
      if (value == null || value.isEmpty) return null;
      if (value.startsWith('data:image')) {
        final base64Data = value.substring(value.indexOf(',') + 1);
        return MemoryImage(base64Decode(base64Data));
      }
      return NetworkImage(value);
    } catch (_) {
      return null;
    }
  }
}
