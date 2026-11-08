// The drawing kit shared by the Apticks reels, posts and stories: easing,
// Tiko, the phone, kinetic type, captions and the background. Pages load
// it with a <script> tag; it is plain browser JavaScript.

const C = { ink: "#0b0e17", lime: "#c8f135", orange: "#ff8a4c", violet: "#a594ff", surface: "#141a29", text: "#f4f6fb" };

// ---- Time and easing ---------------------------------------------------------
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const seg = (t, a, b) => clamp((t - a) / (b - a));
const lerp = (a, b, x) => a + (b - a) * x;
const E = {
  outExpo: (x) => (x >= 1 ? 1 : 1 - 2 ** (-10 * x)),
  outCubic: (x) => 1 - (1 - x) ** 3,
  inCubic: (x) => x * x * x,
  inOutCubic: (x) => (x < 0.5 ? 4 * x * x * x : 1 - (-2 * x + 2) ** 3 / 2),
  inOutSine: (x) => -(Math.cos(Math.PI * x) - 1) / 2,
  outBack: (x) => { const c = 1.9; return 1 + (c + 1) * (x - 1) ** 3 + c * (x - 1) ** 2; },
};
// 0 → 1 over [a, a + i], back to 0 over [b - o, b].
const life = (t, a, b, i = 0.35, o = 0.3) => Math.min(E.outCubic(seg(t, a, a + i)), 1 - E.inCubic(seg(t, b - o, b)));
const rng = (s) => () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
const $ = (id) => document.getElementById(id);
const css = (el, o) => { for (const k in o) el.style[k] = o[k]; };

