// Builds the question bank and writes supabase/seed.sql.
//
// Quant and most reasoning questions come from templates: the numbers
// are random, but the answer is computed, so answer keys can't be wrong
// and nothing is copied from other prep sites. Visual questions are SVG
// figures whose answer is a known turn or flip of the question figure.
// Verbal questions and a few reasoning puzzles are hand-written.
//
// Run from the repo root:  node scripts/generate-questions.ts

import { createHash } from 'node:crypto';
import { writeFileSync } from 'node:fs';

type Section = 'quant' | 'reasoning' | 'verbal';
type Difficulty = 1 | 2 | 3;
type Question = {
  section: Section;
  topic: string;
  difficulty: Difficulty;
  body: string;
  options: string[];
  correctIdx: number;
  explanation: string;
  timeLimit: number;
  template: string;
  figure?: string | null; // SVG shown with the question
  optionFigures?: string[] | null; // SVG per option, when the options are pictures
};
type Draft = Omit<Question, 'template'>;

// ---------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------

// Seeded so re-running produces the same bank.
function mulberry32(seed: number) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(20261024);
const int = (lo: number, hi: number) => lo + Math.floor(rand() * (hi - lo + 1));
const pick = <T>(xs: readonly T[]): T => xs[Math.floor(rand() * xs.length)];
function shuffle<T>(xs: readonly T[]): T[] {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
const gcd = (a: number, b: number): number => (b === 0 ? Math.abs(a) : gcd(b, a % b));
const lcm = (a: number, b: number) => (a / gcd(a, b)) * b;
const isInt = (n: number) => Number.isInteger(n);
const fmt = (n: number) => (isInt(n) ? String(n) : String(Math.round(n * 100) / 100));
const inr = (n: number) => '₹' + n.toLocaleString('en-IN');
const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`;
const days = (n: number) => plural(n, 'day');
const secs = (n: number) => plural(n, 'second');
const pct = (n: number) => `${fmt(n)}%`;
const TIME: Record<Difficulty, number> = { 1: 30, 2: 40, 3: 55 };

// Nearby wrong values: ans ± step, ± 2 step … (positive only).
function near(ans: number, step: number, show: (n: number) => string = fmt): string[] {
  return shuffle([1, -1, 2, -2, 3, -3])
    .map((k) => ans + k * step)
    .filter((v) => v > 0)
    .map(show);
}

// The answer plus the first three usable, distinct distractors, shuffled.
// Distractors are listed most-tempting first (common mistakes), then
// nearby values as filler.
function build(
  section: Section,
  topic: string,
  difficulty: Difficulty,
  body: string,
  answer: string,
  distractors: string[],
  explanation: string,
  timeLimit = TIME[difficulty],
): Draft | null {
  const wrong: string[] = [];
  for (const d of distractors) {
    const bad = d === answer || wrong.includes(d) || d === '' || /NaN|Infinity|^-|^0\b|^₹0$|^0 /.test(d);
    if (!bad) wrong.push(d);
    if (wrong.length === 3) break;
  }
  if (wrong.length < 3) return null;
  const options = shuffle([answer, ...wrong]);
  return { section, topic, difficulty, body, options, correctIdx: options.indexOf(answer), explanation, timeLimit };
}

function fraction(n: number, d: number) {
  const g = gcd(n, d);
  return `${n / g}/${d / g}`;
}

function clockTime(minutes: number) {
  const h24 = Math.floor(minutes / 60) % 24;
  const m = minutes % 60;
  const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
  return `${h12}:${String(m).padStart(2, '0')} ${h24 < 12 ? 'AM' : 'PM'}`;
}

const NAMES = ['Ravi', 'Meena', 'Arjun', 'Sana', 'Kabir', 'Divya', 'Rahul', 'Isha', 'Varun', 'Nisha'];

// ---------------------------------------------------------------------
// Quant templates
// ---------------------------------------------------------------------

type Template = { count: number; make: () => Draft | null };

const quant: Record<string, Template> = {
  percent_of: {
    count: 14,
    make() {
      const p = pick([5, 12, 15, 25, 35, 45, 60, 75, 120, 125, 150]);
      const unit = 100 / gcd(p, 100);
      const n = unit * int(Math.ceil(40 / unit), Math.floor(2400 / unit));
      const ans = (p * n) / 100;
      return build('quant', 'Percentages', 1, `What is ${p}% of ${n}?`, fmt(ans),
        [((p + 5) * n) / 100, ((p - 5) * n) / 100].filter(isInt).map(fmt)
          .concat(near(ans, Math.max(1, Math.round(ans / 10)))),
        `${p}% of ${n} = ${p}/100 × ${n} = ${fmt(ans)}.`);
    },
  },

  successive_change: {
    count: 14,
    make() {
      const a = pick([10, 20, 25, 30, 40, 50]);
      const b = pick([10, 20, 25, 30, 40, 50]);
      const thenFalls = rand() < 0.75;
      const item = pick(['price of a phone', 'salary of an employee', 'population of a town', 'price of a scooter', 'rent of a flat']);
      const net = thenFalls ? a - b - (a * b) / 100 : a + b + (a * b) / 100;
      if (!isInt(net)) return null;
      const label = (x: number) => (x > 0 ? `${fmt(x)}% increase` : x < 0 ? `${fmt(-x)}% decrease` : 'No change');
      const verdict = net > 0 ? `an increase of ${fmt(net)}%` : net < 0 ? `a decrease of ${fmt(-net)}%` : 'no change';
      if (thenFalls) {
        return build('quant', 'Percentages', 2,
          `The ${item} is increased by ${a}% and then decreased by ${b}%. What is the net change?`,
          label(net),
          [label(a - b), label(-net), label(net - 5), label(net + 5), 'No change'],
          `Net change = ${a} − ${b} − (${a} × ${b})/100 = ${fmt(net)}%, which is ${verdict}.`);
      }
      return build('quant', 'Percentages', 2,
        `The ${item} is increased by ${a}% and then by another ${b}%. What is the net change?`,
        label(net),
        [label(a + b), label(net + 5), label(net - 5), label(net + 10)],
        `Net change = ${a} + ${b} + (${a} × ${b})/100 = ${fmt(net)}%, which is ${verdict}.`);
    },
  },

  profit_articles: {
    count: 12,
    make() {
      const x = int(5, 30);
      const y = int(4, x - 1);
      if (((x - y) * 100) % y !== 0) return null;
      const ans = ((x - y) * 100) / y;
      if (ans > 100) return null;
      return build('quant', 'Profit & Loss', 2,
        `The cost price of ${x} articles is equal to the selling price of ${y} articles. What is the profit percentage?`,
        pct(ans),
        [pct(((x - y) * 100) / x), ...near(ans, 5, pct)],
        `Let each article cost ₹1. Then ${y} articles sell for ₹${x}, a profit of ₹${x - y} on ₹${y}. Profit % = ${x - y}/${y} × 100 = ${fmt(ans)}%.`);
    },
  },

  simple_interest: {
    count: 14,
    make() {
      const P = 500 * int(4, 100);
      const R = pick([4, 5, 6, 8, 10, 12, 15]);
      const T = pick([2, 3, 4, 5]);
      const year = (P * R) / 100;
      const ans = year * T;
      return build('quant', 'Interest', 1,
        `What is the simple interest on ${inr(P)} at ${R}% per annum for ${T} years?`,
        inr(ans),
        [inr(year * (T + 1)), inr(year * (T - 1)), inr(ans + 2 * year), inr(year)],
        `SI = P × R × T / 100 = ${inr(P)} × ${R} × ${T} / 100 = ${inr(ans)}.`);
    },
  },

  compound_interest: {
    count: 12,
    make() {
      const r = pick([5, 10, 20]);
      const P = pick([4000, 8000, 10000, 12000, 16000, 20000, 24000, 40000, 50000, 60000]);
      const ci = (P * (200 * r + r * r)) / 10000;
      if (!isInt(ci)) return null;
      const si = (P * r * 2) / 100;
      return build('quant', 'Interest', 2,
        `What is the compound interest on ${inr(P)} at ${r}% per annum for 2 years, compounded annually?`,
        inr(ci),
        [inr(si), inr(ci + (P * r) / 100), inr(2 * ci - si), inr(si - (ci - si))],
        `CI = P[(1 + r/100)² − 1] = ${inr(P)} × [${1 + r / 100}² − 1] = ${inr(ci)}. Simple interest would be ${inr(si)}; the extra ${inr(ci - si)} is interest earned on the first year's interest.`);
    },
  },

  work_together: {
    count: 14,
    make() {
      const a = int(4, 60);
      const b = int(4, 60);
      if (a >= b) return null;
      const t = (a * b) / (a + b);
      if (!isInt(t)) return null;
      const g = gcd(a + b, a * b);
      const num = (a + b) / g;
      const den = (a * b) / g;
      return build('quant', 'Time & Work', 1,
        `A can finish a job in ${a} days and B can finish it in ${b} days. How many days will they take working together?`,
        days(t),
        [(a + b) / 2, b - a].filter(isInt).map(days).concat(near(t, 1, days)),
        `Together they do 1/${a} + 1/${b} = ${num}/${den} of the job per day, so they need ${num === 1 ? '' : `${den}/${num} = `}${t} days.`);
    },
  },

  work_partner_leaves: {
    count: 14,
    make() {
      const a = int(6, 30);
      const b = int(8, 40);
      const k = int(2, 6);
      if (a === b || (k * b) % a !== 0) return null;
      const rem = b - (k * b) / a - k;
      if (rem <= 0) return null;
      return build('quant', 'Time & Work', 3,
        `A can finish a piece of work in ${a} days and B in ${b} days. They work together for ${k} days, then A leaves. In how many more days will B finish the remaining work?`,
        days(rem),
        [days(b - k), days(rem + k), ...near(rem, 1, days)],
        `In ${k} days together they finish ${k}/${a} + ${k}/${b} of the work. B does 1/${b} per day, so B needs ${b} × (1 − ${k}/${a} − ${k}/${b}) = ${b} − ${(k * b) / a} − ${k} = ${rem} more days.`);
    },
  },

  train_pole: {
    count: 12,
    make() {
      const S = pick([36, 54, 72, 90, 108]);
      const v = (S * 5) / 18;
      const t = int(6, 30);
      const L = v * t;
      if (L > 600) return null;
      return build('quant', 'Speed & Distance', 1,
        `A train ${L} m long is running at ${S} km/h. How many seconds will it take to pass a pole?`,
        secs(t),
        [...near(t, 2, secs), ...near(t, 3, secs)],
        `${S} km/h = ${S} × 5/18 = ${v} m/s. Time = ${L} ÷ ${v} = ${t} seconds.`);
    },
  },

  train_platform: {
    count: 12,
    make() {
      const S = pick([36, 54, 72, 90]);
      const v = (S * 5) / 18;
      const L1 = 10 * int(10, 40);
      const L2 = 10 * int(10, 50);
      const total = L1 + L2;
      if (total % v !== 0) return null;
      const t = total / v;
      if (t > 90) return null;
      return build('quant', 'Speed & Distance', 2,
        `A train ${L1} m long, running at ${S} km/h, crosses a platform ${L2} m long. How many seconds does it take?`,
        secs(t),
        [L1 / v, L2 / v].filter(isInt).map(secs).concat(near(t, 3, secs)),
        `It must cover its own length plus the platform: ${L1} + ${L2} = ${total} m. Speed = ${S} × 5/18 = ${v} m/s. Time = ${total} ÷ ${v} = ${t} seconds.`);
    },
  },

  average_removed: {
    count: 12,
    make() {
      const n = pick([5, 6, 7, 8, 10]);
      const a = int(20, 80);
      const b = a + pick([-6, -5, -4, -3, -2, 2, 3, 4, 5, 6]);
      const x = n * a - (n - 1) * b;
      if (x <= 0 || x > 300) return null;
      return build('quant', 'Averages', 2,
        `The average of ${n} numbers is ${a}. When one number is removed, the average of the rest is ${b}. Which number was removed?`,
        String(x),
        [(a - b) * n, a + (a - b)].filter((v) => v > 0).map(String).concat(near(x, n - 1)),
        `Sum of all ${n} = ${n} × ${a} = ${n * a}. Sum of the other ${n - 1} = ${n - 1} × ${b} = ${(n - 1) * b}. Removed number = ${n * a} − ${(n - 1) * b} = ${x}.`);
    },
  },

  ratio_share: {
    count: 12,
    make() {
      const m = int(2, 9);
      const n = int(1, 8);
      if (m === n || gcd(m, n) !== 1) return null;
      const k = 50 * int(1, 40);
      const T = (m + n) * k;
      if (T > 50000) return null;
      const larger = rand() < 0.5;
      const big = Math.max(m, n) * k;
      const small = Math.min(m, n) * k;
      const ans = larger ? big : small;
      return build('quant', 'Ratio', 1,
        `${inr(T)} is divided between Asha and Ben in the ratio ${m}:${n}. What is the ${larger ? 'larger' : 'smaller'} share?`,
        inr(ans),
        [inr(larger ? small : big), ...[T / 2].filter(isInt).map(inr), ...near(ans, k, inr)],
        `Total parts = ${m} + ${n} = ${m + n}. One part = ${inr(T)} ÷ ${m + n} = ${inr(k)}. The ${larger ? 'larger' : 'smaller'} share is ${larger ? Math.max(m, n) : Math.min(m, n)} × ${inr(k)} = ${inr(ans)}.`);
    },
  },

  ages_ratio: {
    count: 12,
    make() {
      const m = int(2, 9);
      const n = int(1, 8);
      if (m <= n || gcd(m, n) !== 1) return null;
      const x = int(2, 8);
      const A = m * x;
      const B = n * x;
      if (A > 70 || B < 4) return null;
      const k = int(2, 15);
      const g = gcd(A + k, B + k);
      const p = (A + k) / g;
      const r = (B + k) / g;
      if (p > 20 || r > 20 || p * n === r * m) return null;
      const years = (y: number) => `${y} years`;
      return build('quant', 'Ages', 3,
        `The present ages of Priya and Karan are in the ratio ${m}:${n}. After ${k} years, the ratio will be ${p}:${r}. What is Priya's present age?`,
        years(A),
        [years(B), years(A + k), years(A + x), years(A - x)],
        `Let the ages be ${m}x and ${n}x. Then ${r}(${m}x + ${k}) = ${p}(${n}x + ${k}), which gives x = ${x}. Priya is ${m} × ${x} = ${A} years old.`);
    },
  },

  unit_digit: {
    count: 12,
    make() {
      const last = pick([2, 3, 4, 7, 8, 9]);
      const base = 10 * int(0, 9) + last;
      const e = int(21, 999);
      const cycle: number[] = [];
      for (let d = last; !cycle.includes(d); d = (d * last) % 10) cycle.push(d);
      const L = cycle.length;
      const pos = ((e - 1) % L) + 1;
      const ans = cycle[pos - 1];
      const others = shuffle([0, 1, 2, 3, 4, 5, 6, 7, 8, 9].filter((d) => d !== ans));
      return build('quant', 'Number System', 2,
        `What is the unit digit of ${base}^${e}?`,
        String(ans),
        [...cycle.filter((d) => d !== ans).map(String), ...others.map(String)],
        `Only the last digit matters. Powers of ${last} end in ${cycle.join(', ')}, repeating every ${L}. ${e} is position ${pos} in that cycle (${e} ÷ ${L} leaves ${e % L}), so the unit digit is ${ans}.`);
    },
  },

  bells_lcm: {
    count: 12,
    make() {
      const xs = shuffle([4, 5, 6, 8, 9, 10, 12, 15, 16, 18, 20, 24, 25, 30, 36, 40, 45])
        .slice(0, 3)
        .sort((p, q) => p - q);
      const L = lcm(lcm(xs[0], xs[1]), xs[2]);
      if (L > 360 || L === xs[2]) return null;
      const start = pick([7, 8, 9, 10]) * 60;
      return build('quant', 'LCM & HCF', 2,
        `Three bells ring at intervals of ${xs[0]}, ${xs[1]} and ${xs[2]} minutes. They ring together at ${clockTime(start)}. When will they next ring together?`,
        clockTime(start + L),
        [L / 2].filter(isInt).map((m) => clockTime(start + m))
          .concat([clockTime(start + 2 * L), clockTime(start + xs[0] + xs[1] + xs[2]), clockTime(start + L + 30)]),
        `They ring together every LCM(${xs.join(', ')}) = ${L} minutes. ${clockTime(start)} + ${L} minutes = ${clockTime(start + L)}.`);
    },
  },

  dice_sum: {
    count: 9,
    make() {
      const s = int(3, 11);
      const ways = 6 - Math.abs(s - 7);
      const pairs: string[] = [];
      for (let i = 1; i <= 6; i++) if (s - i >= 1 && s - i <= 6) pairs.push(`(${i},${s - i})`);
      return build('quant', 'Probability', 2,
        `Two fair dice are thrown. What is the probability that the numbers add up to ${s}?`,
        fraction(ways, 36),
        [fraction(ways + 1, 36), fraction(Math.max(ways - 1, 1), 36), `1/${s}`, fraction(ways + 2, 36)],
        `There are 36 equally likely outcomes. A sum of ${s} comes from ${ways}: ${pairs.join(', ')}. So the probability is ${ways}/36${fraction(ways, 36) === `${ways}/36` ? '' : ` = ${fraction(ways, 36)}`}.`);
    },
  },

  boat_stream: {
    count: 12,
    make() {
      const u = int(6, 20);
      const v = int(1, 5);
      if (v >= u) return null;
      const t1 = int(1, 4);
      const t2 = int(1, 4);
      const down = (u + v) * t1;
      const up = (u - v) * t2;
      const askBoat = rand() < 0.6;
      const kmh = (n: number) => `${n} km/h`;
      return build('quant', 'Boats & Streams', 2,
        `A boat goes ${down} km downstream in ${plural(t1, 'hour')} and ${up} km upstream in ${plural(t2, 'hour')}. What is the speed of ${askBoat ? 'the boat in still water' : 'the stream'}?`,
        kmh(askBoat ? u : v),
        [kmh(askBoat ? v : u), kmh(u + v), kmh(u - v), ...near(askBoat ? u : v, 1, kmh)],
        `Downstream speed = ${down} ÷ ${t1} = ${u + v} km/h. Upstream speed = ${up} ÷ ${t2} = ${u - v} km/h. Boat speed = (${u + v} + ${u - v}) ÷ 2 = ${u} km/h; stream speed = (${u + v} − ${u - v}) ÷ 2 = ${v} km/h.`);
    },
  },

  partnership: {
    count: 12,
    make() {
      const p1 = 1000 * int(5, 60);
      const p2 = 1000 * int(5, 60);
      const t2 = pick([3, 4, 6, 8, 9]);
      const s1 = p1 * 12;
      const s2 = p2 * t2;
      const g = gcd(s1, s2);
      const r1 = s1 / g;
      const r2 = s2 / g;
      if (r1 + r2 > 25) return null;
      const unit = 100 * int(5, 200);
      const profit = (r1 + r2) * unit;
      if (profit > 200000) return null;
      const ans = r1 * unit;
      return build('quant', 'Partnership', 2,
        `A starts a business with ${inr(p1)}. After ${12 - t2} months, B joins with ${inr(p2)}. At the end of the year the profit is ${inr(profit)}. What is A's share?`,
        inr(ans),
        [inr(r2 * unit), ...[(profit * p1) / (p1 + p2)].filter(isInt).map(inr), ...[profit / 2].filter(isInt).map(inr), ...near(ans, unit, inr)],
        `Compare capital × months: A = ${inr(p1)} × 12, B = ${inr(p2)} × ${t2}, a ratio of ${r1}:${r2}. A's share = ${r1}/${r1 + r2} × ${inr(profit)} = ${inr(ans)}.`);
    },
  },

  pass_marks: {
    count: 12,
    make() {
      const p = pick([30, 35, 40, 45, 50]);
      const M = pick([200, 250, 300, 400, 500, 600, 800]);
      const pass = (p * M) / 100;
      if (!isInt(pass)) return null;
      const f = int(5, 40);
      const s = pass - f;
      if (s <= 0) return null;
      return build('quant', 'Percentages', 2,
        `A student needs ${p}% to pass, scored ${s} marks and failed by ${f} marks. What are the maximum marks?`,
        String(M),
        [String(pass), String(M + 50), String(M - 50), String(M + 100)],
        `Pass marks = ${s} + ${f} = ${pass}. That is ${p}% of the maximum, so maximum = ${pass} × 100 / ${p} = ${M}.`);
    },
  },
};

