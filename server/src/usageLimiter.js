import { admin } from './auth.js';

const minuteBuckets = new Map();

export async function enforceAiUsageLimit(uid) {
  enforceMinuteLimit(uid);
  await enforceDailyLimit(uid);
}

function enforceMinuteLimit(uid) {
  const limit = Number(process.env.AI_PER_MINUTE_LIMIT_PER_USER || 3);
  if (limit <= 0) return;

  const now = Date.now();
  const windowMs = 60 * 1000;
  const bucket = minuteBuckets.get(uid) ?? [];
  const active = bucket.filter((timestamp) => now - timestamp < windowMs);

  if (active.length >= limit) {
    const error = new Error('Please slow down and try again in a minute.');
    error.status = 429;
    throw error;
  }

  active.push(now);
  minuteBuckets.set(uid, active);
}

async function enforceDailyLimit(uid) {
  const limit = Number(process.env.AI_DAILY_LIMIT_PER_USER || 30);
  if (limit <= 0) return;

  const dateKey = new Date().toISOString().slice(0, 10);
  const usageRef = admin.firestore().collection('aiUsage').doc(`${uid}_${dateKey}`);

  await admin.firestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(usageRef);
    const count = snapshot.exists ? Number(snapshot.data().count || 0) : 0;

    if (count >= limit) {
      const error = new Error('Daily Echo AI limit reached. Please try again tomorrow.');
      error.status = 429;
      throw error;
    }

    transaction.set(
      usageRef,
      {
        uid,
        date: dateKey,
        count: count + 1,
        limit,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}
