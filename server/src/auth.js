import admin from 'firebase-admin';

function getFirebaseAdmin() {
  if (admin.apps.length > 0) return admin;

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson && serviceAccountJson.trim().length > 0) {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
      projectId: process.env.FIREBASE_PROJECT_ID,
    });
    return admin;
  }

  admin.initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID,
  });
  return admin;
}

export { admin };

export async function verifyAuthorizationHeader(authHeader = '') {
  const [scheme, token] = authHeader.split(' ');

  if (scheme !== 'Bearer' || !token) {
    const error = new Error('Login is required.');
    error.status = 401;
    error.publicMessage = 'Login is required.';
    throw error;
  }

  return getFirebaseAdmin().auth().verifyIdToken(token);
}

export async function requireFirebaseUser(req, res, next) {
  try {
    req.user = await verifyAuthorizationHeader(req.header('authorization') ?? '');
    return next();
  } catch (_) {
    return res.status(401).json({ error: 'Login is required.' });
  }
}
