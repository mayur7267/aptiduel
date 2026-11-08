// Reel 3: "Three mistakes that cost you the aptitude round." Tips people
// save and share, then how Apticks trains each one. Scenes: r3-mistakes.js.

export default {
  title: "3 mistakes in the aptitude round",
  bpm: 100,
  rate: 186,
  lead: 0.35,
  tail: 2.4,
  lines: [
    { id: "hook", text: "Three mistakes that cost you the aptitude round." },
    { id: "m1", text: "One. Getting stuck on a single question. The clock doesn't wait for you.", gap: 0.5 },
    { id: "m2", text: "Two. Practising without a timer. The real test is a race.", gap: 0.5 },
    { id: "m3", text: "Three. Only practising the topics you're already good at.", gap: 0.5 },
    { id: "fix", text: "Apticks trains all three: timed duels, mixed topics, and a rating that shows how ready you are.", gap: 0.5 },
    { id: "cta", text: "Apticks. Play free. Link in bio.", gap: 0.5 },
  ],
  drop: (T) => T.lines.m1.t - 0.05,
  sfx: (T) => {
    const L = T.lines, w = (id, i) => L[id].words[i].t;
    return [
      { type: "pop", t: L.hook.t + 0.05 },
      ...["m1", "m2", "m3"].flatMap((id) => [
        { type: "whoosh", t: L[id].t - 0.4, dur: 0.5, gain: 0.4 },
        { type: "buzz", t: L[id].t + 0.02 },
      ]),
      { type: "pop", t: w("m1", 8) }, { type: "pop", t: w("m2", 6) }, { type: "pop", t: w("m3", 4) },
      { type: "whoosh", t: L.fix.t - 0.4, dur: 0.5, gain: 0.4 },
      { type: "pop", t: w("fix", 4) }, { type: "pop", t: w("fix", 6), pitch: 1.12 }, { type: "pop", t: w("fix", 10), pitch: 1.25 },
      { type: "riser", t: L.cta.t - 1.1, dur: 0.9, gain: 0.15 },
      { type: "whoosh", t: L.cta.t - 0.5, dur: 0.55, gain: 0.45 },
      { type: "impact", t: L.cta.t - 0.06, gain: 0.45 },
      { type: "pop", t: w("cta", 1), pitch: 1.1 },
    ];
  },
};
