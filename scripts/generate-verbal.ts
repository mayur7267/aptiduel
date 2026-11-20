// Builds the Verbal section's questions and writes supabase/seed-verbal-N.sql.
//
// Every question comes from the lists in scripts/verbal/, written for
// Apticks (nothing copied from question sites), and every wrong option is
// wrong by construction:
//   - Synonyms: the wrong options are the word's antonyms or a word from a
//     different idea altogether (see the axes in words.ts), never a near
//     synonym. Antonyms: the wrong options are the word's synonyms.
//   - One-word substitution, idioms, phrasal verbs: the wrong options are
//     other entries' meanings, never two of the same sense.
//   - Spelling: each misspelling is a typical slip (a doubled or single
//     letter, ie/ei, -ance/-ence, a silent letter) and is checked against
//     the system word list, so a "wrong" spelling is never a real word.
//   - Grammar: the wrong options of each sentence are written to be wrong
//     in it; Spot the error puts one of them in.
//   - Voice and reported speech are built by rule (tense, agreement,
//     pronouns, time words), so the right form is computed.
//
// Run from the repo root:  node scripts/generate-verbal.ts
// Writes supabase/seed-verbal-*.sql and prints a sample to check by eye.

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { WORDS } from './verbal/words.ts';
import { IDIOMS, ONE_WORD, PHRASAL } from './verbal/phrases.ts';
import { SPELLING } from './verbal/spelling.ts';
import { GRAMMAR, SLOTS } from './verbal/grammar.ts';
import { JUMBLES } from './verbal/jumbles.ts';
import { DOERS, SPEECH, VERBS } from './verbal/speech.ts';

type Q = {
  topic: string;
  difficulty: 1 | 2 | 3;
  body: string;
  options: string[];
  correct: number;
  explanation: string;
  time: number;
  template: string;
};

// The same tags the hand-written verbal questions carry.
const COMPANIES = ['TCS NQT', 'Infosys', 'Wipro', 'Cognizant', 'Capgemini', 'HCL Tech', 'Tech Mahindra', 'Hexaware', 'Mphasis', 'Deloitte'];

// Questions already on the server (the first 50, written by hand).
const EXISTING_SYN = new Set('abundant ambiguous benevolent candid concise diligent feasible inevitable lucid meticulous obsolete prudent resilient tenacious'.split(' '));
const EXISTING_ANT = new Set('ancient conceal expand fragile generous hostile humble optimistic reject scarcity temporary transparent verbose voluntary'.split(' '));
const EXISTING_IDIOMS = new Set(['a piece of cake', 'bite the bullet', 'break the ice', 'burn the midnight oil', 'call it a day', 'cost an arm and a leg', 'hit the nail on the head', 'once in a blue moon', 'spill the beans', 'under the weather']);

// ---------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------

