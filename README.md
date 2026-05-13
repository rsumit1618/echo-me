# Echo Me

Echo Me is a small-to-mid scale Flutter chat application scaffolded with Firebase, Riverpod, repository boundaries, and local SQLite caching.

## Current Architecture

```text
lib/
  core/
    constants/      Firebase collection names
    di/             get_it registration and Riverpod providers
    errors/         User-facing exception type
    routing/        Auth gate
    theme/          Light, dark, elite themes
    utils/          Phone normalization and image compression
  data/
    model/          Firestore/local serialization models
    repository/     Repository implementations
    source/
      local/        SQLite cache
      remote/       Firebase Auth, Firestore, Storage, FCM wrappers
  domain/
    entity/         AppUser, Contact, Chat, Message, Call
    repository/     Repository contracts
  features/
    auth/           Mobile OTP login
    chats/          Recent chats and one-to-one message thread
    contacts/       Device contact sync and registered-user matching
    calls/          Call history
    home/           4-tab shell
    profile/        Profile image/email management
    settings/       Theme switching
```

## Implemented

- Firebase phone OTP login.
- User profile persistence with phone number, optional email, profile image URL, and FCM token.
- Device contact permission handling, normalization, deduplication, secure sync, and registered-user lookup.
- Bottom navigation: Chats, Contacts, Call History, Settings.
- Real-time one-to-one chats with text and up to 5 images per message.
- Image resize/compression path targeting 100KB before upload.
- Cached/lazy network image rendering in chat.
- Message state model: sent, delivered, read.
- Call history model and Firestore-backed list.
- FCM token capture for server-side notifications.
- Profile image crop/zoom flow and optimized upload.
- Local persisted theme: Light, Dark, Elite.
- SQLite cache foundation for contacts/messages.
- Firestore and Storage security rule files.

## Firebase

Follow [FIREBASE_SETUP.md](FIREBASE_SETUP.md) to connect the project to Firebase, enable phone auth, deploy rules, and create indexes.

## Verification

```bash
flutter pub get
dart analyze lib test
flutter test
```

`flutter build apk --debug` may take a long time on first Android/Gradle setup. In this workspace it timed out before completion, while source analysis and tests passed.
