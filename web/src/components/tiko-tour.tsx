"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { setTouring } from "@/lib/companion";
import { DOCK } from "./companion";
import { Tiko, type TikoMood } from "./tiko";

// First-visit tour of the home page. Tiko hops from card to card along a
// real arc, sits on each one and explains it in a speech bubble. Nothing
// is dimmed or blocked: the page stays usable and Skip is always there.
// Cards opt in with data-tour="name". Seen once per browser; Profile has
// a link (/?tour=1) to replay it.

type Step = { target: string | null; mood: TikoMood; title: string; text: string };

const STEPS: Step[] = [
  { target: null, mood: "wave", title: "Hi, I'm Tiko!", text: "I'll hop you around Apticks. It takes about 20 seconds." },
  {
    target: "quick",
    mood: "point",
    title: "Quick Match",
    text: "Race someone near your rating: 5 questions, about 3 minutes. A right answer scores 100, plus up to 50 for speed.",
  },
  {
    target: "challenge",
    mood: "happy",
    title: "Challenge friends",
    text: "Send a link on WhatsApp. You both get the same 5 questions, and whoever plays second races the other's run.",
  },
  { target: "daily", mood: "happy", title: "Daily Challenge", text: "One set a day, the same for everyone. Play daily to keep your streak alive." },
  {
    target: "company",
    mood: "think",
    title: "Company practice",
    text: "Preparing for TCS NQT, Infosys, Accenture or Wipro? Duel on just the topics their tests ask about.",
  },
  { target: "goals", mood: "cheer", title: "Daily goals", text: "Three small goals every day. Win duels to climb from Trainee all the way to Architect." },
  {
    target: "profile",
    mood: "wave",
    title: "Your profile",
    text: "Add your name and college to join your college leaderboard, and save your account with your email.",
  },
  { target: null, mood: "cheer", title: "You're ready!", text: "Your first duel is one tap away. Good luck!" },
];

const DONE_KEY = "apticks-tour-done";
const GAP = 8;

type Point = { x: number; y: number };

const reducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;

function visibleTarget(name: string) {
  // Some targets exist twice (sidebar and bottom bar); use the one on screen.
  return (
    [...document.querySelectorAll<HTMLElement>(`[data-tour="${name}"]`)].find(
      (el) => el.getClientRects().length > 0,
    ) ?? null
  );
}

// Where Tiko stands: on the target's top edge near its right corner, or
// in the bottom corner of the screen for the intro and the ending.
function spotFor(step: Step, size: number): Point {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const el = step.target ? visibleTarget(step.target) : null;
  if (!el) {
    // The companion's spot, so Tiko starts and ends the tour where it lives.
    const bottom = vw >= 1024 ? DOCK.bottomWide : DOCK.bottomPhone;
    return { x: vw - size - DOCK.right, y: vh - size - bottom };
  }
  const r = el.getBoundingClientRect();
  const x = Math.min(Math.max(r.right - size - 14, GAP), vw - size - GAP);
  const y = Math.min(Math.max(r.top - size + 10, GAP), vh - size - GAP);
  return { x, y };
}

// A projectile arc: constant sideways speed, a parabola up and down, with
// a crouch before take-off and a squash on landing.
function hopFrames(from: Point, to: Point): Keyframe[] {
  const dist = Math.hypot(to.x - from.x, to.y - from.y);
  const height = Math.min(160, 50 + dist * 0.22);
  const at = (p: Point, sx: number, sy: number) => `translate(${p.x}px, ${p.y}px) scale(${sx}, ${sy})`;
  const frames: Keyframe[] = [
    { transform: at(from, 1, 1), offset: 0 },
    { transform: at(from, 1.12, 0.86), offset: 0.12 },
  ];
  const n = 14;
  for (let i = 1; i < n; i++) {
    const t = i / n;
    const p = {
      x: from.x + (to.x - from.x) * t,
      y: from.y + (to.y - from.y) * t - height * 4 * t * (1 - t),
    };
    frames.push({ transform: at(p, t < 0.5 ? 0.93 : 0.96, t < 0.5 ? 1.08 : 1.05), offset: 0.12 + 0.7 * t });
  }
  frames.push({ transform: at(to, 1.14, 0.84), offset: 0.88 });
  frames.push({ transform: at(to, 0.97, 1.03), offset: 0.95 });
  frames.push({ transform: at(to, 1, 1), offset: 1 });
  return frames;
}

