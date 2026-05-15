import { getAdvisor } from './advisors.js';
import { generateGeminiReply } from './geminiClient.js';
import { enforceAiUsageLimit } from './usageLimiter.js';

export async function handleEchoAiChat({ body, user }) {
  const advisor = getAdvisor(body?.advisorId);
  const messages = normalizeMessages(body?.messages);

  if (messages.length === 0) {
    const error = new Error('Message is required.');
    error.status = 400;
    error.publicMessage = 'Message is required.';
    throw error;
  }

  await enforceAiUsageLimit(user.uid);

  const reply = await generateGeminiReply({
    advisor,
    messages,
  });

  return {
    advisor: advisor.name,
    reply,
  };
}

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