// ---------------------------------------------------------------------
// Reasoning templates
// ---------------------------------------------------------------------

const WORDS = [
  'CAT', 'DOG', 'SUN', 'PEN', 'CUP', 'BOX', 'MAP', 'JAR',
  'BOOK', 'MILK', 'FISH', 'ROAD', 'TREE', 'LAMP', 'GOLD', 'RING', 'STAR', 'KING',
  'BIRD', 'SALT', 'WIND', 'DESK', 'CODE', 'JUMP', 'PLAN', 'NOTE', 'MOON', 'ROSE',
  'PLANT', 'WATER', 'CHAIR', 'TABLE', 'LIGHT', 'RIVER', 'STONE', 'BRICK', 'CLOUD', 'GRAPE',
];
const shiftWord = (w: string, k: number) =>
  [...w].map((c) => String.fromCharCode(((c.charCodeAt(0) - 65 + k + 26 * 3) % 26) + 65)).join('');
const mirrorWord = (w: string) => [...w].map((c) => String.fromCharCode(90 - (c.charCodeAt(0) - 65))).join('');

const reasoning: Record<string, Template> = {
  number_series: {
    count: 30,
    make() {
      const kind = pick(['second', 'mul_add', 'squares', 'cubes', 'alternate']);
      const t: number[] = [];
      let why = '';
      if (kind === 'second') {
        const a = int(2, 20);
        const d = int(2, 6);
        const c = int(1, 4);
        t.push(a);
        for (let i = 0; i < 5; i++) t.push(t[i] + d + i * c);
        const diffs = t.slice(1).map((v, i) => v - t[i]);
        why = `The gaps are ${diffs.slice(0, 4).join(', ')}, growing by ${c} each time. The next gap is ${diffs[4]}, so ${t[4]} + ${diffs[4]} = ${t[5]}.`;
      } else if (kind === 'mul_add') {
        const a = int(1, 6);
        const k = pick([2, 3]);
        const c = pick([-1, 1, 2, 3]);
        t.push(a);
        for (let i = 0; i < 5; i++) t.push(t[i] * k + c);
        if (t[5] > 3000 || t.some((v, i) => v <= 0 || (i > 0 && v <= t[i - 1]))) return null;
        why = `Each term is the previous one × ${k} ${c >= 0 ? '+' : '−'} ${Math.abs(c)}. ${t[4]} × ${k} ${c >= 0 ? '+' : '−'} ${Math.abs(c)} = ${t[5]}.`;
      } else if (kind === 'squares') {
        const n = int(2, 8);
        const c = int(-3, 4);
        for (let i = 0; i < 6; i++) t.push((n + i) ** 2 + c);
        const tail = c === 0 ? '' : ` ${c > 0 ? '+' : '−'} ${Math.abs(c)}`;
        why = `The terms are ${n}²${tail}, ${n + 1}²${tail}, ${n + 2}²${tail}, … so the next is ${n + 5}²${tail} = ${t[5]}.`;
      } else if (kind === 'cubes') {
        const n = int(1, 5);
        const c = int(0, 3);
        for (let i = 0; i < 6; i++) t.push((n + i) ** 3 - c);
        const tail = c === 0 ? '' : ` − ${c}`;
        why = `The terms are ${n}³${tail}, ${n + 1}³${tail}, ${n + 2}³${tail}, … so the next is ${n + 5}³${tail} = ${t[5]}.`;
      } else {
        const x0 = int(2, 20);
        const dx = int(2, 7);
        const y0 = int(40, 90);
        const dy = int(2, 6);
        t.push(x0, y0, x0 + dx, y0 - dy, x0 + 2 * dx, y0 - 2 * dy);
        why = `Two series alternate: ${x0}, ${x0 + dx}, ${x0 + 2 * dx} (adding ${dx}) and ${y0}, ${y0 - dy}, … (subtracting ${dy}). The next term is ${y0 - dy} − ${dy} = ${t[5]}.`;
      }
      const ans = t[5];
      const naive = t[4] + (t[4] - t[3]);
      return build('reasoning', 'Number Series', kind === 'second' || kind === 'squares' ? 1 : 2,
        `What comes next in the series? ${t.slice(0, 5).join(', ')}, ?`,
        String(ans),
        [String(naive), ...near(ans, Math.max(2, Math.round(Math.abs(ans) / 20)))],
        why);
    },
  },

  letter_coding: {
    count: 18,
    make() {
      const w1 = pick(WORDS);
      const same = WORDS.filter((w) => w.length === w1.length && w !== w1);
      const w2 = pick(same);
      const mirror = rand() < 0.25;
      if (mirror) {
        const ans = mirrorWord(w2);
        return build('reasoning', 'Coding-Decoding', 2,
          `In a certain code, ${w1} is written as ${mirrorWord(w1)}. How is ${w2} written in that code?`,
          ans,
          [shiftWord(w2, 1), shiftWord(w2, -1), [...ans].reverse().join(''), w2[0] + ans.slice(1)],
          `Each letter is swapped with its mirror in the alphabet (A↔Z, B↔Y, C↔X …): ${w1[0]} → ${mirrorWord(w1)[0]}. So ${w2} becomes ${ans}.`);
      }
      const k = pick([1, 2, 3, -1, -2]);
      const ans = shiftWord(w2, k);
      return build('reasoning', 'Coding-Decoding', 1,
        `In a certain code, ${w1} is written as ${shiftWord(w1, k)}. How is ${w2} written in that code?`,
        ans,
        [shiftWord(w2, k + (k > 0 ? 1 : -1)), shiftWord(w2, -k), [...ans].reverse().join(''), shiftWord(w2, k > 1 ? k - 1 : k + 2)],
        `Each letter moves ${plural(Math.abs(k), 'place')} ${k > 0 ? 'forward' : 'back'} in the alphabet (${w1[0]} → ${shiftWord(w1, k)[0]}). So ${w2} becomes ${ans}.`);
    },
  },

  direction_sense: {
    count: 16,
    make() {
      // [east leg, north-south leg, straight-line distance]
      const [east, ns, dist] = pick([[3, 4, 5], [4, 3, 5], [6, 8, 10], [8, 6, 10], [5, 12, 13], [12, 5, 13], [9, 12, 15], [12, 9, 15]]);
      const c = int(1, 12);
      const endsNorth = rand() < 0.5;
      const a = endsNorth ? c + ns : c - ns;
      if (a <= 0) return null;
      const name = pick(NAMES);
      const walk = `${name} walks ${a} km north, turns right and walks ${east} km, then turns right again and walks ${c} km.`;
      const where = `${name} ends ${east} km east and ${ns} km ${endsNorth ? 'north' : 'south'} of the start`;
      if (rand() < 0.6) {
        const km = (n: number) => `${n} km`;
        return build('reasoning', 'Direction Sense', 2,
          `${walk} How far is ${name} from the starting point?`,
          km(dist),
          [km(a + east + c), km(east + ns), km(a + c), ...near(dist, 1, km)],
          `${where}. Distance = √(${east}² + ${ns}²) = ${dist} km.`);
      }
      const dir = endsNorth ? 'North-East' : 'South-East';
      return build('reasoning', 'Direction Sense', 2,
        `${walk} In which direction is ${name} from the starting point?`,
        dir,
        ['North-East', 'South-East', 'North-West', 'South-West'],
        `${where}, so the direction is ${dir}.`);
    },
  },

  clock_angle: {
    count: 14,
    make() {
      const H = int(1, 12);
      const M = pick([10, 20, 30, 40, 50]);
      const raw = Math.abs(30 * H - 5.5 * M);
      const ang = raw > 180 ? 360 - raw : raw;
      const naiveRaw = Math.abs(30 * H - 6 * M);
      const naive = naiveRaw > 180 ? 360 - naiveRaw : naiveRaw;
      const deg = (n: number) => `${fmt(n)}°`;
      return build('reasoning', 'Clocks', 2,
        `What is the angle between the hour and minute hands of a clock at ${H}:${String(M).padStart(2, '0')}?`,
        deg(ang),
        [deg(naive), deg(360 - ang), ...near(ang, 5, deg)],
        `Angle = |30 × H − 5.5 × M| = |30 × ${H} − 5.5 × ${M}| = ${fmt(raw)}°${raw > 180 ? `. The smaller angle is 360 − ${fmt(raw)} = ${fmt(ang)}°` : ''}.`);
    },
  },

  calendar_day: {
    count: 14,
    make() {
      const WEEK = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      const STARTS = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
      const [m, d] = pick([[1, 26], [2, 14], [3, 1], [4, 15], [5, 1], [6, 10], [7, 4], [8, 15], [9, 5], [10, 2], [11, 14], [12, 25]]);
      const w = int(0, 6);
      const offset = STARTS[m - 1] + d - 1;
      const ans = WEEK[(w + offset) % 7];
      const date = `${d} ${MONTHS[m - 1]}`;
      return build('reasoning', 'Calendars', 2,
        `In a non-leap year, 1 January is a ${WEEK[w]}. What day of the week is ${date}?`,
        ans,
        [WEEK[(w + offset + 1) % 7], WEEK[(w + offset + 6) % 7], WEEK[w], WEEK[(w + offset + 2) % 7]],
        `${date} is ${offset} days after 1 January. ${offset} = 7 × ${Math.floor(offset / 7)} + ${offset % 7}, so it falls ${plural(offset % 7, 'day')} after ${WEEK[w]}: ${ans}.`,
        45);
    },
  },

  odd_one_out: {
    count: 14,
    make() {
      const kind = pick(['squares', 'cubes', 'primes', 'sevens']);
      let members: number[] = [];
      let intruder = 0;
      let what = '';
      let reason = '';
      if (kind === 'squares') {
        members = shuffle([6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]).slice(0, 3).map((n) => n * n);
        const n = int(7, 19);
        intruder = n * n + int(2, 2 * n - 1);
        what = 'perfect squares';
      } else if (kind === 'cubes') {
        members = shuffle([2, 3, 4, 5, 6, 7, 8, 9]).slice(0, 3).map((n) => n ** 3);
        const n = int(3, 9);
        intruder = n ** 3 + pick([-2, -1, 1, 2, 3]);
        what = 'perfect cubes';
      } else if (kind === 'primes') {
        members = shuffle([23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97]).slice(0, 3);
        intruder = pick([21, 27, 33, 39, 49, 51, 57, 63, 69, 77, 81, 87, 91, 93]);
        const f = [3, 7, 13].find((p) => intruder % p === 0) ?? 3;
        what = 'prime numbers';
        reason = ` (${intruder} = ${f} × ${intruder / f})`;
      } else {
        members = shuffle([35, 42, 49, 56, 63, 77, 84, 91, 98, 105, 112, 119]).slice(0, 3);
        intruder = 7 * int(5, 16) + pick([1, 2, 3, 4, 5]);
        what = 'multiples of 7';
      }
      if (members.includes(intruder)) return null;
      const shown = shuffle([...members, intruder]);
      return build('reasoning', 'Odd One Out', 1,
        `Find the odd one out: ${shown.join(', ')}`,
        String(intruder),
        members.map(String),
        `${members.join(', ')} are ${what}. ${intruder} is not${reason}.`);
    },
  },
};

