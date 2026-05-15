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

## Deploy on Vercel

Push the `server` folder to GitHub first. In Vercel, import the same repo and choose:

```text
Root Directory: server
Framework Preset: Other
Install Command: npm install
Build Command: leave empty
Output Directory: leave empty
```

Add these environment variables in Vercel Project Settings:

```env
GEMINI_API_KEY=your_google_ai_studio_key
GEMINI_MODEL=gemini-2.5-flash-lite
AI_DAILY_LIMIT_PER_USER=30
AI_PER_MINUTE_LIMIT_PER_USER=3
FIREBASE_PROJECT_ID=echo-me-fe509
FIREBASE_SERVICE_ACCOUNT_JSON=your_firebase_service_account_json
```

After deploy, test:

```text
https://your-vercel-domain.vercel.app/
https://your-vercel-domain.vercel.app/api/health
```
