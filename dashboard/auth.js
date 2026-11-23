import { auth, db } from "./firebase-config.js";
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  updateProfile
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js";
import {
  doc,
  serverTimestamp,
  setDoc
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";

const body = document.body;
const pageMode = body.dataset.page;
const loginUrl = body.dataset.loginUrl || "./login.html";
const successUrl = body.dataset.successUrl || "./homedashboard/homedashboard/index.html";
const messageBox = document.getElementById("authMessage");
const isProtected = body.dataset.protected === "true";

function showMessage(text, tone = "info") {
  if (!messageBox) return;
  messageBox.textContent = text;
  messageBox.dataset.tone = tone;
}

function setFormState(form, disabled) {
  if (!form) return;
  const elements = form.querySelectorAll("input, button");
  elements.forEach((element) => { element.disabled = disabled; });
}

function getFirebaseMessage(error) {
  switch (error?.code) {
    case "auth/invalid-email": return "Enter a valid email address.";
    case "auth/user-not-found":
    case "auth/wrong-password":
    case "auth/invalid-credential": return "Invalid email or password.";
    case "auth/email-already-in-use": return "This email is already registered.";
    case "auth/weak-password": return "Password should be at least 6 characters.";
    default: return error?.message || "Something went wrong. Try again.";
  }
}

async function handleLogin(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const submitButton = form.querySelector("button[type='submit']");
  const email = form.email.value.trim();
  const password = form.password.value;

  try {
    setFormState(form, true);
    if (submitButton) submitButton.textContent = "Signing in...";
    showMessage("Signing you in...");
    await signInWithEmailAndPassword(auth, email, password);
    window.location.replace(successUrl);
  } catch (error) {
    showMessage(getFirebaseMessage(error), "error");
  } finally {
    setFormState(form, false);
    if (submitButton) submitButton.textContent = "Log In";
  }
}

async function handleSignup(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const submitButton = form.querySelector("button[type='submit']");
  const fullName = form.fullName.value.trim();
  const email = form.email.value.trim();
  const password = form.password.value;
  const confirmPassword = form.confirmPassword.value;

  if (password !== confirmPassword) {
    showMessage("Passwords do not match.", "error");
    return;
  }

  try {
    setFormState(form, true);
    if (submitButton) submitButton.textContent = "Creating account...";
    showMessage("Creating your account...");
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    await updateProfile(userCredential.user, { displayName: fullName });
    await setDoc(doc(db, "users", userCredential.user.uid), {
      fullName, email, uid: userCredential.user.uid,
      createdAt: serverTimestamp(), updatedAt: serverTimestamp()
    });
    window.location.replace(successUrl);
  } catch (error) {
    showMessage(getFirebaseMessage(error), "error");
  } finally {
    setFormState(form, false);
    if (submitButton) submitButton.textContent = "Create Account";
  }
}

function wireSignOutLinks() {
  document.querySelectorAll("[data-sign-out]").forEach((link) => {
    link.addEventListener("click", async (event) => {
      event.preventDefault();
      try { await signOut(auth); } finally { window.location.replace(loginUrl); }
    });
  });
}

function initializeAuthViews() {
  const loginForm = document.getElementById("loginForm");
  const signupForm = document.getElementById("signupForm");

  if (pageMode === "login" && loginForm) loginForm.addEventListener("submit", handleLogin);
  if (pageMode === "signup" && signupForm) signupForm.addEventListener("submit", handleSignup);

  // ✅ الحماية فقط للصفحات اللي عليها data-protected="true"
  if (isProtected) {
    onAuthStateChanged(auth, (user) => {
      if (!user) window.location.replace(loginUrl);
    });
  }

  if (pageMode === "login" || pageMode === "signup") {
    onAuthStateChanged(auth, (user) => {
      if (user) window.location.replace(successUrl);
    });
  }

  wireSignOutLinks();
}

initializeAuthViews();