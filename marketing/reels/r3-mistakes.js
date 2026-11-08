// Reel 3 scenes: the hook on orange with a sad Tiko; mistake one on ink
// (a clock that won't wait), two on violet (no timer), three on lime
// (lopsided topics); how Apticks trains all three on ink; the end card.

const W = 1080, H = 1920;
const foot = (sec) => `${A.foot}/frame-${String(clamp(Math.round(sec * 30), 0, A.footFrames - 1)).padStart(5, "0")}.png`;
let L, plan;

const clockSvg = `<svg viewBox="0 0 200 200" width="380" height="380">
  <circle cx="100" cy="100" r="88" fill="#fff" stroke="${C.ink}" stroke-width="10"/>
  ${Array.from({ length: 12 }, (_, i) => `<line x1="100" y1="22" x2="100" y2="${i % 3 ? 32 : 40}" stroke="${C.ink}" stroke-width="${i % 3 ? 4 : 7}" stroke-linecap="round" transform="rotate(${i * 30} 100 100)"/>`).join("")}
  <line id="hHand" x1="100" y1="100" x2="100" y2="58" stroke="${C.ink}" stroke-width="9" stroke-linecap="round"/>
  <line id="mHand" x1="100" y1="100" x2="100" y2="34" stroke="${C.orange}" stroke-width="7" stroke-linecap="round"/>
  <circle cx="100" cy="100" r="9" fill="${C.ink}"/></svg>`;
const watchSvg = `<svg viewBox="0 0 200 220" width="360" height="396">
  <rect x="82" y="6" width="36" height="22" rx="6" fill="${C.ink}"/>
  <circle cx="100" cy="122" r="86" fill="#fff" stroke="${C.ink}" stroke-width="10"/>
  <line x1="100" y1="122" x2="100" y2="72" stroke="${C.ink}" stroke-width="9" stroke-linecap="round"/>
  <circle cx="100" cy="122" r="9" fill="${C.ink}"/>
  <line id="slash" x1="30" y1="200" x2="176" y2="40" stroke="${C.orange}" stroke-width="22" stroke-linecap="round" stroke-dasharray="220" stroke-dashoffset="220"/></svg>`;
const BARS = [["Quant", 0.92], ["Reasoning", 0.16], ["Verbal", 0.08]];

