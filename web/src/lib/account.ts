import { api, ensureSession, resetSession } from "./api";
import { supabase } from "./supabase";

// A guest account lives only in this browser. Adding an email keeps the
// same account (and rating), so it can be signed in to anywhere.
// Supabase sends a one-time code; see the README for the email templates.

export type Account = { guest: boolean; email: string | null };

function fail(error: { message: string } | null) {
  if (error) throw new Error(error.message);
}

export const account = {
  get: async (): Promise<Account> => {
    await ensureSession();
    const { data } = await supabase().auth.getSession();
    const user = data.session?.user;
    return { guest: user?.is_anonymous ?? true, email: user?.email || null };
  },

  // Guest → saved account. The code goes to the new address.
  sendSaveCode: async (email: string) => {
    await ensureSession();
    const { error } = await supabase().auth.updateUser({ email });
    if (error && /already/i.test(error.message)) {
      throw new Error("That email already has an account. Sign in with it instead.");
    }
    fail(error);
  },
  confirmSaveCode: async (email: string, token: string) => {
    const { error } = await supabase().auth.verifyOtp({ email, token, type: "email_change" });
    fail(error);
  },

  // Sign in to an account saved on another device. Only existing accounts.
  sendSignInCode: async (email: string) => {
    const { error } = await supabase().auth.signInWithOtp({ email, options: { shouldCreateUser: false } });
    if (error && /signups not allowed|not found/i.test(error.message)) {
      throw new Error("No saved account uses that email.");
    }
    fail(error);
  },
  confirmSignInCode: async (email: string, token: string) => {
    const { error } = await supabase().auth.verifyOtp({ email, token, type: "email" });
    fail(error);
  },

  signOut: async () => {
    const { error } = await supabase().auth.signOut();
    resetSession();
    fail(error);
  },

  // Erases the profile, duels and rating. The session is cleared locally,
  // since the user it belongs to no longer exists.
  delete: async () => {
    await api.deleteMe();
    await supabase().auth.signOut({ scope: "local" });
    resetSession();
  },
};
