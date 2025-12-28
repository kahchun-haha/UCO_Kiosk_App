// src/firebase.js
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getFunctions, httpsCallable } from 'firebase/functions';

const firebaseConfig = {
  apiKey: "AIzaSyD-1IKJGWPQhZfhwSuE7hIj2fIRkMwpNrs",
  authDomain: "uco-kiosk-personal-f92b6.firebaseapp.com",
  projectId: "uco-kiosk-personal-f92b6",
  storageBucket: "uco-kiosk-personal-f92b6.firebasestorage.app",
  messagingSenderId: "1045517832974",
  appId: "1:1045517832974:web:b5658a7160c107f8037d5f"
};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);

// ✅ FIX: explicitly set functions region
export const functions = getFunctions(app, "asia-southeast1");

// ---- Callables ----
export const createAgentCallable = httpsCallable(functions, 'createAgent');
export const createAdminCallable = httpsCallable(functions, 'createAdmin');
export const deleteUserCallable = httpsCallable(functions, 'deleteUser');
export const sendMonthlyImpactEmailsManualCallable = httpsCallable(functions, "sendMonthlyImpactEmailsManual");
export const reassignPendingTasksByShiftManualCallable = httpsCallable(functions, "reassignPendingTasksByShiftManual");
