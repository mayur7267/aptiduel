// Builds the App Store screenshots: a headline, the real app screen in a
// phone, and a sticker or two.
//
//   node compose.mjs <raw screens dir> <output dir> [--device iphone|ipad|wide] [--canvas WxH] [--width N]
//
//   iPhone (default)  as large as the raw screens themselves, which is an
//                     Apple size when they come from an iPhone simulator:
//                     1320 x 2868 from a Pro Max (the 6.9" slot).
//   --canvas 1242x2688  an iPhone canvas of another Apple size (6.5" here),
//                     recomposed rather than squashed.
//   --width 2160      the same layout rendered larger, for a 4K master. App
//                     Store Connect rejects anything but its own sizes, so
//                     the masters are for the website and social, not upload.
//   --device ipad     the 13" iPad size, 2064 x 2752 (only usable once the
//                     app runs natively on iPad).
//   --device wide     a 16:9 landscape set, 5244 x 2950 (a size some App Store
//                     Connect upload screens list; Apple's public docs don't).
//
// The raw screens come from ApticksUITests/StoreShotsUITests (see
// README.md). Needs Playwright (npm i playwright) and a network
// connection, for the Google Fonts the website uses too.

import { chromium } from "playwright";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const positional = [];
const flags = {};
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i].startsWith("--")) flags[process.argv[i].slice(2)] = process.argv[++i];
  else positional.push(resolve(process.argv[i]));
}
const [rawDir, outDir] = positional;
if (!rawDir || !outDir) {
  console.error("usage: node compose.mjs <raw screens dir> <output dir> [--device iphone|ipad|wide] [--canvas WxH] [--width N]");
  process.exit(1);
}
mkdirSync(outDir, { recursive: true });
const work = mkdtempSync(join(tmpdir(), "apticks-shots-")); // the pages are scratch, not output

// The raw screen's own size, from the PNG header.
const header = readFileSync(join(rawDir, "01-home.png"));
const RAW_W = header.readUInt32BE(16);
const RAW_H = header.readUInt32BE(20);

// The layout is drawn in CSS pixels and then rendered at SCALE. An iPhone
// canvas is the raw screen's pixel size; the 13" iPad canvas is 1290 x 1720,
// which at 1.6x is 2064 x 2752.
const IPAD = flags.device === "ipad";
const WIDE = flags.device === "wide";
const CANVAS = flags.canvas ? flags.canvas.split("x").map(Number) : null;
const W = WIDE ? 2622 : IPAD ? 1290 : CANVAS ? CANVAS[0] : RAW_W;
const H = WIDE ? 1475 : IPAD ? 1720 : CANVAS ? CANVAS[1] : RAW_H;
const K = H / 2868; // the collage was laid out for a 2868 tall canvas
const SCALE = Number(flags.width ?? (WIDE ? 5244 : IPAD ? 2064 : W)) / W; // wide: 2622 x 1475 at 2x = 5244 x 2950

// ---- Brand ------------------------------------------------------------
const INK = "#0b0e17";
const LIME = "#c8f135";
const ORANGE = "#ff8a4c";
const VIOLET = "#a594ff";

const THEMES = {
  // Dark, like the app.
  ink: { bg: INK, grid: "rgba(255,255,255,0.05)", glow: "rgba(200,241,53,0.20)", l1: "#ffffff", l2: LIME, l2shadow: "none", sub: "rgba(255,255,255,0.72)" },
  // Bright panels break the strip up in search results.
  lime: { bg: LIME, grid: "rgba(11,14,23,0.07)", glow: "rgba(255,255,255,0.55)", l1: INK, l2: "#ffffff", l2shadow: `0.045em 0.045em 0 ${INK}`, sub: "rgba(11,14,23,0.78)" },
  violet: { bg: VIOLET, grid: "rgba(11,14,23,0.08)", glow: "rgba(255,255,255,0.40)", l1: INK, l2: "#ffffff", l2shadow: `0.045em 0.045em 0 ${INK}`, sub: "rgba(11,14,23,0.78)" },
};

