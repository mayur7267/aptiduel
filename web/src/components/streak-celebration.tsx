"use client";

import { useEffect, useRef, useState } from "react";
import { buzz, floorColor, isMilestone, istWeekday, milestoneTitle, nextMilestone, type Celebration } from "@/lib/streak";
import { StreakBlock } from "./streak-block";
import { Tiko, type TikoMood } from "./tiko";

// The Streak Tower moment, full screen. Today's block drops onto your
// tower with a thud and a shake, the number rolls up, a sticker slams in,
// Tiko leaps onto the top and plants a flag, and confetti bursts. Milestones
// (3, 7, 14, 30…) light up the floor and award a badge. A broken streak
// gets its own moment: the tower wobbles, falls, and Tiko starts a new one.
// Everything runs off one clock (like the product film), so it's smooth and
// tap-to-skip lands on the final frame. The iOS app has the same sequence.

const INK = "#0b0e17";
const CONFETTI = ["#c8f135", "#a594ff", "#ff8a4c", "#ffffff", "#7fd3ff"];
const clamp = (v: number, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const seg = (t: number, a: number, b: number) => clamp((t - a) / (b - a));
const lerp = (a: number, b: number, x: number) => a + (b - a) * x;
const E = {
  out: (x: number) => 1 - (1 - x) ** 3,
  inQuad: (x: number) => x * x,
  inOut: (x: number) => (x < 0.5 ? 4 * x ** 3 : 1 - (-2 * x + 2) ** 3 / 2),
  back: (x: number) => 1 + 2.6 * (x - 1) ** 3 + 1.6 * (x - 1) ** 2,
};
// A damped wobble after an impact: 1 at the hit, settling to 0.
const wobble = (tau: number, freq = 13, damp = 7) => (tau < 0 ? 0 : Math.exp(-damp * tau) * Math.cos(freq * tau));
const css = (el: HTMLElement | null, s: Partial<CSSStyleDeclaration>) => el && Object.assign(el.style, s);

type Bit = { x: number; y: number; vx: number; vy: number; r: number; vr: number; w: number; h: number; c: string; round: boolean; born: number };

export function StreakCelebration({
  c,
  onClose,
  onTower,
  onPlay,
}: {
  c: Celebration;
  onClose: () => void;
  onTower: () => void;
  onPlay: () => void;
}) {
  // Only ever mounted in the browser (after the profile loads).
  const [vp] = useState(() => ({ w: window.innerWidth, h: window.innerHeight }));
  const [mood, setMood] = useState<TikoMood>(c.kind === "up" ? "cheer" : "sad");
  const [ready, setReady] = useState(false); // the buttons can be pressed
  const t0 = useRef(0);
  const skip = useRef(false);

  const up = c.kind === "up";
  const peak = up ? c.to : c.from;
  const milestone = up && isMilestone(c.to);
  const END = up ? (milestone ? 4.9 : 3.6) : 3.6;
  const FOOT = up ? (milestone ? 4.3 : 3.0) : 2.9;

  // Layout: the number at the top, the tower above the buttons, Tiko on top.
  const { w: W, h: H } = vp;
  const bw = clamp(W * 0.46, 160, 250);
  const bh = Math.round(bw * 0.34);
  const cx = W / 2;
  const nf = Math.round(clamp(W * 0.22, 84, 150)); // the number's font size
  const numberTop = Math.max(36, H * 0.06);
  const stickerTop = numberTop + nf * 1.02;
  const baseY = H - 178; // the bottom of the tower
  const tikoSize = Math.round(bh * 1.55);
  const room = Math.floor((baseY - (stickerTop + 64 + tikoSize)) / bh);
  const shown = clamp(room, 1, Math.min(peak, 6));
  const days = Array.from({ length: shown }, (_, i) => peak - shown + 1 + i); // bottom → top
  const towerTop = baseY - shown * bh;
  const tikoX = cx + bw * 0.04;
  const tikoY = towerTop - tikoSize * 0.9;

  const root = useRef<HTMLDivElement>(null);
  const iris = useRef<HTMLDivElement>(null);
  const rays = useRef<HTMLDivElement>(null);
  const stage = useRef<HTMLDivElement>(null);
  const blocks = useRef<(HTMLDivElement | null)[]>([]);
  const flashes = useRef<(HTMLDivElement | null)[]>([]);
  const dust = useRef<(HTMLSpanElement | null)[]>([]);
  const numOld = useRef<HTMLSpanElement>(null);
  const numNew = useRef<HTMLSpanElement>(null);
  const numBox = useRef<HTMLDivElement>(null);
  const sticker = useRef<HTMLDivElement>(null);
  const tiko = useRef<HTMLDivElement>(null);
  const pole = useRef<HTMLDivElement>(null);
  const flag = useRef<HTMLDivElement>(null);
  const badge = useRef<HTMLDivElement>(null);
  const foot = useRef<HTMLDivElement>(null);
  const carry = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const sparks = useRef<(HTMLSpanElement | null)[]>([]);

  useEffect(() => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    t0.current = performance.now() - (reduce ? END * 1000 : 0);
    const g = canvas.current?.getContext("2d");
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    if (canvas.current) {
      canvas.current.width = W * dpr;
      canvas.current.height = H * dpr;
    }
    const bits: Bit[] = [];
    const burst = (x: number, y: number, n: number, spread: number, speed: [number, number], at: number) => {
      for (let i = 0; i < n; i++) {
        const a = -Math.PI / 2 + (Math.random() - 0.5) * spread, s = lerp(speed[0], speed[1], Math.random());
        const round = Math.random() < 0.3;
        bits.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, r: Math.random() * 6, vr: (Math.random() - 0.5) * 14,
          w: round ? 9 : 7 + Math.random() * 7, h: round ? 9 : 12 + Math.random() * 10, c: CONFETTI[i % CONFETTI.length], round, born: at });
      }
    };
    const fired = new Set<string>();
    // Haptics and bursts happen once, and not at all when skipped; changes
    // to the screen (always) happen even then.
    const once = (key: string, t: number, at: number, fn: () => void, always = false) => {
      if (t >= at && !fired.has(key)) {
        fired.add(key);
        if (always || (!skip.current && !reduce)) fn();
      }
    };
    // Where each block flies when the tower falls.
    const fall = days.map((_, i) => ({ vx: (Math.random() - 0.5) * 900, vy: -300 - Math.random() * 500, vr: (Math.random() - 0.5) * 9, delay: (shown - 1 - i) * 0.06 }));

    let raf = 0, last = performance.now();
    const frame = (now: number) => {
      const t = Math.min(END + 2, (now - t0.current) / 1000);
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;

      // The backdrop opens as a circle from the middle; flat rays turn behind.
      css(iris.current, { transform: `translate(-50%,-50%) scale(${E.out(seg(t, 0, 0.45))})` });
      css(rays.current, { opacity: String(0.9 * seg(t, 0.3, 1.1)), transform: `translate(-50%,-50%) rotate(${t * 10}deg)` });

      // The screen shakes when the block lands.
      const shakeP = seg(t, 1.25, 1.6), amp = up ? 11 * (1 - shakeP) * (shakeP > 0 && shakeP < 1 ? 1 : 0) : 0;
      // …and the camera punches in on the hit.
      const punch = up ? Math.max(0, wobble(t - 1.25, 9, 5)) * 0.045 : 0;
      css(stage.current, { transform: `translate(${Math.sin(t * 95) * amp}px, ${Math.cos(t * 77) * amp * 0.6}px) scale(${1 + punch})` });

      // Sparkles pop around the new number.
      sparks.current.forEach((el, k) => {
        const p = seg(t, 1.8 + k * 0.05, 2.5 + k * 0.05);
        css(el, { opacity: String(up && p > 0 && p < 1 ? Math.sin(Math.PI * p) : 0), transform: `translate(-50%,-50%) scale(${E.back(Math.min(1, p * 1.6))}) rotate(${p * 90}deg)` });
      });

      days.forEach((_, i) => {
        const el = blocks.current[i];
        const isNew = up && i === shown - 1 && c.to > c.from;
        const finalTop = baseY - (i + 1) * bh;
        if (isNew) {
          // Drops from above the screen and squashes on impact.
          const p = E.inQuad(seg(t, 0.85, 1.25));
          const y = lerp(-finalTop - bh * 2, 0, p);
          const w = wobble(t - 1.25, 16, 7);
          css(el, { transform: `translateY(${y}px) scale(${1 + 0.16 * Math.max(0, w)}, ${1 - 0.24 * Math.max(0, w)})`, opacity: t >= 0.85 ? "1" : "0" });
        } else if (up || t < 1.8) {
          // Old blocks rise into place, then take the hit (or wobble before falling).
          const p = E.back(seg(t, 0.25 + i * 0.07, 0.8 + i * 0.07));
          const hit = up ? Math.max(0, wobble(t - 1.25, 13, 8)) * 5 * (i + 1) / shown : 0;
          const shake = !up ? Math.sin(t * 22 + i) * (i + 1) * 1.6 * seg(t, 0.9, 1.8) : 0;
          css(el, { transform: `translateY(${(1 - p) * (H - finalTop + 40) + hit}px) rotate(${shake}deg)`, opacity: "1" });
        } else {
          // The tower falls: each block flies off, top first.
          const f = fall[i], tau = Math.max(0, t - 1.8 - f.delay);
          css(el, { transform: `translate(${f.vx * tau}px, ${f.vy * tau + 0.5 * 2600 * tau * tau}px) rotate(${f.vr * tau * 57}deg)`, opacity: String(1 - seg(tau, 0.7, 1.1)) });
        }
        // Milestones light the floor, bottom to top.
        const fl = milestone ? Math.sin(Math.PI * seg(t, 3.0 + i * 0.09, 3.3 + i * 0.09)) : 0;
        css(flashes.current[i], { opacity: String(fl * 0.85) });
        if (milestone && fl > 0 && !isNew) css(el, { transform: `${el?.style.transform ?? ""} scale(${1 + 0.06 * fl})` });
      });

      // Dust puffs where the block lands.
      dust.current.forEach((d, k) => {
        const p = seg(t, 1.25, 1.85), side = k % 2 ? 1 : -1, n = Math.floor(k / 2);
        css(d, { opacity: String(up && p > 0 && p < 1 ? (1 - p) * 0.9 : 0), transform: `translate(${side * (bw / 2 + E.out(p) * (30 + n * 22))}px, ${-E.out(p) * (10 + n * 8)}px) scale(${0.4 + E.out(p) * (1 + n * 0.3)})` });
      });

      // The number rolls from yesterday's to today's, then pops.
      if (up) {
        const p = E.back(seg(t, 1.35, 1.85));
        css(numOld.current, { transform: `translateY(${-115 * p}%)`, opacity: String(1 - p) });
        css(numNew.current, { transform: `translateY(${115 * (1 - p)}%)` });
        css(numBox.current, { transform: `scale(${(0.6 + 0.4 * E.back(seg(t, 0.4, 0.9))) * (1 + 0.16 * Math.sin(Math.PI * seg(t, 1.8, 2.15)))})`, opacity: String(seg(t, 0.4, 0.7)) });
      } else {
        css(numBox.current, { transform: `scale(${0.6 + 0.4 * E.back(seg(t, 0.4, 0.9))}) rotate(${-8 * E.out(seg(t, 1.9, 2.2))}deg)`, opacity: String(seg(t, 0.4, 0.7) * (1 - 0.6 * seg(t, 1.9, 2.3))) });
        css(numNew.current, { opacity: "0" });
      }
      // The sticker slams in.
      const sp = E.out(seg(t, up ? 1.75 : 2.15, up ? 2.1 : 2.5));
      css(sticker.current, { opacity: String(sp > 0 ? 1 : 0), transform: `translateX(-50%) scale(${lerp(2.6, 1, sp)}) rotate(${lerp(-18, -4, sp)}deg)` });

      // Tiko leaps onto the top block (or walks in sad and picks up a block).
      if (up) {
        const p = E.inOut(seg(t, 1.95, 2.55)), land = Math.max(0, wobble(t - 2.55, 14, 8));
        const x = lerp(W + 40, tikoX, p), y = lerp(tikoY + 60, tikoY, p) - Math.sin(Math.PI * p) * H * 0.22;
        css(tiko.current, { transform: `translate(${x}px, ${y}px) rotate(${(1 - p) * -25}deg) scale(${1 + 0.12 * land}, ${1 - 0.16 * land})`, opacity: t >= 1.95 ? "1" : "0" });
        css(pole.current, { transform: `scaleY(${E.back(seg(t, 2.55, 2.9))})` });
        css(flag.current, { transform: `scaleX(${E.back(seg(t, 2.8, 3.05))}) skewY(${Math.sin(t * 7) * 5}deg)` });
      } else {
        const p = E.back(seg(t, 2.1, 2.5));
        css(tiko.current, { transform: `translate(${cx - tikoSize / 2}px, ${baseY - tikoSize - 8}px) scale(${p})`, opacity: String(clamp(p * 3)) });
        css(carry.current, { transform: `translate(-50%, 0) scale(${E.back(seg(t, 2.6, 2.9))})` });
      }

      // A milestone's badge flips in over the tower.
      if (milestone) {
        const p = E.back(seg(t, 3.55, 4.15));
        css(badge.current, { opacity: String(seg(t, 3.55, 3.7)), transform: `translate(-50%, -50%) perspective(700px) rotateY(${(1 - p) * 100}deg) scale(${0.6 + 0.4 * p}) translateY(${Math.sin(t * 2.4) * 4}px)` });
        css(stage.current, { opacity: String(1 - 0.55 * seg(t, 3.5, 3.8)) });
      }

      const fp = E.out(seg(t, FOOT, FOOT + 0.45));
      css(foot.current, { opacity: String(fp), transform: `translateY(${(1 - fp) * 30}px)` });

      // Haptics and bursts, each once.
      if (up) {
        once("land", t, 1.25, () => buzz([35, 30, 55]));
        once("roll", t, 1.5, () => buzz(10));
        once("slam", t, 1.8, () => buzz(22));
        once("tiko", t, 2.55, () => buzz(14));
        once("confetti", t, 2.6, () => burst(tikoX + tikoSize / 2, towerTop, 110, 2.4, [700, 1400], t));
        if (milestone) {
          for (let i = 0; i < shown; i++) once(`floor${i}`, t, 3.0 + i * 0.09, () => buzz(12));
          once("badge", t, 3.9, () => {
            buzz([20, 40, 20, 40, 70]);
            burst(cx, H * 0.42, 160, Math.PI * 2, [500, 1300], t);
          });
        }
      } else {
        once("fall", t, 1.8, () => buzz([45, 30, 45, 30, 90]));
        once("mood", t, 2.6, () => setMood("happy"), true);
      }
      once("ready", t, FOOT + 0.2, () => setReady(true), true);

      // Confetti: gravity, drag, spin.
      if (g) {
        g.setTransform(dpr, 0, 0, dpr, 0, 0);
        g.clearRect(0, 0, W, H);
        for (const b of bits) {
          b.vy += 1700 * dt;
          b.vx *= 1 - 1.4 * dt;
          b.vy *= 1 - 0.6 * dt;
          b.x += b.vx * dt;
          b.y += b.vy * dt;
          b.r += b.vr * dt;
          const life = t - b.born;
          g.globalAlpha = clamp(1 - (life - 1.8) / 0.8);
          g.save();
          g.translate(b.x, b.y);
          g.rotate(b.r);
          g.fillStyle = b.c;
          if (b.round) {
            g.beginPath();
            g.arc(0, 0, b.w / 2, 0, Math.PI * 2);
            g.fill();
          } else {
            g.scale(1, Math.cos(b.r * 1.7)); // flutter
            g.fillRect(-b.w / 2, -b.h / 2, b.w, b.h);
          }
          g.restore();
        }
      }
      if (t < END + 2) raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
    // One run per mount: the layout is fixed when it starts.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Esc closes; any tap before the end skips to it.
  useEffect(() => {
    const key = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, [onClose]);

  function skipToEnd() {
    if ((performance.now() - t0.current) / 1000 < END) {
      skip.current = true;
      t0.current = performance.now() - END * 1000;
    }
  }

  const next = up ? nextMilestone(c.to) : null;
  const words = !up
    ? { title: `Your ${c.from}-day tower fell`, sub: "One duel starts a new one. Tiko's already stacking." }
    : milestone
      ? { title: `${c.to}-day streak!`, sub: next ? `Badge unlocked. The next one is at ${next} days. Come back tomorrow for day ${c.to + 1}.` : "The tallest tower on Apticks. Keep stacking." }
      : c.to === 1
        ? { title: c.fresh && c.from === 0 ? "A new tower begins!" : "Day 1 of your tower!", sub: "Play tomorrow to stack day 2 on top." }
        : { title: `${c.to}-day streak!`, sub: `Come back tomorrow to make it ${c.to + 1}.` };

  return (
    <div ref={root} role="dialog" aria-modal="true" aria-label={words.title} onClick={skipToEnd} className="fixed inset-0 z-[100] overflow-hidden select-none">
      <div ref={iris} className="absolute top-1/2 left-1/2 rounded-full" style={{ width: Math.hypot(W, H) * 2.1, height: Math.hypot(W, H) * 2.1, background: INK, transform: "translate(-50%,-50%) scale(0)" }} />
      <div ref={rays} aria-hidden="true" className="absolute" style={{ left: cx, top: towerTop, width: Math.hypot(W, H) * 2, height: Math.hypot(W, H) * 2, opacity: 0 }}>
        <svg viewBox="-100 -100 200 200" width="100%" height="100%">
          {Array.from({ length: 18 }, (_, i) => {
            const a0 = (i * 20 * Math.PI) / 180, a1 = ((i * 20 + 10) * Math.PI) / 180;
            return <path key={i} d={`M0 0 L${100 * Math.cos(a0)} ${100 * Math.sin(a0)} L${100 * Math.cos(a1)} ${100 * Math.sin(a1)} Z`} fill={up ? "#c8f135" : "#a594ff"} opacity="0.07" />;
          })}
        </svg>
      </div>

      <div ref={stage} className="absolute inset-0">
        {/* The number, rolling from yesterday's to today's. */}
        <div ref={numBox} className="absolute left-0 right-0 flex justify-center" style={{ top: numberTop, opacity: 0 }}>
          <div className="relative overflow-hidden font-display font-bold leading-none tracking-tight text-white" style={{ fontSize: nf, height: nf * 1.02, minWidth: nf * 0.7 * String(peak).length }}>
            <span ref={numOld} className="absolute inset-x-0 top-0 text-center">
              {up ? c.from : c.from}
            </span>
            <span ref={numNew} className="absolute inset-x-0 top-0 text-center text-lime" style={{ transform: "translateY(115%)" }}>
              {up ? c.to : 0}
            </span>
          </div>
        </div>
        {[[-0.62, 0.18], [0.66, 0.08], [-0.45, 0.86], [0.52, 0.92], [0.02, -0.12], [0.86, 0.5]].map(([dx, dy], k) => (
          <span
            key={k}
            ref={(el) => { sparks.current[k] = el; }}
            aria-hidden="true"
            className="absolute"
            style={{ left: cx + dx * nf * 1.1, top: numberTop + dy * nf, width: nf * 0.26, height: nf * 0.26, opacity: 0 }}
          >
            <svg viewBox="-10 -10 20 20" width="100%" height="100%">
              <path d="M0 -10 C1 -2 2 -1 10 0 C2 1 1 2 0 10 C-1 2 -2 1 -10 0 C-2 -1 -1 -2 0 -10Z" fill={["#c8f135", "#ff8a4c", "#a594ff", "#ffffff", "#7fd3ff", "#c8f135"][k]} stroke="#0b0e17" strokeWidth="1.4" />
            </svg>
          </span>
        ))}
        <div ref={sticker} className="absolute left-1/2 rounded-2xl border-4 border-ink px-5 py-2 font-display text-[clamp(18px,4.8vw,28px)] font-bold whitespace-nowrap text-ink" style={{ top: stickerTop, background: up ? "#ff8a4c" : "#a594ff", boxShadow: "6px 7px 0 #000", opacity: 0 }}>
          {up ? (c.to === 1 ? "🔥 DAY 1!" : "🔥 DAY STREAK!") : "💥 TOWER DOWN"}
        </div>

        {/* The tower. */}
        {days.map((d, i) => (
          <div key={d} ref={(el) => { blocks.current[i] = el; }} className="absolute" style={{ left: cx - bw / 2, top: baseY - (i + 1) * bh, transformOrigin: "50% 100%", opacity: 0, zIndex: i }}>
            <StreakBlock day={d} weekday={istWeekday(peak - d + (up ? 0 : 1))} width={bw} height={bh} />
            <div ref={(el) => { flashes.current[i] = el; }} className="pointer-events-none absolute inset-0 rounded-[14px] bg-white" style={{ opacity: 0 }} />
          </div>
        ))}
        {Array.from({ length: 6 }, (_, k) => (
          <span key={k} ref={(el) => { dust.current[k] = el; }} aria-hidden="true" className="absolute rounded-full bg-[#e7e2d4]" style={{ left: cx - 9, top: towerTop - 6, width: 18, height: 18, opacity: 0 }} />
        ))}

        {/* The flag, planted on the top block. */}
        {up && (
          <div className="absolute" style={{ left: cx - bw * 0.32, top: towerTop - bh * 1.75, width: bh * 1.1, height: bh * 1.75 }}>
            <div ref={pole} className="absolute bottom-0 left-0 w-[5px] rounded-full bg-white" style={{ height: "100%", transformOrigin: "50% 100%", transform: "scaleY(0)" }} />
            <div ref={flag} className="absolute top-0 left-[5px] flex items-center justify-center border-[3px] border-ink font-display font-bold text-ink" style={{ width: bh * 1.05, height: bh * 0.62, fontSize: bh * 0.34, background: "#ff8a4c", transformOrigin: "0% 50%", transform: "scaleX(0)" }}>
              {c.to}
            </div>
          </div>
        )}

        {/* Tiko. */}
        <div ref={tiko} className="absolute top-0 left-0" style={{ width: tikoSize, height: tikoSize, opacity: 0, transformOrigin: "50% 100%", zIndex: 20 }}>
          <Tiko mood={mood} size={tikoSize} still interactive={false} />
          {!up && (
            <div ref={carry} className="absolute left-1/2" style={{ top: -bh * 0.75, transform: "translate(-50%,0) scale(0)" }}>
              <StreakBlock day={1} weekday={istWeekday(-1)} width={bw * 0.55} height={bh * 0.55} />
            </div>
          )}
        </div>
      </div>

      {/* A milestone's badge. */}
      {milestone && (
        <div ref={badge} className="absolute top-[42%] left-1/2 flex flex-col items-center gap-3" style={{ opacity: 0, zIndex: 30 }}>
          <div className="flex size-[168px] flex-col items-center justify-center rounded-full border-[6px] border-ink text-ink" style={{ background: floorColor(c.to), boxShadow: "10px 12px 0 #000" }}>
            <span className="font-display text-[64px] leading-none font-bold">{c.to}</span>
            <span className="font-mono text-[13px] font-bold tracking-[0.18em]">DAYS</span>
          </div>
          <span className="rounded-xl border-4 border-ink bg-white px-4 py-1.5 font-display text-lg font-bold whitespace-nowrap text-ink" style={{ boxShadow: "6px 7px 0 #000" }}>
            {milestoneTitle(c.to)}
          </span>
        </div>
      )}

      <canvas ref={canvas} aria-hidden="true" className="pointer-events-none absolute inset-0" style={{ width: W, height: H, zIndex: 40 }} />

      {/* The words and the buttons. */}
      <div ref={foot} className="absolute inset-x-0 bottom-0 flex flex-col items-center gap-4 px-6 pb-[max(28px,env(safe-area-inset-bottom))]" style={{ opacity: 0, zIndex: 50, pointerEvents: ready ? "auto" : "none" }}>
        <div className="flex flex-col items-center gap-1 text-center">
          <span className="font-display text-[22px] font-bold text-white">{words.title}</span>
          <span className="max-w-[420px] text-[15px] text-muted">{words.sub}</span>
        </div>
        <div className="flex w-full max-w-[420px] gap-3">
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); if (up) onClose(); else onPlay(); }}
            className="pressable flex h-14 flex-1 items-center justify-center rounded-2xl bg-lime text-[17px] font-bold text-ink [--pop:#5f7710]"
          >
            {up ? "Keep going" : "Play a duel"}
          </button>
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); if (up) onTower(); else onClose(); }}
            className="flex h-14 flex-1 items-center justify-center rounded-2xl border border-line bg-surface text-[16px] font-semibold text-text"
          >
            {up ? "See your tower" : "Not now"}
          </button>
        </div>
      </div>
    </div>
  );
}
