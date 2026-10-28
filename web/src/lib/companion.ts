"use client";

import { useEffect } from "react";
import type { TikoMood } from "@/components/tiko";

// Shared state for Tiko the companion (components/companion.tsx). Pages
// say how Tiko should look and what it should say with useCompanionPage;
// the tour hides it while its own Tiko is hopping around.

export type CompanionPage = {
  mood?: TikoMood;
  say?: string | null; // shown once per visit, then fades
};

type State = { page: CompanionPage | null; touring: boolean; off: boolean };

const OFF_KEY = "apticks-tiko-off";
// The server never shows Tiko; one fixed object keeps React from looping.
const SERVER_STATE: State = { page: null, touring: false, off: false };
let state: State = SERVER_STATE;
const listeners = new Set<() => void>();

function set(patch: Partial<State>) {
  state = { ...state, ...patch };
  listeners.forEach((l) => l());
}

export const companionStore = {
  subscribe(l: () => void) {
    listeners.add(l);
    return () => listeners.delete(l);
  },
  get: () => state,
  serverGet: () => SERVER_STATE,
};

export function setTouring(touring: boolean) {
  set({ touring });
}

// The player can switch Tiko off (and back on) from their profile.
export function readTikoOff() {
  try {
    return localStorage.getItem(OFF_KEY) === "1";
  } catch {
    return false;
  }
}

export function setTikoOff(off: boolean) {
  try {
    if (off) localStorage.setItem(OFF_KEY, "1");
    else localStorage.removeItem(OFF_KEY);
  } catch {
    // Not remembered next time; it still applies now.
  }
  set({ off });
}

// Called by a page to set Tiko's mood and message while it's on screen.
export function useCompanionPage(page: CompanionPage) {
  const { mood, say } = page;
  useEffect(() => {
    set({ page: { mood, say } });
    return () => set({ page: null });
  }, [mood, say]);
}