// ---- Tiko, ported from web/src/components/tiko.tsx ---------------------
const ARMS = {
  downL: "M30 80 Q19 86 20 97", downR: "M90 80 Q101 86 100 97",
  upL: "M30 74 Q16 62 15 46", upR: "M90 74 Q104 62 105 46",
  pointR: "M90 77 Q104 74 114 70",
};
const arm = (d) => {
  const [x, y] = d.trim().split(/\s+/).slice(-2).map(Number);
  return `<path d="${d}" fill="none" stroke="${INK}" stroke-width="10" stroke-linecap="round"/><path d="${d}" fill="none" stroke="${LIME}" stroke-width="4.5" stroke-linecap="round"/><circle cx="${x}" cy="${y}" r="5.5" fill="${LIME}" stroke="${INK}" stroke-width="3"/>`;
};
function tiko(mood, size) {
  const arms = { cheer: [ARMS.upL, ARMS.upR], wave: [ARMS.downL, ARMS.upR], point: [ARMS.downL, ARMS.pointR] }[mood] ?? [ARMS.downL, ARMS.downR];
  const mouth = mood === "cheer"
    ? `<path d="M48 83 Q60 101 72 83 Z" fill="${INK}" stroke="${INK}" stroke-width="3" stroke-linejoin="round"/><path d="M53 92 Q60 97 67 92 Q60 89 53 92 Z" fill="${ORANGE}"/>`
    : `<path d="M49 84 Q60 95 71 84" fill="none" stroke="${INK}" stroke-width="3.5" stroke-linecap="round"/>`;
  const look = mood === "point" ? [3, 0] : [1, 1];
  const eyes = [47, 73].map((cx) => `<ellipse cx="${cx}" cy="66" rx="9.5" ry="11.5" fill="#fff" stroke="${INK}" stroke-width="3"/><circle cx="${cx + look[0]}" cy="${66 + look[1]}" r="5" fill="${INK}"/><circle cx="${cx + look[0] + 1.8}" cy="${66 + look[1] - 2}" r="1.6" fill="#fff"/>`).join("");
  return `<svg viewBox="0 0 120 124" width="${size}" height="${(size * 124) / 120}" style="overflow:visible">
    <path d="M60 36 Q57 22 64 12" fill="none" stroke="${INK}" stroke-width="3.5" stroke-linecap="round"/><circle cx="64" cy="11" r="6.5" fill="${ORANGE}" stroke="${INK}" stroke-width="3"/>
    <ellipse cx="46" cy="109" rx="10" ry="6.5" fill="${LIME}" stroke="${INK}" stroke-width="3"/><ellipse cx="74" cy="109" rx="10" ry="6.5" fill="${LIME}" stroke="${INK}" stroke-width="3"/>
    ${arms.map(arm).join("")}
    <ellipse cx="60" cy="71" rx="36" ry="35" fill="${LIME}" stroke="${INK}" stroke-width="3.5"/>
    <ellipse cx="45" cy="50" rx="11" ry="6" fill="#fff" opacity="0.35" transform="rotate(-25 45 50)"/>
    <ellipse cx="34" cy="81" rx="5.5" ry="3.2" fill="${ORANGE}" opacity="0.55"/><ellipse cx="86" cy="81" rx="5.5" ry="3.2" fill="${ORANGE}" opacity="0.55"/>
    ${eyes}${mouth}</svg>`;
}

// ---- Little icons for the stickers ---------------------------------------
const ICONS = {
  bolt: `<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>`,
  flame: `<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>`,
  trophy: `<path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6M18 9h1.5a2.5 2.5 0 0 0 0-5H18M4 22h16M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22M18 2H6v7a6 6 0 0 0 12 0V2Z"/>`,
  check: `<path d="M20 6 9 17l-5-5"/>`,
  clock: `<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>`,
};
const icon = (name) => `<svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" style="flex:none">${ICONS[name]}</svg>`;

const CHIP_TONES = {
  lime: `background:${LIME};color:${INK};`,
  ink: `background:${INK};color:#fff;border:6px solid #2a3248;`,
  orange: `background:${ORANGE};color:${INK};`,
  violet: `background:${VIOLET};color:${INK};`,
  white: `background:#fff;color:${INK};`,
};
// Where a sticker sits. The corners keep clear of the app's own content: the
// top corners cover the status bar, the bottom ones the tab bar or the
// least important options.
const DY = IPAD ? -160 : 0; // the iPad's phone starts 160px higher
const SPOTS = WIDE
  ? { tr: { right: 130, top: 20, rot: 6 }, tl: { left: 1290, top: 40, rot: -6 }, bl: { left: 1290, top: 1330, rot: -5 }, br: { right: 130, top: 1350, rot: 5 } }
  : {
      tr: { right: 26, top: 662 + DY, rot: 6 },
      tl: { left: 26, top: 678 + DY, rot: -6 },
      bl: { left: 26, top: H - 278, rot: -5 },
      br: { right: 26, top: H - 298, rot: 5 },
    };
