// The week's standalone posts (1080 x 1350) and stories (1080 x 1920).
// Each is complete on its own: it either shows what Apticks is and how it
// works, or it's a joke that still says what Apticks is. One flat brand
// colour, bold type, Tiko and the real app. Stories leave room for an
// Instagram sticker (poll, quiz, link, slider); Captions.md says which.
// Uses kit.js; window.A has the raw screens.

const raw = (name) => `${A.raw}/${name}.png`;
// Pieces of the real screens, as [x, y, width, height] in raw pixels.
const DECK = [44, 516, 1240, 610]; // the Today deck on the home screen
const QUICK = [40, 1216, 1250, 400]; // the Quick Match card on the home screen
const SCORE = [40, 385, 1250, 440]; // the live scoreboard in a duel
const RANK_ROW = [38, 1838, 1244, 198]; // your row on the college leaderboard

const at = (x, y, html, extra = "") => `<div style="position:absolute;left:${x}px;top:${y}px;${extra}">${html}</div>`;
const rot = (deg) => `transform:rotate(${deg}deg)`;
const still = (c) => c.replace('class="chip', 'style="position:static" class="chip');
const logo = (x, y, light) => at(x, y, `<div style="display:flex;align-items:center;gap:16px"><img src="${A.icon}" style="width:64px;height:64px;border-radius:16px;border:3px solid ${light ? C.ink : "rgba(255,255,255,0.15)"}"><span class="h" style="font-size:40px;text-transform:none;letter-spacing:-0.03em;color:${light ? C.ink : "#fff"}">Apticks</span></div>`);
// The line that says what Apticks is, at the foot of a post or story.
const footer = (light, y, text = "Apticks · free 1v1 aptitude duels for placement prep · link in bio") =>
  `<div class="mono" style="position:absolute;left:40px;right:40px;top:${y}px;text-align:center;font-size:27px;color:${light ? "rgba(11,14,23,0.68)" : "rgba(244,246,251,0.6)"}">${text}</div>`;
const pillAt = (y, text = "PLAY FREE · LINK IN BIO") => `<div style="position:absolute;left:0;right:0;top:${y}px;text-align:center"><span class="pill" style="font-size:34px;padding:22px 40px">${text}</span></div>`;
const phoneAt = (x, y, w, screen, deg = 0) => at(x, y, phone("p" + Math.random().toString(36).slice(2, 7), w, `<img class="shot" src="${raw(screen)}">`), rot(deg));
const snipBox = (screen, rect, w) => `<div style="position:relative;flex:none;width:${w}px;height:${(rect[3] * w) / rect[2]}px">${snip("s" + Math.random().toString(36).slice(2, 7), raw(screen), rect, w)}</div>`;
// Tiko on a white sticker, for backgrounds as lime as he is.
const tikoSticker = (mood, size, o = {}) => `<div style="width:${size * 1.12}px;height:${size * 1.12}px;border-radius:50%;background:#fff;border:5px solid var(--ink);box-shadow:var(--hard);display:grid;place-items:center">${tiko(mood, { size: size * 0.82, ...o })}</div>`;
const bubble = (text, size = 40) => `<div style="position:relative;display:inline-block;padding:22px 32px;border-radius:32px 32px 32px 8px;background:#fff;border:5px solid var(--ink);box-shadow:8px 10px 0 var(--ink);font:800 ${size}px Inter;color:var(--ink);white-space:nowrap">${text}</div>`;
const chai = `<svg viewBox="0 0 140 190" width="250" height="340">
  <path d="M46 40 q-10 -14 0 -26 q10 -12 0 -24" fill="none" stroke="${C.ink}" stroke-width="5" stroke-linecap="round" opacity="0.55"/>
  <path d="M72 40 q-10 -14 0 -26 q10 -12 0 -24" fill="none" stroke="${C.ink}" stroke-width="5" stroke-linecap="round" opacity="0.55"/>
  <path d="M98 40 q-10 -14 0 -26 q10 -12 0 -24" fill="none" stroke="${C.ink}" stroke-width="5" stroke-linecap="round" opacity="0.55"/>
  <path d="M20 54 L120 54 L108 182 L32 182 Z" fill="#fff" stroke="${C.ink}" stroke-width="7" stroke-linejoin="round"/>
  <path d="M24 84 L116 84 L108 182 L32 182 Z" fill="#c9843f" stroke="${C.ink}" stroke-width="7" stroke-linejoin="round"/>
  <path d="M26 104 L114 104 M28 128 L112 128 M30 152 L110 152" stroke="#b06f2f" stroke-width="4"/></svg>`;