// ---- Tiko ---------------------------------------------------------------------
// Ported from web/src/components/tiko.tsx. Options animate it: blink (0..1),
// wave (degrees on the raised arm), squash (-1..1, from the feet), antenna
// (degrees), size in px.
const TK_ARMS = {
  downL: "M30 80 Q19 86 20 97", downR: "M90 80 Q101 86 100 97",
  upL: "M30 74 Q16 62 15 46", upR: "M90 74 Q104 62 105 46",
  pointR: "M90 77 Q104 74 114 70", chinR: "M90 82 Q86 96 72 96",
};
function tkArm(d, rot = 0, cx = 90, cy = 76) {
  const [x, y] = d.trim().split(/\s+/).slice(-2).map(Number);
  return `<g transform="rotate(${rot} ${cx} ${cy})"><path d="${d}" fill="none" stroke="${C.ink}" stroke-width="10" stroke-linecap="round"/><path d="${d}" fill="none" stroke="${C.lime}" stroke-width="4.5" stroke-linecap="round"/><circle cx="${x}" cy="${y}" r="5.5" fill="${C.lime}" stroke="${C.ink}" stroke-width="3"/></g>`;
}
function tiko(mood = "happy", o = {}) {
  const { size = 200, blink = 0, wave = 0, squash = 0, antenna = 0 } = o;
  const line = `fill="none" stroke="${C.ink}" stroke-width="3.5" stroke-linecap="round"`;
  const arms =
    mood === "cheer" || mood === "giggle" ? [tkArm(TK_ARMS.upL, -wave * 0.5, 30, 76), tkArm(TK_ARMS.upR, wave * 0.5)]
    : mood === "wave" ? [tkArm(TK_ARMS.downL), tkArm(TK_ARMS.upR, wave)]
    : mood === "point" ? [tkArm(TK_ARMS.downL), tkArm(TK_ARMS.pointR, wave * 0.3)]
    : mood === "think" ? [tkArm(TK_ARMS.downL), tkArm(TK_ARMS.chinR)]
    : [tkArm(TK_ARMS.downL), tkArm(TK_ARMS.downR)];
  const mouth = {
    cheer: `<path d="M48 83 Q60 101 72 83 Z" fill="${C.ink}" stroke="${C.ink}" stroke-width="3" stroke-linejoin="round"/><path d="M53 92 Q60 97 67 92 Q60 89 53 92 Z" fill="${C.orange}"/>`,
    sad: `<path d="M51 91 Q60 84 69 91" ${line}/>`,
    think: `<path d="M54 89 Q60 87 66 89" ${line}/>`,
    confused: `<path d="M49 89 q5.5 -5 11 0 t11 0" ${line}/>`,
    sleep: `<ellipse cx="60" cy="88" rx="3.5" ry="4" fill="${C.ink}"/>`,
  }[mood === "giggle" ? "cheer" : mood] ?? `<path d="M49 84 Q60 95 71 84" ${line}/>`;
  let eyes;
  if (mood === "sleep") eyes = `<path d="M39 68 Q47 74 55 68" ${line}/><path d="M65 68 Q73 74 81 68" ${line}/>`;
  else if (mood === "giggle") eyes = `<path d="M39 70 Q47 58 55 70" ${line}/><path d="M65 70 Q73 58 81 70" ${line}/>`;
  else {
    const look = o.look ?? (mood === "think" ? [3, -3] : mood === "sad" ? [0, 3] : mood === "point" ? [3, 0] : [1, 1]);
    const k = 1 - clamp(blink) * 0.92;
    eyes = `<g transform="translate(0 66) scale(1 ${k}) translate(0 -66)">${[47, 73].map((cx) => `<ellipse cx="${cx}" cy="66" rx="9.5" ry="11.5" fill="#fff" stroke="${C.ink}" stroke-width="3"/><circle cx="${cx + look[0]}" cy="${66 + look[1]}" r="5" fill="${C.ink}"/><circle cx="${cx + look[0] + 1.8}" cy="${66 + look[1] - 2}" r="1.6" fill="#fff"/>`).join("")}</g>`;
  }
  const brows = mood === "sad" ? `<path d="M39 52 L52 49" ${line}/><path d="M68 49 L81 52" ${line}/>`
    : mood === "think" || mood === "confused" ? `<path d="M66 50 Q73 45 81 49" ${line}/>` : "";
  const sx = 1 + squash * 0.1, sy = 1 - squash * 0.1;
  const extra = mood === "confused" ? `<text x="96" y="30" font-size="26" font-weight="800" fill="${C.violet}" font-family="Inter">?</text>`
    : mood === "sleep" ? `<text x="90" y="${30 - (o.zz ?? 0) * 6}" font-size="16" font-weight="800" fill="${C.violet}" opacity="${1 - (o.zz ?? 0) * 0.6}" font-family="Inter">z z</text>` : "";
  return `<svg viewBox="0 0 120 124" width="${size}" height="${(size * 124) / 120}" style="overflow:visible;display:block">
    <g transform="translate(60 115) scale(${sx} ${sy}) translate(-60 -115)">
      <g transform="rotate(${antenna} 60 36)"><path d="M60 36 Q57 22 64 12" ${line}/><circle cx="64" cy="11" r="6.5" fill="${C.orange}" stroke="${C.ink}" stroke-width="3"/></g>
      <ellipse cx="46" cy="109" rx="10" ry="6.5" fill="${C.lime}" stroke="${C.ink}" stroke-width="3"/><ellipse cx="74" cy="109" rx="10" ry="6.5" fill="${C.lime}" stroke="${C.ink}" stroke-width="3"/>
      ${mood !== "think" ? arms.join("") : ""}
      <ellipse cx="60" cy="71" rx="36" ry="35" fill="${C.lime}" stroke="${C.ink}" stroke-width="3.5"/>
      <ellipse cx="45" cy="50" rx="11" ry="6" fill="#fff" opacity="0.35" transform="rotate(-25 45 50)"/>
      <ellipse cx="34" cy="81" rx="5.5" ry="3.2" fill="${C.orange}" opacity="${mood === "giggle" ? 0.9 : 0.55}"/><ellipse cx="86" cy="81" rx="5.5" ry="3.2" fill="${C.orange}" opacity="${mood === "giggle" ? 0.9 : 0.55}"/>
      ${eyes}${brows}${mouth}
      ${mood === "think" ? arms.join("") : ""}
    </g>${extra}</svg>`;
}
// Tiko's idle life at time t: blinks every few seconds, breathes, and the
// antenna sways. Returns options to pass to tiko().
function tikoIdle(t, seed = 0) {
  const p = (t + seed * 1.7) % 3.1;
  const blink = p < 0.14 ? Math.sin((p / 0.14) * Math.PI) : 0;
  return { blink, squash: Math.sin((t + seed) * 3.2) * 0.12, antenna: Math.sin((t + seed) * 2.4) * 7 };
}
// A hop that starts at t0: [lift in px (negative is up), squash].
function hop(t, t0, height = 120, dur = 0.55) {
  const x = (t - t0) / dur;
  if (x < -0.12 || x > 1.25) return [0, 0];
  if (x < 0) return [0, (x / 0.12 + 1) * 0.8];
  if (x <= 1) return [-4 * height * x * (1 - x), -0.5 * Math.sin(Math.PI * x)];
  return [0, Math.sin(((x - 1) / 0.25) * Math.PI) * 0.7];
}