window.setup = () => {
  L = T.lines;
  plan = [
    { t: 0, c: "orange" },
    { t: L.m1.t - 0.05, c: "ink" },
    { t: L.m2.t - 0.05, c: "violet" },
    { t: L.m3.t - 0.05, c: "lime" },
    { t: L.fix.t - 0.05, c: "ink" },
    { t: L.cta.t - 0.2, c: "ink", cut: true },
  ];
  const num = (id, n, color, shadow) => `<div class="h" id="${id}" style="position:absolute;left:70px;top:250px;font-size:300px;line-height:1;color:${color};${shadow ? `text-shadow:0.04em 0.04em 0 ${C.ink}` : ""}">${n}</div>`;
  const tag = (id) => `<div id="${id}" style="position:absolute;left:84px;top:200px"><span class="tag">Mistake</span></div>`;
  const left = "text-align:left;left:80px;right:auto";
  $("world").innerHTML = `
  <style>
    .bar { display: grid; grid-template-columns: 300px 1fr 130px; align-items: center; gap: 24px; margin-bottom: 46px; font: 800 50px Inter; color: var(--ink); }
    .track { height: 64px; border-radius: 27px; border: 4px solid var(--ink); background: #fff; overflow: hidden; }
    .fill { height: 100%; background: var(--ink); width: 0; }
    .pct { font: 700 40px 'JetBrains Mono'; text-align: right; }
  </style>
  <div class="layer on-light" id="sHook">
    <div id="tkH" style="position:absolute;left:390px;top:360px;transform-origin:50% 100%"></div>
    ${headline("hookH", "3 mistakes that / cost you the / *aptitude round.*", 120, 780)}
  </div>

  <div class="layer" id="s1">
    ${tag("tag1")}${num("n1", "01", C.lime)}
    ${headline("h1", "Getting stuck on / *a single question.*", 84, 620, { style: left, max: 920 })}
    <div id="clock" style="position:absolute;left:350px;top:900px">${clockSvg}</div>
    <div id="tk1" style="position:absolute;left:110px;top:1080px;transform-origin:50% 100%"></div>
    ${chip("c1", "THE CLOCK DOESN'T WAIT", "orange", "clock", 46)}
  </div>

  <div class="layer on-light" id="s2">
    ${tag("tag2")}${num("n2", "02", "#fff", true)}
    ${headline("h2", "Practising / *without a timer.*", 92, 620, { style: left, max: 920 })}
    <div id="watch" style="position:absolute;left:360px;top:880px">${watchSvg}</div>
    ${chip("c2", "THE REAL TEST IS A RACE", "lime", "bolt", 46)}
  </div>

  <div class="layer on-light" id="s3">
    ${tag("tag3")}${num("n3", "03", "#fff", true)}
    ${headline("h3", "Only practising / the topics you're / *already good at.*", 84, 620, { style: left, max: 920 })}
    <div id="bars" style="position:absolute;left:80px;top:1040px;width:920px">${BARS.map(([n], i) => `<div class="bar"><span>${n}</span><div class="track"><div class="fill" id="fill${i}"></div></div><span class="pct" id="pct${i}">0%</span></div>`).join("")}</div>
  </div>

  <div class="layer" id="sFix" style="perspective:2600px">
    ${headline("hFix", "Apticks trains / *all three.*", 100, 200)}
    <div id="phWrap" style="position:absolute;left:290px;top:520px;transform-style:preserve-3d">${phone("ph", 500, `<img id="scr" class="shot">`)}</div>
    ${chip("f1", "TIMED DUELS", "lime", "clock", 50)}
    ${chip("f2", "MIXED TOPICS", "orange", "puzzle", 50)}
    ${chip("f3", "READINESS RATING", "violet", "trophy", 50)}
  </div>
  ${endCard("Practise like it's the real test.")}`;

  $("world").appendChild(burstSetup("bE", 26, 9));
  fitAll();
  ["c1", "c2", "f1", "f2", "f3"].forEach((id) => { $(id).style.opacity = 0; });
};

function pop(id, t, t0, t1, rot, x, y) {
  const el = $(id);
  if (!show(id, t > t0 - 0.05 && t < t1 + 0.3)) return;
  const p = E.outBack(seg(t, t0, t0 + 0.42)), q = E.inCubic(seg(t, t1, t1 + 0.25));
  css(el, { left: x + "px", top: y + "px", opacity: String(clamp(seg(t, t0, t0 + 0.1)) * (1 - q)), transform: `rotate(${rot}deg) scale(${(0.4 + 0.6 * p) * (1 - 0.3 * q)})` });
}

// A mistake scene: tag, the big number slamming in, the headline, out.
function mistake(k, t, id, next) {
  const s = lineAt(id), until = lineAt(next);
  if (!show(`s${k}`, t > s - 0.4 && t < until)) return false;
  const p = E.outBack(seg(t, s - 0.05, s + 0.4));
  $(`n${k}`).style.transform = `scale(${0.3 + 0.7 * p}) rotate(${(1 - p) * -12}deg)`;
  $(`n${k}`).style.opacity = clamp(p * 3);
  css($(`tag${k}`), { opacity: String(E.outCubic(seg(t, s, s + 0.3))) });
  rise($(`h${k}`), t, 0, { times: wordsAt(id).slice(1), dur: 0.5 });
  const out = E.inCubic(seg(t, until - 0.42, until - 0.08));
  css($(`s${k}`), { transform: `translateY(${-out * 600}px)`, opacity: String(1 - out) });
  return true;
}

