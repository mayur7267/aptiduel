// Builds the basic aptitude questions and writes supabase/seed-basics.sql.
//
// These are the first-step questions of each topic, the kind a student
// answers in 10 to 20 seconds once they know the idea: one formula, one
// step. All are difficulty 1. Like generate-questions.ts, the numbers are
// random but every answer is computed, so the key can't be wrong. A
// separate file with its own seed, so the main bank never changes.
//
// Run from the repo root:  node scripts/generate-basics.ts

import { writeFileSync } from 'node:fs';

type Section = 'quant' | 'reasoning';
type Draft = {
  section: Section;
  topic: string;
  body: string;
  options: string[];
  correctIdx: number;
  explanation: string;
};

// ---------------------------------------------------------------------
// Helpers (same ideas as generate-questions.ts)
// ---------------------------------------------------------------------

function mulberry32(seed: number) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(20261126);
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
const pct = (n: number) => `${fmt(n)}%`;
const fraction = (n: number, d: number) => {
  const g = gcd(n, d);
  return d / g === 1 ? String(n / g) : `${n / g}/${d / g}`;
};

function near(ans: number, step: number, show: (n: number) => string = fmt): string[] {
  return shuffle([1, -1, 2, -2, 3, -3])
    .map((k) => ans + k * step)
    .filter((v) => v > 0)
    .map(show);
}

// The answer plus the first three usable, distinct distractors (most
// tempting mistakes first), shuffled.
function build(section: Section, topic: string, body: string, answer: string, distractors: string[], explanation: string): Draft | null {
  const wrong: string[] = [];
  for (const d of distractors) {
    const bad = d === answer || wrong.includes(d) || d === '' || /NaN|Infinity|^-|^0\b|^₹0$|^0 /.test(d);
    if (!bad) wrong.push(d);
    if (wrong.length === 3) break;
  }
  if (wrong.length < 3) return null;
  const options = shuffle([answer, ...wrong]);
  return { section, topic, body, options, correctIdx: options.indexOf(answer), explanation };
}

const MEN = ['Ravi', 'Arjun', 'Kabir', 'Rahul', 'Varun', 'Aman', 'Rohit', 'Karan', 'Nikhil', 'Sameer'];
const WOMEN = ['Meena', 'Sana', 'Divya', 'Isha', 'Nisha', 'Priya', 'Anjali', 'Kavya', 'Pooja', 'Riya'];
const NAMES = [...MEN, ...WOMEN];
const ord = (n: number) => `${n}${[11, 12, 13].includes(n % 100) ? 'th' : n % 10 === 1 ? 'st' : n % 10 === 2 ? 'nd' : n % 10 === 3 ? 'rd' : 'th'}`;
const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const ABC = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

type Template = { count: number; make: () => Draft | null };

// ---------------------------------------------------------------------
// Quant
// ---------------------------------------------------------------------