// ---- Phone ------------------------------------------------------------------------
// A phone w px wide around `inner`, the screen's content (1320 x 2868 aspect).
function phone(id, w, inner) {
  const b = Math.round(w * 0.025), r = Math.round(w * 0.155), sw = w - 2 * b, sh = Math.round((sw * 2868) / 1320);
  const iw = Math.round(sw * 0.31), ih = Math.round(sw * 0.092), it = Math.round(sw * 0.028);
  return `<div class="phone" id="${id}" style="width:${w}px"><div class="pbody" style="padding:${b}px;border-radius:${r}px"><div class="pscreen" style="height:${sh}px;border-radius:${r - b}px">${inner}<div class="island" style="width:${iw}px;height:${ih}px;top:${it}px;margin-left:${-iw / 2}px;border-radius:${ih / 2}px"></div><div class="glare"></div></div></div></div>`;
}
const phoneHeight = (w) => { const b = Math.round(w * 0.025); return Math.round(((w - 2 * b) * 2868) / 1320) + 2 * b; };

// A piece of a raw screen (1320 x 2868) as a floating card: rect in raw px.
function snip(id, src, [rx, ry, rw, rh], w) {
  const k = w / rw;
  return `<div class="snip" id="${id}" style="width:${w}px;height:${rh * k}px"><img src="${src}" style="width:${1320 * k}px;margin-left:${-rx * k}px;margin-top:${-ry * k}px"></div>`;
}

// ---- Icons -------------------------------------------------------------------------
const ICONS = {
  bolt: `<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>`,
  clock: `<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>`,
  trophy: `<path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6M18 9h1.5a2.5 2.5 0 0 0 0-5H18M4 22h16M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22M18 2H6v7a6 6 0 0 0 12 0V2Z"/>`,
  check: `<path d="M20 6 9 17l-5-5"/>`,
  flame: `<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>`,
  link: `<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>`,
  target: `<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>`,
  percent: `<path d="M19 5 5 19"/><circle cx="6.5" cy="6.5" r="2.5"/><circle cx="17.5" cy="17.5" r="2.5"/>`,
  puzzle: `<path d="M19.44 7.85c-.47.47-1.1.73-1.77.73s-1.3-.26-1.77-.73c-.47-.47-.73-1.1-.73-1.77s.26-1.3.73-1.77L17 3.24 15.76 2l-2.3 2.3a1 1 0 0 1-.84.28 1 1 0 0 1-.72-.53A2.5 2.5 0 1 0 8 6.5c0 .38.09.74.24 1.07a1 1 0 0 1-.25 1.15L5 11.76 6.24 13l1.06-1.06a2.5 2.5 0 1 1 3.54 3.54L9.76 16.54 11 17.78l2.98-2.98a1 1 0 0 1 1.15-.25 2.5 2.5 0 1 0 1.95-4.15 1 1 0 0 1-.53-.72 1 1 0 0 1 .28-.84l2.3-2.3-1.24-1.24z"/>`,
  book: `<path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"/>`,
  arrow: `<path d="M5 12h14M13 6l6 6-6 6"/>`,
  users: `<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>`,
  calendar: `<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>`,
  x: `<path d="M18 6 6 18M6 6l12 12"/>`,
};
const icon = (name, stroke = 2.6) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round">${ICONS[name]}</svg>`;
const chip = (id, text, tone = "lime", ic = null, size = 52) => `<div class="chip ${tone}" id="${id}" style="font-size:${size}px">${ic ? icon(ic) : ""}<span>${text}</span></div>`;

