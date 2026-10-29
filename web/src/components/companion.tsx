"use client";

import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { companionStore, readTikoOff, setTikoOff } from "@/lib/companion";
import { Tiko, type TikoMood } from "./tiko";

// Tiko the companion: stays with the player in the bottom corner of the
// main screens, with a mood that fits the page, and says the odd helpful
// thing. Screens that draw their own Tiko (matchmaking, duels, results,
// the Daily start, challenge links, 404) don't show this one, so there's
// only ever one Tiko on screen. Mounted once in the root layout so it
// doesn't reappear on every navigation.

// Where the companion sits. The tour's Tiko lands on the same spot at the
// end, so the hand-over is seamless.
export const DOCK = { right: 20, bottomPhone: 92, bottomWide: 24, sizePhone: 64, sizeWide: 76 };

// Profile has Tiko on its banner and its own tile, so the companion sits that one out.
const ROUTE_MOOD: Record<string, TikoMood> = { "/": "happy", "/leaderboard": "point" };

const TIPS = [
  "Right answers score 100, plus up to 50 for speed.",
  "A guess beats a timeout: unanswered questions score nothing.",
  "In a challenge, whoever plays second races the other's run live.",
  "Play the Daily Challenge every day to grow your streak.",
  "Company practice only uses topics from that company's test.",
  "Add your college to climb your college leaderboard.",
  "Tap me five times fast. I dare you.",
];

const wide = () => window.matchMedia("(min-width: 1024px)").matches;
const subscribeWide = (cb: () => void) => {
  const m = window.matchMedia("(min-width: 1024px)");
  m.addEventListener("change", cb);
  return () => m.removeEventListener("change", cb);
};

export function Companion() {
  const path = usePathname();
  const { page, touring, off } = useSyncExternalStore(companionStore.subscribe, companionStore.get, companionStore.serverGet);
  const isWide = useSyncExternalStore(subscribeWide, wide, () => true);
  const [bubble, setBubble] = useState<string | null>(null);
  const seen = useRef(new Set<string>());
  const hideTimer = useRef<number | undefined>(undefined);

  // Read the saved on/off choice once in the browser.
  useEffect(() => {
    if (readTikoOff()) setTikoOff(true);
  }, []);

  const routeMood = ROUTE_MOOD[path];
  const visible = routeMood !== undefined && !touring && !off;
  const mood = page?.mood ?? routeMood ?? "happy";

  function speak(text: string) {
    window.clearTimeout(hideTimer.current);
    setBubble(text);
    hideTimer.current = window.setTimeout(() => setBubble(null), 6000);
  }

  // A page's message shows once per visit.
  const say = visible ? page?.say : null;
  useEffect(() => {
    if (!say || seen.current.has(say)) return;
    // Only counts as seen once it's actually on screen (the tour can
    // cover Tiko first).
    const t = window.setTimeout(() => {
      seen.current.add(say);
      speak(say);
    }, 900);
    return () => window.clearTimeout(t);
  }, [say]);

  // Clear any bubble when Tiko leaves the screen.
  useEffect(() => {
    if (visible) return;
    window.clearTimeout(hideTimer.current);
    const t = window.setTimeout(() => setBubble(null), 0);
    return () => window.clearTimeout(t);
  }, [visible]);

  if (!visible) return null;
  const size = isWide ? DOCK.sizeWide : DOCK.sizePhone;

  return (
    <div
      className="pointer-events-none fixed z-40 flex items-end gap-2"
      style={{ right: DOCK.right, bottom: isWide ? DOCK.bottomWide : DOCK.bottomPhone }}
    >
      {bubble && (
        <button
          onClick={() => setBubble(null)}
          aria-live="polite"
          className="pointer-events-auto relative mb-4 max-w-[230px] rounded-2xl border-2 border-line bg-surface px-3.5 py-2.5 text-left text-[13px] leading-snug text-soft sticker motion-safe:animate-pop"
        >
          {bubble}
          <span
            aria-hidden="true"
            className="absolute -right-[8px] bottom-4 size-3.5 rotate-45 border-t-2 border-r-2 border-line bg-surface"
          />
        </button>
      )}
      <div className="pointer-events-auto motion-safe:animate-rise">
        <Tiko mood={mood} size={size} onTap={() => speak(TIPS[Math.floor(Math.random() * TIPS.length)])} />
      </div>
    </div>
  );
}
