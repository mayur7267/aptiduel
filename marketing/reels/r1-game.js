// Reel 1 scenes: the hook, Tiko waking up, the app, a real duel in the
// phone, then the end card. Every cue follows Ava's words (window.T);
// window.A holds the raw screens, footage and icon. Flat colours: ink,
// orange on "game", lime for the name, violet for the duel, ink to close.

const W = 1080, H = 1920;
const raw = (name) => `${A.raw}/${name}.png`;
const foot = (sec) => `${A.foot}/frame-${String(clamp(Math.round(sec * 30), 0, A.footFrames - 1)).padStart(5, "0")}.png`;
let L, plan;

const PH = { w: 560, x: 260, y: 600 };
const RANK_ROW = [38, 1838, 1244, 198];

window.setup = () => {
  L = T.lines;
  const wg = L.game.words.at(-1).t;
  plan = [
    { t: 0, c: "ink" },
    { t: wg, c: "orange", cut: true },
    { t: L.meet.t - 0.08, c: "lime" },
    { t: L.duels.t - 0.02, c: "violet" },
    { t: L.cta.t - 0.2, c: "ink", cut: true },
  ];
  $("world").innerHTML = `
  <div class="layer" id="sOpen">
    <div id="tk1" style="position:absolute;left:380px;top:330px;transform-origin:50% 100%"></div>
    ${headline("hookH", "Aptitude / prep is / ^boring.^", 150, 760, { max: 980 })}
    <div id="strike" style="position:absolute;height:24px;background:var(--lime);border-radius:12px;transform-origin:left center;transform:scaleX(0)"></div>
    ${headline("gameH1", "So we turned / it into", 104, 790)}
    ${headline("gameH2", "*a game.*", 200, 1030, { max: 1000 })}
  </div>

  <div class="layer on-light" id="sMeet">
    <img id="icon" src="${A.icon}" style="position:absolute;left:375px;top:465px;width:330px;height:330px;border-radius:74px;border:6px solid var(--ink);box-shadow:var(--hard)">
    <div class="h center" id="mark" style="position:absolute;left:0;right:0;top:880px;font-size:170px;text-transform:none;letter-spacing:-0.035em">${letters("Apticks")}</div>
    <div class="center" id="meetTag" style="position:absolute;left:0;right:0;top:1100px"><span class="tag">Placement aptitude · 1v1 duels</span></div>
  </div>

  <div class="layer" id="sPhone" style="perspective:2600px">
    <div id="phWrap" style="position:absolute;left:${PH.x}px;top:${PH.y}px;transform-style:preserve-3d">
      ${phone("ph", PH.w, `<img id="scrA" class="shot"><img id="scrB" class="shot" style="opacity:0">`)}
    </div>
  </div>

  <div class="layer on-light" id="sHeads">
    ${headline("hdDuels", "Head-to-head / *aptitude duels*", 92, 200)}
    <div class="body center" id="subDuels" style="position:absolute;left:0;right:0;top:432px;font-size:40px">${kin("against someone at your level")}</div>
    ${headline("hdRules", "5 questions. / *3 minutes.*", 100, 200)}
    ${headline("hdTopics", "Just like your / *placement test.*", 92, 200)}
    ${headline("hdRating", "Win, and your / *rating climbs.*", 96, 200)}
    ${headline("hdRank", "See where you rank / *in your college.*", 88, 200)}
    ${headline("hdFriend", "Race your friends / *live, with one link.*", 84, 200)}
  </div>

  <div class="layer" id="sStick">
    ${chip("cSpeed", "SPEED COUNTS", "orange", "bolt", 54)}
    ${chip("cRating", "+16 RATING", "lime", "trophy", 54)}
    <div id="rankSnip" style="position:absolute;left:90px;top:1210px;width:900px">${snip("rs", raw("13-ranks"), RANK_ROW, 900)}</div>
    <div class="card" id="bubble" style="left:70px;top:610px;width:640px;padding:30px 34px;border-radius:40px 40px 40px 12px;background:#1d2539">
      <div style="display:flex;align-items:center;gap:20px">
        <div style="width:76px;height:76px;border-radius:50%;background:#2d3550;display:grid;place-items:center;font:800 30px Inter;color:var(--lime)">RM</div>
        <div style="font:800 40px Inter;color:#fff">Beat my 3/5?</div>
        <div style="width:44px;height:44px;color:var(--orange)">${icon("bolt")}</div>
      </div>
      <div style="margin-top:22px;display:flex;align-items:center;gap:14px;padding:18px 22px;border-radius:22px;background:rgba(200,241,53,0.12);color:var(--lime);font:700 30px 'JetBrains Mono'"><span style="width:34px;height:34px;display:inline-block">${icon("link")}</span>aptiduel.vercel.app/c/7RKQ</div>
    </div>
  </div>

  <div class="layer" id="sTopics">
    ${[["Quant", "Percentages · Profit & loss · Interest", "percent", "lime"], ["Reasoning", "Series · Puzzles · Blood relations", "puzzle", "orange"], ["Verbal", "Synonyms · Idioms · Grammar", "book", "violet"]]
      .map(([title, sub, ic, tone], i) => `
      <div class="card" id="topic${i}" style="left:540px;top:${640 + i * 270}px;width:500px;height:240px;padding:34px 34px;display:flex;gap:26px;align-items:center">
        <div style="flex:none;width:110px;height:110px;border-radius:30px;background:var(--${tone});color:var(--ink);display:grid;place-items:center"><div style="width:60px;height:60px">${icon(ic, 2.4)}</div></div>
        <div><div class="h" style="font-size:52px;text-transform:none">${title}</div><div class="body" style="font-size:27px;margin-top:12px;line-height:1.3">${sub}</div></div>
      </div>`).join("")}
  </div>
  ${endCard("Aptitude prep that's a game.")}`;

  $("world").appendChild(burstSetup("b1", 22, 3));
  $("world").appendChild(burstSetup("b3", 26, 9));
  fitAll();
  // The strike-through sits on "boring."
  const r = $("hookH").querySelectorAll(".w")[3].getBoundingClientRect();
  css($("strike"), { left: r.left - 14 + "px", top: r.top + r.height * 0.5 - 12 + "px", width: r.width + 28 + "px" });
  ["cSpeed", "cRating"].forEach((id) => { $(id).style.opacity = 0; });
};

