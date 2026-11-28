"use client";

import Image from "next/image";
import { useEffect, useState } from "react";
import {
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithPopup,
  signOut,
  type User,
} from "firebase/auth";
import { auth } from "@/lib/firebase";

// undefined = still checking, null = signed out, User = signed in
type AuthState = User | null | undefined;

export default function DashboardPage() {
  const [user, setUser] = useState<AuthState>(undefined);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => onAuthStateChanged(auth, setUser), []);

  async function handleSignIn() {
    setError(null);
    setBusy(true);
    try {
      await signInWithPopup(auth, new GoogleAuthProvider());
    } catch (e) {
      const code = (e as { code?: string }).code;
      if (code !== "auth/popup-closed-by-user" && code !== "auth/cancelled-popup-request") {
        setError("Sign-in did not complete. Please try again.");
      }
    } finally {
      setBusy(false);
    }
  }

  async function handleSignOut() {
    await signOut(auth);
  }

  return (
    <div className="flex flex-1 flex-col">
      <header className="border-b border-[#E5E7EB] bg-white">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
          <Image src="/logo-lockup.png" alt="FinStreak" width={150} height={39} priority />
          {user ? (
            <button
              onClick={handleSignOut}
              className="rounded-full border border-[#D1D5DB] px-4 py-2 text-sm font-medium hover:bg-[#F9F9F7]"
            >
              Sign out
            </button>
          ) : null}
        </div>
      </header>

      <main className="mx-auto flex w-full max-w-6xl flex-1 items-center justify-center px-6 py-16">
        {user === undefined ? (
          <p className="text-[#6B7280]">Loading…</p>
        ) : user === null ? (
          <div className="w-full max-w-md rounded-3xl border border-[#E5E7EB] bg-white p-10 text-center shadow-sm">
            <Image
              src="/logo-mark.png"
              alt=""
              width={56}
              height={56}
              className="mx-auto"
            />
            <h1 className="mt-6 text-2xl font-bold tracking-tight text-[#141613]">Sign in to FinStreak</h1>
            <p className="mt-2 text-sm text-[#6B7280]">
              Use the Google account you use in the app.
            </p>
            <button
              onClick={handleSignIn}
              disabled={busy}
              className="mt-8 flex h-12 w-full items-center justify-center gap-3 rounded-full bg-[#214D2A] font-semibold text-white transition-colors hover:bg-[#3C8B47] disabled:opacity-60"
            >
              {busy ? "Signing in…" : "Continue with Google"}
            </button>
            {error ? <p className="mt-4 text-sm text-red-600">{error}</p> : null}
          </div>
        ) : (
          <div className="w-full max-w-2xl rounded-3xl border border-[#E5E7EB] bg-white p-10 shadow-sm">
            <p className="text-sm text-[#6B7280]">Signed in as</p>
            <p className="mt-1 font-semibold text-[#141613]">{user.email ?? user.displayName ?? "Your account"}</p>
            <h1 className="mt-8 text-2xl font-bold tracking-tight text-[#141613]">
              The web version is coming soon
            </h1>
            <p className="mt-3 leading-7 text-[#6B7280]">
              Your full FinStreak app will open here in your browser. Until then, use the app on
              your phone. Everything you add there is tied to this same account.
            </p>
          </div>
        )}
      </main>
    </div>
  );
}
