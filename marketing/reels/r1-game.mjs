// Reel 1: "Aptitude prep is boring. So we turned it into a game." The
// flagship: what Apticks is, in under 30 seconds. Scenes: r1-game.js.

export default {
  title: "Aptitude prep is boring",
  bpm: 104,
  rate: 186,
  lead: 0.35,
  tail: 2.2,
  lines: [
    { id: "hook", text: "Aptitude prep is boring." },
    { id: "game", text: "So we turned it into a game.", gap: 0.3 },
    { id: "meet", text: "Meet Apticks.", gap: 0.5 },
    { id: "duels", text: "Head-to-head aptitude duels, against someone at your level.", gap: 0.45 },
    { id: "rules", text: "Five questions. Three minutes. Speed counts.", gap: 0.3 },
    { id: "topics", text: "Quant, reasoning and verbal. Just like your placement test.", gap: 0.35 },
    { id: "rating", text: "Win, and your rating climbs.", gap: 0.35 },
    { id: "rank", text: "See where you rank in your college.", gap: 0.3 },
    { id: "friend", text: "Then race your friends live, with one link.", gap: 0.35 },
    { id: "cta", text: "Apticks. Play free. Link in bio.", gap: 0.55 },
  ],
  drop: (T) => T.lines.game.words.at(-1).t,
  sfx: (T) => {
    const L = T.lines, w = (id, i) => L[id].words[i].t, last = (id) => L[id].words.at(-1).t;
    return [
      { type: "riser", t: last("game") - 1.1, dur: 1.1, gain: 0.16 },
      { type: "impact", t: last("game"), gain: 0.7 },
      { type: "whoosh", t: L.meet.t - 0.4, dur: 0.5, gain: 0.4 },
      { type: "pop", t: L.meet.t - 0.08 },
      { type: "whoosh", t: L.duels.t - 0.35, dur: 0.6, gain: 0.45 },
      { type: "pop", t: w("rules", 0) }, { type: "pop", t: w("rules", 2), pitch: 1.12 }, { type: "pop", t: w("rules", 4), pitch: 1.25 },
      { type: "whoosh", t: L.topics.t - 0.25, dur: 0.45, gain: 0.35 },
      { type: "pop", t: w("topics", 0) }, { type: "pop", t: w("topics", 1), pitch: 1.12 }, { type: "pop", t: w("topics", 3), pitch: 1.25 },
      { type: "whoosh", t: L.rating.t - 0.3, dur: 0.5, gain: 0.4 },
      { type: "ding", t: last("rating") },
      { type: "whoosh", t: L.rank.t - 0.2, dur: 0.4, gain: 0.3 },
      { type: "pop", t: last("rank") },
      { type: "whoosh", t: L.friend.t - 0.2, dur: 0.4, gain: 0.3 },
      { type: "pop", t: last("friend") },
      { type: "riser", t: L.cta.t - 1.2, dur: 0.95, gain: 0.16 },
      { type: "whoosh", t: L.cta.t - 0.5, dur: 0.55, gain: 0.45 },
      { type: "impact", t: L.cta.t - 0.06, gain: 0.45 },
      { type: "pop", t: w("cta", 1), pitch: 1.1 },
    ];
  },
};