// The phone's screen: which picture shows when, crossfading between them.
function screenAt(t) {
  const segs = [
    { t0: L.duels.t - 0.5, src: () => foot(clamp(t - L.duels.t + 0.15, 0, 2.7)) },
    { t0: L.rules.t, src: () => foot(2.76 + (t - L.rules.t)) },
    { t0: L.topics.t, src: () => foot(5.97 + (t - L.topics.t) * 1.15) },
    { t0: L.rating.t - 0.1, src: () => foot(18.92 + (t - L.rating.t + 0.1)) },
    { t0: L.rank.t - 0.05, src: () => raw("13-ranks") },
    { t0: L.friend.t - 0.05, src: () => raw("16-challenge") },
  ];
  let i = segs.findLastIndex((s) => t >= s.t0);
  if (i < 0) i = 0;
  const m = i > 0 ? seg(t, segs[i].t0, segs[i].t0 + 0.22) : 1;
  return { cur: segs[i].src(), prev: i > 0 && m < 1 ? segs[i - 1].src() : null, m };
}

// A headline that rises with its words and leaves before the next line.
function head(id, t, times, until) {
  const el = $(id);
  if (!show(id, t > times[0] - 0.2 && t < until + 0.05)) return;
  el.style.opacity = 1; el.style.filter = "none";
  rise(el, t, 0, { times, dur: 0.5 });
  leave(el, t, until - 0.24, 0.22);
}