const quant: Record<string, Template> = {
  what_percent: {
    count: 16,
    make() {
      const p = pick([5, 10, 15, 20, 25, 30, 40, 50, 60, 75, 80]);
      const whole = pick([40, 60, 80, 120, 160, 200, 240, 300, 400, 500, 600, 800]);
      const part = (p * whole) / 100;
      if (!isInt(part)) return null;
      return build('quant', 'Percentages', `${part} is what percent of ${whole}?`, pct(p),
        [pct((whole / part) * 1), pct(p + 5), pct(p - 5), pct(p * 2), pct(p + 10)].filter((s) => !s.includes('.')),
        `${part}/${whole} × 100 = ${p}%.`);
    },
  },

  percent_rise: {
    count: 16,
    make() {
      const p = pick([10, 20, 25, 40, 50]);
      const from = pick([200, 400, 500, 800, 1000, 1200, 1600, 2000]);
      const to = from * (1 + p / 100);
      const down = rand() < 0.5;
      const [a, b] = down ? [to, from] : [from, to];
      const ans = (Math.abs(b - a) / a) * 100;
      const otherBase = (Math.abs(b - a) / b) * 100;
      const item = pick(['a book', 'a bag', 'a pair of shoes', 'a ticket', 'a jacket']);
      return build('quant', 'Percentages',
        `The price of ${item} ${down ? 'falls' : 'rises'} from ${inr(a)} to ${inr(b)}. What is the percentage ${down ? 'decrease' : 'increase'}?`,
        pct(ans),
        [isInt(otherBase) ? pct(otherBase) : '', ...near(ans, 5, pct)],
        `Change = ${inr(Math.abs(b - a))}. Divide by the starting price: ${Math.abs(b - a)}/${a} × 100 = ${fmt(ans)}%.`);
    },
  },

  average_of: {
    count: 16,
    make() {
      const n = pick([4, 5]);
      const xs = Array.from({ length: n }, () => int(8, 60));
      const sum = xs.reduce((s, x) => s + x, 0);
      if (sum % n !== 0) return null;
      const ans = sum / n;
      return build('quant', 'Averages', `What is the average of ${xs.slice(0, -1).join(', ')} and ${xs.at(-1)}?`, fmt(ans),
        [isInt(sum / (n - 1)) ? fmt(sum / (n - 1)) : '', ...near(ans, 1), ...near(ans, 2)],
        `Sum = ${sum}. Average = ${sum} ÷ ${n} = ${fmt(ans)}.`);
    },
  },

  profit_percent: {
    count: 16,
    make() {
      const cp = pick([200, 250, 400, 500, 800, 1000, 1200, 1500, 2000]);
      const p = pick([5, 10, 12, 15, 20, 25, 30, 40]);
      const loss = rand() < 0.35;
      const sp = cp * (1 + (loss ? -p : p) / 100);
      if (!isInt(sp)) return null;
      const onSp = (Math.abs(sp - cp) / sp) * 100;
      const who = pick(['A shopkeeper', 'A trader', 'A dealer', 'A vendor']);
      const item = pick(['a watch', 'a chair', 'a lamp', 'a phone cover', 'a fan', 'a bag']);
      return build('quant', 'Profit & Loss',
        `${who} buys ${item} for ${inr(cp)} and sells it for ${inr(sp)}. What is the ${loss ? 'loss' : 'profit'} percentage?`,
        pct(p),
        [isInt(onSp) ? pct(onSp) : '', ...near(p, 5, pct), pct(p * 2)],
        `${loss ? 'Loss' : 'Profit'} = ${inr(Math.abs(sp - cp))}. As a percent of the cost price: ${Math.abs(sp - cp)}/${cp} × 100 = ${p}%.`);
    },
  },

  selling_price: {
    count: 16,
    make() {
      const cp = pick([300, 400, 500, 600, 800, 1000, 1200, 1500, 2500]);
      const p = pick([10, 15, 20, 25, 30]);
      const loss = rand() < 0.35;
      const sp = cp * (1 + (loss ? -p : p) / 100);
      if (!isInt(sp)) return null;
      const flip = cp * (1 + (loss ? p : -p) / 100);
      return build('quant', 'Profit & Loss',
        `An item costs ${inr(cp)}. At what price should it be sold to make a ${loss ? 'loss' : 'profit'} of ${p}%?`,
        inr(sp),
        [inr(flip), inr(cp + (loss ? -1 : 1) * p * 10), ...near(sp, cp / 20, inr)],
        `${loss ? 'Selling price = cost − ' : 'Selling price = cost + '}${p}% of cost = ${inr(cp)} ${loss ? '−' : '+'} ${inr((cp * p) / 100)} = ${inr(sp)}.`);
    },
  },

  speed_basic: {
    count: 16,
    make() {
      const speed = pick([30, 36, 40, 45, 48, 50, 54, 60, 72, 75, 80, 90]);
      const hours = pick([2, 3, 4, 5]);
      const dist = speed * hours;
      const vehicle = pick(['A car', 'A bus', 'A train', 'A bike']);
      const ask = pick(['speed', 'time', 'distance'] as const);
      if (ask === 'speed') {
        return build('quant', 'Speed & Distance', `${vehicle} covers ${dist} km in ${hours} hours. What is its speed?`, `${speed} km/h`,
          [`${dist * hours} km/h`, ...near(speed, 5, (n) => `${n} km/h`)],
          `Speed = distance ÷ time = ${dist} ÷ ${hours} = ${speed} km/h.`);
      }
      if (ask === 'time') {
        return build('quant', 'Speed & Distance', `${vehicle} travels at ${speed} km/h. How long does it take to cover ${dist} km?`, `${hours} hours`,
          near(hours, 1, (n) => `${n} hours`).concat([`${hours * 2} hours`]),
          `Time = distance ÷ speed = ${dist} ÷ ${speed} = ${hours} hours.`);
      }
      return build('quant', 'Speed & Distance', `${vehicle} travels at ${speed} km/h for ${hours} hours. How far does it go?`, `${dist} km`,
        [`${speed + hours} km`, ...near(dist, speed / 2, (n) => `${fmt(n)} km`)],
        `Distance = speed × time = ${speed} × ${hours} = ${dist} km.`);
    },
  },

  kmph_to_mps: {
    count: 12,
    make() {
      const toMps = rand() < 0.6;
      const k = int(1, 8) * 18; // km/h values that convert to whole m/s
      const m = (k * 5) / 18;
      if (toMps) {
        return build('quant', 'Speed & Distance', `Convert ${k} km/h into metres per second.`, `${m} m/s`,
          [`${fmt((k * 18) / 5)} m/s`, ...near(m, 5, (n) => `${n} m/s`)],
          `Multiply by 5/18: ${k} × 5/18 = ${m} m/s.`);
      }
      return build('quant', 'Speed & Distance', `Convert ${m} m/s into kilometres per hour.`, `${k} km/h`,
        [isInt((m * 5) / 18) ? `${(m * 5) / 18} km/h` : '', ...near(k, 18, (n) => `${n} km/h`), ...near(k, 9, (n) => `${n} km/h`)],
        `Multiply by 18/5: ${m} × 18/5 = ${k} km/h.`);
    },
  },

  ratio_divide: {
    count: 16,
    make() {
      const a = int(1, 7);
      const b = int(1, 9);
      if (a === b || gcd(a, b) !== 1) return null;
      const unit = pick([50, 100, 150, 200, 250, 500]);
      const total = (a + b) * unit;
      const [p, q] = shuffle(NAMES).slice(0, 2);
      const askFirst = rand() < 0.5;
      const ans = (askFirst ? a : b) * unit;
      const other = (askFirst ? b : a) * unit;
      return build('quant', 'Ratio',
        `${inr(total)} is divided between ${p} and ${q} in the ratio ${a} : ${b}. What is ${askFirst ? p : q}'s share?`,
        inr(ans),
        [inr(other), isInt(total / 2) ? inr(total / 2) : '', ...near(ans, unit, inr)],
        `Total parts = ${a} + ${b} = ${a + b}. One part = ${inr(total)} ÷ ${a + b} = ${inr(unit)}. ${askFirst ? p : q} gets ${askFirst ? a : b} parts = ${inr(ans)}.`);
    },
  },

  hcf_two: {
    count: 14,
    make() {
      const g = pick([4, 6, 8, 9, 12, 14, 15, 16, 18]);
      const x = int(2, 7);
      const y = int(x + 1, 9);
      if (gcd(x, y) !== 1) return null;
      const a = g * x;
      const b = g * y;
      const divs = [2, 3, 4, 6].filter((d) => g % d === 0 && g / d > 1).map((d) => fmt(g / d));
      return build('quant', 'LCM & HCF', `What is the HCF of ${a} and ${b}?`, fmt(g),
        [...divs, fmt(g * 2), ...near(g, 2)],
        `${a} = ${g} × ${x} and ${b} = ${g} × ${y}, and ${x} and ${y} share no factor. So the HCF is ${g}.`);
    },
  },

  lcm_two: {
    count: 14,
    make() {
      const a = int(4, 18);
      const b = int(a + 1, 24);
      const l = lcm(a, b);
      if (l === a * b && l > 200) return null;
      if (l === b) return null; // "LCM of 6 and 12" is too easy to be a question
      return build('quant', 'LCM & HCF', `What is the LCM of ${a} and ${b}?`, fmt(l),
        [l !== a * b ? fmt(a * b) : '', isInt(l / 2) && l / 2 > b ? fmt(l / 2) : '', fmt(l * 2), ...near(l, a)],
        `List multiples of ${b} until one is also a multiple of ${a}: the first is ${l}.`);
    },
  },

  work_part: {
    count: 14,
    make() {
      const n = pick([6, 8, 10, 12, 15, 16, 18, 20, 24]);
      const d = int(2, n - 2);
      if (gcd(d, n) === 1 && n > 12) return null; // keep the fractions friendly
      const name = pick(NAMES);
      return build('quant', 'Time & Work',
        `${name} can finish a job alone in ${n} days. What part of the job does ${name} finish in ${d} days?`,
        fraction(d, n),
        [fraction(1, n), fraction(n - d, n), fraction(d + 1, n), fraction(d - 1, n), fraction(1, d)],
        `In one day ${name} does 1/${n} of the job. In ${d} days: ${d} × 1/${n} = ${fraction(d, n)}.`);
    },
  },

  si_rate: {
    count: 14,
    make() {
      const P = pick([1000, 2000, 2500, 4000, 5000, 8000, 10000]);
      const R = pick([4, 5, 6, 8, 10, 12]);
      const T = pick([2, 3, 4, 5]);
      const si = (P * R * T) / 100;
      return build('quant', 'Interest',
        `${inr(P)} earns a simple interest of ${inr(si)} in ${T} years. What is the rate of interest per annum?`,
        pct(R),
        [pct(R * T), isInt(R / 2) ? pct(R / 2) : '', ...near(R, 2, pct)],
        `Rate = SI × 100 ÷ (P × T) = ${si} × 100 ÷ (${P} × ${T}) = ${R}%.`);
    },
  },

  ages_sum_diff: {
    count: 14,
    make() {
      const son = int(6, 20);
      const gap = int(22, 34);
      const father = son + gap;
      const sum = son + father;
      const [kid, parent] = pick([['son', 'father'], ['daughter', 'mother'], ['son', 'mother'], ['daughter', 'father']] as const);
      const askKid = rand() < 0.6;
      const ans = askKid ? son : father;
      return build('quant', 'Ages',
        `The sum of the ages of a ${parent} and ${kid} is ${sum} years. The ${parent} is ${gap} years older. How old is the ${askKid ? kid : parent}?`,
        `${ans} years`,
        [`${askKid ? father : son} years`, isInt(sum / 2) ? `${sum / 2} years` : '', ...near(ans, 2, (n) => `${n} years`)],
        `${kid[0].toUpperCase() + kid.slice(1)} = (sum − difference) ÷ 2 = (${sum} − ${gap}) ÷ 2 = ${son}. ${parent[0].toUpperCase() + parent.slice(1)} = ${son} + ${gap} = ${father}.`);
    },
  },

  divisible_by: {
    count: 14,
    make() {
      const by = pick([3, 4, 9, 11]);
      const rule: Record<number, string> = {
        3: 'its digits add up to a multiple of 3',
        4: 'its last two digits form a multiple of 4',
        9: 'its digits add up to a multiple of 9',
        11: 'the difference between the sums of its alternate digits is 0 or a multiple of 11',
      };
      const ok = by * int(Math.ceil(1000 / by), Math.floor(9999 / by));
      const wrong: string[] = [];
      while (wrong.length < 3) {
        const w = ok + pick([1, 2, -1, -2, 10, -10, 100]) * int(1, 3);
        if (w % by !== 0 && w > 999 && w < 10000 && !wrong.includes(String(w))) wrong.push(String(w));
      }
      const listed = shuffle([String(ok), ...wrong]);
      return build('quant', 'Number System', `Which of these is divisible by ${by}: ${listed.slice(0, 3).join(', ')} or ${listed[3]}?`, String(ok), wrong,
        `A number is divisible by ${by} when ${rule[by]}. Only ${ok} passes: ${ok} = ${by} × ${ok / by}.`);
    },
  },
};