// ---------------------------------------------------------------------
// More logical reasoning
// ---------------------------------------------------------------------

const letter = (i: number) => String.fromCharCode(65 + i);
function ord(n: number) {
  const teen = n % 100 >= 11 && n % 100 <= 13;
  const suffix = teen ? 'th' : ({ 1: 'st', 2: 'nd', 3: 'rd' } as Record<number, string>)[n % 10] ?? 'th';
  return `${n}${suffix}`;
}

const logic: Record<string, Template> = {
  letter_series: {
    count: 12,
    make() {
      if (rand() < 0.6) {
        const s = int(0, 8);
        const d = int(2, 5);
        if (s + 5 * d > 25) return null;
        const t = [0, 1, 2, 3, 4].map((k) => letter(s + k * d));
        return build('reasoning', 'Letter Series', 1,
          `What comes next in the series? ${t.slice(0, 4).join(', ')}, ?`,
          t[4],
          [letter(s + 4 * d + 1), letter(s + 4 * d - 1), letter(s + 5 * d), letter(s + 3 * d + 1)],
          `Each letter is ${d} places after the one before: ${t.slice(0, 4).join(' → ')}. ${d} places after ${t[3]} is ${t[4]}.`);
      }
      const s = int(0, 8);
      const d = pick([1, 2]);
      if (s + 5 * d > 12) return null;
      const first = (k: number) => letter(s + k * d);
      const second = (k: number) => letter(25 - s - k * d);
      const pair = (k: number) => first(k) + second(k);
      const ans = pair(4);
      return build('reasoning', 'Letter Series', 2,
        `What comes next in the series? ${[0, 1, 2, 3].map(pair).join(', ')}, ?`,
        ans,
        [second(4) + first(4), first(4) + letter(26 - s - 4 * d), letter(s + 4 * d + 1) + second(4), pair(5)],
        `The first letters move ${d} forward (${[0, 1, 2, 3, 4].map(first).join(', ')}) while the second letters move ${d} back from Z (${[0, 1, 2, 3, 4].map(second).join(', ')}). So the next pair is ${ans}.`);
    },
  },

  row_position: {
    count: 12,
    make() {
      const name = pick(NAMES);
      if (rand() < 0.5) {
        const n = int(20, 60);
        const l = int(3, n - 3);
        const ans = n - l + 1;
        return build('reasoning', 'Ranking', 1,
          `In a row of ${n} students, ${name} is ${ord(l)} from the left end. What is ${name}'s position from the right end?`,
          ord(ans),
          [ord(n - l), ord(ans + 1), ord(l), ord(ans - 2), ord(ans + 2)],
          `${l - 1} students are to the left of ${name}, so ${n} − ${l} = ${n - l} are to the right. That makes ${name} ${ord(ans)} from the right.`);
      }
      const l = int(5, 25);
      const r = int(5, 25);
      const ans = l + r - 1;
      return build('reasoning', 'Ranking', 2,
        `${name} is ${ord(l)} from the left end of a row and ${ord(r)} from the right end. How many people are in the row?`,
        String(ans),
        [String(l + r), String(l + r - 2), String(l + r + 1)],
        `Counting from both ends counts ${name} twice, so the row has ${l} + ${r} − 1 = ${ans} people.`);
    },
  },

  number_analogy: {
    count: 10,
    make() {
      const rules = [
        { f: (n: number) => n ** 3, how: (n: number) => `${n}³` },
        { f: (n: number) => n * n + 1, how: (n: number) => `${n}² + 1` },
        { f: (n: number) => n * n - 1, how: (n: number) => `${n}² − 1` },
        { f: (n: number) => n * (n + 1), how: (n: number) => `${n} × ${n + 1}` },
        { f: (n: number) => 2 * n + 3, how: (n: number) => `2 × ${n} + 3` },
      ];
      const r = pick(rules);
      const a = int(2, 9);
      const b = int(2, 12);
      if (a === b) return null;
      // Reject pairs that a second obvious rule also explains (3 : 9 is
      // both ×3 and squaring), or where "add the same number" lands on
      // another option. Those have two defensible answers.
      const obvious = [...rules.map((x) => x.f), (n: number) => n * n, (n: number) => 2 * n, (n: number) => 3 * n];
      if (obvious.some((g) => g !== r.f && g(a) === r.f(a) && g(b) !== r.f(b))) return null;
      return build('reasoning', 'Analogies', 2,
        `Find the missing number. ${a} : ${r.f(a)} :: ${b} : ?`,
        String(r.f(b)),
        [...shuffle(rules.filter((x) => x !== r).map((x) => String(x.f(b)))), String(r.f(b) + b)],
        `${r.f(a)} = ${r.how(a)}. The same rule for ${b} gives ${r.how(b)} = ${r.f(b)}.`);
    },
  },

  alphabet_position: {
    count: 8,
    make() {
      const p = int(4, 16);
      const k = int(3, 9);
      if (p + k > 24) return null;
      const ans = letter(p + k - 1);
      return build('reasoning', 'Alphabet Test', 2,
        `In the English alphabet, which letter is ${ord(k)} to the right of the ${ord(p)} letter from the left?`,
        ans,
        [letter(p + k - 2), letter(p + k), letter(p + k + 1), letter(p - 1)],
        `The ${ord(p)} letter is ${letter(p - 1)}. Moving ${k} places to the right gives the ${ord(p + k)} letter, ${ans}.`);
    },
  },
};