const chip = ({ text, tone = "lime", ic, at, x, r, y, rot, size = 52 }) => {
  const sp = at ? SPOTS[at] : r !== undefined ? { right: r, top: y, rot: rot ?? 0 } : { left: x, top: y, rot: rot ?? 0 };
  const pos = ["left", "right", "top"].filter((k) => sp[k] !== undefined).map((k) => `${k}:${sp[k]}px`).join(";");
  return `<div class="chip" style="${pos};transform:rotate(${rot ?? sp.rot}deg);font-size:${size}px;${CHIP_TONES[tone]}">${ic ? icon(ic) : ""}<span>${text}</span></div>`;
};

// A piece of the real app screen, lifted out as a floating card. rect is
// [x, y, width, height] in the raw screen's own pixels.
const snip = ({ raw, rect: [rx, ry, rw, rh], x, y, w, rot = 0 }) => {
  const k = w / rw;
  return `<div class="snip" style="left:${x}px;top:${y}px;width:${w}px;height:${rh * k}px;transform:rotate(${rot}deg)">
    <img src="file://${join(rawDir, raw)}.png" style="width:${RAW_W * k}px;margin-left:${-rx * k}px;margin-top:${-ry * k}px"></div>`;
};
// The cards on the home screen (raw pixels): the Today deck, Quick Match
// and the Duel a friend tile.
// Where the cards sit on the home screen, as [x, y, width, height] in raw
// pixels, measured per screen size: a bigger phone is wider, and its safe
// area shifts things a few pixels. Add a size here if you capture on another.
const HOME_RECTS = {
  1206: { deck: [40, 520, 1140, 620], quick: [40, 1222, 1140, 395], friend: [40, 1624, 560, 335] }, // iPhone 18 Pro
  1320: { deck: [44, 516, 1240, 610], quick: [44, 1218, 1240, 395], friend: [44, 1620, 616, 340] }, // iPhone 18 Pro Max
};
const rects = HOME_RECTS[RAW_W];
if (!rects) {
  console.error(`No home-screen card positions for a ${RAW_W} px wide screen: measure them and add them to HOME_RECTS.`);
  process.exit(1);
}
const DECK = rects.deck;
const QUICK = rects.quick;
const FRIEND = rects.friend;