// ---- Kinetic type ------------------------------------------------------------------
// Words in masks, so each can rise into view. "/" breaks the line, and
// markers colour a run of words: *lime*, ~orange~, ^grey^, _violet_.
const MARKS = { "*": "lime", "~": "orange", "^": "grey", _: "violet" };
function kin(text) {
  let tone = "";
  return text.split(" ").map((w) => {
    if (w === "/") return "<br>";
    if (MARKS[w[0]]) { tone = MARKS[w[0]]; w = w.slice(1); }
    const cls = tone;
    if (MARKS[w.at(-1)]) { w = w.slice(0, -1); tone = ""; }
    return `<span class="w"><span class="wi ${cls}">${w}</span></span>`;
  }).join(" ");
}
// One mask per letter, for a wordmark that types itself in.
const letters = (text) => [...text].map((ch) => `<span class="w"><span class="wi">${ch}</span></span>`).join("");
// A centred headline whose lines fit within `max` px.
function headline(id, text, size, top, { max = 960, cls = "", style = "" } = {}) {
  return `<div class="h center ${cls}" id="${id}" data-max="${max}" style="position:absolute;left:0;right:0;top:${top}px;font-size:${size}px;${style}"><span class="fit" style="display:inline-block;white-space:nowrap">${kin(text)}</span></div>`;
}
function fitAll(root = document) {
  root.querySelectorAll("[data-max]").forEach((el) => {
    const inner = el.querySelector(".fit") ?? el;
    let s = parseFloat(getComputedStyle(el).fontSize);
    while (inner.offsetWidth > Number(el.dataset.max) && s > 24) { s -= 2; el.style.fontSize = s + "px"; }
  });
}
const show = (id, on) => { $(id).style.display = on ? "" : "none"; return on; };
// Swaps an <img> to src and waits until it can be drawn.
async function setImg(el, src) {
  if (el.dataset.src === src) return;
  el.dataset.src = src; el.src = src;
  await el.decode().catch(() => {});
}
// Brings the words of `el` up one by one from t0 (or at the given times).
function rise(el, t, t0, { stagger = 0.07, dur = 0.55, times } = {}) {
  el.querySelectorAll(".wi").forEach((w, i) => {
    const s = times ? times[Math.min(i, times.length - 1)] : t0 + i * stagger;
    const p = E.outExpo(seg(t, s, s + dur));
    w.style.transform = `translateY(${(1 - p) * 105}%)`;
  });
}
// Takes a block away: up, blurred and faded.
function leave(el, t, t0, dur = 0.35) {
  const p = E.inCubic(seg(t, t0, t0 + dur));
  el.style.opacity = 1 - p;
  el.style.filter = p > 0 ? `blur(${p * 14}px)` : "none";
  return p;
}
// When each word of a line is spoken, from the voice-over timings.
const wordsAt = (id) => window.T.lines[id].words.map((w) => w.t);
const lineAt = (id) => window.T.lines[id].t;
const lineEnd = (id) => window.T.lines[id].t + window.T.lines[id].d;

// ---- Particles and camera ----------------------------------------------------------
function burstSetup(id, n = 18, seed = 3) {
  const r = rng(seed), cols = [C.lime, C.orange, C.violet, "#fff"];
  const parts = Array.from({ length: n }, (_, i) => ({ a: (i / n) * Math.PI * 2 + r() * 0.4, v: 700 + r() * 900, s: 14 + r() * 18, c: cols[i % 4], spin: (r() - 0.5) * 900, shape: r() > 0.5 }));
  const el = document.createElement("div");
  el.id = id; el.className = "layer"; el.style.pointerEvents = "none";
  el.innerHTML = parts.map((p, i) => `<div data-i="${i}" style="position:absolute;width:${p.s}px;height:${p.s}px;background:${p.c};border-radius:${p.shape ? "50%" : "4px"};opacity:0"></div>`).join("");
  el._parts = parts;
  return el;
}
function burst(el, t, t0, x, y) {
  const dt = t - t0;
  [...el.children].forEach((d, i) => {
    const p = el._parts[i];
    if (dt < 0 || dt > 1.4) { d.style.opacity = 0; return; }
    const px = x + Math.cos(p.a) * p.v * dt * (1 - dt * 0.35), py = y + Math.sin(p.a) * p.v * dt * (1 - dt * 0.35) + 1100 * dt * dt;
    css(d, { left: px + "px", top: py + "px", opacity: String(clamp(1.4 - dt * 1.2)), transform: `rotate(${p.spin * dt}deg) scale(${1 - dt * 0.4})` });
  });
}
function shake(t, t0, amp = 14, dur = 0.35) {
  const x = seg(t, t0, t0 + dur);
  if (x <= 0 || x >= 1) return [0, 0];
  const k = (1 - x) ** 2 * amp;
  return [Math.sin(t * 91) * k, Math.cos(t * 77) * k];
}

