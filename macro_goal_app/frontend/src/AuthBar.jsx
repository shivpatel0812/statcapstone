import { useState } from "react";
import { signInWithPopup, signOut } from "firebase/auth";
import { useAuth } from "./AuthContext";
import { getFirebaseAuth, googleAuthProvider } from "./firebase";

export default function AuthBar() {
  const { user, firebaseConfigured } = useAuth();
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  if (!firebaseConfigured) return null;

  async function handleSignIn() {
    const auth = getFirebaseAuth();
    if (!auth) return;
    setBusy(true);
    setErr("");
    try {
      await signInWithPopup(auth, googleAuthProvider);
    } catch (e) {
      setErr(e?.message || String(e));
    } finally {
      setBusy(false);
    }
  }

  async function handleSignOut() {
    const auth = getFirebaseAuth();
    if (!auth) return;
    setBusy(true);
    setErr("");
    try {
      await signOut(auth);
    } catch (e) {
      setErr(e?.message || String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth-bar">
      {user ? (
        <div className="auth-bar__signed-in">
          {user.photoURL ? (
            <img src={user.photoURL} alt="" className="auth-bar__avatar" width={32} height={32} />
          ) : null}
          <span className="auth-bar__email" title={user.email || user.uid}>
            {user.displayName || user.email || "Signed in"}
          </span>
          <button type="button" className="auth-bar__btn auth-bar__btn--ghost" onClick={handleSignOut} disabled={busy}>
            Sign out
          </button>
        </div>
      ) : (
        <button type="button" className="auth-bar__btn" onClick={handleSignIn} disabled={busy}>
          {busy ? "Signing in…" : "Sign in with Google"}
        </button>
      )}
      {err ? <p className="auth-bar__error">{err}</p> : null}
    </div>
  );
}
