import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

// This is your unique configuration object from your screenshot
const firebaseConfig = {
  apiKey: "AIzaSyD-1IKJGWPQhZfhwSuE7hIj2fIRkMwpNrs",
  authDomain: "uco-kiosk-personal-f92b6.firebaseapp.com",
  projectId: "uco-kiosk-personal-f92b6",
  storageBucket: "uco-kiosk-personal-f92b6.appspot.com",
  messagingSenderId: "303212845625",
  appId: "1:303212845625:web:80893047a0709b578c7c97"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Export the services you need for your dashboard
export const auth = getAuth(app);
export const db = getFirestore(app);