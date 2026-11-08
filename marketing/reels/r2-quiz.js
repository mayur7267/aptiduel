// Reel 2 scenes: the hook on ink, the question card on violet, a 5-second
// countdown on orange, the answer on lime, the trick on ink, the same
// question in the real app on violet, then the end card.

const W = 1080, H = 1920;
const raw = (name) => `${A.raw}/${name}.png`;
const foot = (sec) => `${A.foot}/frame-${String(clamp(Math.round(sec * 30), 0, A.footFrames - 1)).padStart(5, "0")}.png`;
let L, plan, cd;

const OPTS = [["A", "20%"], ["B", "25%"], ["C", "16%"], ["D", "30%"]];
const RIGHT = 1;
const STEPS = [
  ["1", `16 sell <span class="mute">=</span> 20 cost`],
  ["2", `Gain <span class="mute">=</span> 4 on every 16`],
  ["3", `4 ÷ 16 <span class="mute">=</span> <span class="hl">25%</span>`],
];

window.setup = () => {
  L = T.lines;
  cd = L.opts.t + L.opts.d + 0.3;
  plan = [
    { t: 0, c: "ink" },
    { t: L.q.t - 0.05, c: "violet" },
    { t: cd, c: "orange", cut: true },
    { t: L.answer.t - 0.05, c: "lime", cut: true },
    { t: L.why.t - 0.05, c: "ink" },
    { t: L.next.t - 0.05, c: "violet" },
    { t: L.cta.t - 0.2, c: "ink", cut: true },
  ];
  const q = "The cost price of 20 articles equals the selling price of 16. What's the profit percentage?";
  $("world").innerHTML = `
  <style>
    .qtext .wi.num { background: var(--lime); border-radius: 10px; padding: 0 8px; }
    .opt { display: flex; align-items: center; gap: 26px; height: 108px; padding: 0 26px; border: 4px solid var(--ink); border-radius: 26px; background: #fff; margin-top: 18px; }
    .opt .let { width: 64px; height: 64px; border-radius: 50%; background: var(--ink); color: #fff; display: grid; place-items: center; font: 800 32px Inter; flex: none; }
    .opt .val { font: 900 50px Unbounded; color: var(--ink); letter-spacing: -0.02em; }
    .opt.right { background: var(--lime); }
    .step { display: flex; align-items: center; gap: 30px; padding: 38px 40px; border-radius: 34px; background: #fff; color: var(--ink); border: 4px solid var(--ink); box-shadow: 14px 16px 0 var(--lime); margin-bottom: 44px; }
    .step .n { width: 84px; height: 84px; border-radius: 50%; background: var(--ink); color: var(--lime); display: grid; place-items: center; font: 900 40px Unbounded; flex: none; }
    .step .s { font: 700 54px 'JetBrains Mono'; letter-spacing: -0.02em; }
    .step .mute { color: rgba(11,14,23,0.4); }
    .step .hl { background: var(--lime); padding: 0 12px; border-radius: 12px; font-size: 64px; }
  </style>
  <div class="layer" id="sHook">
    <div id="tkH" style="position:absolute;left:390px;top:380px;transform-origin:50% 100%"></div>
    ${headline("hookH", "Can you solve / this in / *5 seconds?*", 128, 780)}
    <div class="center" id="hookTag" style="position:absolute;left:0;right:0;top:1270px"><span class="tag">Placement aptitude · Quant</span></div>
  </div>

  <div class="layer on-light" id="sQ">
    ${headline("qHead", "Quick quiz · *5 seconds*", 66, 190)}
    <div class="card white" id="qcard" style="left:70px;top:330px;width:940px;padding:44px 44px 30px">
      <div style="display:flex;gap:16px"><span class="chip orange" style="position:static;font-size:26px;border-width:4px;box-shadow:none">PROFIT &amp; LOSS</span><span class="chip lime" style="position:static;font-size:26px;border-width:4px;box-shadow:none">QUANT</span></div>
      <div class="qtext" id="qtext" style="margin-top:34px;font:800 52px/1.28 Inter;color:var(--ink);letter-spacing:-0.01em">${q.split(" ").map((w) => `<span class="w"><span class="wi ${/^\d+\.?$/.test(w) ? "num" : ""}">${w}</span></span>`).join(" ")}</div>
      <div id="opts" style="margin-top:26px">${OPTS.map(([l, v], i) => `<div class="opt" id="opt${i}"><span class="let" id="let${i}">${l}</span><span class="val">${v}</span></div>`).join("")}</div>
    </div>
    <div id="ring" style="position:absolute;left:835px;top:268px;width:200px;height:200px">
      <svg viewBox="0 0 200 200" width="200" height="200"><circle cx="100" cy="100" r="92" fill="var(--ink)"/><circle cx="100" cy="100" r="74" fill="none" stroke="rgba(255,255,255,0.15)" stroke-width="14"/><circle id="ringArc" cx="100" cy="100" r="74" fill="none" stroke="var(--lime)" stroke-width="14" stroke-linecap="round" transform="rotate(-90 100 100)" stroke-dasharray="465" stroke-dashoffset="0"/></svg>
      <div id="ringN" style="position:absolute;inset:0;display:grid;place-items:center;font:900 92px Unbounded;color:var(--lime)">5</div>
    </div>
    <div id="tkQ" style="position:absolute;left:40px;top:1255px;transform-origin:50% 100%"></div>
    ${chip("cComment", "COMMENT YOUR ANSWER", "ink", null, 34)}
    ${chip("cRight", "25% · CORRECT", "ink", "check", 46)}
  </div>

  <div class="layer" id="sWhy">
    ${headline("whyH", "The *trick*", 120, 250)}
    <div id="steps" style="position:absolute;left:80px;top:520px;width:900px">${STEPS.map(([n, s], i) => `<div class="step" id="step${i}"><span class="n">${n}</span><span class="s">${s}</span></div>`).join("")}</div>
  </div>

  <div class="layer" id="sNext" style="perspective:2600px">
    <div class="on-light">${headline("nextH", "Now try 5 in a row, / *against the clock.*", 82, 200)}</div>
    <div id="phWrap" style="position:absolute;left:260px;top:560px;transform-style:preserve-3d">${phone("ph", 560, `<img id="scr" class="shot">`)}</div>
  </div>
  ${endCard("5 questions. 3 minutes. Beat the clock.")}`;

  $("world").appendChild(burstSetup("bA", 22, 5));
  $("world").appendChild(burstSetup("bE", 26, 9));
  fitAll();
  ["cComment", "cRight"].forEach((id) => { $(id).style.opacity = 0; });
};