// A sticker that pops in at t0 and goes at t1.
function pop(id, t, t0, t1, rot, x, y) {
  const el = $(id);
  if (!show(id, t > t0 - 0.05 && t < t1 + 0.3)) return;
  const p = E.outBack(seg(t, t0, t0 + 0.42)), q = E.inCubic(seg(t, t1, t1 + 0.25));
  css(el, { left: x + "px", top: y + "px", opacity: String(clamp(seg(t, t0, t0 + 0.1)) * (1 - q)), transform: `rotate(${rot}deg) scale(${(0.4 + 0.6 * p) * (1 - 0.3 * q)})` });
}

window.frame = async (t) => {
  drawBackground(t, plan);
  const tG = L.game.t, tM = L.meet.t, tD = L.duels.t, tR = L.rules.t, tT = L.topics.t;
  const tRa = L.rating.t, tRk = L.rank.t, tF = L.friend.t, tC = L.cta.t;
  const wg = L.game.words.at(-1).t;
  const [sx, sy] = shake(t, wg, 20, 0.45);
  $("world").style.transform = `translate(${sx}px, ${sy}px)`;
  burst($("b1"), t, wg, 520, 450);
  burst($("b3"), t, tC + 0.05, 540, 510);

  // ---- Open: "Aptitude prep is boring." / "So we turned it into a game."
  if (show("sOpen", t < tM)) {
    const awake = t >= wg - 0.05, idle = tikoIdle(t);
    $("sOpen").classList.toggle("on-light", t >= wg);
    const [lift, sq] = hop(t, wg - 0.05, 190, 0.62);
    $("tk1").innerHTML = tiko(awake ? "cheer" : "sleep", { size: 320, blink: awake ? idle.blink : 0, squash: awake ? sq : idle.squash * 0.5, antenna: idle.antenna, wave: awake ? Math.sin(t * 13) * 12 : 0, zz: (t * 0.6) % 1 });
    $("tk1").style.transform = `translateY(${lift}px) scale(${E.outBack(seg(t, 0.02, 0.5))})`;
    rise($("hookH"), t, 0, { times: wordsAt("hook"), dur: 0.5 });
    const he = lineEnd("hook");
    $("strike").style.transform = `scaleX(${E.outExpo(seg(t, he + 0.02, he + 0.32))})`;
    for (const id of ["hookH", "strike"]) leave($(id), t, tG - 0.04, 0.2);
    const gw = wordsAt("game");
    rise($("gameH1"), t, 0, { times: gw.slice(0, 5).map((x) => x + 0.12), dur: 0.5 });
    rise($("gameH2"), t, 0, { times: gw.slice(5), dur: 0.45 });
    $("gameH2").style.transform = `scale(${lerp(1.45, 1, E.outBack(seg(t, wg, wg + 0.5)))})`;
    const out = E.inCubic(seg(t, tM - 0.42, tM - 0.08));
    css($("sOpen"), { transform: `translateY(${-out * 520}px) scale(${1 - out * 0.1})`, opacity: String(1 - out) });
  }

  // ---- Meet Apticks
  if (show("sMeet", t > tM - 0.4 && t < tD + 0.25)) {
    const p = E.outBack(seg(t, tM - 0.25, tM + 0.3));
    css($("icon"), { opacity: String(seg(t, tM - 0.25, tM - 0.12)), transform: `scale(${0.25 + 0.75 * p}) rotate(${(1 - p) * -16}deg)` });
    rise($("mark"), t, wordsAt("meet")[1] - 0.06, { stagger: 0.035, dur: 0.5 });
    css($("meetTag"), { opacity: String(E.outCubic(seg(t, tM + 0.5, tM + 0.9))), transform: `translateY(${(1 - E.outCubic(seg(t, tM + 0.5, tM + 0.9))) * 30}px)` });
    const out = E.inCubic(seg(t, tD - 0.38, tD + 0.05));
    css($("sMeet"), { transform: `translateY(${-out * 420}px) scale(${1 - 0.2 * out})`, opacity: String(1 - out) });
  }

  // ---- The phone, with a real duel
  const phoneOn = show("sPhone", t > tD - 0.4 && t < tC - 0.18);
  show("sHeads", phoneOn); show("sStick", phoneOn);
  if (phoneOn) {
    const pin = E.outExpo(seg(t, tD - 0.3, tD + 0.6));
    const tp = E.inOutCubic(seg(t, tT - 0.15, tT + 0.45)) * (1 - E.inOutCubic(seg(t, tRa - 0.35, tRa + 0.2)));
    const y = lerp(1500, 0, pin) + Math.sin(t * 1.1) * 8;
    const rx = lerp(40, 6, pin) + Math.sin(t * 0.8) * 1.5;
    const ry = lerp(-7 + 3 * Math.sin(t * 0.6), 24, tp);
    $("phWrap").style.transform = `translate(${-255 * tp}px, ${y}px) rotateX(${rx}deg) rotateY(${ry}deg) scale(${1 - 0.12 * tp})`;
    const { cur, prev, m } = screenAt(t);
    if (prev) { await setImg($("scrA"), prev); await setImg($("scrB"), cur); $("scrB").style.opacity = m; }
    else { await setImg($("scrA"), cur); $("scrB").style.opacity = 0; }

    const dw = wordsAt("duels");
    head("hdDuels", t, dw.slice(0, 3), tR);
    if (show("subDuels", t > dw[3] - 0.2 && t < tR + 0.05)) { rise($("subDuels"), t, 0, { times: dw.slice(3), dur: 0.45 }); $("subDuels").style.opacity = 1; leave($("subDuels"), t, tR - 0.24, 0.22); }
    const rw = wordsAt("rules");
    head("hdRules", t, rw.slice(0, 4), tT);
    pop("cSpeed", t, rw[4], tT - 0.3, 6, 470, 690);
    head("hdTopics", t, wordsAt("topics").slice(4), tRa);
    const aw = wordsAt("rating");
    head("hdRating", t, aw, tRk);
    pop("cRating", t, aw[4] - 0.05, tRk - 0.3, -6, 545, 1010);
    const kw = wordsAt("rank");
    head("hdRank", t, kw, tF);
    if (show("rankSnip", t > kw[6] - 0.1 && t < tF + 0.1)) {
      const p = E.outBack(seg(t, kw[6] - 0.05, kw[6] + 0.45)), q = E.inCubic(seg(t, tF - 0.3, tF));
      css($("rankSnip"), { opacity: String(clamp(p * 3) * (1 - q)), transform: `translateY(${(1 - p) * 60}px) rotate(${-3 * p}deg) scale(${0.7 + 0.3 * p})` });
    }
    const fw = wordsAt("friend");
    head("hdFriend", t, fw.slice(1), tC - 0.2);
    if (show("bubble", t > fw[7] - 0.15)) {
      const p = E.outBack(seg(t, fw[7] - 0.12, fw[7] + 0.35));
      css($("bubble"), { opacity: String(clamp(p * 3)), transform: `translateX(${(1 - p) * -120}px) rotate(${-4 * p}deg) scale(${0.7 + 0.3 * p})` });
    }
  }

  // ---- Quant, reasoning, verbal
  if (show("sTopics", t > tT - 0.1 && t < tRa + 0.1)) {
    const tw = wordsAt("topics");
    [tw[0], tw[1], tw[3]].forEach((s, i) => {
      const p = E.outExpo(seg(t, s - 0.08, s + 0.45)), q = E.inCubic(seg(t, tRa - 0.38 + i * 0.05, tRa - 0.1 + i * 0.05));
      css($(`topic${i}`), { opacity: String(clamp(p * 2) * (1 - q)), transform: `translateX(${(1 - p) * 160 + q * 200}px) rotate(${(1 - p) * 6}deg)` });
    });
  }

  // ---- The end card
  const cw = wordsAt("cta");
  drawEndCard(t, tC - 0.2, { mark: cw[0], pill: cw[1], url: cw[3] });
};
