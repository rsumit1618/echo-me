# TODO

## Completed
- [ ] Plan approved by user (start implementation).

## Next implementation steps
- [x] Inspect chat provider/repository error path and adjust so empty chats shows empty state and never throws.

- [x] Fix profile image picker crash: add concurrency guard, robust null/path/file checks, and wrap crop/upload/update in safer error handling.

- [ ] Add “frame image” option to profile image flow (UI + processing + upload + storage/update).
- [ ] Improve contacts sync performance: chunk Firestore writes, move heavy local upserts off UI thread (isolate/compute), and add stricter null checks.
- [ ] Ensure first-time login/profile bootstrap fully upserts/merges user data without null overwrites.
- [ ] Add missing null-safety in relevant model `fromMap`/parsers.

## Validation
- [ ] Run `flutter analyze`
- [ ] Run app smoke checks for: profile picker, chats empty state, contacts invite for unregistered, first login sync.

