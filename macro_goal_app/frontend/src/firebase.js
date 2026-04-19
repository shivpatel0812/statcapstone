import { initializeApp, getApps } from "firebase/app";
import { getAuth, GoogleAuthProvider } from "firebase/auth";
import { getAnalytics, isSupported } from "firebase/analytics";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
  measurementId: import.meta.env.VITE_FIREBASE_MEASUREMENT_ID,
};

export function isFirebaseConfigured() {
  return Boolean(
    firebaseConfig.apiKey && firebaseConfig.authDomain && firebaseConfig.projectId && firebaseConfig.appId
  );
}

function attachAnalyticsIfConfigured(app) {
  if (!firebaseConfig.measurementId) return;
  isSupported()
    .then((supported) => {
      if (supported) getAnalytics(app);
    })
    .catch(() => {});
}

function getOrInitApp() {
  if (!isFirebaseConfigured()) return null;
  if (!getApps().length) {
    const app = initializeApp(firebaseConfig);
    attachAnalyticsIfConfigured(app);
    return app;
  }
  return getApps()[0];
}

export function getFirebaseAuth() {
  const app = getOrInitApp();
  return app ? getAuth(app) : null;
}

export function getFirestoreDb() {
  const app = getOrInitApp();
  return app ? getFirestore(app) : null;
}

export const googleAuthProvider = new GoogleAuthProvider();
