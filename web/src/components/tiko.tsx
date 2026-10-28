"use client";

import { useEffect, useRef, useState } from "react";

// Tiko, the Apticks mascot: a little lime alien whose antenna is the
// stopwatch button. Drawn as plain SVG so it stays sharp, matches the
// palette and can move. Idle motion (hops, blinking, antenna wiggle) lives
// in globals.css. Tapping Tiko gets a reaction: a physics jump, a flip or
// a giggle, with a burst of stars; five quick taps make it dizzy. Motion
// is skipped for people who prefer reduced motion.

export type TikoMood = "wave" | "happy" | "point" | "think" | "cheer" | "sad" | "confused" | "sleep" | "giggle";

const INK = "#0b0e17";
const LIME = "#c8f135";
const ORANGE = "#ff8a4c";
const VIOLET = "#a594ff";

// Arm shapes, from shoulder to hand.
const ARMS: Record<string, string> = {
  downL: "M30 80 Q19 86 20 97",
  downR: "M90 80 Q101 86 100 97",
  upL: "M30 74 Q16 62 15 46",
  upR: "M90 74 Q104 62 105 46",
  pointR: "M90 77 Q104 74 114 70",
  chinR: "M90 82 Q86 96 72 96",
};

// Idle motion per mood: cheerful moods hop now and then (cheer keeps
// bouncing), quiet ones just breathe.
const IDLE: Record<TikoMood, string> = {
  wave: "tiko-hop",
  happy: "tiko-hop",
  point: "tiko-hop",
  cheer: "tiko-bounce",
  giggle: "tiko-bounce",
  think: "tiko-breathe",
  sad: "tiko-breathe",
  confused: "tiko-breathe",
  sleep: "tiko-breathe",
};

function Arm({ d, className }: { d: string; className?: string }) {
  const end = d.trim().split(/\s+/).slice(-2).map(Number);
  return (
    <g className={className}>
      <path d={d} fill="none" stroke={INK} strokeWidth="10" strokeLinecap="round" />
      <path d={d} fill="none" stroke={LIME} strokeWidth="4.5" strokeLinecap="round" />
      <circle cx={end[0]} cy={end[1]} r="5.5" fill={LIME} stroke={INK} strokeWidth="3" />
    </g>
  );
}

function Mouth({ mood }: { mood: TikoMood }) {
  const line = { fill: "none", stroke: INK, strokeWidth: 3.5, strokeLinecap: "round" as const };
  switch (mood) {
    case "cheer":
    case "giggle":
      return (
        <g>
          <path d="M48 83 Q60 101 72 83 Z" fill={INK} stroke={INK} strokeWidth="3" strokeLinejoin="round" />
          <path d="M53 92 Q60 97 67 92 Q60 89 53 92 Z" fill={ORANGE} />
        </g>
      );
    case "sad":
      return <path d="M51 91 Q60 84 69 91" {...line} />;
    case "think":
      return <path d="M54 89 Q60 87 66 89" {...line} />;
    case "confused":
      return <path d="M49 89 q5.5 -5 11 0 t11 0" {...line} />;
    case "sleep":
      return <ellipse cx="60" cy="88" rx="3.5" ry="4" fill={INK} />;
    default:
      return <path d="M49 84 Q60 95 71 84" {...line} />;
  }
}

function Eyes({ mood }: { mood: TikoMood }) {
  const arc = { fill: "none", stroke: INK, strokeWidth: 3.5, strokeLinecap: "round" as const };
  if (mood === "sleep") {
    return (
      <g>
        <path d="M39 68 Q47 74 55 68" {...arc} />
        <path d="M65 68 Q73 74 81 68" {...arc} />
      </g>
    );
  }
  if (mood === "giggle") {
    // Squeezed-shut happy eyes: ^ ^
    return (
      <g>
        <path d="M39 70 Q47 58 55 70" {...arc} />
        <path d="M65 70 Q73 58 81 70" {...arc} />
      </g>
    );
  }
  // Where the pupils look.
  const look = mood === "think" ? [3, -3] : mood === "sad" ? [0, 3] : mood === "point" ? [3, 0] : [1, 1];
  return (
    <g className="tiko-eyes">
      {[47, 73].map((cx) => (
        <g key={cx}>
          <ellipse cx={cx} cy="66" rx="9.5" ry="11.5" fill="#ffffff" stroke={INK} strokeWidth="3" />
          <circle cx={cx + look[0]} cy={66 + look[1]} r="5" fill={INK} />
          <circle cx={cx + look[0] + 1.8} cy={66 + look[1] - 2} r="1.6" fill="#ffffff" />
        </g>
      ))}
    </g>
  );
}

function Brows({ mood }: { mood: TikoMood }) {
  const brow = { fill: "none", stroke: INK, strokeWidth: 3, strokeLinecap: "round" as const };
  if (mood === "sad")
    return (
      <g>
        <path d="M39 52 L52 49" {...brow} />
        <path d="M68 49 L81 52" {...brow} />
      </g>
    );
  if (mood === "think" || mood === "confused") return <path d="M66 50 Q73 45 81 49" {...brow} />;
  return null;
}