window.frame = async (t) => {
  drawBackground(t, plan);
  const tC = L.cta.t, tFx = L.fix.t;
  burst($("bE"), t, tC + 0.05, 540, 510);

  if (show("sHook", t < L.m1.t)) {
    const idle = tikoIdle(t);
    $("tkH").innerHTML = tiko("sad", { size: 300, ...idle });
    $("tkH").style.transform = `scale(${E.outBack(seg(t, 0.02, 0.5))})`;
    rise($("hookH"), t, 0, { times: wordsAt("hook"), dur: 0.5 });
    const out = E.inCubic(seg(t, L.m1.t - 0.42, L.m1.t - 0.08));
    css($("sHook"), { transform: `translateY(${-out * 600}px)`, opacity: String(1 - out) });
  }

  if (mistake(1, t, "m1", "m2")) {
    const s = L.m1.t, w1 = wordsAt("m1");
    const p = E.outBack(seg(t, w1[1], w1[1] + 0.45));
    $("clock").style.transform = `scale(${p}) rotate(${(1 - p) * 20}deg)`;
    $("mHand").setAttribute("transform", `rotate(${(t - s) * 540} 100 100)`);
    $("hHand").setAttribute("transform", `rotate(${(t - s) * 45} 100 100)`);
    const idle = tikoIdle(t, 2);
    $("tk1").innerHTML = tiko("confused", { size: 200, ...idle });
    $("tk1").style.transform = `scale(${E.outBack(seg(t, w1[2], w1[2] + 0.4))}) rotate(-8deg)`;
    pop("c1", t, w1[8] - 0.05, L.m2.t - 0.5, -4, 140, 1330);
  }
  if (mistake(2, t, "m2", "m3")) {
    const w2 = wordsAt("m2"), p = E.outBack(seg(t, w2[1], w2[1] + 0.45));
    $("watch").style.transform = `scale(${p}) rotate(${(1 - p) * -16}deg)`;
    $("slash").setAttribute("stroke-dashoffset", String(220 * (1 - E.outExpo(seg(t, w2[2], w2[2] + 0.4)))));
    pop("c2", t, w2[6] - 0.05, L.m3.t - 0.5, 4, 150, 1330);
  }
  if (mistake(3, t, "m3", "fix")) {
    const w3 = wordsAt("m3");
    BARS.forEach(([, v], i) => {
      const p = E.outExpo(seg(t, w3[4] + i * 0.25, w3[4] + i * 0.25 + 0.8));
      $(`fill${i}`).style.width = `${v * p * 100}%`;
      $(`pct${i}`).textContent = `${Math.round(v * p * 100)}%`;
    });
  }

  if (show("sFix", t > tFx - 0.4 && t < tC - 0.18)) {
    rise($("hFix"), t, 0, { times: wordsAt("fix").slice(0, 4), dur: 0.5 });
    const pin = E.outExpo(seg(t, tFx - 0.25, tFx + 0.6));
    $("phWrap").style.transform = `translateY(${lerp(1500, 0, pin) + Math.sin(t * 1.1) * 8}px) rotateX(${lerp(40, 6, pin)}deg) rotateY(${-6 + 3 * Math.sin(t * 0.6)}deg)`;
    await setImg($("scr"), foot(2.76 + clamp(t - tFx, 0, 30) * 1.6));
    const fw = wordsAt("fix");
    pop("f1", t, fw[4] - 0.05, tC - 0.5, -6, 60, 760);
    pop("f2", t, fw[6] - 0.05, tC - 0.5, 5, 410, 1010);
    pop("f3", t, fw[10] - 0.05, tC - 0.5, -4, 70, 1260);
  }

  const cw = wordsAt("cta");
  drawEndCard(t, tC - 0.2, { mark: cw[0], pill: cw[1], url: cw[3] });
};