const STEPS = [
  ["Tap Quick Match", "Get matched with someone at your level.", "01-home", QUICK],
  ["Answer 5 questions", "Quant, reasoning, verbal. 3 minutes. Faster answers score more.", "08-duel-right", SCORE],
  ["Win and rank up", "Your rating climbs. See your rank in your college.", "13-ranks", RANK_ROW],
];

window.STILLS = {
  // ---- Posts: what Apticks is ------------------------------------------------
  "post-1-aptitude-is-a-game": { w: 1080, h: 1350, bg: "lime", light: true, html: () => `
    ${logo(70, 64, true)}
    ${headline("h", "Aptitude prep / that's a *game.*", 104, 170, { max: 940 })}
    <div class="body center" style="position:absolute;left:0;right:0;top:430px;font-size:38px">1v1 duels · 5 questions · 3 minutes</div>
    ${phoneAt(470, 560, 520, "09-result", 6)}
    ${at(50, 820, tikoSticker("cheer", 330, { wave: 10 }), rot(-6))}
    ${at(610, 505, still(chip("c1", "+16 RATING", "ink", "trophy", 50)), rot(5))}
    ${at(50, 1225, `<span class="pill" style="font-size:34px;padding:22px 40px">PLAY FREE · LINK IN BIO</span>`)}` },

  "post-2-how-it-works": { w: 1080, h: 1350, bg: "violet", light: true, html: () => `
    ${logo(70, 64, true)}
    ${headline("h", "How Apticks / *works*", 100, 150, { max: 940 })}
    ${STEPS.map(([title, sub, screen, rect], i) => `
    <div class="card white" style="left:70px;top:${420 + i * 262}px;width:940px;height:236px;padding:0 30px;display:flex;align-items:center;gap:24px">
      <div style="flex:none;width:80px;height:80px;border-radius:50%;background:var(--ink);color:var(--lime);display:grid;place-items:center;font:900 38px Unbounded">${i + 1}</div>
      <div style="flex:1;min-width:0"><div class="h" style="font-size:42px;text-transform:none;color:var(--ink);line-height:1.1">${title}</div><div style="font:600 29px/1.3 Inter;color:rgba(11,14,23,0.75);margin-top:10px">${sub}</div></div>
      ${snipBox(screen, rect, 320)}
    </div>`).join("")}
    ${pillAt(1218)}` },

  "post-4-daily-challenge": { w: 1080, h: 1350, bg: "ink", light: false, html: () => `
    ${logo(70, 64, false)}
    ${headline("h", "Same 5 questions. / *Everyone.* / Every day.", 88, 160, { max: 940 })}
    <div class="body center" style="position:absolute;left:90px;right:90px;top:470px;font-size:32px;line-height:1.35">The Daily Challenge on Apticks: 5 placement-style questions in 3 minutes. Keep your streak alive.</div>
    ${at(70, 640, snip("s", raw("11-daily-done"), DECK, 600), rot(-3))}
    ${phoneAt(650, 600, 370, "12-calendar", 6)}
    ${at(60, 1040, still(chip("c", "DON'T BREAK THE STREAK", "orange", "flame", 44)), rot(-4))}
    ${at(470, 1105, tiko("cheer", { size: 160 }), rot(-6))}
    <div class="mono" style="position:absolute;left:64px;top:1275px;width:560px;font-size:26px;color:rgba(244,246,251,0.6)">Play free · link in bio</div>` },

  // ---- Posts: funny ones ------------------------------------------------------
  "post-3-tag-a-friend": { w: 1080, h: 1350, bg: "orange", light: true, html: () => `
    ${logo(70, 64, true)}
    ${headline("h", "Tag the friend / who says / *“aptitude is easy”*", 90, 160, { max: 960 })}
    ${phoneAt(590, 560, 420, "16-challenge", 6)}
    ${at(70, 560, bubble("Prove it. 😏", 44), rot(-4))}
    ${at(120, 700, tiko("point", { size: 270 }), rot(-4))}
    <div class="card" style="left:60px;top:1010px;width:520px;padding:30px 34px;background:var(--ink)">
      <div style="font:800 34px/1.3 Inter;color:#fff">Send one link. Same 5 aptitude questions. <span style="color:var(--lime)">Live.</span></div>
      <div style="font:800 34px/1.3 Inter;color:var(--orange);margin-top:10px">Loser buys chai. ☕</div>
    </div>
    <div class="mono" style="position:absolute;left:64px;top:1255px;width:520px;font-size:26px;line-height:1.4;color:rgba(11,14,23,0.7)">Apticks · free 1v1 aptitude duels<br>link in bio</div>` },

  "post-5-me-before-after": { w: 1080, h: 1350, bg: "cream", light: true, html: () => `
    <div style="position:absolute;left:0;top:0;width:1080px;height:675px;background:var(--cream)"></div>
    <div style="position:absolute;left:0;top:675px;width:1080px;height:675px;background:var(--orange);border-top:6px solid var(--ink)"></div>
    <div class="h" style="position:absolute;left:70px;top:90px;font-size:64px;color:var(--ink);line-height:1.1">Me before<br>placement<br>season</div>
    ${at(600, 150, tiko("sleep", { size: 380, zz: 0.2 }))}
    <div class="h" style="position:absolute;left:70px;top:770px;font-size:64px;color:var(--ink);line-height:1.1">Me after<br>5 duels on<br>Apticks</div>
    ${at(600, 790, tiko("cheer", { size: 380, wave: 12 }))}
    ${at(70, 1135, still(chip("c", "+64 RATING", "ink", "trophy", 40)), rot(-4))}
    ${footer(true, 1290, "Apticks · free 1v1 aptitude duels · link in bio")}` },

  "post-6-chai-vs-duel": { w: 1080, h: 1350, bg: "cream", light: true, html: () => `
    ${logo(70, 64, true)}
    ${headline("h1", "Chai takes 4 minutes / to cool down.", 70, 170, { max: 940, style: "text-align:left;left:70px" })}
    ${headline("h2", "~An Apticks duel / takes 3.~", 104, 330, { max: 940, style: "text-align:left;left:70px" })}
    ${at(110, 640, chai, rot(-4))}
    ${at(420, 650, tiko("cheer", { size: 300, wave: 14 }), rot(4))}
    ${at(700, 640, still(chip("c", "3:00", "lime", "clock", 64)), rot(6))}
    <div class="h" style="position:absolute;left:0;right:0;top:1035px;text-align:center;font-size:52px;color:var(--ink);text-transform:none">So… one duel per chai? ☕⚡</div>
    <div class="body center" style="position:absolute;left:0;right:0;top:1120px;font-size:32px">5 placement-style questions · 1v1 · free</div>
    ${pillAt(1200, "PLAY FREE · LINK IN BIO")}` },

  // ---- Stories ------------------------------------------------------------------
  "story-1-meet-apticks": { w: 1080, h: 1920, bg: "lime", light: true, html: () => `
    ${logo(70, 260, true)}
    ${headline("h", "Aptitude prep, / but it's a *game.*", 96, 380, { max: 940 })}
    ${phoneAt(320, 640, 440, "09-result", 4)}
    ${at(50, 1040, tikoSticker("wave", 250, { wave: 20 }), rot(-6))}
    ${footer(true, 1650, "Apticks · free 1v1 aptitude duels · tap the link")}` },

  "story-2-poll-section": { w: 1080, h: 1920, bg: "violet", light: true, html: () => `
    ${logo(70, 260, true)}
    ${headline("h", "Which section / scares you / *the most?*", 104, 420, { max: 940 })}
    ${at(380, 820, tiko("confused", { size: 320 }))}
    ${footer(true, 1650, "Apticks · 1v1 duels in quant, reasoning and verbal")}` },

  "story-3-quiz-odd-one-out": { w: 1080, h: 1920, bg: "orange", light: true, html: () => `
    ${logo(70, 260, true)}
    ${headline("h", "Odd one / *out?*", 120, 400, { max: 940 })}
    <div style="position:absolute;left:70px;right:70px;top:720px;display:grid;grid-template-columns:1fr 1fr;gap:30px">
      ${["42", "56", "84", "71"].map((n) => `<div style="height:200px;border-radius:36px;background:#fff;border:5px solid var(--ink);box-shadow:var(--hard);display:grid;place-items:center;font:900 110px Unbounded;color:var(--ink)">${n}</div>`).join("")}
    </div>
    ${at(800, 590, tiko("think", { size: 190 }), rot(8))}
    ${footer(true, 1650, "Tap the quiz to answer · 5 like this in 3 min on Apticks")}` },

  "story-4-rank-in-college": { w: 1080, h: 1920, bg: "lime", light: true, html: () => `
    ${logo(70, 260, true)}
    ${headline("h", "See where you rank / *in your college.*", 90, 380, { max: 940 })}
    ${phoneAt(320, 620, 440, "13-ranks", -4)}
    ${at(60, 1180, snip("r", raw("13-ranks"), RANK_ROW, 760), rot(-3))}
    ${at(800, 1010, tikoSticker("cheer", 190, { wave: 12 }), rot(8))}
    ${footer(true, 1650, "Apticks · win duels, climb your college · tap the link")}` },

  "story-5-duel-a-friend": { w: 1080, h: 1920, bg: "ink", light: false, html: () => `
    ${logo(70, 260, false)}
    ${headline("h", "Duel a friend / *with one link.*", 96, 380, { max: 940 })}
    ${phoneAt(320, 640, 440, "16-challenge", -4)}
    ${at(640, 1060, still(chip("c", "LIVE", "lime", "bolt", 56)), rot(6))}
    ${footer(false, 1650, "Apticks · same 5 questions, live · tap the link")}` },

  "story-6-daily-is-live": { w: 1080, h: 1920, bg: "violet", light: true, html: () => `
    ${logo(70, 260, true)}
    ${headline("h", "Today's Daily / is *live.*", 110, 400, { max: 940 })}
    <div class="body center" style="position:absolute;left:0;right:0;top:680px;font-size:42px">Same 5 questions for everyone. Can you get 5/5?</div>
    ${at(70, 800, snip("s", raw("11-daily-done"), DECK, 940), rot(-2))}
    ${at(800, 1180, tiko("cheer", { size: 210, wave: 12 }), rot(8))}
    ${footer(true, 1650, "Apticks Daily Challenge · 3 minutes · tap the link")}` },

  "story-7-how-ready": { w: 1080, h: 1920, bg: "orange", light: true, html: () => `
    ${logo(70, 260, true)}
    ${headline("h", "How ready are / you for / *placements?*", 104, 420, { max: 940 })}
    ${at(380, 820, tiko("think", { size: 320 }))}
    ${footer(true, 1650, "Find out in 3 minutes on Apticks · link in bio")}` },
};

window.renderStill = async (id) => {
  const s = STILLS[id];
  const stage = $("stage");
  stage.className = `stage bg-${s.bg}${s.light ? " on-light" : ""}`;
  css(stage, { width: s.w + "px", height: s.h + "px" });
  stage.innerHTML = s.html();
  fitAll(stage);
  await Promise.all([...stage.querySelectorAll("img")].map((im) => im.decode().catch(() => {})));
  return { w: s.w, h: s.h };
};
