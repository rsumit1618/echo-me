import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { requireFirebaseUser } from './auth.js';
import { getAdvisor } from './advisors.js';
import { generateGeminiReply } from './geminiClient.js';
import { enforceAiUsageLimit } from './usageLimiter.js';

const app = express();
const port = Number(process.env.PORT || 8080);

app.use(helmet());
app.use(cors({ origin: true }));
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_, res) => {
  res.json({ ok: true });
});

app.post('/api/echo-ai/chat', requireFirebaseUser, async (req, res) => {
  try {
    const advisor = getAdvisor(req.body?.advisorId);
    const messages = normalizeMessages(req.body?.messages);

    if (messages.length === 0) {
      return res.status(400).json({ error: 'Message is required.' });
    }

    await enforceAiUsageLimit(req.user.uid);

    const reply = await generateGeminiReply({
      advisor,
      messages,
    });

    return res.json({
      advisor: advisor.name,
      reply,
    });
  } catch (error) {
    console.error('echo-ai chat failed', error);
    return res.status(error.status || 500).json({
      error:
        error.status === 429
          ? error.message
          : 'AI is not available right now. Please try again.',
    });
  }
});

app.use((_, res) => {
  res.status(404).json({ error: 'Not found.' });
});

app.listen(port, () => {
  console.log(`Echo Me AI server listening on port ${port}`);
});

function normalizeMessages(value) {
  if (!Array.isArray(value)) return [];

  return value
    .map((message) => ({
      role: message?.role === 'assistant' ? 'assistant' : 'user',
      content: String(message?.content ?? '').trim(),
    }))
    .filter((message) => message.content.length > 0)
    .slice(-16);
}
