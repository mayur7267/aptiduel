// Composes the App Store preview video's frames: captions, stickers and the
// real screen recording (already cut into frames by frames.swift) inside a
// phone.
//
//   node compose-preview.mjs <screen frames dir> <output frames dir> '<scenes json>' [WxH]
//
//   WxH is 1200x1600 by default (iPad 13" portrait) or 886x1920 (the iPhone
//   6.1"/6.3" preview size).
//
// scenes (seconds from the first frame): quick = Quick Match tapped, q1 = the
// first question appears, result = the result screen appears.
// Then encode.swift turns the output frames into the .mp4.

import { chromium } from "playwright";
import { mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const [framesDir, outDir] = process.argv.slice(2, 4).map((p) => resolve(p));
const scenes = JSON.parse(process.argv[4] ?? "{}");
const frames = readdirSync(framesDir).filter((f) => f.endsWith(".png")).sort();
mkdirSync(outDir, { recursive: true });
const work = mkdtempSync(join(tmpdir(), "apticks-preview-"));

const [W, H] = (process.argv[5] ?? "1200x1600").split("x").map(Number);
const FPS = 30;
const INK = "#0b0e17";
const LIME = "#c8f135";
const ORANGE = "#ff8a4c";

// A tall canvas (iPhone) gives the phone more room than the squarer iPad one.
const TALL = H / W > 1.7;
const bezel = 16;
const pw = TALL ? 685 : 548; // the phone's width; its screen is 1320 x 2868
const phoneTop = TALL ? 420 : 432;
const headTop = TALL ? 78 : 64;
const headMax = TALL ? 96 : 104;
const subSize = TALL ? 30 : 34;
const chipTop = TALL ? 372 : 392;
const chipFont = TALL ? 28 : 32;
const radius = TALL ? 100 : 92;
const screenH = Math.round((pw - bezel * 2) * (2868 / 1320));
const island = TALL ? { w: 176, h: 52, top: 20 } : { w: 160, h: 48, top: 18 };

const heads = [
  { l1: "APTITUDE PREP", l2: "THAT'S A GAME", sub: "Duel friends. Climb your college." },
  { l1: "LIVE 1V1", l2: "APTITUDE DUELS", sub: "5 questions. 3 minutes. Fastest wins." },
  { l1: "WIN. RANK UP.", l2: "REPEAT.", sub: "A live rating shows how ready you are." },
];

const html = `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@600&family=Unbounded:wght@900&display=swap" rel="stylesheet">
<style>
  *{box-sizing:border-box}
  html,body{margin:0;width:${W}px;height:${H}px;overflow:hidden;background:${INK}}
  .stage{position:relative;width:${W}px;height:${H}px;overflow:hidden;background:${INK}}
  .grid{position:absolute;inset:0;background-image:linear-gradient(rgba(255,255,255,0.05) 2px,transparent 2px),linear-gradient(90deg,rgba(255,255,255,0.05) 2px,transparent 2px);background-size:80px 80px}
  .glow{position:absolute;width:1500px;height:1500px;left:${(W - 1500) / 2}px;top:${phoneTop - 2}px;border-radius:50%;background:radial-gradient(closest-side,rgba(200,241,53,0.20),transparent)}
  .head{position:absolute;left:0;right:0;top:${headTop}px;text-align:center;padding:0 ${TALL ? 36 : 50}px}
  .l1,.l2{font-family:'Unbounded',sans-serif;font-weight:900;line-height:1.05;letter-spacing:-0.012em;word-spacing:0.14em;white-space:nowrap}
  .l1{color:#fff}.l2{color:${LIME}}
  .sub{margin-top:20px;font:600 ${subSize}px/1.2 'Inter',sans-serif;color:rgba(255,255,255,0.72)}
  .phone{position:absolute;left:${(W - pw) / 2}px;top:${phoneTop}px;width:${pw}px;filter:drop-shadow(0 40px 50px rgba(0,0,0,0.6))}
  .body{padding:${bezel}px;border-radius:${radius}px;background:linear-gradient(150deg,#4a5267,#161b28 40%,#0a0d14);box-shadow:inset 0 0 0 2px rgba(255,255,255,0.14)}
  .screen{position:relative;overflow:hidden;border-radius:${radius - bezel}px;background:#000;height:${screenH}px}
  .screen img{display:block;width:100%}
  .island{position:absolute;top:${island.top}px;left:50%;width:${island.w}px;height:${island.h}px;margin-left:-${island.w / 2}px;border-radius:${island.h / 2}px;background:#000}
  .chip{position:absolute;z-index:5;display:flex;align-items:center;gap:12px;padding:18px 28px;border-radius:24px;font-family:'Unbounded',sans-serif;font-weight:900;font-size:${chipFont}px;letter-spacing:-0.01em;white-space:nowrap;box-shadow:8px 10px 0 rgba(0,0,0,0.38);opacity:0}
  #speed{background:${ORANGE};color:${INK};right:${TALL ? 30 : 46}px;top:${chipTop}px}
  #rating{background:${LIME};color:${INK};right:${TALL ? 30 : 46}px;top:${chipTop}px}
  .chip svg{width:1em;height:1em;flex:none}
</style></head><body><div class="stage">
  <div class="grid"></div><div class="glow"></div>
  ${heads.map((h, i) => `<div class="head" id="h${i}" style="opacity:${i === 0 ? 1 : 0}"><div class="l1" data-fit>${h.l1}</div><div class="l2" data-fit>${h.l2}</div><div class="sub">${h.sub}</div></div>`).join("")}
  <div class="phone" id="phone"><div class="body"><div class="screen"><img id="shot"><div class="island"></div></div></div></div>
  <div class="chip" id="speed"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 4 14h7l-1 8 9-12h-7z"/></svg>SPEED BONUS +50</div>
  <div class="chip" id="rating"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 4 14h7l-1 8 9-12h-7z"/></svg>+16 RATING</div>
</div>
<script>
  const S = ${JSON.stringify({ quick: 4, q1: 5, result: 20, ...scenes })};
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  const smooth = (v) => { v = clamp(v); return v * v * (3 - 2 * v); };
  const backOut = (v) => { v = clamp(v); const c = 1.70158; return 1 + (c + 1) * Math.pow(v - 1, 3) + c * Math.pow(v - 1, 2); };
  const $ = (id) => document.getElementById(id);
  const b1 = S.quick + 0.5, b2 = S.result - 0.3;
  document.fonts.ready.then(() => {
    document.querySelectorAll('[data-fit]').forEach((el) => {
      let size = ${headMax}; el.style.fontSize = size + 'px';
      while (el.scrollWidth > ${W - (TALL ? 72 : 100)} && size > 40) { size -= 2; el.style.fontSize = size + 'px'; }
    });
    document.body.dataset.ready = '1';
  });
  // Draws the moment t (seconds) with the given screen frame.
  window.draw = async (src, t) => {
    const img = $('shot'); img.src = src; await img.decode();
    $('h0').style.opacity = 1 - smooth((t - b1) / 0.5);
    $('h1').style.opacity = smooth((t - b1) / 0.5) * (1 - smooth((t - b2) / 0.5));
    $('h2').style.opacity = smooth((t - b2) / 0.5);
    // the two stickers pop in, and the first leaves when the result arrives
    const sp = backOut((t - (S.q1 + 0.9)) / 0.45), spOut = 1 - smooth((t - (S.result - 0.5)) / 0.3);
    $('speed').style.opacity = clamp(sp) * spOut; $('speed').style.transform = 'rotate(6deg) scale(' + (0.6 + 0.4 * clamp(sp, 0, 1.15)) + ')';
    const rp = backOut((t - (S.result + 0.6)) / 0.45);
    $('rating').style.opacity = clamp(rp); $('rating').style.transform = 'rotate(6deg) scale(' + (0.6 + 0.4 * clamp(rp, 0, 1.15)) + ')';
    // a slow float, so the phone is never dead still
    $('phone').style.transform = 'translateY(' + (Math.sin(t * 1.3) * 5) + 'px) rotate(' + (Math.sin(t * 0.9) * 0.5) + 'deg)';
  };
</script></body></html>`;

const file = join(work, "preview.html");
writeFileSync(file, html);
const browser = await chromium.launch();
const page = await (await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1 })).newPage();
await page.goto(`file://${file}`, { waitUntil: "networkidle" });
await page.waitForSelector("body[data-ready='1']");
for (let i = 0; i < frames.length; i++) {
  await page.evaluate(([src, t]) => window.draw(src, t), [`file://${join(framesDir, frames[i])}`, i / FPS]);
  await page.screenshot({ path: join(outDir, `frame-${String(i).padStart(5, "0")}.png`), clip: { x: 0, y: 0, width: W, height: H } });
  if (i % 100 === 0) console.log(`frame ${i} / ${frames.length}`);
}
await browser.close();
rmSync(work, { recursive: true, force: true });
console.log(`composed ${frames.length} frames`);
