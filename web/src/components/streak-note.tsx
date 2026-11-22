"use client";

import { useEffect, useRef } from "react";
import { buzz, homeNoteText } from "@/lib/streak";
import { Tiko } from "./tiko";

// Back on Home after the day's first duel: Tiko drops onto the streak
// chip with a bounce and a short note ("Day 5 done! 🔥"), then leaves after
// a few seconds or a tap. Sits inside the chip's wrapper (position: relative).
export function StreakNote({ day, onDone }: { day: number; onDone: () => void }) {
  const tiko = useRef<HTMLDivElement>(null);
  const bubble = useRef<HTMLDivElement>(null);
  const { title, sub } = homeNoteText(day);

  useEffect(() => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const ms = (n: number) => (reduce ? 1 : n);
    tiko.current?.animate(
      [
        { transform: "translateY(-90px) scale(0.6)", opacity: 0 },
        { transform: "translateY(0) scale(1.18, 0.82)", opacity: 1, offset: 0.55 },
        { transform: "translateY(-12px) scale(0.94, 1.06)", offset: 0.78 },
        { transform: "translateY(0) scale(1)", opacity: 1 },
      ],
      { duration: ms(700), delay: ms(250), easing: "cubic-bezier(0.3, 0, 0.3, 1)", fill: "both" },
    );
    bubble.current?.animate(
      [
        { opacity: 0, transform: "translateY(-8px) scale(0.85)" },
        { opacity: 1, transform: "translateY(0) scale(1)" },
      ],
      { duration: ms(380), delay: ms(800), easing: "cubic-bezier(0.34, 1.56, 0.64, 1)", fill: "both" },
    );
    const land = window.setTimeout(() => buzz(12), ms(640));
    const leave = window.setTimeout(() => {
      const opts = { duration: ms(300), fill: "both" as const, easing: "ease-in" };
      tiko.current?.animate([{ opacity: 1 }, { opacity: 0, transform: "translateY(-30px) scale(0.8)" }], opts);
      bubble.current?.animate([{ opacity: 1 }, { opacity: 0, transform: "translateY(-6px)" }], opts).finished.then(onDone, onDone);
    }, 6000);
    return () => {
      window.clearTimeout(land);
      window.clearTimeout(leave);
    };
    // Plays once when it appears.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      <div ref={tiko} aria-hidden="true" className="pointer-events-none absolute bottom-[42%] -left-4 z-30" style={{ opacity: 0, transformOrigin: "50% 100%" }}>
        <Tiko mood="cheer" size={40} still interactive={false} />
      </div>
      <div
        ref={bubble}
        role="status"
        onClick={onDone}
        className="absolute top-[calc(100%+12px)] right-0 z-30 w-[236px] cursor-pointer rounded-2xl border-[3px] border-ink bg-white px-3.5 py-2.5 text-ink"
        style={{ opacity: 0, boxShadow: "5px 6px 0 #000" }}
      >
        <span aria-hidden="true" className="absolute -top-[10px] right-7 size-4 rotate-45 border-t-[3px] border-l-[3px] border-ink bg-white" />
        <div className="font-display text-[15px] font-bold">{title}</div>
        <div className="text-[13px] leading-snug text-ink/70">{sub}</div>
      </div>
    </>
  );
}