// ---------------------------------------------------------------------
// Visual reasoning
// Figures are small SVGs drawn in currentColor so they follow the app's
// text colour. Each answer is a known turn or flip of the question
// figure, so it is right by construction.
// ---------------------------------------------------------------------

const svg = (w: number, h: number, body: string) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;

// Shapes with no symmetry at all, so every turn and every mirror image
// looks clearly different. Drawn around (0, 0) within ±32. Avoid shapes
// whose only asymmetry is a small detail (an arrow's tail barb, an L
// with nearly equal arms): their mirror images look like rotations.
const GLYPHS = [
  '<path d="M-18 32V-32H18L8-20L18-8H-18"/>', // flag
  '<path d="M-22-26H22V26H0"/>', // hook
  '<path d="M-14 32V-32H8A16 16 0 0 1 8 0H-14"/>', // P
  '<path d="M-14 32V-32H18M-14-2H10"/>', // F
];

// angle: clockwise turn in degrees. flip: then mirrored left to right.
type Pose = { angle: number; flip: boolean };
const norm = (a: number) => ((a % 360) + 360) % 360;
const pose = (g: string, p: Pose, x = 50, y = 50) =>
  `<g transform="translate(${x} ${y})${p.flip ? ' scale(-1 1)' : ''} rotate(${norm(p.angle)})">${g}</g>`;
const cell = (inner: string) => svg(100, 100, inner);
const box = (x: number, dashed = false) =>
  `<rect x="${x + 3}" y="3" width="94" height="94" rx="12" stroke-width="2" opacity=".35"${dashed ? ' stroke-dasharray="6 6"' : ''}/>`;
const qmark = (x: number, y = 50) =>
  `<text x="${x}" y="${y}" font-size="44" font-weight="700" font-family="system-ui, sans-serif" fill="currentColor" stroke="none" text-anchor="middle" dominant-baseline="central">?</text>`;

// A row of figures ending in a "?" box.
function strip(items: string[]) {
  const parts = items.map((inner, i) => box(i * 110) + `<g transform="translate(${i * 110} 0)">${inner}</g>`);
  const last = items.length * 110;
  parts.push(box(last, true) + qmark(last + 50));
  return svg(last + 100, 100, parts.join(''));
}

function polygon(k: number) {
  const pts = Array.from({ length: k }, (_, i) => {
    const t = -Math.PI / 2 + (2 * Math.PI * i) / k;
    return `${(50 + 36 * Math.cos(t)).toFixed(1)} ${(50 + 36 * Math.sin(t)).toFixed(1)}`;
  });
  return `<path d="M${pts.join('L')}Z"/>`;
}

const dots = (n: number) =>
  Array.from({ length: n }, (_, i) =>
    `<circle cx="${25 + (i % 3) * 25}" cy="${25 + Math.floor(i / 3) * 25}" r="8" fill="currentColor" stroke="none"/>`).join('');

type Shape = 'circle' | 'square' | 'triangle';
type Fill = 'empty' | 'dotted' | 'solid';
function shapeAt(shape: Shape, fill: Fill, cx: number, cy: number) {
  const solid = fill === 'solid' ? ' fill="currentColor"' : '';
  let s =
    shape === 'circle' ? `<circle cx="${cx}" cy="${cy}" r="24"${solid}/>`
    : shape === 'square' ? `<rect x="${cx - 22}" y="${cy - 22}" width="44" height="44"${solid}/>`
    : `<path d="M${cx} ${cy - 26}L${cx + 26} ${cy + 20}H${cx - 26}Z"${solid}/>`;
  if (fill === 'dotted') s += `<circle cx="${cx}" cy="${shape === 'triangle' ? cy + 5 : cy}" r="6" fill="currentColor" stroke="none"/>`;
  return s;
}

const LETTERS = 'ABCD';

// Picture options: the answer plus three distinct wrong figures, shuffled.
function visual(
  topic: string,
  difficulty: Difficulty,
  body: string,
  figure: string | null,
  answer: string,
  distractors: string[],
  explain: (letter: string) => string,
  timeLimit = 45,
): Draft | null {
  const wrong: string[] = [];
  for (const d of distractors) {
    if (d !== answer && !wrong.includes(d)) wrong.push(d);
    if (wrong.length === 3) break;
  }
  if (wrong.length < 3) return null;
  const figures = shuffle([answer, ...wrong]);
  const idx = figures.indexOf(answer);
  return {
    section: 'reasoning', topic, difficulty, body,
    options: ['Figure A', 'Figure B', 'Figure C', 'Figure D'],
    correctIdx: idx, explanation: explain(LETTERS[idx]), timeLimit,
    figure, optionFigures: figures,
  };
}