function Drawing({ mood, size, still }: { mood: TikoMood; size: number; still: boolean }) {
  const arms =
    mood === "cheer" || mood === "giggle"
      ? [<Arm key="l" d={ARMS.upL} />, <Arm key="r" d={ARMS.upR} />]
      : mood === "wave"
        ? [<Arm key="l" d={ARMS.downL} />, <Arm key="r" d={ARMS.upR} className="tiko-wave-arm" />]
        : mood === "point"
          ? [<Arm key="l" d={ARMS.downL} />, <Arm key="r" d={ARMS.pointR} />]
          : mood === "think"
            ? [<Arm key="l" d={ARMS.downL} />, <Arm key="r" d={ARMS.chinR} />]
            : [<Arm key="l" d={ARMS.downL} />, <Arm key="r" d={ARMS.downR} />];

  return (
    <svg viewBox="0 0 120 124" width={size} height={(size * 124) / 120} aria-hidden="true" className="block overflow-visible">
      <g className={still ? undefined : IDLE[mood]}>
        {/* Antenna: the stopwatch button. */}
        <g className="tiko-antenna">
          <path d="M60 36 Q57 22 64 12" fill="none" stroke={INK} strokeWidth="3.5" strokeLinecap="round" />
          <circle cx="64" cy="11" r="6.5" fill={ORANGE} stroke={INK} strokeWidth="3" />
        </g>
        {/* Feet, then arms, behind the body. */}
        <ellipse cx="46" cy="109" rx="10" ry="6.5" fill={LIME} stroke={INK} strokeWidth="3" />
        <ellipse cx="74" cy="109" rx="10" ry="6.5" fill={LIME} stroke={INK} strokeWidth="3" />
        {mood !== "think" && arms}
        <ellipse cx="60" cy="71" rx="36" ry="35" fill={LIME} stroke={INK} strokeWidth="3.5" />
        <ellipse cx="45" cy="50" rx="11" ry="6" fill="#ffffff" opacity="0.35" transform="rotate(-25 45 50)" />
        <ellipse cx="34" cy="81" rx="5.5" ry="3.2" fill={ORANGE} opacity={mood === "giggle" ? 0.9 : 0.55} />
        <ellipse cx="86" cy="81" rx="5.5" ry="3.2" fill={ORANGE} opacity={mood === "giggle" ? 0.9 : 0.55} />
        <Eyes mood={mood} />
        <Brows mood={mood} />
        <Mouth mood={mood} />
        {mood === "think" && arms}
      </g>
      {mood === "confused" && (
        <text x="96" y="30" fontSize="26" fontWeight="800" fill={VIOLET} className="tiko-float" fontFamily="sans-serif">
          ?
        </text>
      )}
      {mood === "sleep" && (
        <text x="88" y="34" fontSize="16" fontWeight="800" fill={VIOLET} className="tiko-float" fontFamily="sans-serif">
          z z
        </text>
      )}
    </svg>
  );
}

export type TikoMove = "boing" | "flip" | "giggle" | "droop";

// Physics jumps for a tap: crouch, launch (slowing as it rises), fall
// (speeding up), squash on landing, rebound.
const RISE = "cubic-bezier(0.25, 0.46, 0.45, 0.94)";
const FALL = "cubic-bezier(0.55, 0.085, 0.68, 0.53)";
const MOVES: Record<TikoMove, { frames: Keyframe[]; duration: number }> = {
  boing: {
    duration: 820,
    frames: [
      { transform: "translateY(0) scale(1, 1)", easing: "ease-out" },
      { transform: "translateY(0) scale(1.18, 0.78)", offset: 0.14, easing: RISE },
      { transform: "translateY(-46%) scale(0.9, 1.14)", offset: 0.42, easing: FALL },
      { transform: "translateY(0) scale(0.92, 1.1)", offset: 0.7, easing: "ease-out" },
      { transform: "translateY(0) scale(1.2, 0.8)", offset: 0.8, easing: "ease-out" },
      { transform: "translateY(0) scale(0.96, 1.04)", offset: 0.9 },
      { transform: "translateY(0) scale(1, 1)" },
    ],
  },
  flip: {
    duration: 950,
    frames: [
      { transform: "translateY(0) rotate(0deg) scale(1, 1)", easing: "ease-out" },
      { transform: "translateY(0) rotate(0deg) scale(1.15, 0.82)", offset: 0.12, easing: RISE },
      { transform: "translateY(-52%) rotate(-180deg) scale(1, 1)", offset: 0.42, easing: FALL },
      { transform: "translateY(0) rotate(-360deg) scale(0.94, 1.08)", offset: 0.72, easing: "ease-out" },
      { transform: "translateY(0) rotate(-360deg) scale(1.16, 0.84)", offset: 0.82, easing: "ease-out" },
      { transform: "translateY(0) rotate(-360deg) scale(1, 1)" },
    ],
  },
  // A wrong answer: sag down, shake the head, perk back up.
  droop: {
    duration: 900,
    frames: [
      { transform: "translateY(0) rotate(0deg) scale(1, 1)", easing: "ease-out" },
      { transform: "translateY(6%) rotate(0deg) scale(1.08, 0.88)", offset: 0.25 },
      { transform: "translateY(4%) rotate(-6deg) scale(1.04, 0.92)", offset: 0.45 },
      { transform: "translateY(4%) rotate(6deg) scale(1.04, 0.92)", offset: 0.65 },
      { transform: "translateY(2%) rotate(-2deg) scale(1.02, 0.97)", offset: 0.82 },
      { transform: "translateY(0) rotate(0deg) scale(1, 1)" },
    ],
  },
  giggle: {
    duration: 720,
    frames: [
      { transform: "rotate(0deg) scale(1, 1)" },
      { transform: "rotate(-10deg) scale(1.06, 0.94)", offset: 0.15 },
      { transform: "rotate(9deg) scale(0.96, 1.04)", offset: 0.32 },
      { transform: "rotate(-7deg) scale(1.04, 0.96)", offset: 0.5 },
      { transform: "rotate(5deg) scale(0.98, 1.02)", offset: 0.68 },
      { transform: "rotate(-2deg) scale(1, 1)", offset: 0.85 },
      { transform: "rotate(0deg) scale(1, 1)" },
    ],
  },
};

