import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echo_me/core/di/providers.dart';
import 'package:echo_me/core/errors/app_exception.dart';
import 'package:echo_me/core/utils/image_optimizer.dart';
import 'package:echo_me/core/widgets/app_avatar_image.dart';
import 'package:echo_me/core/widgets/app_card.dart';
import 'package:echo_me/core/widgets/app_state_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const _developerAdminEmail = 'rsumit1618@gmail.com';
const _developerDocPath = 'appConfig/developerContact';

final developerContactProvider = StreamProvider.autoDispose<DeveloperContact>((
  ref,
) {
  return FirebaseFirestore.instance
      .doc(_developerDocPath)
      .snapshots()
      .map((snapshot) => DeveloperContact.fromMap(snapshot.data()));
});

class DeveloperContact {
  final String name;
  final String title;
  final String email;
  final String profileImageUrl;
  final String linkedInUrl;
  final String githubUrl;
  final String portfolioUrl;

  const DeveloperContact({
    required this.name,
    required this.title,
    required this.email,
    required this.profileImageUrl,
    required this.linkedInUrl,
    required this.githubUrl,
    required this.portfolioUrl,
  });

  factory DeveloperContact.fromMap(Map<String, dynamic>? data) {
    return DeveloperContact(
      name: data?['name'] as String? ?? 'Sumit Rai',
      title: data?['title'] as String? ?? 'Senior Software Engineer',
      email: data?['email'] as String? ?? _developerAdminEmail,
      profileImageUrl: data?['profileImageUrl'] as String? ?? '',
      linkedInUrl: data?['linkedInUrl'] as String? ?? '',
      githubUrl: data?['githubUrl'] as String? ?? '',
      portfolioUrl: data?['portfolioUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'title': title,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'linkedInUrl': linkedInUrl,
      'githubUrl': githubUrl,
      'portfolioUrl': portfolioUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DeveloperContact copyWith({
    String? name,
    String? title,
    String? email,
    String? profileImageUrl,
    String? linkedInUrl,
    String? githubUrl,
    String? portfolioUrl,
  }) {
    return DeveloperContact(
      name: name ?? this.name,
      title: title ?? this.title,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      linkedInUrl: linkedInUrl ?? this.linkedInUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
    );
  }
}

class DeveloperContactScreen extends ConsumerStatefulWidget {
  const DeveloperContactScreen({super.key});

  @override
  ConsumerState<DeveloperContactScreen> createState() =>
      _DeveloperContactScreenState();
}

class _DeveloperContactScreenState
    extends ConsumerState<DeveloperContactScreen> {
  final _name = TextEditingController();
  final _title = TextEditingController();
  final _email = TextEditingController();
  final _linkedIn = TextEditingController();
  final _github = TextEditingController();
  final _portfolio = TextEditingController();

  bool _editing = false;
  bool _saving = false;
  String _profileImageUrl = '';
  String? _loadedSignature;

  bool get _isAdmin {
    final email =
        ref.watch(authStateProvider).valueOrNull?.email ??
        ref.watch(authRepositoryProvider).firebaseUser?.email;
    return email?.toLowerCase().trim() == _developerAdminEmail;
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _email.dispose();
    _linkedIn.dispose();
    _github.dispose();
    _portfolio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contact = ref.watch(developerContactProvider);
    final isAdmin = _isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Contact'),
        actions: [
          if (isAdmin)
            TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => _toggleEdit(contact.valueOrNull),
              icon: Icon(_editing ? Icons.close : Icons.edit),
              label: Text(_editing ? 'Cancel' : 'Edit'),
            ),
        ],
      ),
      body: contact.when(
        data: (data) {
          _syncControllers(data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DeveloperHero(
                contact: data.copyWith(profileImageUrl: _profileImageUrl),
                editing: _editing && isAdmin,
                saving: _saving,
                onImageTap: _pickImage,
              ),
              const SizedBox(height: 16),
              _editing && isAdmin
                  ? _EditorCard(
                      name: _name,
                      title: _title,
                      email: _email,
                      linkedIn: _linkedIn,
                      github: _github,
                      portfolio: _portfolio,
                      saving: _saving,
                      onSave: _save,
                    )
                  : _DetailsCard(contact: data),
            ],
          );
        },
        loading: () => const AppLoadingView(),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(developerContactProvider),
        ),
      ),
    );
  }

  void _syncControllers(DeveloperContact contact) {
    final signature = [
      contact.name,
      contact.title,
      contact.email,
      contact.profileImageUrl,
      contact.linkedInUrl,
      contact.githubUrl,
      contact.portfolioUrl,
    ].join('|');
    if (_loadedSignature == signature || _editing) return;
    _loadedSignature = signature;
    _name.text = contact.name;
    _title.text = contact.title;
    _email.text = contact.email;
    _linkedIn.text = contact.linkedInUrl;
    _github.text = contact.githubUrl;
    _portfolio.text = contact.portfolioUrl;
    _profileImageUrl = contact.profileImageUrl;
  }

  void _toggleEdit(DeveloperContact? contact) {
    setState(() {
      _editing = !_editing;
      if (!_editing && contact != null) {
        _loadedSignature = null;
        _syncControllers(contact);
      }
    });
  }

  Future<void> _pickImage() async {
    if (!_editing || !_isAdmin || _saving) return;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Developer image',
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Developer image', aspectRatioLockEnabled: true),
        ],
      );
      if (cropped == null) return;
      final optimized = await ImageOptimizer().compressToUnder100Kb(
        File(cropped.path),
      );
      final bytes = await optimized.readAsBytes();
      final url = await compute(_encodeDeveloperImageDataUrl, bytes);
      if (mounted) setState(() => _profileImageUrl = url);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _save() async {
    if (!_isAdmin) return;
    setState(() => _saving = true);
    try {
      final contact = DeveloperContact(
        name: _name.text.trim().isEmpty ? 'Sumit Rai' : _name.text.trim(),
        title: _title.text.trim().isEmpty
            ? 'Senior Software Engineer'
            : _title.text.trim(),
        email: _email.text.trim().isEmpty
            ? _developerAdminEmail
            : _email.text.trim(),
        profileImageUrl: _profileImageUrl.trim(),
        linkedInUrl: _linkedIn.text.trim(),
        githubUrl: _github.text.trim(),
        portfolioUrl: _portfolio.text.trim(),
      );

      await FirebaseFirestore.instance
          .doc(_developerDocPath)
          .set(contact.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 20));

      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Developer contact updated.')),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppErrorMapper.message(error))));
  }
}