// ---- Background ---------------------------------------------------------------------------
// One solid colour at a time. A reel lists its colours as [{ t, c, cut }]:
// each new colour wipes up over the last, landing at t, or cuts at t.
const BG = { ink: "#0b0e17", lime: "#c8f135", violet: "#a594ff", orange: "#ff8a4c", cream: "#f6f3ea" };
const background = () => `<div class="layer" id="bgBase"></div><div class="layer" id="bgNext"></div>`;
function drawBackground(t, plan, H = 1920) {
  let i = plan.findLastIndex((e) => t >= e.t - (e.cut ? 0 : 0.32));
  if (i < 0) i = 0;
  const e = plan[i], wiping = i > 0 && !e.cut && t < e.t;
  $("bgBase").style.background = BG[wiping ? plan[i - 1].c : e.c];
  $("bgNext").style.background = BG[e.c];
  $("bgNext").style.transform = `translateY(${wiping ? H * (1 - E.inOutCubic(seg(t, e.t - 0.32, e.t))) : H}px)`;
}

// ---- Captions --------------------------------------------------------------------------------
// Short chunks (up to 3 words, breaking at punctuation) with the spoken
// word in lime. Lines marked caption: false are left to the headline.
let CAP = [];
function captionsSetup(lines, top = 1330) {
  CAP = [];
  for (const line of Object.values(lines)) {
    if (line.caption === false) continue;
    let cur = [];
    for (const w of line.words) {
      cur.push(w);
      if (cur.length === 3 || /[,.!?:]$/.test(w.w)) { CAP.push(cur); cur = []; }
    }
    if (cur.length) CAP.push(cur);
  }
  CAP.sort((a, b) => a[0].t - b[0].t);
  CAP.forEach((c, i) => { c.t0 = c[0].t - 0.04; c.t1 = Math.min(i + 1 < CAP.length ? CAP[i + 1][0].t - 0.04 : 1e9, c.at(-1).t + c.at(-1).d + 0.35); });
  $("cap").style.top = top + "px";
}
let capShown = -1;
function drawCaptions(t, { hidden = false, top } = {}) {
  const el = $("cap");
  if (top !== undefined) el.style.top = top + "px";
  const i = hidden ? -1 : CAP.findIndex((c) => t >= c.t0 && t < c.t1);
  if (i !== capShown) {
    el.innerHTML = i < 0 ? "" : `<span class="chunk">${CAP[i].map((w) => `<span class="cw">${w.w.replace(/[[\]]/g, "")}</span>`).join(" ")}</span>`;
    capShown = i;
  }
  if (i < 0) return;
  const c = CAP[i], p = E.outBack(seg(t, c.t0, c.t0 + 0.2));
  const chunk = el.firstElementChild;
  chunk.style.transform = `translateY(${(1 - clamp(p)) * 24}px) scale(${0.9 + 0.1 * p})`;
  chunk.style.opacity = clamp(seg(t, c.t0, c.t0 + 0.08)) * (1 - seg(t, c.t1 - 0.06, c.t1));
  [...chunk.children].forEach((s, k) => s.classList.toggle("on", t >= c[k].t && t < c[k].t + c[k].d + 0.05));
}

