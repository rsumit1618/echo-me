import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { requireFirebaseUser } from './auth.js';
import { handleEchoAiChat } from './echoAiHandler.js';

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
    const result = await handleEchoAiChat({ body: req.body, user: req.user });
    return res.json(result);
  } catch (error) {
    console.error('echo-ai chat failed', error);
    return res.status(error.status || 500).json({
      error:
        error.publicMessage ||
        error.message ||
        'AI is not available right now. Please try again.',
    });
  }
});

app.use((_, res) => {
  res.status(404).json({ error: 'Not found.' });
});

app.listen(port, () => {
  console.log(`Echo Me AI server listening on port ${port}`);
});