export function TikoTour() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [step, setStep] = useState(0);
  const [pos, setPos] = useState<Point | null>(null);
  const [landed, setLanded] = useState(false);
  const [bubble, setBubble] = useState<{ x: number; y: number; w: number } | null>(null);
  const tikoRef = useRef<HTMLDivElement>(null);
  const bubbleRef = useRef<HTMLDivElement>(null);
  const posRef = useRef<Point | null>(null);
  const [size, setSize] = useState(76);

  // Show on the first visit, or when asked to replay (/?tour=1).
  useEffect(() => {
    const replay = new URLSearchParams(window.location.search).get("tour") === "1";
    let seen = false;
    try {
      seen = localStorage.getItem(DONE_KEY) === "1";
    } catch {
      // Storage blocked: show the tour, it just won't be remembered.
    }
    if (replay) window.history.replaceState(null, "", window.location.pathname);
    if (!replay && seen) return;
    // Let the home page lay out first.
    const t = window.setTimeout(() => {
      setSize(window.innerWidth >= 1024 ? DOCK.sizeWide : DOCK.sizePhone);
      setOpen(true);
    }, 700);
    return () => window.clearTimeout(t);
  }, []);

  const finish = useCallback(() => {
    try {
      localStorage.setItem(DONE_KEY, "1");
    } catch {
      // Not remembered; harmless.
    }
    setOpen(false);
    setStep(0);
    setLanded(false);
    setPos(null);
    posRef.current = null;
  }, []);

  // Tiko is airborne until the hop to the next spot lands.
  const next = () => {
    setLanded(false);
    setStep((n) => n + 1);
  };

  // While the tour is on screen its Tiko stands in for the companion, which
  // takes over from the same spot when the tour ends or the page is left.
  useEffect(() => {
    if (!open) return;
    setTouring(true);
    return () => setTouring(false);
  }, [open]);

  // Move to the current step: bring its card into view, then hop there.
  useEffect(() => {
    if (!open) return;
    const s = STEPS[step];
    const el = s.target ? visibleTarget(s.target) : null;
    el?.setAttribute("data-tour-active", "");
    el?.scrollIntoView({ behavior: reducedMotion() ? "auto" : "smooth", block: "center" });

    let anim: Animation | undefined;
    const go = window.setTimeout(
      () => {
        const to = spotFor(s, size);
        // The tour starts where the companion already stands.
        const from = posRef.current ?? to;
        posRef.current = to;
        const node = tikoRef.current;
        if (!node || reducedMotion()) {
          setPos(to);
          setLanded(true);
          return;
        }
        const dist = Math.hypot(to.x - from.x, to.y - from.y);
        anim = node.animate(hopFrames(from, to), { duration: Math.min(1100, 560 + dist * 0.45), easing: "linear" });
        anim.onfinish = () => {
          setPos(to);
          setLanded(true);
        };
        setPos(to);
      },
      el ? 450 : 50,
    );
    return () => {
      window.clearTimeout(go);
      anim?.cancel();
      el?.removeAttribute("data-tour-active");
    };
  }, [open, step, size]);

  // Stay on the card while the page scrolls or resizes.
  useEffect(() => {
    if (!open || !landed) return;
    let frame = 0;
    const follow = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const to = spotFor(STEPS[step], size);
        posRef.current = to;
        setPos(to);
      });
    };
    window.addEventListener("scroll", follow, { passive: true });
    window.addEventListener("resize", follow);
    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener("scroll", follow);
      window.removeEventListener("resize", follow);
    };
  }, [open, landed, step, size]);

  // Put the bubble beside Tiko (left if there's room, else right, else
  // above), bottom-aligned with Tiko's feet, and always on screen.
  useLayoutEffect(() => {
    if (!open || !pos || !landed || !bubbleRef.current) return;
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const w = Math.min(300, vw - 2 * GAP - 16);
    const h = bubbleRef.current.offsetHeight;
    let x: number;
    let y = pos.y + size - h;
    if (pos.x - GAP - w >= GAP) x = pos.x - GAP - w;
    else if (pos.x + size + GAP + w <= vw - GAP) x = pos.x + size + GAP;
    else {
      x = Math.min(Math.max(pos.x + size / 2 - w / 2, GAP), vw - w - GAP);
      y = pos.y - h - GAP;
      if (y < GAP) y = pos.y + size + GAP;
    }
    y = Math.min(Math.max(y, GAP), vh - h - GAP);
    setBubble({ x, y, w });
  }, [open, pos, landed, size, step]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") finish();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, finish]);

  if (!open) return null;
  const s = STEPS[step];
  const last = step === STEPS.length - 1;

  return (
    <div className="pointer-events-none fixed inset-0 z-50">
      <div
        ref={tikoRef}
        className="pointer-events-auto absolute top-0 left-0 origin-bottom"
        style={pos ? { transform: `translate(${pos.x}px, ${pos.y}px)` } : { visibility: "hidden" }}
      >
        <Tiko mood={s.mood} size={size} still={!landed} />
      </div>

      <div
        ref={bubbleRef}
        role="dialog"
        aria-label="App tour"
        aria-live="polite"
        className={`pointer-events-auto absolute top-0 left-0 rounded-2xl border-2 border-line bg-surface p-4 sticker transition-opacity duration-200 ${
          landed && bubble ? "opacity-100 motion-safe:animate-pop" : "invisible opacity-0"
        }`}
        style={bubble ? { transform: `translate(${bubble.x}px, ${bubble.y}px)`, width: bubble.w } : { width: 300 }}
        key={step}
      >
        <p className="font-display text-[15px] font-bold">{s.title}</p>
        <p className="mt-1 text-sm leading-relaxed text-soft">{s.text}</p>
        <div className="mt-3 flex items-center justify-between gap-3">
          <span className="flex gap-1" aria-label={`Step ${step + 1} of ${STEPS.length}`}>
            {STEPS.map((_, i) => (
              <span key={i} className={`size-1.5 rounded-full ${i === step ? "bg-lime" : "bg-line-strong"}`} />
            ))}
          </span>
          <span className="flex items-center gap-2">
            {last ? (
              <>
                <button onClick={finish} className="rounded-lg px-2.5 py-1.5 text-xs font-semibold text-muted hover:text-text">
                  Later
                </button>
                <button
                  onClick={() => {
                    finish();
                    router.push("/play");
                  }}
                  className="rounded-lg bg-lime px-3 py-1.5 text-xs font-bold text-ink hover:bg-lime-hover"
                >
                  Find a match
                </button>
              </>
            ) : (
              <>
                <button onClick={finish} className="rounded-lg px-2.5 py-1.5 text-xs font-semibold text-muted hover:text-text">
                  Skip
                </button>
                <button
                  autoFocus
                  onClick={next}
                  className="rounded-lg bg-lime px-3 py-1.5 text-xs font-bold text-ink hover:bg-lime-hover"
                >
                  {step === 0 ? "Show me" : "Next"}
                </button>
              </>
            )}
          </span>
        </div>
      </div>
    </div>
  );
}