// Stars that pop out of a tap, each flying a different way.
const SPARKS = [
  { dx: -42, dy: -30, c: "#c8f135" },
  { dx: 40, dy: -34, c: "#ff8a4c" },
  { dx: -30, dy: -58, c: "#a594ff" },
  { dx: 32, dy: -60, c: "#f2f4f8" },
  { dx: 2, dy: -72, c: "#c8f135" },
];

export function Tiko({
  mood = "happy",
  size = 96,
  still = false,
  interactive = true,
  onTap,
  play,
  className = "",
}: {
  mood?: TikoMood;
  size?: number;
  still?: boolean; // no idle motion, for when something else is moving Tiko
  interactive?: boolean; // false inside another button or link
  onTap?: () => void; // after Tiko reacts to a tap, e.g. to say something
  play?: { move: TikoMove; key: number }; // a page asks for a move; a new key plays it again
  className?: string;
}) {
  const body = useRef<HTMLSpanElement>(null);
  const [face, setFace] = useState<TikoMood | null>(null);
  const [burst, setBurst] = useState(0);
  const busy = useRef(false);
  const taps = useRef<number[]>([]);

  function react() {
    if (busy.current) return;
    busy.current = true;
    onTap?.();
    const now = Date.now();
    taps.current = [...taps.current.filter((t) => now - t < 3000), now];
    const dizzy = taps.current.length >= 5;
    if (dizzy) taps.current = [];

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const pick: TikoMove = dizzy ? "flip" : (["boing", "flip", "giggle"] as const)[Math.floor(Math.random() * 3)];
    setFace(dizzy ? "confused" : "giggle");
    if (!reduce) setBurst((n) => n + 1);
    if ("vibrate" in navigator) navigator.vibrate?.(12);

    const done = () => {
      busy.current = false;
      window.setTimeout(() => setFace(null), dizzy ? 900 : 250);
    };
    if (reduce || !body.current) {
      window.setTimeout(done, 600);
      return;
    }
    const move = MOVES[pick];
    body.current.animate(move.frames, { duration: move.duration }).onfinish = done;
  }

  // Moves a page asks for, like a jump for a right answer.
  const playKey = play?.key;
  const playMove = play?.move;
  useEffect(() => {
    if (playKey === undefined || !playMove || !body.current) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const anim = body.current.animate(MOVES[playMove].frames, { duration: MOVES[playMove].duration });
    return () => anim.cancel();
  }, [playKey, playMove]);

  const shown = face ?? mood;
  const inner = (
    <span ref={body} className="relative block origin-bottom">
      <Drawing mood={shown} size={size} still={still || face !== null} />
      {burst > 0 && (
        <span key={burst} aria-hidden="true" className="pointer-events-none absolute inset-x-0 top-[30%] flex justify-center">
          {SPARKS.map((s, i) => (
            <svg
              key={i}
              viewBox="0 0 20 20"
              className="tiko-spark absolute size-3.5"
              style={{ ["--dx" as string]: `${s.dx}px`, ["--dy" as string]: `${s.dy}px`, animationDelay: `${i * 25}ms` }}
            >
              <path d="M10 0 L12.6 7.4 L20 10 L12.6 12.6 L10 20 L7.4 12.6 L0 10 L7.4 7.4 Z" fill={s.c} />
            </svg>
          ))}
        </span>
      )}
    </span>
  );

  if (!interactive) return <span className={`inline-block ${className}`}>{inner}</span>;
  return (
    <button
      type="button"
      onClick={react}
      aria-label="Tiko, the Apticks mascot. Tap to play."
      className={`inline-block cursor-pointer touch-manipulation rounded-2xl select-none [-webkit-tap-highlight-color:transparent] ${className}`}
    >
      {inner}
    </button>
  );
}