String _encodeDeveloperImageDataUrl(List<int> bytes) {
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

class _DeveloperHero extends StatelessWidget {
  final DeveloperContact contact;
  final bool editing;
  final bool saving;
  final VoidCallback onImageTap;

  const _DeveloperHero({
    required this.contact,
    required this.editing,
    required this.saving,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
          InkWell(
            customBorder: const CircleBorder(),
            onTap: editing ? onImageTap : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: .9),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppAvatarImage(
                      imageUrl: contact.profileImageUrl,
                      radius: 58,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      fallback: Text(
                        'SR',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ),
                ),
                if (editing)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      child: saving
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.edit, size: 18),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            contact.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contact.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: .88),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final DeveloperContact contact;

  const _DetailsCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About Developer',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Flutter, Firebase, clean architecture, realtime chat, and polished mobile app experiences.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              _InfoTile(
                icon: Icons.mail_outline,
                title: 'Email',
                value: contact.email,
                actionLabel: 'Email',
                uri: Uri(scheme: 'mailto', path: contact.email),
              ),
              _InfoTile(
                icon: Icons.work_outline,
                title: 'Role',
                value: contact.title,
              ),
              _InfoTile(
                icon: Icons.link,
                title: 'LinkedIn',
                value: contact.linkedInUrl.isEmpty
                    ? 'LinkedIn link will be added soon'
                    : contact.linkedInUrl,
                actionLabel: 'Open LinkedIn',
                uri: _webUri(contact.linkedInUrl),
              ),
              _InfoTile(
                icon: Icons.code,
                title: 'GitHub',
                value: contact.githubUrl.isEmpty
                    ? 'GitHub link will be added soon'
                    : contact.githubUrl,
                actionLabel: 'Open GitHub',
                uri: _webUri(contact.githubUrl),
              ),
              _InfoTile(
                icon: Icons.language,
                title: 'Portfolio',
                value: contact.portfolioUrl.isEmpty
                    ? 'Portfolio link will be added soon'
                    : contact.portfolioUrl,
                actionLabel: 'Open Portfolio',
                uri: _webUri(contact.portfolioUrl),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? actionLabel;
  final Uri? uri;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.actionLabel,
    this.uri,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      onTap: uri == null ? null : () => _launchContactUri(context, uri!),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colorScheme.onPrimaryContainer),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: uri == null
          ? null
          : IconButton(
              tooltip: actionLabel ?? 'Open',
              onPressed: () => _launchContactUri(context, uri!),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
    );
  }
}

Uri? _webUri(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return null;
  final uri = Uri.tryParse(clean);
  if (uri == null) return null;
  if (uri.hasScheme) return uri;
  return Uri.tryParse('https://$clean');
}

Future<void> _launchContactUri(BuildContext context, Uri uri) async {
  var launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open this link.')));
  }
}

class _EditorCard extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController title;
  final TextEditingController email;
  final TextEditingController linkedIn;
  final TextEditingController github;
  final TextEditingController portfolio;
  final bool saving;
  final VoidCallback onSave;

  const _EditorCard({
    required this.name,
    required this.title,
    required this.email,
    required this.linkedIn,
    required this.github,
    required this.portfolio,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: title,
            decoration: const InputDecoration(
              labelText: 'Title',
              prefixIcon: Icon(Icons.work_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: linkedIn,
            decoration: const InputDecoration(
              labelText: 'LinkedIn URL',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: github,
            decoration: const InputDecoration(
              labelText: 'GitHub URL',
              prefixIcon: Icon(Icons.code),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: portfolio,
            decoration: const InputDecoration(
              labelText: 'Portfolio URL',
              prefixIcon: Icon(Icons.language),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(saving ? 'Saving...' : 'Save developer contact'),
          ),
        ],
      ),
    );
  }
}
