# Echo Me Firebase Setup

## Current Android Firebase project

This project is configured for:

- Firebase project: `echo-me-fe509`
- Android package: `com.sr.echo_me`
- Android config file: `android/app/google-services.json`

## 1. Firebase Console setup

1. Open the Firebase Console.
2. Select project `echo-me-fe509`.
3. Confirm the Android app package is `com.sr.echo_me`.
4. Add an iOS app later only if you need iPhone support.

## 2. Generate options

Install the FlutterFire CLI, then run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

The Android values are already filled from `google-services.json`.

## 3. Enable Firebase services

Enable these products:

- Authentication: Phone provider
- Firestore Database
- Cloud Storage
- Cloud Messaging

For Android OTP, add SHA-1 and SHA-256 fingerprints in Firebase project settings.

## 4. Deploy rules

Copy `firestore.rules` and `storage.rules` into Firebase Console, or deploy with:

```bash
firebase deploy --only firestore:rules,storage
```

To deploy indexes too:

```bash
firebase deploy --only firestore
```

## 5. Firestore schema

- `users/{uid}`: phone, optional email, optimized profile image URL, FCM token.
- `phoneIndex/{+E164}`: maps normalized phone numbers to registered user IDs.
- `users/{uid}/contacts/{phone}`: deduplicated contact sync results.
- `chats/{chatId}`: one-to-one chat metadata and last message.
- `chats/{chatId}/messages/{messageId}`: text/images and message state.
- `users/{uid}/calls/{callId}`: incoming, outgoing, and missed call history.

Create indexes if Firestore prompts for:

- `chats`: `participantIds array-contains`, `updatedAt desc`
- `chats/{chatId}/messages`: `createdAt desc`
- `users/{uid}/calls`: `startedAt desc`

## 6. Notifications

The client stores FCM tokens. Production message/contact-join notifications should be sent from Cloud Functions so users cannot spoof notifications from the app.