const visualTemplates: Record<string, Template> = {
  figure_rotation: {
    count: 14,
    make() {
      const g = pick(GLYPHS);
      const step = pick([45, 90, 90, 135]) * pick([1, -1]);
      const a0 = 45 * int(0, 7);
      const at = (k: number): Pose => ({ angle: a0 + k * step, flip: false });
      const turn = `${Math.abs(step)}° ${step > 0 ? 'clockwise' : 'anticlockwise'}`;
      return visual('Figure Series', 2, 'Which figure comes next in the series?',
        strip([0, 1, 2, 3].map((k) => pose(g, at(k)))),
        cell(pose(g, at(4))),
        shuffle([at(3), { ...at(4), flip: true }, at(5), { angle: a0 + 4 * step + 180, flip: false }])
          .map((p) => cell(pose(g, p))),
        (l) => `The figure turns ${turn} at every step. Turning the last figure ${turn} once more gives option ${l}.`);
    },
  },

  mirror_image: {
    count: 12,
    make() {
      const g = pick(GLYPHS);
      const a = pick([0, 45, 90, 135, 180, 270]);
      const vertical = rand() < 0.6;
      const p: Pose = { angle: a, flip: false };
      // A mirror to the right flips left-right. A mirror below flips
      // top-bottom, which is a left-right flip turned 180°.
      const ans: Pose = vertical ? { angle: a, flip: true } : { angle: a + 180, flip: true };
      const otherMirror: Pose = vertical ? { angle: a + 180, flip: true } : { angle: a, flip: true };
      const fig = vertical
        ? svg(150, 100, pose(g, p) + '<path d="M118 4V96" stroke-width="3" stroke-dasharray="7 7"/>')
        : svg(100, 150, pose(g, p) + '<path d="M4 118H96" stroke-width="3" stroke-dasharray="7 7"/>');
      return visual('Mirror Images', 2,
        `Which option is the mirror image of the figure in the dashed ${vertical ? 'vertical' : 'horizontal'} line?`,
        fig,
        cell(pose(g, ans)),
        shuffle([p, otherMirror, { angle: a + 180, flip: false }, { angle: a + 90, flip: false }])
          .map((x) => cell(pose(g, x))),
        (l) => vertical
          ? `A mirror to the right swaps left and right but keeps top and bottom where they are. Option ${l} is the figure flipped left to right.`
          : `A mirror below swaps top and bottom but keeps left and right where they are. Option ${l} is the figure flipped upside down, not turned.`);
    },
  },

  odd_figure: {
    count: 12,
    make() {
      const g = pick(GLYPHS);
      const angles = shuffle([0, 45, 90, 135, 180, 225, 270, 315]).slice(0, 4);
      return visual('Odd Figure Out', 2,
        'Three of these figures are the same shape, just turned. Which one is different?',
        null,
        cell(pose(g, { angle: angles[3], flip: true })),
        angles.slice(0, 3).map((a) => cell(pose(g, { angle: a, flip: false }))),
        (l) => `Turn the figures and three of them line up exactly. Option ${l} is a mirror image, and no amount of turning makes a mirror image.`);
    },
  },

  count_series: {
    count: 8,
    make() {
      if (rand() < 0.5) {
        const s = int(3, 4);
        return visual('Figure Series', 1, 'Which figure comes next in the series?',
          strip([0, 1, 2, 3].map((i) => polygon(s + i))),
          cell(polygon(s + 4)),
          [s + 3, s + 5, s + 6, s + 2].map((k) => cell(polygon(k))),
          (l) => `Each figure has one more side than the one before: ${[0, 1, 2, 3].map((i) => s + i).join(', ')}. The next has ${s + 4} sides, which is option ${l}.`,
          40);
      }
      const d = pick([1, 2]);
      const c0 = d === 2 ? 1 : int(1, 5);
      const ans = c0 + 4 * d;
      return visual('Figure Series', 1, 'Which figure comes next in the series?',
        strip([0, 1, 2, 3].map((i) => dots(c0 + i * d))),
        cell(dots(ans)),
        [ans - d, ans + 1, ans - 1, ans + d, ans - 2, ans + 2, ans - 3]
          .filter((n) => n >= 1 && n <= 9)
          .map((n) => cell(dots(n))),
        (l) => `The number of dots goes up by ${d} each time: ${[0, 1, 2, 3].map((i) => c0 + i * d).join(', ')}. The next figure has ${ans} dots, which is option ${l}.`,
        40);
    },
  },

  dot_path: {
    count: 10,
    make() {
      // Corners and middles of the sides, clockwise from top-left.
      const spots = [[22, 22], [50, 22], [78, 22], [78, 50], [78, 78], [50, 78], [22, 78], [22, 50]];
      const s = int(0, 7);
      const step = pick([1, 2, 3]) * pick([1, -1]);
      const at = (k: number) => {
        const [x, y] = spots[(((s + k * step) % 8) + 8) % 8];
        return `<rect x="22" y="22" width="56" height="56" rx="3" stroke-width="4"/><circle cx="${x}" cy="${y}" r="9" fill="currentColor" stroke="none"/>`;
      };
      const dir = step > 0 ? 'clockwise' : 'anticlockwise';
      const n = Math.abs(step);
      return visual('Figure Series', 2, 'The dot moves around the square in a fixed pattern. Where will it be next?',
        strip([0, 1, 2, 3].map(at)),
        cell(at(4)),
        [cell(at(3)), cell(at(5)), cell(at(-4)), cell(at(6))],
        (l) => `The dot moves ${n} spot${n > 1 ? 's' : ''} ${dir} each time, counting corners and the middles of the sides. One more move puts it where option ${l} shows.`);
    },
  },

  pattern_matrix: {
    count: 12,
    make() {
      const shapes = shuffle<Shape>(['circle', 'square', 'triangle']);
      const fills = shuffle<Fill>(['empty', 'dotted', 'solid']);
      const sa = pick([1, 2]);
      const fb = pick([1, 2]);
      const sh = (i: number, j: number) => shapes[(sa * i + j) % 3];
      const fl = (i: number, j: number) => fills[(i + fb * j) % 3];
      let body = '<path d="M5 5H295V295H5Z" stroke-width="2" opacity=".35"/><path d="M100 5V295M200 5V295M5 100H295M5 200H295" stroke-width="2" opacity=".35"/>';
      for (let i = 0; i < 3; i++) {
        for (let j = 0; j < 3; j++) {
          if (i === 2 && j === 2) continue;
          body += shapeAt(sh(i, j), fl(i, j), 50 + 100 * j, 50 + 100 * i);
        }
      }
      body += qmark(250, 250);
      const ansShape = sh(2, 2);
      const ansFill = fl(2, 2);
      const others = [
        ...fills.filter((f) => f !== ansFill).map((f) => cell(shapeAt(ansShape, f, 50, 50))),
        ...shapes.filter((x) => x !== ansShape).map((x) => cell(shapeAt(x, ansFill, 50, 50))),
      ];
      return visual('Pattern Matrix', 2, 'Which figure completes the grid?',
        svg(300, 300, body),
        cell(shapeAt(ansShape, ansFill, 50, 50)),
        shuffle(others),
        (l) => `Every row and every column has one circle, one square and one triangle, and one empty, one dotted and one solid shape. The bottom row is missing a ${ansShape} and the right column is missing a ${ansFill} shape, so the answer is the ${ansFill} ${ansShape}: option ${l}.`,
        50);
    },
  },
};

// ---------------------------------------------------------------------
// Hand-written questions: [topic, difficulty, body, answer, wrong x3, explanation]
// ---------------------------------------------------------------------

type Curated = [string, Difficulty, string, string, [string, string, string], string];

const curatedReasoning: Curated[] = [
  ['Blood Relations', 2, `Pointing to a man, Neha said, "He is the only son of my grandfather's only son." How is the man related to Neha?`, 'Brother', ['Father', 'Cousin', 'Uncle'], `Neha's grandfather's only son is Neha's father, and her father's only son is her brother.`],
  ['Blood Relations', 2, 'A is the brother of B. B is the sister of C. C is the father of D. How is A related to D?', 'Uncle', ['Father', 'Brother', 'Grandfather'], 'A, B and C are siblings. C is D\'s father, so A (male) is D\'s uncle.'],
  ['Blood Relations', 2, `Introducing a woman, Rohit said, "Her mother is the only daughter of my mother." How is the woman related to Rohit?`, 'Niece', ['Sister', 'Daughter', 'Cousin'], `The only daughter of Rohit's mother is Rohit's sister. The woman is his sister's daughter, so his niece.`],
  ['Blood Relations', 1, 'P is the father of Q. Q is the son of R. How is R related to P?', 'Wife', ['Sister', 'Mother', 'Daughter'], 'P is the father and R is the other parent of Q, so R is the mother and P\'s wife.'],
  ['Blood Relations', 1, `X's mother is the sister of Y's father. How is X related to Y?`, 'Cousin', ['Brother', 'Nephew', 'Uncle'], `X's mother and Y's father are siblings, so X and Y are cousins.`],
  ['Blood Relations', 2, `Pointing to a photo, Arun said, "She is the daughter of my grandfather's only son." How is the girl related to Arun?`, 'Sister', ['Cousin', 'Niece', 'Aunt'], `Arun's grandfather's only son is Arun's father, so the girl is his father's daughter: his sister.`],
  ['Blood Relations', 3, 'M is the son of N. N is the daughter of O. O is the husband of P. How is P related to M?', 'Grandmother', ['Mother', 'Aunt', 'Grandfather'], 'O and P are N\'s parents, and M is N\'s son, so P is M\'s grandmother.'],
  ['Blood Relations', 2, `A's father is B's son. C is B's only daughter. How is C related to A?`, 'Aunt', ['Mother', 'Sister', 'Grandmother'], `C is the sister of A's father, so C is A's aunt.`],
  ['Blood Relations', 2, `Pointing to a man, Kavya said, "His wife is my mother's only daughter." How is the man related to Kavya?`, 'Husband', ['Father', 'Brother', 'Brother-in-law'], `Kavya's mother's only daughter is Kavya herself, so the man is Kavya's husband.`],
  ['Blood Relations', 3, 'J is the brother of K. L is the mother of J. M is the father of L. How is M related to K?', 'Grandfather', ['Father', 'Uncle', 'Brother'], 'L is the mother of J and K, and M is L\'s father, so M is K\'s grandfather.'],
  ['Syllogisms', 1, 'Statements: All pens are books. All books are bags. Which conclusion follows?', 'All pens are bags', ['All bags are pens', 'Some bags are not books', 'No pen is a bag'], 'Pens sit inside books, and books sit inside bags, so every pen is a bag.'],
  ['Syllogisms', 2, 'Statements: Some cats are dogs. All dogs are birds. Which conclusion follows?', 'Some cats are birds', ['All cats are birds', 'No cat is a bird', 'All birds are cats'], 'The cats that are dogs are also birds, so some cats are birds.'],
  ['Syllogisms', 2, 'Statements: No apple is a mango. All mangoes are fruits. Which conclusion follows?', 'Some fruits are not apples', ['No apple is a fruit', 'All fruits are mangoes', 'Some apples are mangoes'], 'Mangoes are fruits and no mango is an apple, so at least those fruits are not apples.'],
  ['Syllogisms', 2, 'Statements: All roses are flowers. Some flowers are red. Which conclusion definitely follows?', 'Some flowers are roses', ['Some roses are red', 'All flowers are roses', 'No rose is red'], 'Since every rose is a flower, some flowers are roses. Nothing links roses to the red flowers.'],
  ['Syllogisms', 1, 'Statements: All doctors are graduates. No graduate is unemployed. Which conclusion follows?', 'No doctor is unemployed', ['All graduates are doctors', 'Some doctors are unemployed', 'Some unemployed people are graduates'], 'Every doctor is a graduate and no graduate is unemployed, so no doctor is unemployed.'],
  ['Syllogisms', 2, 'Statements: Some laptops are phones. No phone is a tablet. Which conclusion follows?', 'Some laptops are not tablets', ['No laptop is a tablet', 'All phones are laptops', 'Some tablets are phones'], 'The laptops that are phones cannot be tablets, so some laptops are not tablets.'],
  // Word analogies
  ['Analogies', 1, 'Book : Library :: Painting : ?', 'Gallery', ['Frame', 'Artist', 'Canvas'], 'A library is where books are kept and shown; a gallery is where paintings are.'],
  ['Analogies', 1, 'Doctor : Hospital :: Teacher : ?', 'School', ['Student', 'Book', 'Lesson'], 'A doctor works in a hospital; a teacher works in a school.'],
  ['Analogies', 1, 'Cow : Herd :: Wolf : ?', 'Pack', ['Flock', 'Swarm', 'Den'], 'A group of cows is a herd; a group of wolves is a pack.'],
  ['Analogies', 1, 'Pen : Write :: Knife : ?', 'Cut', ['Sharp', 'Kitchen', 'Steel'], 'A pen is used to write; a knife is used to cut.'],
  ['Analogies', 2, 'Thermometer : Temperature :: Barometer : ?', 'Pressure', ['Rainfall', 'Humidity', 'Wind speed'], 'A thermometer measures temperature; a barometer measures air pressure.'],
  ['Analogies', 1, 'Eye : See :: Ear : ?', 'Hear', ['Sound', 'Noise', 'Speak'], 'Eyes are used to see; ears are used to hear.'],
  ['Analogies', 1, 'Carpenter : Wood :: Tailor : ?', 'Cloth', ['Needle', 'Shirt', 'Scissors'], 'A carpenter works with wood; a tailor works with cloth.'],
  ['Analogies', 1, 'Water : Thirst :: Food : ?', 'Hunger', ['Taste', 'Kitchen', 'Cook'], 'Water ends thirst; food ends hunger.'],
  ['Analogies', 1, 'Seed : Tree :: Egg : ?', 'Bird', ['Nest', 'Shell', 'Yolk'], 'A seed grows into a tree; an egg grows into a bird.'],
  ['Analogies', 2, 'Kilometre : Distance :: Kilogram : ?', 'Mass', ['Volume', 'Length', 'Speed'], 'A kilometre is a unit of distance; a kilogram is a unit of mass.'],
  // Seating and ordering
  ['Seating Arrangement', 2, 'Five friends sit in a row facing north. C is at the extreme left and E at the extreme right. D sits between C and B, and A is to the immediate right of B. Who sits in the middle?', 'B', ['D', 'A', 'C'], 'From the left: C, D, B, A, E. B is in the middle.'],
  ['Seating Arrangement', 3, 'Six people P, Q, R, S, T and U sit around a round table facing the centre. P is opposite S. Q is to the immediate left of P and T to the immediate right of P. R is opposite Q. Who is opposite T?', 'U', ['R', 'Q', 'S'], 'Facing the centre, your left is the clockwise side. Going clockwise from P: P, Q, U, S, R, T. T is opposite U.'],
  ['Seating Arrangement', 2, 'Five houses stand in a row. The white house is at the far left and the yellow house at the far right. The red house is to the right of the green house but to the left of the blue house. Which house is in the middle?', 'Red', ['Green', 'Blue', 'White'], 'From the left: white, green, red, blue, yellow. Red is in the middle.'],
  ['Seating Arrangement', 2, 'A, B, C, D and E stand in a queue. B is ahead of A but behind E. C is ahead of D but behind A. Who is third in the queue?', 'A', ['B', 'C', 'E'], 'From the front: E, B, A, C, D. A is third.'],
  ['Ranking', 2, 'Among P, Q, R, S and T, Q is taller than only T. R is taller than Q but shorter than both P and S. P is not the tallest. Who is the tallest?', 'S', ['P', 'R', 'Q'], 'T is shortest, then Q, then R. P and S are taller than R, and P is not the tallest, so S is.'],
  ['Ranking', 1, 'Seven books are stacked in a pile. The Maths book is 4th from the top, and the English book is just above it. How many books are below the English book?', '4', ['3', '5', '2'], 'The English book is 3rd from the top, so 7 − 3 = 4 books are below it.'],
  // Inequalities
  ['Inequalities', 2, 'If P > Q, Q ≥ R and R > S, which of these is definitely true?', 'P > S', ['Q < S', 'R ≥ P', 'S > Q'], 'P > Q ≥ R > S, so P is greater than S.'],
  ['Inequalities', 2, 'If A ≥ B, B = C and C > D, which of these is definitely true?', 'A > D', ['A = D', 'B < D', 'D ≥ A'], 'A ≥ B = C > D. Even if A equals B, it is still greater than D.'],
  ['Inequalities', 2, 'If M < N, N ≤ O and O < P, which of these is definitely true?', 'M < P', ['N > P', 'M ≥ O', 'P ≤ N'], 'M < N ≤ O < P, so M is less than P.'],
  ['Inequalities', 3, 'If X ≥ Y and Y ≥ Z, which of these must be true?', 'X ≥ Z', ['X > Z', 'Z > X', 'Y > X'], 'X ≥ Y ≥ Z gives X ≥ Z. "X > Z" is not certain, because all three could be equal.'],
];