// ---------------------------------------------------------------------
// Reasoning
// ---------------------------------------------------------------------

const reasoning: Record<string, Template> = {
  simple_series: {
    count: 18,
    make() {
      const kind = pick(['add', 'mul', 'square'] as const);
      let xs: number[];
      let why: string;
      if (kind === 'add') {
        const a = int(2, 30);
        const d = int(3, 12);
        xs = Array.from({ length: 6 }, (_, i) => a + i * d);
        why = `Each number is ${d} more than the one before: ${xs[4]} + ${d} = ${xs[5]}.`;
      } else if (kind === 'mul') {
        const a = int(1, 5);
        const r = pick([2, 3]);
        xs = Array.from({ length: 6 }, (_, i) => a * r ** i);
        why = `Each number is ${r} times the one before: ${xs[4]} × ${r} = ${xs[5]}.`;
      } else {
        const s = int(1, 6);
        xs = Array.from({ length: 6 }, (_, i) => (s + i) ** 2);
        why = `These are squares: ${s}², ${s + 1}², … so next is ${s + 5}² = ${xs[5]}.`;
      }
      const ans = xs[5];
      const step = Math.max(1, xs[5] - xs[4]);
      return build('reasoning', 'Number Series', `What comes next: ${xs.slice(0, 5).join(', ')}, ?`, String(ans),
        [String(ans + 1), String(ans - 1), String(xs[4] + (xs[4] - xs[3])), ...near(ans, Math.ceil(step / 2))],
        why);
    },
  },

  letter_right_left: {
    count: 16,
    make() {
      const i = int(4, 21);
      const k = int(3, 7);
      const right = rand() < 0.6;
      const j = right ? i + k : i - k;
      if (j < 0 || j > 25) return null;
      const wrongWay = right ? i - k : i + k;
      return build('reasoning', 'Alphabet Test',
        `In the English alphabet, which letter is ${ord(k)} to the ${right ? 'right' : 'left'} of ${ABC[i]}?`,
        ABC[j],
        [wrongWay >= 0 && wrongWay <= 25 ? ABC[wrongWay] : '', ABC[right ? j - 1 : j + 1], ABC[right ? j + 1 : j - 1]].filter(Boolean),
        `${ABC[i]} is letter ${i + 1}. ${right ? 'Add' : 'Subtract'} ${k}: letter ${j + 1} is ${ABC[j]}.`);
    },
  },

  opposite_letter: {
    count: 12,
    make() {
      const i = int(0, 25);
      const j = 25 - i;
      if (i === j) return null;
      return build('reasoning', 'Alphabet Test',
        `If the alphabet is paired from both ends (A with Z, B with Y, and so on), which letter pairs with ${ABC[i]}?`,
        ABC[j],
        [ABC[Math.min(25, j + 1)], ABC[Math.max(0, j - 1)], ABC[(i + 13) % 26]],
        `Positions of a pair add up to 27. ${ABC[i]} is ${i + 1}, so its pair is 27 − ${i + 1} = ${j + 1}, which is ${ABC[j]}.`);
    },
  },

  walk_distance: {
    count: 14,
    make() {
      const [a, b, c] = pick([[3, 4, 5], [6, 8, 10], [5, 12, 13], [9, 12, 15], [8, 15, 17], [12, 16, 20]]);
      const name = pick(NAMES);
      const [d1, d2] = pick([['north', 'east'], ['north', 'west'], ['south', 'east'], ['east', 'north'], ['west', 'south']]);
      return build('reasoning', 'Direction Sense',
        `${name} walks ${a} km ${d1}, then turns and walks ${b} km ${d2}. How far is ${name} from the starting point?`,
        `${c} km`,
        [`${a + b} km`, `${b - a} km`, `${c + 1} km`, `${c - 1} km`],
        `The two walks are at right angles, so the distance is √(${a}² + ${b}²) = √${a * a + b * b} = ${c} km.`);
    },
  },

  facing_turns: {
    count: 12,
    make() {
      const DIRS = ['North', 'East', 'South', 'West'];
      const start = int(0, 3);
      const turns = Array.from({ length: int(2, 3) }, () => pick(['right', 'left', 'right', 'about'] as const));
      let at = start;
      for (const t of turns) at = (at + (t === 'right' ? 1 : t === 'left' ? 3 : 2)) % 4;
      const name = pick(NAMES);
      const said = turns.map((t) => (t === 'about' ? 'turns around' : `turns ${t}`));
      const list = said.length === 2 ? `${said[0]}, then ${said[1]}` : `${said[0]}, ${said[1]}, then ${said[2]}`;
      const options = shuffle(DIRS);
      return {
        section: 'reasoning',
        topic: 'Direction Sense',
        body: `${name} is facing ${DIRS[start]}. ${name} ${list}. Which direction is ${name} facing now?`,
        options,
        correctIdx: options.indexOf(DIRS[at]),
        explanation: `A right turn is a quarter turn clockwise, a left turn a quarter turn anticlockwise, and turning around is half a turn. From ${DIRS[start]}, that ends at ${DIRS[at]}.`,
      };
    },
  },

  days_later: {
    count: 14,
    make() {
      const today = int(0, 6);
      const n = pick([3, 5, 8, 10, 12, 15, 17, 20, 25, 30, 40, 50, 61, 100]);
      const after = rand() < 0.75;
      const ans = ((today + (after ? n : -n)) % 7 + 7) % 7;
      const opts = [DAYS[ans], DAYS[(ans + 1) % 7], DAYS[(ans + 6) % 7], DAYS[(ans + 2) % 7]];
      const options = shuffle(opts);
      return {
        section: 'reasoning',
        topic: 'Calendars',
        body: `If today is ${DAYS[today]}, what day of the week ${after ? `will it be ${n} days from now` : `was it ${n} days ago`}?`,
        options,
        correctIdx: options.indexOf(DAYS[ans]),
        explanation: `Days repeat every 7. ${n} ÷ 7 leaves ${n % 7}, so count ${n % 7} day${n % 7 === 1 ? '' : 's'} ${after ? 'forward' : 'back'} from ${DAYS[today]}: ${DAYS[ans]}.`,
      };
    },
  },

  clock_hour: {
    count: 11,
    make() {
      const h = int(1, 11);
      const raw = 30 * h;
      const ans = Math.min(raw, 360 - raw);
      return build('reasoning', 'Clocks', `What is the smaller angle between the hands of a clock at ${h}:00?`, `${ans}°`,
        [raw !== ans ? `${raw}°` : '', `${ans + 30}°`, `${ans - 30}°`, `${ans + 15}°`, `${h * 6}°`],
        `Each hour mark is 30° apart. At ${h}:00 the hands are ${Math.min(h, 12 - h)} marks apart: ${Math.min(h, 12 - h)} × 30° = ${ans}°.`);
    },
  },

  row_rank: {
    count: 16,
    make() {
      const n = int(20, 50);
      const k = int(4, n - 4);
      const name = pick(NAMES);
      const from = pick(['left', 'top'] as const);
      const to = from === 'left' ? 'right' : 'bottom';
      const ans = n - k + 1;
      const where = from === 'left' ? `In a row of ${n} students` : `In a class of ${n} students`;
      return build('reasoning', 'Ranking',
        `${where}, ${name} is ${ord(k)} from the ${from}. What is ${name}'s position from the ${to}?`,
        ord(ans),
        [ord(n - k), ord(ans + 1), ord(n - k - 1), ord(k + 1)],
        `Position from the ${to} = total − position from the ${from} + 1 = ${n} − ${k} + 1 = ${ans}.`);
    },
  },

  shift_code: {
    count: 16,
    make() {
      const WORDS = ['CAT', 'DOG', 'SUN', 'PEN', 'BOX', 'CUP', 'HAT', 'MAP', 'BAG', 'KEY', 'TOP', 'NET', 'FAN', 'RED', 'BUS', 'COW', 'JAM', 'LOG', 'MUG', 'PIN'];
      const k = pick([1, 2, -1, 3]);
      const [w1, w2] = shuffle(WORDS).slice(0, 2);
      const enc = (w: string, s: number) => [...w].map((c) => ABC[(ABC.indexOf(c) + s + 26) % 26]).join('');
      const say = k > 0 ? `${k} letter${k > 1 ? 's' : ''} forward` : `${-k} letter back`;
      return build('reasoning', 'Coding-Decoding',
        `If ${w1} is written as ${enc(w1, k)}, how is ${w2} written in that code?`,
        enc(w2, k),
        [enc(w2, -k), enc(w2, k + 1), enc(w2, k === 1 ? 2 : 1), [...enc(w2, k)].reverse().join('')],
        `Each letter moves ${say} in the alphabet: ${w1} → ${enc(w1, k)}, so ${w2} → ${enc(w2, k)}.`);
    },
  },

  number_pair: {
    count: 14,
    make() {
      const kind = pick(['square', 'cube', 'times'] as const);
      const a = int(2, kind === 'cube' ? 6 : 12);
      let b = int(2, kind === 'cube' ? 7 : 15);
      if (a === b) b += 1;
      const k = int(3, 9);
      const f = (x: number) => (kind === 'square' ? x * x : kind === 'cube' ? x ** 3 : x * k);
      const ans = f(b);
      const why = kind === 'square' ? `${a}² = ${f(a)}, so ${b}² = ${ans}.` : kind === 'cube' ? `${a}³ = ${f(a)}, so ${b}³ = ${ans}.` : `${a} × ${k} = ${f(a)}, so ${b} × ${k} = ${ans}.`;
      // a² is also a × a (and a³ is a × a²), so for squares and cubes the
      // "times" reading would give another answer: keep it off the options.
      const other = String(b * (f(a) / a));
      const wrong = kind === 'times'
        ? [String(b * (k + 1)), String(b * (k - 1)), String(ans + k), String(ans - k)]
        : kind === 'square'
          ? [String((b + 1) ** 2), String((b - 1) ** 2), String(ans + b), String(ans - 1)]
          : [String((b + 1) ** 3), String((b - 1) ** 3), String(b * b), String(ans + b)];
      return build('reasoning', 'Analogies', `${a} : ${f(a)} :: ${b} : ?`, String(ans),
        wrong.filter((s) => s !== other),
        why);
    },
  },

  odd_number_out: {
    count: 14,
    make() {
      const kind = pick(['prime', 'even', 'mult'] as const);
      if (kind === 'prime') {
        const primes = shuffle([7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59]).slice(0, 3);
        const odd = pick([9, 15, 21, 25, 27, 33, 35, 39, 45, 49, 51, 57]);
        return build('reasoning', 'Odd One Out', `Find the odd one out: ${shuffle([...primes, odd]).join(', ')}`, String(odd), primes.map(String),
          `${primes.join(', ')} are prime numbers. ${odd} is not: it can be divided by ${[3, 5, 7].find((p) => odd % p === 0)}.`);
      }
      if (kind === 'even') {
        const evens = shuffle([12, 18, 24, 36, 42, 48, 56, 64, 72, 86, 94]).slice(0, 3);
        const odd = pick([15, 21, 27, 33, 45, 51, 63, 77, 81]);
        return build('reasoning', 'Odd One Out', `Find the odd one out: ${shuffle([...evens, odd]).join(', ')}`, String(odd), evens.map(String),
          `${evens.join(', ')} are even. ${odd} is odd.`);
      }
      const m = pick([6, 7, 8, 9, 12]);
      const ms = shuffle([2, 3, 4, 5, 6, 7, 8, 9]).slice(0, 3).map((x) => x * m);
      const odd = m * int(3, 8) + pick([1, 2, -1]);
      if (ms.includes(odd)) return null;
      // Even/odd mustn't single out a different number.
      const all = [...ms, odd];
      const evens = all.filter((x) => x % 2 === 0);
      const odds = all.filter((x) => x % 2 !== 0);
      const lone = evens.length === 1 ? evens[0] : odds.length === 1 ? odds[0] : null;
      if (lone !== null && lone !== odd) return null;
      return build('reasoning', 'Odd One Out', `Find the odd one out: ${shuffle([...ms, odd]).join(', ')}`, String(odd), ms.map(String),
        `${ms.join(', ')} are all multiples of ${m}. ${odd} is not.`);
    },
  },
};

