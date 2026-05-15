import 'dotenv/config';
import { verifyAuthorizationHeader } from '../../../src/auth.js';
import { handleEchoAiChat } from '../../../src/echoAiHandler.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    return res.end();
  }

  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return sendJson(res, 405, { error: 'Method not allowed.' });
  }

  try {
    const user = await verifyAuthorizationHeader(req.headers.authorization ?? '');
    const result = await handleEchoAiChat({ body: req.body, user });
    return sendJson(res, 200, result);
  } catch (error) {
    console.error('echo-ai chat failed', error);
    return sendJson(res, error.status || 500, {
      error:
        error.publicMessage ||
        error.message ||
        'AI is not available right now. Please try again.',
    });
  }
}

function sendJson(res, statusCode, body) {
  res.statusCode = statusCode;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify(body));
}