function pop(id, t, t0, t1, rot, x, y) {
  const el = $(id);
  if (!show(id, t > t0 - 0.05 && t < t1 + 0.3)) return;
  const p = E.outBack(seg(t, t0, t0 + 0.42)), q = E.inCubic(seg(t, t1, t1 + 0.25));
  css(el, { left: x + "px", top: y + "px", opacity: String(clamp(seg(t, t0, t0 + 0.1)) * (1 - q)), transform: `rotate(${rot}deg) scale(${(0.4 + 0.6 * p) * (1 - 0.3 * q)})` });
}

window.frame = async (t) => {
  drawBackground(t, plan);
  const tQ = L.q.t, tA = L.answer.t, tW = L.why.t, tN = L.next.t, tC = L.cta.t;
  const [sx, sy] = shake(t, tA - 0.05, 16, 0.35);
  $("world").style.transform = `translate(${sx}px, ${sy}px)`;
  burst($("bA"), t, tA - 0.03, 180, 1330);
  burst($("bE"), t, tC + 0.05, 540, 510);

  // ---- Hook
  if (show("sHook", t < tQ)) {
    const idle = tikoIdle(t);
    $("tkH").innerHTML = tiko("think", { size: 300, ...idle });
    $("tkH").style.transform = `scale(${E.outBack(seg(t, 0.02, 0.5))})`;
    rise($("hookH"), t, 0, { times: wordsAt("hook"), dur: 0.5 });
    css($("hookTag"), { opacity: String(E.outCubic(seg(t, lineEnd("hook") - 0.3, lineEnd("hook")))) });
    const out = E.inCubic(seg(t, tQ - 0.42, tQ - 0.08));
    css($("sHook"), { transform: `translateY(${-out * 520}px)`, opacity: String(1 - out) });
  }

  // ---- The question, the countdown and the answer
  if (show("sQ", t > tQ - 0.4 && t < tW)) {
    const pin = E.outExpo(seg(t, tQ - 0.3, tQ + 0.5));
    const out = E.inCubic(seg(t, tW - 0.4, tW - 0.05));
    $("sQ").style.transform = `translateY(${(1 - pin) * 1400 - out * 1500}px)`;
    rise($("qtext"), t, 0, { times: wordsAt("q"), dur: 0.4 });
    const ow = wordsAt("opts"), at = [ow[2], ow[3], ow[4], ow[6]];
    const answered = t >= tA - 0.05;
    OPTS.forEach((_, i) => {
      const p = E.outBack(seg(t, at[i] - 0.08, at[i] + 0.35));
      const el = $(`opt${i}`);
      el.classList.toggle("right", answered && i === RIGHT);
      $(`let${i}`).innerHTML = answered && i === RIGHT ? `<span style="width:36px;height:36px;display:block;color:var(--lime)">${icon("check", 3.4)}</span>` : OPTS[i][0];
      css(el, { opacity: String(clamp(p * 3) * (answered && i !== RIGHT ? 0.35 : 1)), transform: `translateX(${(1 - p) * 80}px) scale(${answered && i === RIGHT ? 1 + 0.05 * E.outBack(seg(t, tA - 0.05, tA + 0.3)) : 1})` });
    });
    rise($("qHead"), t, tQ - 0.1, { stagger: 0.06 });
    // The timer: a full ring until the countdown, then five ticks.
    const rp = E.outBack(seg(t, tQ + 0.3, tQ + 0.7)), gone = E.inCubic(seg(t, tA - 0.1, tA + 0.15));
    const left = clamp(1 - (t - cd) / 5);
    const n = t < cd ? 5 : Math.max(1, 5 - Math.floor(t - cd));
    const beat = t >= cd && t < cd + 5 ? 1 + 0.22 * (1 - E.outCubic(seg((t - cd) % 1, 0, 0.35))) : 1;
    $("ringN").textContent = n;
    $("ringN").style.transform = `scale(${beat})`;
    $("ringArc").setAttribute("stroke-dashoffset", String(465 * (1 - left)));
    $("ringArc").setAttribute("stroke", t >= cd + 3 ? C.orange : C.lime);
    $("ring").style.transform = `scale(${rp * (1 - gone)}) rotate(${(1 - rp) * -30}deg)`;
    // Tiko thinks, worries through the countdown, then cheers.
    const idle = tikoIdle(t, 3), [lift, sq] = hop(t, tA - 0.05, 160, 0.6);
    const mood = answered ? "cheer" : t >= cd ? "confused" : "think";
    $("tkQ").innerHTML = tiko(mood, { size: 210, ...idle, squash: sq + idle.squash * 0.4, wave: answered ? Math.sin(t * 13) * 14 : 0 });
    $("tkQ").style.transform = `translateY(${lift}px) scale(${E.outBack(seg(t, tQ + 0.6, tQ + 1.0))}) rotate(-6deg)`;
    pop("cComment", t, cd + 0.15, tA - 0.15, -3, 330, 1390);
    pop("cRight", t, tA + 0.1, tW - 0.4, 5, 470, 1380);
  }

  // ---- The trick
  if (show("sWhy", t > tW - 0.4 && t < tN)) {
    const ww = wordsAt("why");
    rise($("whyH"), t, tW - 0.25, { stagger: 0.08 });
    [ww[0], ww[6], ww[13]].forEach((s, i) => {
      const p = E.outBack(seg(t, s - 0.1, s + 0.4));
      css($(`step${i}`), { opacity: String(clamp(p * 3)), transform: `translateX(${(1 - p) * -140}px) rotate(${(1 - p) * -4}deg)` });
    });
    const out = E.inCubic(seg(t, tN - 0.4, tN - 0.08));
    css($("sWhy"), { transform: `translateY(${-out * 600}px)`, opacity: String(1 - out) });
  }

  // ---- The same question in the real app
  if (show("sNext", t > tN - 0.4 && t < tC - 0.18)) {
    rise($("nextH"), t, 0, { times: wordsAt("next"), dur: 0.5 });
    const pin = E.outExpo(seg(t, tN - 0.25, tN + 0.6));
    $("phWrap").style.transform = `translateY(${lerp(1500, 0, pin) + Math.sin(t * 1.1) * 8}px) rotateX(${lerp(40, 6, pin)}deg) rotateY(${-6 + 3 * Math.sin(t * 0.6)}deg)`;
    await setImg($("scr"), foot(2.76 + clamp(t - tN, 0, 3.2) * 1.0));
  }

  const cw = wordsAt("cta");
  drawEndCard(t, tC - 0.2, { mark: cw[0], pill: cw[1], url: cw[3] });
};