// ---------------------------------------------------------------------
// Blood relations: fixed patterns, names chosen to match each role.
// ---------------------------------------------------------------------

type Rel = { make: (m: string[], w: string[]) => [string, string, string]; answer: string; wrong: string[] };
const RELATIONS: Rel[] = [
  { make: (m, w) => [`${m[0]} is the father of ${w[0]}. ${w[0]} is the sister of ${m[1]}. How is ${m[0]} related to ${m[1]}?`, m[0], m[1]],
    answer: 'Father', wrong: ['Uncle', 'Brother', 'Grandfather'] },
  { make: (m, w) => [`${w[0]} is the sister of ${m[0]}'s father. How is ${w[0]} related to ${m[0]}?`, w[0], m[0]],
    answer: 'Aunt', wrong: ['Sister', 'Mother', 'Cousin'] },
  { make: (m, w) => [`${m[0]} is the brother of ${w[0]}'s mother. How is ${m[0]} related to ${w[0]}?`, m[0], w[0]],
    answer: 'Uncle', wrong: ['Brother', 'Father', 'Cousin'] },
  { make: (m, w) => [`${w[0]} is the mother of ${w[1]}'s mother. How is ${w[0]} related to ${w[1]}?`, w[0], w[1]],
    answer: 'Grandmother', wrong: ['Mother', 'Aunt', 'Sister'] },
  { make: (m, w) => [`${m[0]} is the son of ${w[0]}. ${w[0]} is the daughter of ${m[1]}. How is ${m[1]} related to ${m[0]}?`, m[1], m[0]],
    answer: 'Grandfather', wrong: ['Father', 'Uncle', 'Brother'] },
  { make: (m, w) => [`${w[0]} is the wife of ${m[0]}. ${m[0]} is the son of ${m[1]}. How is ${w[0]} related to ${m[1]}?`, w[0], m[1]],
    answer: 'Daughter-in-law', wrong: ['Daughter', 'Wife', 'Sister'] },
  { make: (m, w) => [`${m[0]} is the brother of ${w[0]}. ${w[0]} is the daughter of ${m[1]}. How is ${m[0]} related to ${m[1]}?`, m[0], m[1]],
    answer: 'Son', wrong: ['Brother', 'Nephew', 'Father'] },
  { make: (m, w) => [`${m[0]} is the son of ${w[0]}'s brother. How is ${m[0]} related to ${w[0]}?`, m[0], w[0]],
    answer: 'Nephew', wrong: ['Son', 'Brother', 'Cousin'] },
  { make: (m, w) => [`${w[0]} is the daughter of ${m[0]}'s sister. How is ${w[0]} related to ${m[0]}?`, w[0], m[0]],
    answer: 'Niece', wrong: ['Daughter', 'Sister', 'Cousin'] },
  { make: (m, w) => [`${m[0]} is the son of ${m[1]}'s father's brother. How is ${m[0]} related to ${m[1]}?`, m[0], m[1]],
    answer: 'Cousin', wrong: ['Brother', 'Nephew', 'Uncle'] },
];

