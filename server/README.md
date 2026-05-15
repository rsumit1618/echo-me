# Echo Me AI Server

Private Node.js backend for Echo AI. Keep this server separate from the Flutter app at runtime.

## Why this exists

Do not put AI API keys inside Flutter. APK files can be reverse engineered. This server keeps `GEMINI_API_KEY` private and only accepts requests from signed-in Firebase users.

## Local setup

```powershell
cd server
copy .env.example .env
npm install
npm run dev
```

Fill `.env` with real values. `.env` is ignored by Git.

Use Google AI Studio to create a Gemini API key, then paste it into:

```env
GEMINI_API_KEY=your_key_here
```

The server also limits Echo AI usage per Firebase user:

```env
AI_DAILY_LIMIT_PER_USER=30
AI_PER_MINUTE_LIMIT_PER_USER=3
```

## Public access protection

The API requires a Firebase ID token:

```text
Authorization: Bearer <firebase_id_token>
```

Unauthenticated users get `401`.

## Endpoint

```text
POST /api/echo-ai/chat
```

Body:

```json
{
  "advisorId": "friend",
  "messages": [
    { "role": "user", "content": "Help me plan my day" }
  ]
}
```