// Classic interview puzzles. Longer to read, so they get more time.
const PUZZLE_TIME: Record<Difficulty, number> = { 1: 40, 2: 55, 3: 75 };

const curatedPuzzles: Curated[] = [
  ['Puzzles', 2, 'There are 25 horses and a track that races 5 at a time. There is no stopwatch, so a race only tells you the finishing order. What is the fewest races needed to find the single fastest horse?', '6', ['5', '7', '25'], 'Race 5 groups of 5, then race the 5 group winners. The winner of that 6th race is the fastest.'],
  ['Puzzles', 3, 'There are 25 horses and a track that races 5 at a time. There is no stopwatch, so a race only tells you the finishing order. What is the fewest races needed to find the 3 fastest horses?', '7', ['6', '8', '11'], 'Race 5 groups of 5 (5 races), then race the group winners (race 6); its winner is the fastest. Only 5 horses can still be 2nd or 3rd: the 2nd and 3rd of race 6, the 2nd and 3rd from the fastest horse\'s group, and the 2nd from the runner-up\'s group. Race them (race 7).'],
  ['Puzzles', 3, '100 doors are all closed. On pass 1 you toggle every door, on pass 2 every 2nd door, on pass 3 every 3rd door, and so on up to pass 100. How many doors are open at the end?', '10', ['50', '25', '1'], 'A door is toggled once for each of its factors. Only perfect squares have an odd number of factors, so doors 1, 4, 9, …, 100 end up open: 10 doors.'],
  ['Puzzles', 3, '100 doors start closed. On pass k (k = 1 to 100) you toggle every k-th door. Which of these doors is open at the end?', 'Door 64', ['Door 50', 'Door 48', 'Door 99'], '64 is a perfect square (8 × 8), so it has an odd number of factors and is toggled an odd number of times. 50, 48 and 99 are not squares, so they end closed.'],
  ['Puzzles', 3, 'You have 2 identical eggs and a 100-floor building. An egg breaks if dropped from a certain floor or higher. In the worst case, what is the fewest drops needed to find that floor?', '14', ['10', '50', '7'], 'With d drops, drop the first egg from floor d, then d + (d − 1), and so on, checking the gaps with the second egg. That covers d(d + 1)/2 floors, and the smallest d with d(d + 1)/2 ≥ 100 is 14.'],
  ['Puzzles', 3, 'Two ropes each take exactly 60 minutes to burn, but they burn unevenly, and you can only light their ends. Which of these times can you measure exactly?', '45 minutes', ['40 minutes', '50 minutes', '20 minutes'], 'Light rope A at both ends and rope B at one end. A burns out at 30 minutes; then light B\'s other end. Its remaining half burns from both ends in 15 minutes, giving 45 in total.'],
  ['Puzzles', 2, 'Three switches outside a closed room control three bulbs inside. You can flip the switches as you like but enter the room only once. How do you match every switch to its bulb?', 'Leave one switch on for a few minutes, switch it off, switch on another, then go in and touch the bulbs', ['Switch all three on, then go in', 'It cannot be done in one visit', 'Switch one on, then go in and look'], 'The lit bulb belongs to the switch that is on. The warm, dark bulb belongs to the switch you turned off. The cold, dark bulb belongs to the switch you never touched.'],
  ['Puzzles', 2, 'You have 8 identical-looking balls. One is slightly heavier. Using a balance scale, what is the fewest weighings that always finds the heavy ball?', '2', ['3', '1', '4'], 'Weigh 3 against 3. If they balance, weigh the last 2 against each other. If not, take the heavier 3 and weigh 1 against 1: the heavier side wins, or the ball left out if they balance.'],
  ['Puzzles', 2, 'There are 27 coins and one is a lighter fake. With a balance scale, what is the fewest weighings that always finds the fake?', '3', ['4', '9', '5'], 'Each weighing splits the suspects into three equal groups and shows which group holds the fake: 27 → 9 → 3 → 1, so 3 weighings.'],
  ['Puzzles', 3, 'One of 1,000 bottles is poisoned, and the poison takes exactly 24 hours to act. You have only 24 hours. What is the fewest testers needed to find the poisoned bottle?', '10', ['100', '500', '1,000'], 'Number the bottles in binary. Tester k sips from every bottle whose k-th bit is 1. Who falls ill spells out the poisoned bottle\'s number, and 10 bits cover up to 1,024 bottles.'],
  ['Puzzles', 3, 'Four people must cross a bridge at night with one torch, which must be carried on every crossing. At most two cross at a time, at the slower person\'s pace. They take 1, 2, 5 and 10 minutes. What is the shortest total time?', '17 minutes', ['19 minutes', '18 minutes', '21 minutes'], '1 and 2 cross (2), 1 returns (1), 5 and 10 cross (10), 2 returns (2), 1 and 2 cross (2): 2 + 1 + 10 + 2 + 2 = 17.'],
  ['Puzzles', 1, 'At a party, each of 10 people shakes hands with every other person exactly once. How many handshakes are there?', '45', ['90', '100', '50'], 'Each handshake is one pair of people: 10 × 9 / 2 = 45.'],
  ['Puzzles', 3, 'A prize is behind one of 3 doors. You pick a door, and the host, who knows where the prize is, opens another door with no prize behind it. If you switch to the remaining door, what is your chance of winning?', '2/3', ['1/2', '1/3', '1'], 'Your first pick is right only 1/3 of the time. In the other 2/3 of cases the host has to leave the prize behind the remaining door, so switching wins 2/3 of the time.'],
  ['Puzzles', 2, 'Three ants sit at the corners of a triangle. Each picks one of its two edges at random and walks along it at the same speed. What is the chance that no two ants meet?', '1/4', ['1/8', '1/2', '3/4'], 'There are 2 × 2 × 2 = 8 equally likely choices. The ants avoid each other only if all go clockwise or all go anticlockwise: 2 out of 8, so 1/4.'],
  ['Puzzles', 2, 'A snail is at the bottom of a 30 m well. Each day it climbs 3 m, and each night it slips back 2 m. On which day does it reach the top?', 'Day 28', ['Day 30', 'Day 27', 'Day 29'], 'After 27 days and nights it is at 27 m. On day 28 it climbs 3 m, reaches 30 m and is out before it can slip back.'],
  ['Puzzles', 1, 'A drawer holds 10 black and 10 white socks. In the dark, what is the fewest socks you must take out to be sure of a matching pair?', '3', ['2', '11', '4'], 'With only two colours, any 3 socks must include two of the same colour.'],
  ['Puzzles', 2, 'A drawer holds 10 black and 10 white socks. In the dark, what is the fewest socks you must take out to be sure of getting 2 black socks?', '12', ['3', '11', '20'], 'In the worst case you first take all 10 white socks. The next 2 must be black: 10 + 2 = 12.'],
  ['Puzzles', 1, 'A bat and a ball cost ₹110 together. The bat costs ₹100 more than the ball. How much does the ball cost?', '₹5', ['₹10', '₹15', '₹55'], 'If the ball costs x, the bat costs x + 100, so 2x + 100 = 110 and x = 5.'],
  ['Puzzles', 2, 'A patch of lily pads doubles in size every day. It covers the whole lake on day 48. On which day did it cover half the lake?', 'Day 47', ['Day 24', 'Day 46', 'Day 36'], 'It doubles each day, so one day before covering the whole lake it covered half: day 47.'],
  ['Puzzles', 2, 'If 5 machines make 5 widgets in 5 minutes, how long do 100 machines take to make 100 widgets?', '5 minutes', ['100 minutes', '20 minutes', '1 minute'], 'Each machine makes 1 widget in 5 minutes. 100 machines working at once make 100 widgets in the same 5 minutes.'],
  ['Puzzles', 3, 'How many squares of any size are there on a standard 8 × 8 chessboard?', '204', ['64', '196', '256'], 'Count each size: 8² + 7² + … + 1² = 64 + 49 + 36 + 25 + 16 + 9 + 4 + 1 = 204.'],
  ['Puzzles', 2, 'What is the fewest straight cuts needed to cut a round cake into 8 equal pieces?', '3', ['4', '7', '8'], 'Two cuts across the top make 4 equal pieces, and one horizontal cut through the middle doubles that to 8.'],
  ['Puzzles', 2, 'You must pay a worker 1/7 of a gold bar at the end of each day for 7 days. What is the fewest cuts you need to make in the bar?', '2', ['3', '6', '1'], 'Cut it into pieces of 1/7, 2/7 and 4/7. Any amount from 1/7 to 7/7 can be paid by handing over pieces and taking change back.'],
  ['Puzzles', 2, 'There are 10 bags of coins. Real coins weigh 10 g, but every coin in one bag is fake and weighs 9 g. With a digital scale, what is the fewest weighings needed to find the fake bag?', '1', ['2', '3', '10'], 'Take 1 coin from bag 1, 2 from bag 2, and so on up to 10 from bag 10, and weigh them once. The total falls short of 550 g by the number of the fake bag.'],
  ['Puzzles', 1, '100 players enter a knockout tournament, and every match knocks out its loser. How many matches are needed to find the champion?', '99', ['50', '100', '64'], 'Every player except the champion loses exactly once, and each match has one loser: 99 matches.'],
  ['Puzzles', 2, 'Three boxes are labelled Apples, Oranges and Mixed, and every label is wrong. Without looking inside, what is the fewest fruits you must take out to label all the boxes correctly?', '1', ['2', '3', '6'], 'The box labelled Mixed holds only one kind, so one fruit from it tells you which. Say it is an apple: that box is Apples. The box labelled Oranges can\'t be Oranges, so it is Mixed, and the last box is Oranges.'],
  ['Puzzles', 1, 'What is the fewest people needed in a room to be sure that at least two were born in the same month?', '13', ['12', '24', '7'], 'There are 12 months, so with 13 people at least two must share a month (the pigeonhole principle).'],
  ['Puzzles', 2, 'How many times do the hour and minute hands of a clock overlap in 12 hours?', '11', ['12', '24', '22'], 'The minute hand catches the hour hand once every 12/11 hours, so they overlap 11 times in 12 hours.'],
  ['Puzzles', 2, 'Two trains start 100 km apart and head towards each other at 50 km/h each. A bird flies back and forth between them at 75 km/h until they meet. How far does the bird fly?', '75 km', ['100 km', '150 km', '50 km'], 'The gap closes at 100 km/h, so the trains meet after 1 hour. The bird flies for that hour at 75 km/h: 75 km.'],
];