function bloodRelations(): Draft[] {
  const out: Draft[] = [];
  for (const r of RELATIONS) {
    for (let i = 0; i < 4; i++) {
      const m = shuffle(MEN);
      const w = shuffle(WOMEN);
      const [body] = r.make(m, w);
      const options = shuffle([r.answer, ...r.wrong]);
      out.push({
        section: 'reasoning',
        topic: 'Blood Relations',
        body,
        options,
        correctIdx: options.indexOf(r.answer),
        explanation: explainRelation(r.answer),
      });
    }
  }
  return out;
}

function explainRelation(answer: string) {
  const why: Record<string, string> = {
    Father: 'He is the father of the sister, so he is the father of her brother too.',
    Aunt: "Your father's sister is your aunt.",
    Uncle: "Your mother's brother is your uncle (maternal uncle).",
    Grandmother: "Your mother's mother is your grandmother.",
    Grandfather: "Your mother's father is your grandfather.",
    'Daughter-in-law': "A son's wife is the daughter-in-law.",
    Son: "A daughter's brother is also a son of the same parent.",
    Nephew: "Your brother's son is your nephew.",
    Niece: "Your sister's daughter is your niece.",
    Cousin: "Your father's brother's son is your cousin.",
  };
  return why[answer];
}

// ---------------------------------------------------------------------
// Build
// ---------------------------------------------------------------------

