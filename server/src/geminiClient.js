const geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

export async function generateGeminiReply({ advisor, messages }) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey.includes('replace_with')) {
    throw new Error('GEMINI_API_KEY is not configured.');
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
    const error = new Error(message);
    error.status = response.status;
    throw error;
  }

  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  const reply = parts
    .map((part) => part.text)
    .filter(Boolean)
    .join('\n')
    .trim();

  if (!reply) throw new Error('Gemini reply was empty.');
  return reply;
}

function toGeminiContent(message) {
  return {
    role: message.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: message.content }],
  };
}