const curatedVerbal: Curated[] = [
  // Synonyms
  ['Synonyms', 1, 'Choose the word closest in meaning to ABUNDANT.', 'Plentiful', ['Scarce', 'Tiny', 'Hidden'], 'Abundant means existing in large amounts, the same as plentiful.'],
  ['Synonyms', 1, 'Choose the word closest in meaning to CANDID.', 'Frank', ['Secretive', 'Shy', 'Rude'], 'Candid means open and honest, the same as frank.'],
  ['Synonyms', 1, 'Choose the word closest in meaning to DILIGENT.', 'Hardworking', ['Lazy', 'Careless', 'Clever'], 'Diligent means showing steady, careful effort.'],
  ['Synonyms', 1, 'Choose the word closest in meaning to OBSOLETE.', 'Outdated', ['Modern', 'Useful', 'Rare'], 'Obsolete means no longer in use, or outdated.'],
  ['Synonyms', 2, 'Choose the word closest in meaning to METICULOUS.', 'Careful', ['Hasty', 'Messy', 'Brave'], 'Meticulous means paying close attention to every detail.'],
  ['Synonyms', 2, 'Choose the word closest in meaning to AMBIGUOUS.', 'Unclear', ['Obvious', 'Certain', 'Simple'], 'Ambiguous means open to more than one meaning, so unclear.'],
  ['Synonyms', 1, 'Choose the word closest in meaning to BENEVOLENT.', 'Kind', ['Cruel', 'Greedy', 'Proud'], 'Benevolent means well-meaning and kind.'],
  ['Synonyms', 1, 'Choose the word closest in meaning to CONCISE.', 'Brief', ['Lengthy', 'Vague', 'Complex'], 'Concise means saying a lot in few words.'],
  ['Synonyms', 1, 'Choose the word closest in meaning to FEASIBLE.', 'Possible', ['Impossible', 'Expensive', 'Pointless'], 'Feasible means possible to do.'],
  ['Synonyms', 2, 'Choose the word closest in meaning to RESILIENT.', 'Hardy', ['Fragile', 'Rigid', 'Weak'], 'Resilient means able to recover quickly from difficulty, so hardy.'],
  ['Synonyms', 2, 'Choose the word closest in meaning to LUCID.', 'Clear', ['Confusing', 'Dull', 'Long'], 'Lucid means expressed clearly and easy to understand.'],
  ['Synonyms', 2, 'Choose the word closest in meaning to PRUDENT.', 'Wise', ['Reckless', 'Generous', 'Timid'], 'Prudent means showing good judgement, so wise.'],
  ['Synonyms', 2, 'Choose the word closest in meaning to TENACIOUS.', 'Persistent', ['Weak', 'Hesitant', 'Gentle'], 'Tenacious means holding on firmly and not giving up.'],
  ['Synonyms', 1, 'Choose the word closest in meaning to INEVITABLE.', 'Unavoidable', ['Uncertain', 'Unlikely', 'Optional'], 'Inevitable means certain to happen, so unavoidable.'],
  // Antonyms
  ['Antonyms', 1, 'Choose the word opposite in meaning to EXPAND.', 'Contract', ['Enlarge', 'Extend', 'Spread'], 'Expand means to grow larger; contract means to grow smaller.'],
  ['Antonyms', 1, 'Choose the word opposite in meaning to GENEROUS.', 'Stingy', ['Kind', 'Liberal', 'Wealthy'], 'Generous means giving freely; stingy means unwilling to give.'],
  ['Antonyms', 1, 'Choose the word opposite in meaning to ANCIENT.', 'Modern', ['Old', 'Antique', 'Historic'], 'Ancient means very old; modern means recent.'],
  ['Antonyms', 2, 'Choose the word opposite in meaning to TRANSPARENT.', 'Opaque', ['Clear', 'Visible', 'Thin'], 'Transparent lets light through; opaque does not.'],
  ['Antonyms', 1, 'Choose the word opposite in meaning to HUMBLE.', 'Arrogant', ['Modest', 'Polite', 'Simple'], 'Humble means modest; arrogant means having too high an opinion of oneself.'],
  ['Antonyms', 2, 'Choose the word opposite in meaning to SCARCITY.', 'Abundance', ['Shortage', 'Lack', 'Poverty'], 'Scarcity means too little of something; abundance means plenty.'],
  ['Antonyms', 1, 'Choose the word opposite in meaning to OPTIMISTIC.', 'Pessimistic', ['Hopeful', 'Cheerful', 'Positive'], 'Optimistic expects good outcomes; pessimistic expects bad ones.'],
  ['Antonyms', 1, 'Choose the word opposite in meaning to TEMPORARY.', 'Permanent', ['Brief', 'Short', 'Passing'], 'Temporary lasts a short time; permanent lasts for good.'],
  ['Antonyms', 2, 'Choose the word opposite in meaning to VOLUNTARY.', 'Compulsory', ['Willing', 'Optional', 'Free'], 'Voluntary is done by choice; compulsory is required.'],
  ['Antonyms', 1, 'Choose the word opposite in meaning to FRAGILE.', 'Sturdy', ['Delicate', 'Weak', 'Brittle'], 'Fragile breaks easily; sturdy is strong.'],
  ['Antonyms', 1, 'Choose the word opposite in meaning to CONCEAL.', 'Reveal', ['Hide', 'Cover', 'Mask'], 'Conceal means to hide; reveal means to show.'],
  ['Antonyms', 2, 'Choose the word opposite in meaning to VERBOSE.', 'Concise', ['Wordy', 'Talkative', 'Lengthy'], 'Verbose uses too many words; concise uses few.'],
  ['Antonyms', 1, 'Choose the word opposite in meaning to HOSTILE.', 'Friendly', ['Aggressive', 'Unkind', 'Angry'], 'Hostile means unfriendly or aggressive.'],
  ['Antonyms', 1, 'Choose the word opposite in meaning to REJECT.', 'Accept', ['Refuse', 'Decline', 'Deny'], 'Reject means to refuse; accept means to take or agree to.'],
  // Fill in the blank
  ['Grammar', 1, 'Fill in the blank: She has been working here ___ 2019.', 'since', ['for', 'from', 'by'], 'Use "since" with a starting point in time (2019); "for" goes with a length of time.'],
  ['Grammar', 2, 'Fill in the blank: Neither the manager nor the employees ___ present at the meeting.', 'were', ['was', 'is', 'has been'], 'With "neither … nor", the verb agrees with the nearer subject, "employees", which is plural.'],
  ['Grammar', 1, 'Fill in the blank: He is good ___ solving puzzles.', 'at', ['in', 'on', 'with'], 'The fixed phrase is "good at" something.'],
  ['Grammar', 1, 'Fill in the blank: I prefer tea ___ coffee.', 'to', ['than', 'over', 'from'], 'The verb "prefer" takes "to": prefer A to B.'],
  ['Grammar', 2, 'Fill in the blank: Each of the students ___ given a laptop.', 'was', ['were', 'are', 'have been'], '"Each" is singular, so it takes the singular verb "was".'],
  ['Grammar', 2, 'Fill in the blank: If I ___ you, I would accept the offer.', 'were', ['was', 'am', 'be'], 'Imaginary conditions use "were" for every subject: "If I were you".'],
  ['Grammar', 2, 'Fill in the blank: The train had already left when we ___ the station.', 'reached', ['reach', 'have reached', 'had reach'], 'The later past action takes the simple past: "had left … when we reached".'],
  ['Grammar', 1, 'Fill in the blank: She is the ___ of the two sisters.', 'taller', ['tallest', 'more tall', 'most tall'], 'Comparing two people uses the comparative form, "taller".'],
  ['Grammar', 1, 'Fill in the blank: Please refrain ___ using your phone during the test.', 'from', ['to', 'of', 'with'], 'The fixed phrase is "refrain from" doing something.'],
  ['Grammar', 1, 'Fill in the blank: The committee ___ its decision yesterday.', 'announced', ['announces', 'has announced', 'announcing'], '"Yesterday" is a finished past time, so use the simple past.'],
  ['Grammar', 1, 'Fill in the blank: He insisted ___ paying the bill.', 'on', ['for', 'to', 'at'], 'The fixed phrase is "insist on" doing something.'],
  ['Grammar', 2, 'Fill in the blank: Hardly had I reached the station ___ the train left.', 'when', ['than', 'then', 'and'], '"Hardly … when" is the fixed pair; "than" goes with "no sooner".'],
  // Idioms
  ['Idioms', 1, `What does the idiom "break the ice" mean?`, 'Start a conversation in an awkward situation', ['Cause a fight', 'Leave suddenly', 'Make a mistake'], 'To break the ice is to ease tension by starting to talk.'],
  ['Idioms', 2, `What does the idiom "hit the nail on the head" mean?`, 'Describe a problem exactly right', ['Hurt someone by accident', 'Work very hard', 'Fix something badly'], 'It means to say exactly what is true or what is causing a problem.'],
  ['Idioms', 1, `What does the idiom "once in a blue moon" mean?`, 'Very rarely', ['Every night', 'Very soon', 'At midnight'], 'It describes something that happens very rarely.'],
  ['Idioms', 1, `What does the idiom "spill the beans" mean?`, 'Reveal a secret', ['Waste food', 'Make a mess', 'Tell a lie'], 'To spill the beans is to let a secret out.'],
  ['Idioms', 1, `What does the idiom "burn the midnight oil" mean?`, 'Work late into the night', ['Waste money', 'Start a fire', 'Sleep early'], 'It means staying up late to work or study.'],
  ['Idioms', 1, `What does the idiom "a piece of cake" mean?`, 'Something very easy', ['A small reward', 'A sweet treat', 'A tough task'], 'A piece of cake is a task that is very easy.'],
  ['Idioms', 1, `What does the idiom "cost an arm and a leg" mean?`, 'Be very expensive', ['Be very painful', 'Be dangerous', 'Be cheap'], 'Something that costs an arm and a leg is very expensive.'],
  ['Idioms', 1, `What does the idiom "under the weather" mean?`, 'Feeling ill', ['Feeling happy', 'Being outdoors', 'Being very busy'], 'Under the weather means slightly unwell.'],
  ['Idioms', 2, `What does the idiom "bite the bullet" mean?`, 'Face something difficult bravely', ['Eat quickly', 'Avoid a problem', 'Get hurt'], 'To bite the bullet is to accept something unpleasant and get on with it.'],
  ['Idioms', 1, `What does the idiom "call it a day" mean?`, 'Stop working for now', ['Name a day', 'Start early', 'Celebrate'], 'To call it a day is to stop what you are doing for the day.'],
];