type Out = Draft & { template: string };
const out: Out[] = [];
const seen = new Set<string>();
function run(group: Record<string, Template>) {
  for (const [name, t] of Object.entries(group)) {
    let made = 0;
    for (let tries = 0; made < t.count && tries < t.count * 200; tries++) {
      const q = t.make();
      if (!q || seen.has(q.body)) continue;
      seen.add(q.body);
      out.push({ ...q, template: `basic_${name}` });
      made++;
    }
    if (made < t.count) console.warn(`basic_${name}: made ${made} of ${t.count}`);
  }
}
run(quant);
run(reasoning);
for (const q of bloodRelations()) {
  if (seen.has(q.body)) continue;
  seen.add(q.body);
  out.push({ ...q, template: 'basic_blood_relation' });
}

// Every question: four distinct options and the key pointing at one.
for (const q of out) {
  if (q.options.length !== 4 || new Set(q.options).size !== 4 || q.correctIdx < 0 || q.correctIdx > 3) {
    throw new Error(`bad question: ${q.body} ${JSON.stringify(q.options)}`);
  }
}

const sq = (s: string | null) => (s === null ? 'null' : `'${s.replace(/'/g, "''")}'`);
const sqArr = (xs: string[]) => `array[${xs.map(sq).join(', ')}]`;
const lines = out.map((q) =>
  `  (${sq(q.section)}, ${sq(q.topic)}, 1, ${sq(q.body)}, ${sqArr(q.options)}, ${q.correctIdx}, ${sq(q.explanation)}, 30, ${sq(q.template)})`);

const sql = `-- Generated by scripts/generate-basics.ts. Do not edit by hand.
-- Basic (difficulty 1) aptitude questions. Safe to run again: existing rows are kept.

insert into public.questions
  (section, topic, difficulty, body, options, correct_idx, explanation, time_limit_s, template)
values
${lines.join(',\n')}
on conflict (body, (coalesce(variant, ''))) do nothing;

-- Same company tags as the topic's other questions.
update public.questions q
   set company_tags = t.tags
  from (select distinct on (topic) topic, company_tags as tags
          from public.questions
         where company_tags is not null and template not like 'basic\\_%'
         order by topic, id) t
 where q.topic = t.topic and q.template like 'basic\\_%' and q.company_tags is null;
`;

writeFileSync(new URL('../supabase/seed-basics.sql', import.meta.url), sql);
const by = out.reduce<Record<string, number>>((a, q) => ((a[q.topic] = (a[q.topic] ?? 0) + 1), a), {});
console.log(`Wrote ${out.length} basic questions to supabase/seed-basics.sql`);
console.log(Object.entries(by).map(([k, v]) => `  ${k}: ${v}`).join('\n'));
