import { cert, getApps, initializeApp, type App } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

// Service account JSON for the finella-dev project, kept in server env only.
// Never expose this to the browser or to the mobile app.
function init(): App {
  if (getApps().length) return getApps()[0];
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON is not set");
  }
  return initializeApp({ credential: cert(JSON.parse(raw)) });
}

export function adminAuth() {
  return getAuth(init());
}

export function adminDb() {
  return getFirestore(init());
}