// ---------------------------------------------------------------------
// Build, check and write
// ---------------------------------------------------------------------

const out: (Question & { variant: string | null })[] = [];
const seen = new Set<string>();

// Picture questions share wording, so they're told apart by their figures.
function variantOf(q: Draft) {
  if (!q.figure && !q.optionFigures) return null;
  const all = [q.figure ?? '', ...[...(q.optionFigures ?? [])].sort()].join('|');
  return createHash('md5').update(all).digest('hex').slice(0, 16);
}

function add(q: Draft, template: string) {
  const variant = variantOf(q);
  const key = `${q.body}|${variant ?? ''}`;
  if (seen.has(key)) return false;
  if (q.options.length !== 4 || new Set(q.options).size !== 4) throw new Error(`Bad options: ${q.body}`);
  if (q.correctIdx < 0 || q.correctIdx > 3) throw new Error(`Bad answer index: ${q.body}`);
  if (q.optionFigures && new Set(q.optionFigures).size !== 4) throw new Error(`Repeated option figure: ${q.body}`);
  seen.add(key);
  out.push({ ...q, template, variant });
  return true;
}

for (const [id, t] of Object.entries({ ...quant, ...reasoning, ...logic, ...visualTemplates })) {
  let made = 0;
  for (let tries = 0; tries < 20000 && made < t.count; tries++) {
    const q = t.make();
    if (q && add(q, id)) made++;
  }
  if (made < t.count) console.warn(`  ${id}: only ${made} of ${t.count}`);
}

for (const [section, items] of [['reasoning', curatedReasoning], ['verbal', curatedVerbal]] as const) {
  for (const [topic, difficulty, body, answer, wrong, explanation] of items) {
    const q = build(section, topic, difficulty, body, answer, [...wrong], explanation, section === 'verbal' ? 25 : TIME[difficulty]);
    if (!q) throw new Error(`Bad curated question: ${body}`);
    add(q, `curated_${topic.toLowerCase().replace(/\W+/g, '_')}`);
  }
}

for (const [topic, difficulty, body, answer, wrong, explanation] of curatedPuzzles) {
  const q = build('reasoning', topic, difficulty, body, answer, [...wrong], explanation, PUZZLE_TIME[difficulty]);
  if (!q) throw new Error(`Bad puzzle: ${body}`);
  add(q, 'curated_puzzles');
}

// A numeric odd-one-out has two answers if another option also stands
// out: the only even (or odd) number, or the only square, cube, prime or
// multiple of 7. Those are dropped after generation, and replacements are
// made last, so every other question keeps its exact wording.
// Migration 0010_audit_fixes retires them in databases seeded earlier.
const isSquare = (n: number) => Number.isInteger(Math.sqrt(n));
const isCube = (n: number) => Math.round(Math.cbrt(n)) ** 3 === n;
const isPrime = (n: number) => {
  if (n < 2) return false;
  for (let d = 2; d * d <= n; d++) if (n % d === 0) return false;
  return true;
};
const STANDOUT: ((n: number) => boolean)[] = [(n) => n % 2 === 0, isSquare, isCube, isPrime, (n) => n % 7 === 0];

function ambiguousOddOneOut(q: Draft) {
  if (q.topic !== 'Odd One Out' || !q.options.every((o) => /^\d+$/.test(o))) return false;
  const nums = q.options.map(Number);
  const key = nums[q.correctIdx];
  return STANDOUT.some((has) => {
    const yes = nums.filter(has);
    const no = nums.filter((n) => !has(n));
    const lone = yes.length === 1 ? yes[0] : no.length === 1 ? no[0] : null;
    return lone !== null && lone !== key;
  });
}

const dropped = out.filter(ambiguousOddOneOut);
for (const q of dropped) out.splice(out.indexOf(q), 1);
let replaced = 0;
for (let tries = 0; tries < 20000 && replaced < dropped.length; tries++) {
  const q = reasoning.odd_one_out.make();
  if (q && !ambiguousOddOneOut(q) && add(q, 'odd_one_out')) replaced++;
}
if (replaced < dropped.length) console.warn(`  odd_one_out: only ${replaced} of ${dropped.length} replacements`);

// Which companies' aptitude tests cover each topic, going by their
// published test patterns. It means "this kind of question is on that
// test", never "this exact question was asked there".
const COMPANY_TOPICS: Record<string, string[]> = {
  'TCS NQT': ['Percentages', 'Ratio', 'Profit & Loss', 'Speed & Distance', 'Number System', 'LCM & HCF',
    'Number Series', 'Letter Series', 'Seating Arrangement', 'Ranking', 'Blood Relations', 'Coding-Decoding',
    'Syllogisms', 'Grammar', 'Synonyms', 'Antonyms'],
  Infosys: ['Percentages', 'Profit & Loss', 'Speed & Distance', 'Probability', 'Number Series', 'Syllogisms',
    'Seating Arrangement', 'Blood Relations', 'Direction Sense', 'Coding-Decoding', 'Puzzles', 'Grammar',
    'Synonyms', 'Antonyms'],
  Accenture: ['Percentages', 'Profit & Loss', 'Time & Work', 'Coding-Decoding', 'Blood Relations',
    'Seating Arrangement', 'Syllogisms', 'Figure Series', 'Pattern Matrix', 'Odd Figure Out', 'Grammar'],
  Wipro: ['Probability', 'Clocks', 'Calendars', 'Number System', 'LCM & HCF', 'Speed & Distance',
    'Coding-Decoding', 'Direction Sense', 'Syllogisms', 'Synonyms', 'Antonyms'],
};
const companiesFor = (topic: string) =>
  Object.entries(COMPANY_TOPICS).filter(([, topics]) => topics.includes(topic)).map(([company]) => company);

const COLLEGES: [string, string | null][] = [
  ['VIT Vellore', 'Vellore'], ['VIT Chennai', 'Chennai'], ['VIT-AP', 'Amaravati'], ['VIT Bhopal', 'Bhopal'],
  ['SRM Institute of Science and Technology', 'Chennai'], ['Manipal Institute of Technology', 'Manipal'],
  ['KIIT University', 'Bhubaneswar'], ['PSG College of Technology', 'Coimbatore'], ['Anna University (CEG)', 'Chennai'],
  ['Amrita Vishwa Vidyapeetham', 'Coimbatore'], ['SASTRA University', 'Thanjavur'], ['Sathyabama Institute', 'Chennai'],
  ['RV College of Engineering', 'Bengaluru'], ['BMS College of Engineering', 'Bengaluru'], ['PES University', 'Bengaluru'],
  ['MS Ramaiah Institute of Technology', 'Bengaluru'], ['Dayananda Sagar College of Engineering', 'Bengaluru'],
  ['CMR Institute of Technology', 'Bengaluru'], ['Christ University', 'Bengaluru'], ['NMIT', 'Bengaluru'],
  ['NIT Trichy', 'Tiruchirappalli'], ['NIT Warangal', 'Warangal'], ['NIT Surathkal', 'Mangaluru'], ['NIT Calicut', 'Kozhikode'],
  ['MNNIT Allahabad', 'Prayagraj'], ['MANIT Bhopal', 'Bhopal'], ['SVNIT Surat', 'Surat'], ['IIIT Hyderabad', 'Hyderabad'],
  ['JNTU Hyderabad', 'Hyderabad'], ['CBIT Hyderabad', 'Hyderabad'], ['VNR VJIET', 'Hyderabad'], ['GITAM University', 'Visakhapatnam'],
  ['KL University', 'Vijayawada'], ['COEP Technological University', 'Pune'], ['PICT Pune', 'Pune'], ['MIT World Peace University', 'Pune'],
  ['Symbiosis Institute of Technology', 'Pune'], ['Bharati Vidyapeeth College of Engineering', 'Pune'], ['VJTI Mumbai', 'Mumbai'],
  ['DJ Sanghvi College of Engineering', 'Mumbai'], ['Nirma University', 'Ahmedabad'], ['LD College of Engineering', 'Ahmedabad'],
  ['Delhi Technological University', 'Delhi'], ['NSUT Delhi', 'Delhi'], ['GGSIPU', 'Delhi'], ['JIIT Noida', 'Noida'],
  ['Amity University', 'Noida'], ['Galgotias University', 'Greater Noida'], ['Bennett University', 'Greater Noida'],
  ['Shiv Nadar University', 'Greater Noida'], ['Thapar Institute', 'Patiala'], ['Chandigarh University', 'Mohali'],
  ['Lovely Professional University', 'Phagwara'], ['UPES Dehradun', 'Dehradun'], ['Graphic Era University', 'Dehradun'],
  ['BITS Pilani', 'Pilani'], ['Jadavpur University', 'Kolkata'], ['Heritage Institute of Technology', 'Kolkata'],
  ['Institute of Engineering & Management', 'Kolkata'], ['Other college', null],
];

const sq = (s: string | null) => (s === null ? 'null' : `'${s.replace(/'/g, "''")}'`);
const sqArr = (xs: string[] | null | undefined) => (xs ? `array[${xs.map(sq).join(', ')}]` : 'null');
const tagUpdates = [...new Set(out.map((q) => q.topic))].sort().map((topic) =>
  `update public.questions set company_tags = ${sqArr(companiesFor(topic))}::text[] where topic = ${sq(topic)};`);
const lines = out.map((q) =>
  `  (${sq(q.section)}, ${sq(q.topic)}, ${q.difficulty}, ${sq(q.body)}, ${sqArr(q.options)}, ${q.correctIdx}, ${sq(q.explanation)}, ${q.timeLimit}, ${sq(q.template)}, ${sq(q.figure ?? null)}, ${sqArr(q.optionFigures)}, ${sq(q.variant)})`);

const sql = `-- Generated by scripts/generate-questions.ts. Do not edit by hand.
-- Needs migration 0005_visual. Safe to run again: existing rows are kept.

insert into public.colleges (name, city) values
${COLLEGES.map(([n, c]) => `  (${sq(n)}, ${sq(c)})`).join(',\n')}
on conflict (name) do nothing;

insert into public.questions
  (section, topic, difficulty, body, options, correct_idx, explanation, time_limit_s, template, figure, option_figures, variant)
values
${lines.join(',\n')}
on conflict (body, (coalesce(variant, ''))) do nothing;

-- Company test patterns each topic belongs to (see COMPANY_TOPICS).
${tagUpdates.join('\n')}
`;

const target = new URL('../supabase/seed.sql', import.meta.url);
writeFileSync(target, sql);

const bySection = out.reduce<Record<string, number>>((acc, q) => ((acc[q.section] = (acc[q.section] ?? 0) + 1), acc), {});
console.log(`Wrote ${out.length} questions (${Object.entries(bySection).map(([k, v]) => `${k} ${v}`).join(', ')}) and ${COLLEGES.length} colleges to supabase/seed.sql`);
