// Sound for the reels: Ava's voice-over, a music bed and sound effects,
// mixed to one 48 kHz stereo WAV. Everything but the voice is synthesised
// here, so there is nothing to license.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";

export const RATE = 48000;

// ---- WAV in and out -----------------------------------------------------

export function readWav(path) {
  const b = readFileSync(path);
  let p = 12, fmt, data;
  while (p < b.length) {
    const id = b.toString("ascii", p, p + 4), size = b.readUInt32LE(p + 4);
    if (id === "fmt ") fmt = { channels: b.readUInt16LE(p + 10), rate: b.readUInt32LE(p + 12), bits: b.readUInt16LE(p + 22) };
    if (id === "data") data = b.subarray(p + 8, p + 8 + size);
    p += 8 + size + (size & 1);
  }
  if (!fmt || fmt.bits !== 16) throw new Error(`${path}: expected 16-bit PCM`);
  const n = data.length / 2 / fmt.channels;
  const out = Array.from({ length: fmt.channels }, () => new Float32Array(n));
  for (let i = 0; i < n; i++) for (let c = 0; c < fmt.channels; c++) out[c][i] = data.readInt16LE((i * fmt.channels + c) * 2) / 32768;
  return { rate: fmt.rate, channels: out };
}

export function writeWav(path, L, R) {
  const n = L.length, b = Buffer.alloc(44 + n * 4);
  b.write("RIFF", 0); b.writeUInt32LE(36 + n * 4, 4); b.write("WAVEfmt ", 8);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(2, 22); b.writeUInt32LE(RATE, 24);
  b.writeUInt32LE(RATE * 4, 28); b.writeUInt16LE(4, 32); b.writeUInt16LE(16, 34); b.write("data", 36); b.writeUInt32LE(n * 4, 40);
  const s = (v) => Math.max(-32768, Math.min(32767, Math.round(v * 32767)));
  for (let i = 0; i < n; i++) { b.writeInt16LE(s(L[i]), 44 + i * 4); b.writeInt16LE(s(R[i]), 46 + i * 4); }
  writeFileSync(path, b);
}

// ---- The voice ------------------------------------------------------------

// Speaks one line with macOS's own voice and trims the silence around it.
export function speak(text, path, { voice = "Ava (Premium)", rate = 185 } = {}) {
  execFileSync("say", ["-v", voice, "-r", String(rate), "--file-format=WAVE", "--data-format=LEI16@48000", "-o", path, text]);
  const { rate: r, channels } = readWav(path);
  if (r !== RATE) throw new Error(`say wrote ${r} Hz, expected ${RATE}`);
  const x = channels[0];
  let a = 0, b = x.length - 1;
  while (a < b && Math.abs(x[a]) < 0.004) a++;
  while (b > a && Math.abs(x[b]) < 0.004) b--;
  const pad = Math.round(0.02 * RATE);
  return x.slice(Math.max(0, a - pad), Math.min(x.length, b + pad));
}

// When each word of a line is said, roughly: by syllables, with a beat
// more for punctuation. Good enough for captions that follow the voice.
export function wordTimes(text, start, dur) {
  const words = text.replace(/\[\[[^\]]*\]\]/g, " ").split(/\s+/).filter(Boolean);
  const weight = (w) => Math.max(1, (w.toLowerCase().match(/[aeiouy]+/g) ?? []).length) + (/[,.:;?!]$/.test(w) ? 0.8 : 0) + 0.35;
  const total = words.reduce((s, w) => s + weight(w), 0);
  let t = start;
  return words.map((w) => { const d = (weight(w) / total) * dur; const o = { w, t, d }; t += d; return o; });
}

// ---- Synth helpers ----------------------------------------------------------

const TAU = Math.PI * 2;
const midi = (n) => 440 * 2 ** ((n - 69) / 12);
let seed = 7;
const noise = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 2147483648 - 1; };

// Band-limited wavetables: a soft saw for pads, odd harmonics for plucks.
const TABLE = 4096;
const table = (harm) => {
  const t = new Float32Array(TABLE);
  for (let i = 0; i < TABLE; i++) for (const [h, a] of harm) t[i] += a * Math.sin((TAU * h * i) / TABLE);
  let m = 0; for (const v of t) m = Math.max(m, Math.abs(v));
  return t.map((v) => v / m);
};
const SAW = table(Array.from({ length: 10 }, (_, k) => [k + 1, 1 / (k + 1)]));
const PLUCK = table([[1, 1], [3, 0.25], [5, 0.08], [2, 0.18]]);
const osc = (tb, phase) => tb[Math.floor((phase - Math.floor(phase)) * TABLE)];