function rng(seed: string) {
  let h = createHash('md5').update(seed).digest().readUInt32LE(0);
  return () => {
    h = (h + 0x6d2b79f5) | 0;
    let t = Math.imul(h ^ (h >>> 15), 1 | h);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function shuffle<T>(xs: T[], r: () => number): T[] {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(r() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
const pick = <T,>(xs: T[], r: () => number): T => xs[Math.floor(r() * xs.length)];
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
const lc = (s: string) => s.charAt(0).toLowerCase() + s.slice(1);
const lines = (s: string) => s.trim().split('\n').map((l) => l.trim()).filter(Boolean);

// A question with its options in a random (but repeatable) order.
function make(q: Omit<Q, 'options' | 'correct'> & { right: string; wrong: string[]; keepOrder?: boolean }, seed: string): Q {
  const all = [q.right, ...q.wrong];
  const options = q.keepOrder ? all : shuffle(all, rng(seed));
  const { right, wrong, keepOrder, ...rest } = q;
  void wrong;
  void keepOrder;
  return { ...rest, options, correct: options.indexOf(right) };
}

const out: Q[] = [];
const problems: string[] = [];
function add(q: Q) {
  const seen = new Set(q.options.map((o) => o.toLowerCase().trim()));
  if (q.options.length !== 4) problems.push(`not 4 options: ${q.body}`);
  else if (seen.size !== 4) problems.push(`repeated option: ${q.body} ${JSON.stringify(q.options)}`);
  else if (q.correct < 0) problems.push(`answer missing: ${q.body}`);
  else if (/[{}]|___/.test(q.options.join(' ')) || /[{}]/.test(q.body)) problems.push(`unfilled slot: ${q.body}`);
  else if (!q.explanation) problems.push(`no explanation: ${q.body}`);
  else out.push(q);
}

// ---------------------------------------------------------------------
// Synonyms and antonyms
// ---------------------------------------------------------------------

type Word = { word: string; pos: string; axis: string; level: 1 | 2 | 3; meaning: string; syns: string[]; ants: string[] };
const words: Word[] = lines(WORDS).map((l) => {
  const [word, pos, axis, level, meaning, syns, ants] = l.split('|');
  return { word, pos, axis, level: Number(level) as 1 | 2 | 3, meaning, syns: syns.split(','), ants: ants.split(',') };
});
const byWord = new Map(words.map((w) => [w.word, w]));
const axisOf = (w: Word) => w.axis.replace(/[+-]$/, '');
const near = (w: Word) => new Set([w.word, ...w.syns, ...w.ants]);

// Everything a word is tied to: its own synonyms and antonyms, theirs when
// they're in the bank too, and any word that lists it or its synonyms.
function related(w: Word): Set<string> {
  const r = near(w);
  for (const x of [...r]) {
    const other = byWord.get(x);
    if (other) for (const y of near(other)) r.add(y);
  }
  const mine = new Set([w.word, ...w.syns]);
  for (const other of words) {
    if ([...near(other)].some((x) => mine.has(x))) for (const y of near(other)) r.add(y);
  }
  return r;
}

// Words from a different idea with nothing in common with this one.
function unrelated(w: Word): string[] {
  const rel = related(w);
  return words
    .filter((o) => o.pos === w.pos && axisOf(o) !== axisOf(w) && !rel.has(o.word) && ![...near(o)].some((x) => rel.has(x)))
    .map((o) => o.word);
}

for (const w of words) {
  const others = unrelated(w);
  const time = w.level === 3 ? 30 : 25;
  if (!EXISTING_SYN.has(w.word)) {
    for (const [i, answer] of w.syns.slice(0, 2).entries()) {
      const r = rng(`syn|${w.word}|${i}`);
      const wrong = [...w.ants.slice(0, 2)];
      for (const o of shuffle(others, r)) if (wrong.length < 3 && !wrong.includes(o)) wrong.push(o);
      add(make({
        topic: 'Synonyms', difficulty: w.level, time, template: 'verbal-synonyms',
        body: `Choose the word closest in meaning to ${w.word.toUpperCase()}.`,
        right: cap(answer), wrong: wrong.map(cap),
        explanation: `${cap(w.word)} means "${w.meaning}". ${cap(answer)} is the closest in meaning.`,
      }, `syn|${w.word}|${answer}`));
    }
  }
  if (!EXISTING_ANT.has(w.word)) {
    const answer = w.ants[0];
    const wrong = w.syns.slice(0, 3);
    add(make({
      topic: 'Antonyms', difficulty: w.level, time, template: 'verbal-antonyms',
      body: `Choose the word opposite in meaning to ${w.word.toUpperCase()}.`,
      right: cap(answer), wrong: wrong.map(cap),
      explanation: `${cap(w.word)} means "${w.meaning}", so the opposite is ${cap(answer)}.`,
    }, `ant|${w.word}`));
  }
}

// ---------------------------------------------------------------------
// One-word substitution
// ---------------------------------------------------------------------

const oneWords = lines(ONE_WORD).map((l) => {
  const [phrase, word, group, level] = l.split('|');
  return { phrase, word, group, level: Number(level) as 1 | 2 | 3 };
});
for (const e of oneWords) {
  const peers = oneWords.filter((o) => o.group === e.group && o.word !== e.word);
  const r = rng(`ow|${e.word}`);
  const three = shuffle(peers, r).slice(0, 3);
  add(make({
    topic: 'One-word substitution', difficulty: e.level, time: 25, template: 'verbal-one-word',
    body: `Which one word means "${lc(e.phrase)}"?`,
    right: e.word, wrong: three.map((o) => o.word),
    explanation: `${e.word}: ${lc(e.phrase)}.`,
  }, `ow|${e.word}`));
  const three2 = shuffle(peers, rng(`owr|${e.word}`)).slice(0, 3);
  add(make({
    topic: 'One-word substitution', difficulty: e.level, time: 30, template: 'verbal-one-word-meaning',
    body: `What does "${e.word}" mean?`,
    right: cap(lc(e.phrase)), wrong: three2.map((o) => cap(lc(o.phrase))),
    explanation: `${e.word}: ${lc(e.phrase)}.`,
  }, `owr|${e.word}`));
}

// ---------------------------------------------------------------------
// Idioms
// ---------------------------------------------------------------------

const idioms = lines(IDIOMS).map((l) => {
  const [idiom, meaning, level, sense] = l.split('|');
  return { idiom, meaning, level: Number(level) as 1 | 2 | 3, sense: sense || '' };
});
for (const e of idioms) {
  if (EXISTING_IDIOMS.has(e.idiom)) continue;
  const peers = idioms.filter((o) => o.idiom !== e.idiom && (!e.sense || o.sense !== e.sense));
  add(make({
    topic: 'Idioms', difficulty: e.level, time: 25, template: 'verbal-idioms',
    body: `What does the idiom "${e.idiom}" mean?`,
    right: cap(e.meaning), wrong: shuffle(peers, rng(`id|${e.idiom}`)).slice(0, 3).map((o) => cap(o.meaning)),
    explanation: `"${cap(e.idiom)}" means ${e.meaning}.`,
  }, `id|${e.idiom}`));
  add(make({
    topic: 'Idioms', difficulty: e.level, time: 30, template: 'verbal-idioms-which',
    body: `Which idiom means "${e.meaning}"?`,
    right: cap(e.idiom), wrong: shuffle(peers, rng(`idw|${e.idiom}`)).slice(0, 3).map((o) => cap(o.idiom)),
    explanation: `"${cap(e.idiom)}" means ${e.meaning}.`,
  }, `idw|${e.idiom}`));
}

// ---------------------------------------------------------------------
// Phrasal verbs
// ---------------------------------------------------------------------

const phrasals = lines(PHRASAL).map((l) => {
  const [form, meaning, sentence, level, sense] = l.split('|');
  return { form, meaning, sentence, level: Number(level) as 1 | 2 | 3, sense: sense || '' };
});
for (const e of phrasals) {
  if (!e.sentence.includes(e.form.split(' ')[0])) problems.push(`phrasal verb not in its sentence: ${e.form}`);
  const peers = phrasals.filter((o) => o.form !== e.form && (!e.sense || o.sense !== e.sense) && o.meaning !== e.meaning);
  add(make({
    topic: 'Phrasal verbs', difficulty: e.level, time: 30, template: 'verbal-phrasal',
    body: `What does "${e.form}" mean in this sentence?\n"${e.sentence}"`,
    right: cap(e.meaning), wrong: shuffle(peers, rng(`ph|${e.form}`)).slice(0, 3).map((o) => cap(o.meaning)),
    explanation: `Here "${e.form}" means "${e.meaning}".`,
  }, `ph|${e.form}`));
}

// ---------------------------------------------------------------------
// Spelling
// ---------------------------------------------------------------------

const dictionary = new Set(readFileSync('/usr/share/dict/words', 'utf8').split('\n').map((w) => w.trim().toLowerCase()));
const VOWELS = 'aeiou';
const isVowel = (c: string) => VOWELS.includes(c);

// Famous misspellings no rule makes.
const CLASSIC_SLIPS: Record<string, string[]> = { forty: ['fourty', 'fortey', 'fourtey'] };

// Typical slips, in tiers from the most common kind: a dropped double
// letter, ie/ei and suffix mix-ups; then a dropped silent letter or c for
// s; then a vowel swapped later in the word; and last a wrongly doubled
// letter. Each tier is shuffled, so the three picked vary.
function misspellings(word: string): string[] {
  const w = word.toLowerCase();
  const tiers: string[][] = [[], [], [], []];
  for (let i = 0; i < w.length - 1; i++) {
    if (w[i] === w[i + 1] && /[a-z]/.test(w[i])) tiers[0].push(w.slice(0, i) + w.slice(i + 1));
  }
  for (const [a, b] of [['ie', 'ei'], ['ei', 'ie']]) {
    let k = w.indexOf(a);
    while (k >= 0) {
      tiers[0].push(w.slice(0, k) + b + w.slice(k + 2));
      k = w.indexOf(a, k + 1);
    }
  }
  for (const [a, b] of [['ance', 'ence'], ['ence', 'ance'], ['ant', 'ent'], ['ent', 'ant'], ['able', 'ible'], ['ible', 'able'], ['ary', 'ery'], ['ery', 'ary'], ['eous', 'ious'], ['ious', 'eous'], ['cede', 'ceed'], ['ceed', 'cede'], ['sede', 'cede'], ['ise', 'ize']]) {
    const k = w.lastIndexOf(a);
    if (k > 0) tiers[0].push(w.slice(0, k) + b + w.slice(k + a.length));
  }
  for (const [re, to] of [[/rh/, 'r'], [/gh/, 'g'], [/sc(?=[ie])/, 's'], [/mn$/, 'm'], [/mb$/, 'm'], [/^kn/, 'n'], [/^ps/, 's'], [/^pn/, 'n'], [/gu(?=[ae])/, 'g'], [/(?<=[a-z])c(?=[ei])/, 's'], [/(?<=[a-z])s(?=[ei])/, 'c'], [/ph/, 'f'], [/ch/, 'c'], [/tg/, 'g']] as [RegExp, string][]) {
    if (re.test(w)) tiers[1].push(w.replace(re, to));
  }
  for (let i = 2; i < w.length - 2; i++) {
    if (isVowel(w[i]) && !isVowel(w[i - 1]) && !isVowel(w[i + 1])) tiers[2].push(w.slice(0, i) + w.slice(i + 1));
  }
  for (let i = 1; i < w.length - 2; i++) {
    if (w[i] !== w[i + 1]) tiers[3].push(w.slice(0, i) + w[i + 1] + w[i] + w.slice(i + 2));
  }
  const firstVowel = [...w].findIndex(isVowel);
  for (let i = firstVowel + 1; i < w.length - 1; i++) {
    const swap = { a: 'e', e: 'a', i: 'e' }[w[i] as 'a' | 'e' | 'i'];
    if (swap) tiers[2].push(w.slice(0, i) + swap + w.slice(i + 1));
    if (w[i] === 'e') tiers[2].push(w.slice(0, i) + 'i' + w.slice(i + 1));
  }
  for (let i = 1; i < w.length - 1; i++) {
    const c = w[i];
    if (/[bcdfglmnprst]/.test(c) && isVowel(w[i - 1]) && isVowel(w[i + 1])) tiers[3].push(w.slice(0, i + 1) + c + w.slice(i + 1));
  }
  const ok = (m: string) => m !== w && m.length >= 3 && !dictionary.has(m) && !/(.)\1\1/.test(m);
  const keep = (m: string) => (word[0] === word[0].toUpperCase() ? cap(m) : m);
  const r = rng(`slips|${word}`);
  const seen = new Set<string>();
  const outList: string[] = [...(CLASSIC_SLIPS[w] ?? [])];
  for (const tier of tiers) {
    for (const m of shuffle(tier.filter(ok), r)) {
      if (!seen.has(m)) {
        seen.add(m);
        outList.push(m);
      }
    }
  }
  return outList.map(keep);
}

const spellings = lines(SPELLING).map((l) => {
  const [word, level] = l.split('|');
  return { word, level: Number(level) as 1 | 2 | 3 };
});
// The word list has no inflected forms ("occurred"), so only those may be
// missing from it.
const INFLECTED = new Set(['occurred', 'referred', 'omitted']);
for (const e of spellings) {
  if (!dictionary.has(e.word.toLowerCase()) && !INFLECTED.has(e.word)) problems.push(`not in the word list: ${e.word}`);
}
for (const e of spellings) {
  const slips = misspellings(e.word);
  if (slips.length < 3) {
    problems.push(`too few misspellings for ${e.word}`);
    continue;
  }
  const three = slips.slice(0, 3);
  add(make({
    topic: 'Spelling', difficulty: e.level, time: 25, template: 'verbal-spelling',
    body: 'Choose the correctly spelt word.',
    right: e.word, wrong: three,
    explanation: `The correct spelling is "${e.word}".`,
  }, `sp|${e.word}`));
  const others = shuffle(spellings.filter((o) => o.word !== e.word), rng(`spw|${e.word}`)).slice(0, 3).map((o) => o.word);
  const wrongOne = slips[0];
  add(make({
    topic: 'Spelling', difficulty: e.level, time: 25, template: 'verbal-misspelt',
    body: 'Which word is spelt wrongly?',
    right: wrongOne, wrong: others,
    explanation: `"${wrongOne}" is wrong; it is spelt "${e.word}".`,
  }, `spw|${e.word}`));
}

// ---------------------------------------------------------------------
// Grammar: Fill in the blanks and Spot the error
// ---------------------------------------------------------------------

const frames = lines(GRAMMAR).map((l) => {
  const [topic, level, sentence, right, wrong, rule] = l.split('|');
  return { topic, level: Number(level) as 1 | 2 | 3, sentence, right, wrong: wrong.split(';'), rule };
});

// The frame with its slots filled: different people, places and dates.
function fill(sentence: string, r: () => number): string {
  const used = new Set<string>();
  return sentence.replace(/\{(\w+)\}/g, (_, slot: string) => {
    const choices = SLOTS[slot].filter((v) => !used.has(v));
    const v = pick(choices, r);
    used.add(v);
    return v;
  });
}

// Put a word in the blank. "No article" leaves it out.
function put(part: string, word: string): string {
  if (word !== 'No article' && word !== 'no article') return part.replace('___', word);
  const rest = part.replace('___', '').replace(/^\s+/, '');
  return part.startsWith('___') ? cap(rest) : part.replace(' ___', '');
}

for (const f of frames) {
  const slotted = /\{/.test(f.sentence);
  if (f.sentence.split(' / ').length !== 3) problems.push(`sentence not in three parts: ${f.sentence}`);
  const copies = slotted ? 4 : 1;
  const seen = new Set<string>();
  for (let k = 0; k < copies * 3 && seen.size < copies; k++) {
    const s = fill(f.sentence, rng(`gr|${f.sentence}|${k}`));
    if (seen.has(s)) continue;
    seen.add(s);
    const blank = s.replace(/ \/ /g, ' ');
    add(make({
      topic: 'Fill in the blanks', difficulty: f.level, time: 30, template: 'verbal-fill',
      body: `Fill in the blank: ${blank}`,
      right: f.right, wrong: f.wrong,
      explanation: `${f.rule} The sentence reads: "${put(blank, f.right)}"`,
    }, `fill|${s}`));
  }
  // Spot the error: a wrong word in the blank, or (sometimes) none.
  const spots = slotted ? 3 : 2;
  for (let k = 0; k < spots; k++) {
    const s = fill(f.sentence, rng(`sp|${f.sentence}|${k}`));
    const parts = s.split(' / ');
    const at = parts.findIndex((p) => p.includes('___'));
    const noError = k === spots - 1 && slotted;
    const word = noError ? f.right : f.wrong[k % f.wrong.length];
    const shown = parts.map((p, i) => (i === at ? put(p, word) : p));
    const sentence = shown.join(' ');
    const correctSentence = parts.map((p, i) => (i === at ? put(p, f.right) : p)).join(' ');
    add({
      topic: 'Spot the error', difficulty: Math.min(3, f.level + 1) as 1 | 2 | 3, time: 40, template: 'verbal-spot-error',
      body: `Which part of this sentence has an error?\n"${sentence}"`,
      options: [...shown, 'No error'],
      correct: noError ? 3 : at,
      explanation: noError ? `The sentence is correct. ${f.rule}` : `${f.rule} It should read: "${correctSentence}"`,
    });
  }
}

// ---------------------------------------------------------------------
// Active and passive voice
// ---------------------------------------------------------------------

type Tense = 'present' | 'past' | 'presentCont' | 'pastCont' | 'presentPerfect' | 'pastPerfect' | 'future';
const TENSE_NAME: Record<Tense, string> = {
  present: 'simple present', past: 'simple past', presentCont: 'present continuous', pastCont: 'past continuous',
  presentPerfect: 'present perfect', pastPerfect: 'past perfect', future: 'simple future',
};
const NEAR: Record<Tense, Tense[]> = {
  present: ['past', 'presentCont', 'presentPerfect', 'future'],
  past: ['present', 'pastCont', 'pastPerfect', 'presentPerfect'],
  presentCont: ['present', 'pastCont', 'presentPerfect', 'past'],
  pastCont: ['past', 'presentCont', 'pastPerfect', 'present'],
  presentPerfect: ['present', 'past', 'pastPerfect', 'presentCont'],
  pastPerfect: ['past', 'presentPerfect', 'pastCont', 'present'],
  future: ['present', 'past', 'presentPerfect', 'presentCont'],
};
const verbs = lines(VERBS).map((l) => {
  const [base, he, past, pp, ing, one, many] = l.split('|');
  return { base, he, past, pp, ing, one, many };
});
const doers = lines(DOERS).map((l) => {
  const [s, o, p] = l.split('|');
  return { s, o, p };
});
// Odd pairs ("The company sings a song") are left out.
const COMPANY_VERBS = new Set(['write', 'sign', 'deliver', 'send', 'build', 'prepare', 'invite', 'repair', 'check', 'paint', 'clean']);

type Verb = (typeof verbs)[number];
type Doer = (typeof doers)[number];
function active(d: Doer, v: Verb, obj: string, t: Tense): string {
  const be = d.p === '1' ? 'am' : d.p === '3' ? 'is' : 'are';
  const vp = {
    present: d.p === '3' ? v.he : v.base,
    past: v.past,
    presentCont: `${be} ${v.ing}`,
    pastCont: `${d.p === 'p' ? 'were' : 'was'} ${v.ing}`,
    presentPerfect: `${d.p === '3' ? 'has' : 'have'} ${v.pp}`,
    pastPerfect: `had ${v.pp}`,
    future: `will ${v.base}`,
  }[t];
  return `${d.s} ${vp} ${obj}.`;
}
function passive(d: Doer, v: Verb, obj: string, plural: boolean, t: Tense): string {
  const be = {
    present: plural ? 'are' : 'is',
    past: plural ? 'were' : 'was',
    presentCont: plural ? 'are being' : 'is being',
    pastCont: plural ? 'were being' : 'was being',
    presentPerfect: plural ? 'have been' : 'has been',
    pastPerfect: 'had been',
    future: 'will be',
  }[t];
  return `${cap(obj)} ${be} ${v.pp} by ${d.o}.`;
}
const TENSES = Object.keys(TENSE_NAME) as Tense[];
const voiceSeen = new Set<string>();
for (let k = 0; voiceSeen.size < 340 && k < 5000; k++) {
  const r = rng(`voice|${k}`);
  const v = pick(verbs, r);
  const d = pick(doers, r);
  if (d.s === 'The company' && !COMPANY_VERBS.has(v.base)) continue;
  const plural = r() < 0.4;
  const obj = plural ? v.many : v.one;
  const t = pick(TENSES, r);
  const toPassive = voiceSeen.size % 2 === 0;
  const key = `${toPassive}|${d.s}|${v.base}|${plural}|${t}`;
  if (voiceSeen.has(key)) continue;
  const form = (tt: Tense) => (toPassive ? passive(d, v, obj, plural, tt) : active(d, v, obj, tt));
  const right = form(t);
  const wrong: string[] = [];
  for (const tt of NEAR[t]) {
    const w = form(tt);
    if (wrong.length < 3 && w !== right && !wrong.includes(w)) wrong.push(w);
  }
  if (wrong.length < 3) continue;
  voiceSeen.add(key);
  const level = (t === 'present' || t === 'past' ? 1 : t === 'pastPerfect' || t === 'pastCont' ? 3 : 2) as 1 | 2 | 3;
  add(make({
    topic: 'Active and passive voice', difficulty: level, time: 40, template: toPassive ? 'verbal-to-passive' : 'verbal-to-active',
    body: toPassive
      ? `Choose the passive form of this sentence:\n"${active(d, v, obj, t)}"`
      : `Choose the active form of this sentence:\n"${passive(d, v, obj, plural, t)}"`,
    right, wrong,
    explanation: toPassive
      ? `The sentence is in the ${TENSE_NAME[t]}, and so is its passive: "${right}"`
      : `The passive is in the ${TENSE_NAME[t]}, and so is the active form: "${right}"`,
  }, key));
}

// ---------------------------------------------------------------------
// Direct and indirect speech
// ---------------------------------------------------------------------

const speech = lines(SPEECH).map((l) => {
  const [kind, level, direct, right, wrong] = l.split('|');
  return { kind, level: Number(level) as 1 | 2 | 3, direct, right, wrong: wrong.split(';') };
});
const SPEAKERS = [
  { name: 'Ravi', he: 'he', his: 'his', him: 'him' },
  { name: 'Arjun', he: 'he', his: 'his', him: 'him' },
  { name: 'Karan', he: 'he', his: 'his', him: 'him' },
  { name: 'Priya', he: 'she', his: 'her', him: 'her' },
  { name: 'Neha', he: 'she', his: 'her', him: 'her' },
  { name: 'Meera', he: 'she', his: 'her', him: 'her' },
];
const RULE: Record<string, string> = {
  said: 'After "said", the tense moves one step back, "I" and "my" change to match the speaker, and words like "today", "tomorrow" and "here" change too.',
  told: 'After "said to me", we report with "told me that", move the tense back and change "I" and "you" to match who is speaking.',
  asked: 'A reported question uses "asked", the word order of a statement (not a question) and a tense one step back.',
  order: 'A command is reported as "told me to ..." (or "told me not to ...").',
  request: 'A request with "please" is reported as "requested me to ...".',
  advise: 'Advice is reported as "advised me to ...".',
};
for (const e of speech) {
  for (const sp of SPEAKERS) {
    const city = pick(SLOTS.city, rng(`city|${e.direct}|${sp.name}`));
    const sub = (s: string) => s.replace(/\{he\}/g, sp.he).replace(/\{his\}/g, sp.his).replace(/\{him\}/g, sp.him).replace(/\{city\}/g, city);
    const quote = sub(e.direct);
    const reporting = e.kind === 'said' ? `${sp.name} said, "${quote}"` : `${sp.name} said to me, "${quote}"`;
    const right = `${sp.name} ${sub(e.right)}.`;
    add(make({
      topic: 'Direct and indirect speech', difficulty: e.level, time: 40, template: 'verbal-speech',
      body: `Choose the correct indirect form:\n${reporting}`,
      right, wrong: e.wrong.map((w) => `${sp.name} ${sub(w)}.`),
      explanation: `${RULE[e.kind]} So: "${right}"`,
    }, `speech|${sp.name}|${e.direct}`));
  }
}

// ---------------------------------------------------------------------
// Para jumbles
// ---------------------------------------------------------------------

const blocks = JUMBLES.trim().split(/\n\s*\n/).map((b) => lines(b));
for (const [n, b] of blocks.entries()) {
  if (b.length !== 5) {
    problems.push(`para jumble ${n + 1} has ${b.length} lines`);
    continue;
  }
  const sentences = b.slice(0, 4);
  const reason = b[4];
  const r = rng(`pj|${sentences[0]}`);
  // Labels P Q R S go to the sentences in a shuffled order.
  const shown = shuffle([0, 1, 2, 3], r);
  const label = (i: number) => 'PQRS'[shown.indexOf(i)];
  const order = [0, 1, 2, 3];
  const spell = (o: number[]) => o.map(label).join('');
  const right = spell(order);
  const wrong = [[1, 0, 2, 3], [0, 2, 1, 3], [0, 1, 3, 2]].map(spell);
  add(make({
    topic: 'Para jumbles', difficulty: 2, time: 75, template: 'verbal-para-jumble',
    body: `Arrange the sentences in the right order.\n${shown.map((i, k) => `${'PQRS'[k]}: ${sentences[i]}`).join('\n')}`,
    right, wrong,
    explanation: `${reason} The order is ${right}.`,
  }, `pj|${sentences[0]}`));
}

// ---------------------------------------------------------------------
// Checks, a sample to read, and the seed files
// ---------------------------------------------------------------------

const keys = new Set<string>();
const variant = (q: Q) => createHash('md5').update(q.template + '|' + q.options.join('|') + '|' + q.correct).digest('hex').slice(0, 16);
for (const q of out) {
  const k = q.body + '|' + variant(q);
  if (keys.has(k)) problems.push(`duplicate: ${q.body}`);
  keys.add(k);
}
if (problems.length) {
  console.error(problems.join('\n'));
  console.error(`${problems.length} problems`);
  process.exit(1);
}

const byTopic = new Map<string, number>();
for (const q of out) byTopic.set(q.topic, (byTopic.get(q.topic) ?? 0) + 1);
console.log([...byTopic].map(([t, n]) => `${t}: ${n}`).join('\n'));
console.log(`total: ${out.length}`);

if (process.argv.includes('--sample')) {
  const r = rng('sample');
  for (const topic of byTopic.keys()) {
    for (const q of shuffle(out.filter((x) => x.topic === topic), r).slice(0, 6)) {
      console.log(`\n[${q.topic} · ${q.difficulty}] ${q.body}`);
      q.options.forEach((o, i) => console.log(`  ${i === q.correct ? '✓' : ' '} ${o}`));
      console.log(`  → ${q.explanation}`);
    }
  }
}

const sq = (s: string) => `'${s.replace(/'/g, "''")}'`;
const sqArr = (xs: string[]) => `array[${xs.map(sq).join(', ')}]`;
const row = (q: Q) =>
  `  ('verbal', ${sq(q.topic)}, ${q.difficulty}, ${sq(q.body)}, ${sqArr(q.options)}, ${q.correct}, ${sq(q.explanation)}, ${q.time}, ${sqArr(COMPANIES)}, ${sq(q.template)}, ${sq(variant(q))})`;
const ordered = shuffle(out, rng('order'));
const per = 1000;
const files = Math.ceil(ordered.length / per);
for (let i = 0; i < files; i++) {
  const chunk = ordered.slice(i * per, (i + 1) * per);
  const sql = `-- Generated by scripts/generate-verbal.ts. Do not edit by hand.
-- Part ${i + 1} of ${files}. Safe to run again: existing rows are kept.

insert into public.questions
  (section, topic, difficulty, body, options, correct_idx, explanation, time_limit_s, company_tags, template, variant)
values
${chunk.map(row).join(',\n')}
on conflict (body, (coalesce(variant, ''))) do nothing;
`;
  writeFileSync(new URL(`../supabase/seed-verbal-${i + 1}.sql`, import.meta.url), sql);
}
console.log(`wrote ${files} files`);
