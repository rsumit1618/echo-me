import 'dotenv/config';
import { verifyAuthorizationHeader } from '../../../src/auth.js';
import { handleEchoAiChat } from '../../../src/echoAiHandler.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Method not allowed.' });
  }

  try {
    const user = await verifyAuthorizationHeader(req.headers.authorization ?? '');
    const result = await handleEchoAiChat({ body: req.body, user });
    return res.status(200).json(result);
  } catch (error) {
    console.error('echo-ai chat failed', error);
    return res.status(error.status || 500).json({
      error:
        error.publicMessage ||
        error.message ||
        'AI is not available right now. Please try again.',
    });
  }
}
