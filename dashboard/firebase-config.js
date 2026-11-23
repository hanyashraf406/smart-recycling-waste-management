import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-app.js";
import { getAnalytics, isSupported as analyticsIsSupported } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-analytics.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";

export const firebaseConfig = {
  apiKey: "AIzaSyA3SRnpVHvmjDdqEjLIKl9j0ZypiAMgNUA",
  authDomain: "cach-6ebd3.firebaseapp.com",
  projectId: "cach-6ebd3",
  storageBucket: "cach-6ebd3.firebasestorage.app",
  messagingSenderId: "379255642460",
  appId: "1:379255642460:web:7540f30dbf9f48893c4999",
  measurementId: "G-E78N28CEGY"
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

export const analytics = await analyticsIsSupported() ? getAnalytics(app) : null;