// ---- The set ----------------------------------------------------------------
// crop: how much of the screen to show (from the top); fade: dissolve the
// cut edge into the panel. phone: false makes a collage of floating cards.
const BASE = { y: 720, pw: 960 };
const SHOTS = [
  {
    ...BASE, id: "01-aptitude-prep-game", raw: "01-home", theme: "lime", crop: 0.44, fade: true,
    l1: "APTITUDE PREP", l2: "THAT'S A GAME", sub: "Duel friends, climb your college, get placement-ready.",
    ry: -9, rz: -3, ipad: { pw: 860, crop: 0.36 },
    wide: { crop: 0.56, fade: true },
    extras: ({ ipad, wide }) => wide ? [
      snip({ raw: "01-home", rect: QUICK, x: 1470, y: 800, w: 960, rot: -3 }),
      snip({ raw: "01-home", rect: FRIEND, x: 1560, y: 1130, w: 440, rot: 3 }),
      chip({ text: "NO SIGN-UP TO START", tone: "ink", x: 150, y: 1130, rot: -3, size: 42 }),
      `<div class="mascot" style="left:1380px;top:520px;transform:rotate(-8deg)">${tiko("wave", 230)}</div>`,
    ] : ipad ? [
      snip({ raw: "01-home", rect: QUICK, x: 145, y: 1130, w: 1000, rot: -3 }),
      chip({ text: "NO SIGN-UP TO START", tone: "ink", x: 60, y: 1560, rot: -4, size: 38 }),
      `<div class="mascot" style="left:930px;top:1440px;transform:rotate(6deg)">${tiko("wave", 260)}</div>`,
    ] : [
      snip({ raw: "01-home", rect: QUICK, x: 95, y: 1580, w: 1100, rot: -3 }),
      snip({ raw: "01-home", rect: FRIEND, x: 60, y: 2040, w: 540, rot: 3 }),
      chip({ text: "NO SIGN-UP TO START", tone: "ink", r: 28, y: 2130, rot: -4, size: 42 }),
      `<div class="mascot" style="left:860px;top:${Math.min(2380, H - 340)}px;transform:rotate(6deg)">${tiko("wave", 320)}</div>`,
    ],
  },
  {
    ...BASE, id: "02-live-aptitude-duels", raw: "06-duel-question", theme: "ink", crop: 1, fade: false,
    l1: "LIVE 1V1", l2: "APTITUDE DUELS", sub: "5 questions. 3 minutes. Fastest right answer wins.",
    ry: 8, rz: 3,
    extras: () => [chip({ text: "SPEED BONUS +50", tone: "orange", ic: "bolt", at: "tr", size: 50 })],
  },
  {
    ...BASE, id: "03-all-sections-real-puzzles", raw: "07-duel-figure", theme: "ink", crop: 1, fade: false,
    l1: "ALL 3 SECTIONS.", l2: "REAL PUZZLES.", sub: "Quant, reasoning and verbal, even picture puzzles.",
    ry: -8, rz: -3,
    extras: ({ ipad, wide }) => [chip({ text: "PICTURE PUZZLES", tone: "violet", at: "tl", size: 46 }), ...(ipad || wide ? [] : [chip({ text: "QUANT · REASONING · VERBAL", tone: "lime", at: "br", size: 38 })])],
  },
  {
    ...BASE, id: "04-win-rank-up", raw: "09-result", theme: "violet", crop: 1, fade: false,
    l1: "WIN. RANK UP.", l2: "REPEAT.", sub: "A live rating that shows how ready you really are.",
    ry: 7, rz: 3, ipad: { pw: 800, crop: 0.68 },
    extras: () => [chip({ text: "+16 RATING", tone: "lime", ic: "bolt", at: "tr", size: 52 })],
  },
  {
    ...BASE, id: "05-daily-challenge-streak", raw: "12-calendar", theme: "ink", crop: 1, fade: false,
    l1: "DAILY CHALLENGE.", l2: "KEEP THE STREAK.", sub: "One fresh set a day. The same 5 for everyone.",
    ry: -8, rz: -3,
    extras: () => [chip({ text: "3 DAYS IN A ROW", tone: "orange", ic: "flame", at: "tr", size: 48 })],
  },
  {
    ...BASE, id: "06-college-leaderboard", raw: "13-ranks", theme: "lime", crop: 1, fade: false,
    l1: "BEAT YOUR COLLEGE.", l2: "TOP INDIA.", sub: "Leaderboards for your campus and all of India.",
    ry: 8, rz: 3,
    extras: () => [chip({ text: "ALL INDIA RANKS", tone: "ink", ic: "trophy", at: "tr", size: 48 })],
  },
  {
    ...BASE, id: "07-daily-goals", phone: false, theme: "ink",
    l1: "DAILY GOALS.", l2: "BUILD THE HABIT.", sub: "Three small goals a day keep your prep on track.",
    extras: ({ ipad, wide }) => wide ? [
      snip({ raw: "02-goals", rect: DECK, x: 1510, y: 150, w: 980, rot: -3 }),
      snip({ raw: "01-home", rect: DECK, x: 1470, y: 770, w: 980, rot: 2 }),
      chip({ text: "3 SMALL GOALS", tone: "lime", ic: "check", at: "tr", size: 44 }),
      `<div class="mascot" style="left:1330px;top:1130px;transform:rotate(-8deg)">${tiko("cheer", 240)}</div>`,
    ] : ipad ? [
      snip({ raw: "02-goals", rect: DECK, x: 95, y: 580, w: 900, rot: -3 }),
      snip({ raw: "01-home", rect: DECK, x: 295, y: 1110, w: 900, rot: 2 }),
      chip({ text: "3 SMALL GOALS", tone: "lime", ic: "check", r: 26, y: 440, rot: 6, size: 42 }),
      `<div class="mascot" style="left:40px;top:1360px;transform:rotate(-8deg)">${tiko("cheer", 250)}</div>`,
    ] : [
      snip({ raw: "02-goals", rect: DECK, x: 70, y: Math.round(790 * K), w: 1150, rot: -3 }),
      snip({ raw: "01-home", rect: DECK, x: 70, y: Math.round(1500 * K), w: 1150, rot: 2 }),
      snip({ raw: "01-home", rect: QUICK, x: 70, y: Math.round(2200 * K), w: 1150, rot: -2 }),
      chip({ text: "3 SMALL GOALS", tone: "lime", ic: "check", r: 26, y: Math.round(662 - (1 - K) * 1800 + 18 * (1 - K) / 0.063), rot: 6, size: 46 }),
      `<div class="mascot" style="left:915px;top:${Math.min(2450, H - 300)}px;transform:rotate(8deg)">${tiko("cheer", 290)}</div>`,
    ],
  },
  {
    ...BASE, id: "08-challenge-a-friend", raw: "16-challenge", theme: "violet", crop: 1, fade: false,
    l1: "CHALLENGE A FRIEND", l2: "IN ONE TAP", sub: "Send a link. Your friend needs no sign-up.",
    ry: 8, rz: 3,
    extras: () => [chip({ text: "FREE TO PLAY", tone: "lime", ic: "check", at: "tr", size: 48 })],
  },
  {
    ...BASE, id: "09-learn-from-every-answer", raw: "10-review", theme: "ink", crop: 1, fade: false,
    l1: "LEARN FROM", l2: "EVERY ANSWER", sub: "Step-by-step explanations after each duel.",
    ry: -8, rz: -3,
    extras: () => [chip({ text: "SEE WHY", tone: "lime", ic: "check", at: "tr", size: 52 })],
  },
  {
    ...BASE, id: "10-player-card", raw: "14-profile", theme: "lime", crop: 1, fade: false,
    l1: "YOUR PLAYER CARD.", l2: "SHOW IT OFF.", sub: "Your rating, tier and college on one card.",
    ry: 8, rz: 3,
    extras: () => [chip({ text: "CONSULTANT TIER", tone: "ink", ic: "trophy", at: "tr", size: 44 })],
  },
];

