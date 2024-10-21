const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

exports.hashAndStoreApiKey = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { apiKey } = data;
  const userId = context.auth.uid;

  if (!apiKey) {
    throw new functions.https.HttpsError('invalid-argument', 'API key is required.');
  }

  // Hash the API key
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(apiKey, salt, 1000, 64, 'sha512').toString('hex');

  // Store the hashed key
  await admin.firestore().collection('Users').doc(userId).set({
    hashed_API: hash,
    salt: salt
  }, { merge: true });

  // Create documents for ChatLogs and WarnLogs
  await admin.firestore().collection('ChatLogs').doc(userId).set({});
  await admin.firestore().collection('WarnLogs').doc(userId).set({});

  return { success: true, message: 'API key hashed and stored successfully' };
});