// ---- The end card ------------------------------------------------------------------------------------
// Tiko cheering over the icon, the name, a tagline and the call to action,
// revealed by a lime wipe. Shared by every reel.
function endCard(tagline, pill = "PLAY FREE", W = 1080, H = 1920) {
  return `<div class="layer" id="sEnd">
    <div id="endTiko" style="position:absolute;left:350px;top:340px;transform-origin:50% 100%"></div>
    <div id="endRow" style="position:absolute;left:0;right:0;top:850px;display:flex;justify-content:center;align-items:center;gap:30px">
      <img src="${A.icon}" id="endIcon" style="width:150px;height:150px;border-radius:34px;border:4px solid rgba(255,255,255,0.14)">
      <div class="h" id="endMark" style="font-size:132px;text-transform:none;letter-spacing:-0.035em">${letters("Apticks")}</div>
    </div>
    <div class="body center" id="endTag" style="position:absolute;left:0;right:0;top:1055px;font-size:46px">${tagline}</div>
    <div class="center" id="endPill" style="position:absolute;left:0;right:0;top:1180px"><span class="pill">${pill} <span style="width:44px;height:44px;display:inline-block">${icon("arrow", 3)}</span> LINK IN BIO<span class="shine" id="endShine"></span></span></div>
    <div class="mono center" id="endUrl" style="position:absolute;left:0;right:0;top:1355px;font-size:34px;color:rgba(244,246,251,0.55)">aptiduel.vercel.app</div>
  </div>
  <div id="endWipe" style="position:absolute;left:0;top:0;width:${W}px;height:${H}px;background:var(--lime);transform:translateY(${H}px)"></div>`;
}
// t0: when the wipe has covered the screen; at: { mark, pill, url } times.
function drawEndCard(t, t0, at, H = 1920) {
  const wIn = E.inOutCubic(seg(t, t0 - 0.32, t0)), wOut = E.inOutCubic(seg(t, t0 + 0.06, t0 + 0.46));
  $("endWipe").style.transform = `translateY(${H * (1 - wIn) - H * wOut}px)`;
  if (!show("sEnd", t > t0)) return false;
  const idle = tikoIdle(t, 1), k = Math.max(0, Math.floor((t - (t0 + 0.2)) / 1.15));
  const [l1, s1] = hop(t, t0 + 0.2, 150, 0.6);
  const [l2, s2] = k > 0 ? hop(t, t0 + 0.2 + k * 1.15, 60, 0.45) : [0, 0];
  $("endTiko").innerHTML = tiko("cheer", { size: 380, ...idle, squash: s1 + s2 + idle.squash * 0.3, wave: Math.sin(t * 12) * 14 });
  $("endTiko").style.transform = `translateY(${l1 + l2}px) scale(${E.outBack(seg(t, t0 + 0.05, t0 + 0.45))})`;
  const ip = E.outBack(seg(t, at.mark - 0.1, at.mark + 0.35));
  $("endIcon").style.transform = `scale(${ip}) rotate(${(1 - ip) * -20}deg)`;
  rise($("endMark"), t, at.mark - 0.05, { stagger: 0.03, dur: 0.45 });
  css($("endTag"), { opacity: String(E.outCubic(seg(t, at.mark + 0.35, at.mark + 0.75))) });
  const pp = E.outBack(seg(t, at.pill - 0.05, at.pill + 0.4));
  css($("endPill"), { opacity: String(clamp(pp * 3)), transform: `scale(${0.6 + 0.4 * pp})` });
  $("endShine").style.left = `${-50 + (((t - at.pill) % 1.7 + 1.7) % 1.7) / 1.7 * 200}%`;
  css($("endUrl"), { opacity: String(E.outCubic(seg(t, at.url - 0.1, at.url + 0.3))) });
  return true;
}

// ---- Frame driver --------------------------------------------------------------------------------
// A reel defines setup() and frame(t); the renderer calls draw(t) per frame.
window.draw = async (t) => { await window.frame(t); };
// Called by the renderer once every script has loaded.
window.start = async () => {
  await Promise.all(["900 100px Unbounded", "700 100px Unbounded", "800 100px Inter", "600 100px Inter", "700 100px 'JetBrains Mono'"].map((f) => document.fonts.load(f)));
  await window.setup?.();
  await document.fonts.ready;
  await Promise.all([...document.images].map((im) => im.decode().catch(() => {})));
  return true;
};