// The 13" iPad canvas is squarer, so the phone is smaller and cut off lower.
const IPAD_PHONE = { pw: 900, y: 560, crop: 0.6, fade: true };
// The wide canvas puts the whole phone at the right and the words at the left.
const WIDE_PHONE = { pw: 640, y: 62, crop: 1, fade: false, cx: 1950 };
const variant = (s) =>
  WIDE ? { ...s, ...(s.phone === false ? {} : WIDE_PHONE), ...(s.wide ?? {}) }
  : IPAD ? { ...s, ...(s.phone === false ? {} : IPAD_PHONE), ...(s.ipad ?? {}) }
  : s;

// ---- Page --------------------------------------------------------------------
function page(s) {
  const t = THEMES[s.theme];
  const bezel = 18;
  const ph = (s.pw - bezel * 2) * (RAW_H / RAW_W) * (s.crop ?? 1); // visible screen height
  const radius = 150;
  const mask = s.fade ? "mask-image:linear-gradient(to bottom,#000 78%,transparent 100%);-webkit-mask-image:linear-gradient(to bottom,#000 78%,transparent 100%);" : "";
  return `<!doctype html><html><head><meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@500;600&family=Unbounded:wght@800;900&display=swap" rel="stylesheet">
<style>
  *{box-sizing:border-box}
  html,body{margin:0;width:${W}px;height:${H}px;overflow:hidden}
  .stage{position:relative;width:${W}px;height:${H}px;overflow:hidden;background:${t.bg}}
  .grid{position:absolute;inset:0;background-image:linear-gradient(${t.grid} 2px,transparent 2px),linear-gradient(90deg,${t.grid} 2px,transparent 2px);background-size:86px 86px}
  .glow{position:absolute;width:1700px;height:1700px;left:${(s.cx ?? W / 2) - 850}px;top:${WIDE ? -100 : s.y - 150}px;border-radius:50%;background:radial-gradient(closest-side,${t.glow},transparent)}
  .head{position:absolute;${WIDE ? "left:150px;top:0;bottom:0;width:1240px;display:flex;flex-direction:column;justify-content:center;text-align:left" : `left:0;right:0;top:${IPAD ? 100 : 140}px;padding:0 60px;text-align:center`}}
  .l1,.l2{font-family:'Unbounded',sans-serif;font-weight:900;line-height:1.04;letter-spacing:-0.012em;word-spacing:0.14em;white-space:nowrap}
  .l1{color:${t.l1}}
  .l2{color:${t.l2};text-shadow:${t.l2shadow}}
  .sub{margin:${WIDE ? "44px 0 0" : IPAD ? "28px auto 0" : "38px auto 0"};max-width:${WIDE ? 1080 : IPAD ? 1200 : 1000}px;font:600 48px/1.28 'Inter',sans-serif;color:${t.sub};text-wrap:balance}
  .phone{position:absolute;left:${(s.cx ?? W / 2) - s.pw / 2}px;top:${s.y}px;width:${s.pw}px;
    transform:perspective(2600px) rotateY(${s.ry}deg) rotateZ(${s.rz}deg);transform-origin:50% 40%;
    filter:drop-shadow(0 60px 70px rgba(0,0,0,${s.theme === "ink" ? 0.6 : 0.38}))}
  .fade{${mask}}
  .body{padding:${bezel}px;border-radius:${radius}px;background:linear-gradient(150deg,#4a5267,#161b28 40%,#0a0d14);
    box-shadow:inset 0 0 0 3px rgba(255,255,255,0.14)}
  .screen{position:relative;overflow:hidden;border-radius:${radius - bezel}px;background:#000;height:${ph}px}
  .screen img{display:block;width:100%}
  .island{position:absolute;top:30px;left:50%;width:300px;height:88px;margin-left:-150px;border-radius:44px;background:#000}
  .chip{position:absolute;z-index:5;display:flex;align-items:center;gap:18px;padding:26px 40px;border-radius:34px;
    font-family:'Unbounded',sans-serif;font-weight:900;letter-spacing:-0.01em;white-space:nowrap;box-shadow:12px 14px 0 rgba(0,0,0,0.38)}
  .snip{position:absolute;z-index:3;overflow:hidden;border-radius:46px;background:#0b0e17;box-shadow:0 0 0 4px rgba(255,255,255,0.10),14px 18px 0 rgba(0,0,0,0.36)}
  .snip img{display:block;max-width:none}
  .mascot{position:absolute;z-index:6;filter:drop-shadow(10px 14px 0 rgba(0,0,0,0.3))}
</style></head><body><div class="stage">
  <div class="grid"></div><div class="glow"></div>
  <div class="head"><div class="l1" data-fit>${s.l1}</div><div class="l2" data-fit>${s.l2}</div><div class="sub">${s.sub}</div></div>
  ${s.phone === false ? "" : `<div class="phone"><div class="fade"><div class="body"><div class="screen"><img src="file://${join(rawDir, s.raw)}.png"><div class="island"></div></div></div></div></div>`}
  ${s.extras({ ipad: IPAD, wide: WIDE }).join("\n  ")}
</div>
<script>
  // Each headline line is as large as fits the width, up to a cap.
  document.fonts.ready.then(() => {
    document.querySelectorAll('[data-fit]').forEach((el) => {
      let size = ${WIDE ? 190 : IPAD ? 130 : 150}; el.style.fontSize = size + 'px';
      while (el.scrollWidth > ${WIDE ? 1240 : W - 120} && size > 60) { size -= 2; el.style.fontSize = size + 'px'; }
    });
    document.body.dataset.ready = '1';
  });
</script></body></html>`;
}

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: SCALE });
const tab = await ctx.newPage();
for (const spec of SHOTS) {
  const s = variant(spec);
  const file = join(work, `${s.id}.html`);
  writeFileSync(file, page(s));
  await tab.goto(`file://${file}`, { waitUntil: "networkidle" });
  await tab.waitForSelector("body[data-ready='1']");
  await tab.screenshot({ path: join(outDir, `${s.id}.png`), clip: { x: 0, y: 0, width: W, height: H } });
  console.log("made", s.id);
}
await browser.close();
rmSync(work, { recursive: true, force: true });