// A Chamberlin state-variable filter, one per voice.
const svf = () => {
  let low = 0, band = 0;
  return (x, fc, q = 0.7) => {
    const f = 2 * Math.sin(Math.PI * Math.min(fc, RATE / 7) / RATE);
    low += f * band; const high = x - low - q * band; band += f * high;
    return { low, band, high };
  };
};

// A small Schroeder reverb.
function reverb(x, { mix = 0.2, room = 0.8, spread = 0 } = {}) {
  const combs = [1557, 1617, 1491, 1422, 1277, 1356].map((d) => ({ buf: new Float32Array(Math.round((d + spread) * 1.09)), i: 0, lp: 0 }));
  const alls = [556, 441, 341].map((d) => ({ buf: new Float32Array(Math.round((d + spread) * 1.09)), i: 0 }));
  const out = new Float32Array(x.length);
  for (let n = 0; n < x.length; n++) {
    let s = 0;
    for (const c of combs) { const y = c.buf[c.i]; c.lp = y * 0.65 + c.lp * 0.35; c.buf[c.i] = x[n] * 0.015 + c.lp * room; c.i = (c.i + 1) % c.buf.length; s += y; }
    for (const a of alls) { const y = a.buf[a.i]; const v = s + y * 0.5; a.buf[a.i] = v; a.i = (a.i + 1) % a.buf.length; s = y - v * 0.5; }
    out[n] = x[n] + s * mix;
  }
  return out;
}

// ---- The music bed ----------------------------------------------------------

// A warm, unobtrusive groove: Fmaj7 - G6 - Em7 - Am7. Before `drop` only
// the pad and the pluck play, with the filter opening; the drums and bass
// come in at the drop. It fades out over the last `fade` seconds.
const CHORDS = [
  { root: 41, notes: [53, 57, 60, 64] },
  { root: 43, notes: [55, 59, 62, 64] },
  { root: 40, notes: [55, 59, 62, 64] },
  { root: 45, notes: [55, 60, 64, 67] },
];
export function music(seconds, { bpm = 104, drop = 0, fade = 1.6 } = {}) {
  const n = Math.round(seconds * RATE), spb = 60 / bpm, bar = spb * 4;
  const padL = new Float32Array(n), padR = new Float32Array(n), plk = new Float32Array(n);
  const drum = new Float32Array(n), bass = new Float32Array(n);
  const fl = svf(), fr = svf(), hat = svf(), clap = svf();
  for (let i = 0; i < n; i++) {
    const t = i / RATE, k = Math.floor(t / bar), inBar = t - k * bar;
    const after = t >= drop;
    // Pad: this bar's chord, and the last one's tail.
    let l = 0, r = 0;
    for (const [kk, g] of [[k, Math.min(1, inBar / 0.35)], [k - 1, Math.max(0, 1 - inBar / 0.5)]]) {
      if (kk < 0 || g <= 0) continue;
      for (const note of CHORDS[kk % 4].notes) {
        const f = midi(note);
        l += g * (osc(SAW, t * f * 0.997) + osc(SAW, t * f * 1.004)) * 0.5;
        r += g * (osc(SAW, t * f * 1.003) + osc(SAW, t * f * 0.996)) * 0.5;
      }
    }
    const open = after ? 1700 + 350 * Math.sin(t * 0.7) : 350 + 1250 * Math.min(1, t / Math.max(drop, 0.01)) ** 2;
    const sinceBeat = t % spb;
    const pump = after ? 1 - 0.42 * Math.exp(-sinceBeat / 0.11) : 1;
    padL[i] = fl(l, open).low * 0.09 * pump;
    padR[i] = fr(r, open).low * 0.09 * pump;
    // Pluck: 16th-note arpeggio over the chord.
    const s16 = spb / 4, step = Math.floor(t / s16), inStep = t - step * s16;
    const notes = CHORDS[k % 4].notes, pattern = [0, 2, 1, 3, 2, 3, 1, 2];
    if (step % 8 !== 7) plk[i] = osc(PLUCK, t * midi(notes[pattern[step % 8]] + 12)) * Math.exp(-inStep / 0.07) * Math.min(1, inStep / 0.002) * 0.06;
    if (!after) continue;
    // Kick on every beat, a soft clap on 2 and 4, hats on the off-beats.
    const beat = Math.floor(t / spb) % 4, tb = sinceBeat;
    const phase = 46 * tb + 80 * 0.028 * (1 - Math.exp(-tb / 0.028));
    let d = Math.sin(TAU * phase) * Math.exp(-tb / 0.2) * 0.55 + noise() * Math.exp(-tb / 0.002) * 0.08;
    if (beat === 1 || beat === 3) {
      const env = Math.exp(-tb / 0.11) * (tb < 0.02 ? 0.6 + 0.4 * Math.cos((tb / 0.01) * TAU) : 1);
      d += clap(noise() * env, 1500, 1.2).band * 0.32;
    }
    const s8 = spb / 2, in8 = t % s8;
    if (Math.floor(t / s8) % 2 === 1) d += hat(noise(), 7000).high * Math.exp(-in8 / 0.03) * 0.07;
    drum[i] = d;
    // Bass: the chord's root on a syncopated 8th-note pattern.
    const e8 = Math.floor(t / s8) % 8;
    if ([0, 3, 4, 6].includes(e8)) {
      const f = midi(CHORDS[k % 4].root + 12);
      const env = Math.min(1, in8 / 0.004) * (0.55 + 0.45 * Math.exp(-in8 / 0.09)) * Math.min(1, (s8 - in8) / 0.02);
      bass[i] = (Math.sin(TAU * f * t) + 0.35 * Math.sin(TAU * 2 * f * t) + 0.12 * Math.sin(TAU * 3 * f * t)) * env * 0.16 * pump;
    }
  }
  // A ping-pong delay on the pluck, then reverb on the melodic parts.
  const dl = Math.round(spb * 0.75 * RATE);
  const pl = new Float32Array(n), pr = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    pl[i] = plk[i] + (i >= dl ? pr[i - dl] * 0.42 : 0);
    pr[i] = i >= dl ? pl[i - dl] * 0.42 : 0;
  }
  const melL = reverb(padL.map((v, i) => v + pl[i] * 0.8), { mix: 0.9, room: 0.82 });
  const melR = reverb(padR.map((v, i) => v + pr[i] * 0.8), { mix: 0.9, room: 0.82, spread: 23 });
  const L = new Float32Array(n), R = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / RATE, g = Math.min(1, (seconds - t) / fade);
    L[i] = (melL[i] + drum[i] + bass[i]) * g;
    R[i] = (melR[i] + drum[i] + bass[i]) * g;
  }
  return [L, R];
}

