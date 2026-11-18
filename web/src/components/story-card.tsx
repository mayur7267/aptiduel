"use client";

import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { siteUrl } from "@/lib/format";
import { Picture } from "./icons";
import { Tiko } from "./tiko";

// A 9:16 picture of your result for an Instagram Story or WhatsApp Status.
//
// It's drawn as soon as the result opens, not when you tap: iPhones only
// open the share sheet straight after a tap, and drawing first would miss
// that moment. Phones that can share pictures get the share sheet;
// laptops download it. Nobody can tap a story picture, so the address is
// printed big, and your link is copied for Instagram's Link sticker.

export type StoryData = {
  chip: string; // "DAILY · 14 NOV", "QUICK MATCH"
  headline: string; // "I won!", "Today's Daily"
  correct: number;
  score: number;
  time: string; // "0:42"
  grid: boolean[];
  extra: string | null; // "Beat Mayur by 149 points", "#3 of 40 today"
};

const W = 1080;
const H = 1920;
const INK = "#0b0e17";
const LIME = "#c8f135";
const LIME_INK = "#2a3410";
const LIME_DARK = "#5f7710";
const TEXT = "#f2f4f8";
const MUTED = "#a6aec0";
const RED = "#ff6b7a";
const GRID = "#151a26";

// The logo mark, with plain colours so it draws outside the page.
const MARK = `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><rect x="26" y="5" width="12" height="6" rx="2.5" fill="${TEXT}"/><rect x="30" y="10" width="4" height="6" fill="${TEXT}"/><circle cx="32" cy="37.5" r="21.5" fill="${LIME}"/><path d="M35.66 16.31L27.5 35.5L37 35.5L28.45 58.71A21.5 21.5 0 0 0 35.66 16.31Z" fill="#ff8a4c"/><path d="M35.66 16.31L27.5 35.5L37 35.5L28.45 58.71" fill="none" stroke="${INK}" stroke-width="3.4"/></svg>`;

const noSubscribe = () => () => {};

// A small button that sits beside the WhatsApp one. `onShare` hears
// "share" when the share sheet opened (so the page can say the link was
// copied for the Link sticker) and "download" on a laptop.
export function StoryButton({
  data,
  onShare,
}: {
  data: StoryData;
  onShare: (channel: "share" | "download") => void;
}) {
  const tikoRef = useRef<HTMLDivElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  // false on the server, real value after hydration
  const touch = useSyncExternalStore(noSubscribe, () => window.matchMedia("(pointer: coarse)").matches, () => false);
  const key = JSON.stringify(data);

  useEffect(() => {
    let active = true;
    let url: string | null = null;
    const svg = tikoRef.current?.querySelector("svg");
    draw(JSON.parse(key) as StoryData, svg ?? null)
      .then((blob) => {
        if (!active) return;
        url = URL.createObjectURL(blob);
        setFile(new File([blob], "apticks-result.png", { type: "image/png" }));
        setPreview(url);
      })
      .catch(() => active && setFailed(true));
    return () => {
      active = false;
      if (url) URL.revokeObjectURL(url);
    };
  }, [key]);

  function share() {
    if (!file) return;
    // For Instagram's Link sticker. Copied first: once the share sheet is
    // open, the page loses focus and the clipboard refuses.
    navigator.clipboard?.writeText(siteUrl("/?via=story")).catch(() => {});
    if (touch && navigator.canShare?.({ files: [file] })) {
      onShare("share");
      navigator.share({ files: [file] }).catch(() => {});
      return;
    }
    onShare("download");
    const a = document.createElement("a");
    a.href = preview ?? URL.createObjectURL(file);
    a.download = file.name;
    a.click();
  }

  if (failed) return null;

  return (
    <>
      {/* The drawing of Tiko the card uses, kept out of sight. */}
      <div ref={tikoRef} aria-hidden="true" className="hidden">
        <Tiko mood="cheer" size={120} still interactive={false} />
      </div>
      <button
        onClick={share}
        disabled={!file}
        aria-label={touch ? "Share a story picture of your score" : "Download a story picture of your score"}
        className="flex h-14 shrink-0 items-center justify-center gap-2 rounded-2xl border border-line bg-surface px-3.5 text-[15px] font-semibold whitespace-nowrap hover:bg-raised disabled:opacity-60"
      >
        <Picture size={18} strokeWidth={2.2} className="shrink-0 text-violet-soft" />
        Story picture
      </button>
    </>
  );
}

function fontVar(name: string, fallback: string) {
  const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return v || fallback;
}

function loadImage(svg: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
  });
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

// Shrinks text until it fits the width.
function fit(ctx: CanvasRenderingContext2D, text: string, font: (px: number) => string, px: number, width: number) {
  let size = px;
  ctx.font = font(size);
  while (size > 24 && ctx.measureText(text).width > width) {
    size -= 4;
    ctx.font = font(size);
  }
  return size;
}

