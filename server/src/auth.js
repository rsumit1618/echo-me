import admin from 'firebase-admin';

function initializeFirebaseAdmin() {
  if (admin.apps.length > 0) return;

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson && serviceAccountJson.trim().length > 0) {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
      projectId: process.env.FIREBASE_PROJECT_ID,
    });
    return;
  }

  admin.initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID,
  });
}

initializeFirebaseAdmin();

export { admin };

export async function requireFirebaseUser(req, res, next) {
  try {
    const authHeader = req.header('authorization') ?? '';
    const [scheme, token] = authHeader.split(' ');

    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ error: 'Login is required.' });
    }

    req.user = await admin.auth().verifyIdToken(token);
    return next();
  } catch (_) {
    return res.status(401).json({ error: 'Login is required.' });
  }
}