// ---- Sound effects ----------------------------------------------------------

// Each adds itself into the stereo buffers at time t (seconds).
export const SFX = {
  whoosh(L, R, t, { dur = 0.5, gain = 0.5 } = {}) {
    const f = svf(), a = Math.round(t * RATE), n = Math.round(dur * RATE);
    for (let i = 0; i < n && a + i < L.length; i++) {
      if (a + i < 0) continue;
      const x = i / n, fc = 300 * (12 ** Math.sin(Math.PI * Math.min(1, x * 1.3) * 0.5)), env = Math.sin(Math.PI * x) ** 2;
      const v = f(noise(), fc, 0.5).band * env * gain;
      L[a + i] += v * Math.cos(x * Math.PI * 0.5); R[a + i] += v * Math.sin(x * Math.PI * 0.5);
    }
  },
  pop(L, R, t, { gain = 0.32, pitch = 1 } = {}) {
    const a = Math.round(t * RATE), n = Math.round(0.14 * RATE);
    let ph = 0;
    for (let i = 0; i < n && a + i < L.length; i++) {
      const x = i / RATE; ph += (pitch * (380 + 620 * Math.min(1, x / 0.05))) / RATE;
      const v = Math.sin(TAU * ph) * Math.min(1, x / 0.002) * Math.exp(-x / 0.045) * gain;
      L[a + i] += v; R[a + i] += v;
    }
  },
  tick(L, R, t, { gain = 0.22, hi = false } = {}) {
    const a = Math.round(t * RATE), n = Math.round(0.06 * RATE), f = hi ? 3400 : 2500;
    for (let i = 0; i < n && a + i < L.length; i++) {
      const x = i / RATE, v = (Math.sin(TAU * f * x) * 0.8 + noise() * 0.2) * Math.exp(-x / 0.009) * gain;
      L[a + i] += v; R[a + i] += v;
    }
  },
  ding(L, R, t, { gain = 0.26 } = {}) {
    for (const [f, dt] of [[1046.5, 0], [1568, 0.085]]) {
      const a = Math.round((t + dt) * RATE), n = Math.round(1.1 * RATE);
      for (let i = 0; i < n && a + i < L.length; i++) {
        const x = i / RATE, env = Math.min(1, x / 0.003) * Math.exp(-x / 0.32);
        const v = (Math.sin(TAU * f * x) + 0.28 * Math.sin(TAU * 2 * f * x) + 0.1 * Math.sin(TAU * 3.01 * f * x)) * env * gain;
        L[a + i] += v * (dt ? 0.8 : 1); R[a + i] += v * (dt ? 1 : 0.8);
      }
    }
  },
  impact(L, R, t, { gain = 0.75 } = {}) {
    const a = Math.round(t * RATE), n = Math.round(1.2 * RATE), lp = svf();
    for (let i = 0; i < n && a + i < L.length; i++) {
      const x = i / RATE, ph = 38 * x + 70 * 0.05 * (1 - Math.exp(-x / 0.05));
      const v = (Math.sin(TAU * ph) * Math.exp(-x / 0.35) + lp(noise(), 900).low * Math.exp(-x / 0.06) * 1.4) * gain;
      L[a + i] += v; R[a + i] += v;
    }
  },
  // A soft two-note "nope", for a mistake.
  buzz(L, R, t, { gain = 0.2 } = {}) {
    const lp = svf();
    for (const dt of [0, 0.16]) {
      const a = Math.round((t + dt) * RATE), n = Math.round(0.12 * RATE);
      for (let i = 0; i < n && a + i < L.length; i++) {
        const x = i / RATE, sq = Math.sign(Math.sin(TAU * 155 * x)) * 0.6 + Math.sin(TAU * 310 * x) * 0.4;
        const v = lp(sq, 1400).low * Math.min(1, x / 0.004) * Math.min(1, (0.12 - x) / 0.02) * gain;
        L[a + i] += v; R[a + i] += v;
      }
    }
  },
  riser(L, R, t, { dur = 1.2, gain = 0.22 } = {}) {
    const f = svf(), a = Math.round(t * RATE), n = Math.round(dur * RATE);
    for (let i = 0; i < n && a + i < L.length; i++) {
      if (a + i < 0) continue;
      const x = i / n, v = f(noise(), 400 * 14 ** x, 0.4).band * x * x * gain;
      L[a + i] += v; R[a + i] += v;
    }
  },
};

