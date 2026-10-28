import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!;

// Kept from the old name so existing players stay signed in.
const STORAGE_KEY = "aptiduel-auth";

let browserClient: SupabaseClient | null = null;

// Browser client. The session lives in localStorage, so a player keeps
// their guest account (and rating) on this device.
export function supabase() {
  browserClient ??= createClient(url, key, {
    auth: { persistSession: true, autoRefreshToken: true, storageKey: STORAGE_KEY },
  });
  return browserClient;
}

// Whether this browser has played before, checked without creating a
// guest account.
export function hasSavedSession() {
  try {
    return localStorage.getItem(STORAGE_KEY) !== null;
  } catch {
    return false;
  }
}

// Server-side client for public reads (challenge pages, share images).
// It never carries a user session.
export function publicSupabase() {
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
