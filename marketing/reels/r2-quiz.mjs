// Reel 2: "Can you solve this in five seconds?" A placement-style question
// from the Apticks bank, a 5-second countdown, the answer and the trick.
// Scenes: r2-quiz.js.

export default {
  title: "Solve this in 5 seconds",
  bpm: 98,
  rate: 184,
  lead: 0.35,
  tail: 2.4,
  lines: [
    { id: "hook", text: "Can you solve this in five seconds?" },
    { id: "q", text: "The cost price of twenty articles equals the selling price of sixteen. What's the profit percentage?", gap: 0.45 },
    { id: "opts", text: "Is it twenty, twenty-five, sixteen, or thirty percent?", gap: 0.3 },
    { id: "answer", text: "It's twenty-five percent.", gap: 5.6 },
    { id: "why", text: "Sixteen sell for what twenty cost. So you gain four on every sixteen. And four out of sixteen is twenty-five percent.", gap: 0.35 },
    { id: "next", text: "Now try five in a row, against the clock.", gap: 0.4 },
    { id: "cta", text: "Apticks. Play free. Link in bio.", gap: 0.5 },
  ],
  drop: (T) => T.lines.q.t,
  sfx: (T) => {
    const L = T.lines, w = (id, i) => L[id].words[i].t, last = (id) => L[id].words.at(-1).t;
    const cd = L.opts.t + L.opts.d + 0.3;
    return [
      { type: "pop", t: L.hook.t + 0.05 },
      { type: "whoosh", t: L.q.t - 0.4, dur: 0.5, gain: 0.4 },
      { type: "pop", t: w("opts", 2) }, { type: "pop", t: w("opts", 3), pitch: 1.1 }, { type: "pop", t: w("opts", 4), pitch: 1.2 }, { type: "pop", t: w("opts", 6), pitch: 1.3 },
      ...[0, 1, 2, 3, 4].map((k) => ({ type: "tick", t: cd + k, hi: k === 4, gain: 0.3 })),
      { type: "ding", t: L.answer.t - 0.05 },
      { type: "impact", t: L.answer.t - 0.05, gain: 0.35 },
      { type: "whoosh", t: L.why.t - 0.3, dur: 0.45, gain: 0.35 },
      { type: "pop", t: w("why", 0) }, { type: "pop", t: w("why", 6), pitch: 1.12 }, { type: "pop", t: w("why", 13), pitch: 1.25 },
      { type: "whoosh", t: L.next.t - 0.3, dur: 0.45, gain: 0.35 },
      { type: "riser", t: L.cta.t - 1.1, dur: 0.9, gain: 0.15 },
      { type: "whoosh", t: L.cta.t - 0.5, dur: 0.55, gain: 0.45 },
      { type: "impact", t: L.cta.t - 0.06, gain: 0.45 },
      { type: "pop", t: w("cta", 1), pitch: 1.1 },
    ];
  },
};