async function draw(d: StoryData, tikoSvg: SVGSVGElement | null): Promise<Blob> {
  const display = fontVar("--font-unbounded", "sans-serif");
  const sans = fontVar("--font-inter", "sans-serif");
  const mono = fontVar("--font-jetbrains", "monospace");
  await Promise.all([
    document.fonts.load(`700 80px ${display}`),
    document.fonts.load(`600 40px ${sans}`),
    document.fonts.load(`700 40px ${mono}`),
  ]).catch(() => {});

  const canvas = document.createElement("canvas");
  canvas.width = W;
  canvas.height = H;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("No canvas");

  // Background: the site's dark grid.
  ctx.fillStyle = INK;
  ctx.fillRect(0, 0, W, H);
  ctx.strokeStyle = GRID;
  ctx.lineWidth = 2;
  for (let x = 90; x < W; x += 90) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, H);
    ctx.stroke();
  }
  for (let y = 90; y < H; y += 90) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(W, y);
    ctx.stroke();
  }

  // Logo.
  const mark = await loadImage(MARK);
  // Instagram covers about the top and bottom 250 px with its own bars,
  // so everything sits between.
  ctx.drawImage(mark, 96, 262, 104, 104);
  ctx.textBaseline = "middle";
  ctx.font = `700 72px ${display}`;
  ctx.fillStyle = TEXT;
  ctx.fillText("Ap", 220, 316);
  ctx.fillStyle = LIME;
  ctx.fillText("ticks", 220 + ctx.measureText("Ap").width, 316);

  // The lime card, raised like a sticker.
  const cx = 80;
  const cy = 430;
  const cw = W - 160;
  const ch = 880;
  ctx.fillStyle = LIME_DARK;
  roundRect(ctx, cx + 16, cy + 16, cw, ch, 60);
  ctx.fill();
  ctx.fillStyle = LIME;
  roundRect(ctx, cx, cy, cw, ch, 60);
  ctx.fill();

  // Chip.
  ctx.save();
  ctx.translate(cx + 64, cy + 74);
  ctx.rotate((-3 * Math.PI) / 180);
  ctx.font = `700 34px ${mono}`;
  const chipW = ctx.measureText(d.chip).width + 44;
  ctx.fillStyle = INK;
  roundRect(ctx, 0, -32, chipW, 64, 12);
  ctx.fill();
  ctx.fillStyle = LIME;
  ctx.fillText(d.chip, 22, 2);
  ctx.restore();

  // Headline and the big score.
  ctx.fillStyle = INK;
  ctx.textAlign = "left";
  fit(ctx, d.headline, (px) => `700 ${px}px ${display}`, 92, cw - 128);
  ctx.fillText(d.headline, cx + 64, cy + 192);

  ctx.font = `700 270px ${display}`;
  ctx.fillText(`${d.correct}/5`, cx + 56, cy + 392);

  ctx.font = `700 50px ${mono}`;
  ctx.fillStyle = LIME_INK;
  ctx.fillText(`${d.time} · ${d.score} pts`, cx + 64, cy + 556);

  // Right or wrong, question by question.
  const size = 116;
  const gap = 22;
  d.grid.slice(0, 5).forEach((ok, i) => {
    const x = cx + 64 + i * (size + gap);
    const y = cy + 618;
    ctx.fillStyle = ok ? INK : RED;
    roundRect(ctx, x, y, size, size, 26);
    ctx.fill();
    ctx.strokeStyle = ok ? LIME : INK;
    ctx.lineWidth = 12;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.beginPath();
    if (ok) {
      ctx.moveTo(x + 32, y + 60);
      ctx.lineTo(x + 52, y + 80);
      ctx.lineTo(x + 86, y + 38);
    } else {
      ctx.moveTo(x + 38, y + 38);
      ctx.lineTo(x + 78, y + 78);
      ctx.moveTo(x + 78, y + 38);
      ctx.lineTo(x + 38, y + 78);
    }
    ctx.stroke();
  });

  if (d.extra) {
    ctx.fillStyle = INK;
    fit(ctx, d.extra, (px) => `600 ${px}px ${sans}`, 46, cw - 128 - 230);
    ctx.fillText(d.extra, cx + 64, cy + 808);
  }

  // Tiko, cheering on the card's corner.
  if (tikoSvg) {
    const clone = tikoSvg.cloneNode(true) as SVGSVGElement;
    // Room for arms that reach past the drawing's edge.
    clone.setAttribute("viewBox", "-16 -16 152 156");
    clone.setAttribute("width", "320");
    clone.setAttribute("height", "328");
    clone.removeAttribute("class");
    const tiko = await loadImage(new XMLSerializer().serializeToString(clone)).catch(() => null);
    if (tiko) ctx.drawImage(tiko, W - 380, cy + ch - 250, 320, 328);
  }

  // The ask, and where to go.
  ctx.textAlign = "center";
  ctx.fillStyle = TEXT;
  fit(ctx, "Can you beat me?", (px) => `700 ${px}px ${display}`, 92, W - 160);
  ctx.fillText("Can you beat me?", W / 2, 1418);

  ctx.font = `700 76px ${display}`;
  const site = "playapticks.in";
  const sw = ctx.measureText(site).width + 96;
  ctx.strokeStyle = LIME;
  ctx.lineWidth = 6;
  roundRect(ctx, (W - sw) / 2, 1478, sw, 124, 62);
  ctx.stroke();
  ctx.fillStyle = LIME;
  ctx.fillText(site, W / 2, 1542);

  ctx.font = `600 38px ${sans}`;
  ctx.fillStyle = MUTED;
  ctx.fillText("5 placement-style questions · 3 minutes · free", W / 2, 1652);

  return new Promise<Blob>((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error("No picture"))), "image/png"),
  );
}
