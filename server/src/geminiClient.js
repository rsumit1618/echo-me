const geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

export async function generateGeminiReply({ advisor, messages }) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey.includes('replace_with')) {
    throw publicError(
      'GEMINI_API_KEY is not configured.',
      500,
      'AI key is missing on the server. Add GEMINI_API_KEY in server/.env and restart the server.',
    );
  }

  const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash-lite';
  const response = await fetch(`${geminiBaseUrl}/${model}:generateContent`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify({
      system_instruction: {
        parts: [{ text: advisor.systemPrompt }],
      },
      contents: messages.map(toGeminiContent),
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 600,
      },
    }),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = data?.error?.message || 'Gemini request failed.';
    throw publicError(message, response.status, mapGeminiError(response.status));
  }

  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  const reply = parts
    .map((part) => part.text)
    .filter(Boolean)
    .join('\n')
    .trim();

  if (!reply) {
    throw publicError(
      'Gemini reply was empty.',
      502,
      'AI returned an empty reply. Please try again.',
    );
  }
  return reply;
}

function toGeminiContent(message) {
  return {
    role: message.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: message.content }],
  };
}

function mapGeminiError(status) {
  if (status === 400 || status === 404) {
    return 'AI model is not available. Check GEMINI_MODEL in server/.env.';
  }

  if (status === 401 || status === 403) {
    return 'AI key is invalid or does not have access. Check GEMINI_API_KEY in server/.env.';
  }

  if (status === 429) {
    return 'Free AI limit is reached or busy. Please try again later.';
  }

  return 'AI is not available right now. Please try again.';
}

function publicError(message, status, publicMessage) {
  const error = new Error(message);
  error.status = status;
  error.publicMessage = publicMessage;
  return error;
}