// ---- The mix ------------------------------------------------------------------

// lines: [{ samples, t }] voice-over clips; sfx: [{ type, t, ...opts }].
// Returns { full: [L, R], voiceOnly: [L, R] }; voiceOnly has the voice and
// effects but no music, for adding a trending sound in Instagram.
export function mix(seconds, lines, sfx, { bpm, drop } = {}) {
  const n = Math.round(seconds * RATE);
  const vo = new Float32Array(n);
  let peak = 0;
  for (const { samples, t } of lines) for (let i = 0; i < samples.length; i++) peak = Math.max(peak, Math.abs(samples[i]));
  for (const { samples, t } of lines) {
    const a = Math.round(t * RATE);
    for (let i = 0; i < samples.length && a + i < n; i++) vo[a + i] += (samples[i] / peak) * 0.72;
  }
  // The music ducks under the voice.
  const duck = new Float32Array(n).fill(1);
  for (const { samples, t } of lines) {
    const a = t - 0.08, b = t + samples.length / RATE + 0.2;
    for (let i = Math.max(0, Math.round((a - 0.12) * RATE)); i < Math.min(n, Math.round((b + 0.25) * RATE)); i++) {
      const x = i / RATE, inside = x < a ? 1 - (a - x) / 0.12 : x > b ? 1 - (x - b) / 0.25 : 1;
      duck[i] = Math.min(duck[i], 1 - 0.62 * Math.max(0, Math.min(1, inside)));
    }
  }
  const [mL, mR] = music(seconds, { bpm, drop });
  const fxL = new Float32Array(n), fxR = new Float32Array(n);
  for (const { type, t, ...o } of sfx) SFX[type](fxL, fxR, t, o);

  const build = (withMusic) => {
    const L = new Float32Array(n), R = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const m = withMusic ? 0.4 * duck[i] : 0;
      L[i] = vo[i] + fxL[i] + mL[i] * m;
      R[i] = vo[i] + fxR[i] + mR[i] * m;
    }
    // Soft-clip the peaks, then settle at -1 dBFS.
    let p = 0;
    for (let i = 0; i < n; i++) { L[i] = Math.tanh(L[i] * 1.15) / 1.15; R[i] = Math.tanh(R[i] * 1.15) / 1.15; p = Math.max(p, Math.abs(L[i]), Math.abs(R[i])); }
    const g = 0.89 / p;
    for (let i = 0; i < n; i++) { L[i] *= g; R[i] *= g; }
    return [L, R];
  };
  return { full: build(true), voiceOnly: build(false) };
}
