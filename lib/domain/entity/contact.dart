enum ContactAction { invite, chatNow, call }

class AppContact {
  static const defaultDisplayName = 'Unknown Contact';

  final String id;
  final String displayName;
  final String normalizedPhone;
  final String? registeredUserId;
  final String? profileImageUrl;
  final bool canCall;
  final DateTime syncedAt;

  const AppContact({
    required this.id,
    required this.displayName,
    required this.normalizedPhone,
    this.registeredUserId,
    this.profileImageUrl,
    this.canCall = false,
    required this.syncedAt,
  });

  ContactAction get action {
    if (registeredUserId == null) return ContactAction.invite;
    return ContactAction.chatNow;
  }
}
