// Unit tests for the plain helpers in src/lib. Uses Node's built-in test
// runner, which loads the TypeScript files directly.
//
// Run from web/:  npm test

import assert from "node:assert/strict";
import { test } from "node:test";
import { COMPANIES, companyBySlug } from "../src/lib/companies.ts";
import { batch, challengeShareText, clock, initials, signed, tierFor, untilIstMidnight } from "../src/lib/format.ts";

test("tierFor names the tier and the gap to the next", () => {
  assert.deepEqual(
    { ...tierFor(1000), next: tierFor(1000).next?.name },
    { name: "Trainee", min: 900, next: "Analyst", progress: 0.5, toNext: 100 },
  );
  assert.equal(tierFor(850).name, "Fresher");
  assert.equal(tierFor(100).progress, 0);
  const top = tierFor(2400);
  assert.equal(top.name, "Architect");
  assert.equal(top.next, null);
  assert.equal(top.toNext, 0);
});

test("clock shows minutes and seconds, never negative", () => {
  assert.equal(clock(108_000), "1:48");
  assert.equal(clock(5_400), "0:05");
  assert.equal(clock(-200), "0:00");
});

test("signed uses a real minus sign", () => {
  assert.equal(signed(12), "+12");
  assert.equal(signed(-7), "−7");
  assert.equal(signed(0), "±0");
});

test("initials", () => {
  assert.equal(initials("Sneha G."), "SG");
  assert.equal(initials("mayur"), "MA");
  assert.equal(initials("   "), "?");
});

test("untilIstMidnight counts down to midnight in India", () => {
  assert.equal(untilIstMidnight(Date.UTC(2026, 9, 28, 18, 30)), "24h 00m"); // 00:00 IST
  assert.equal(untilIstMidnight(Date.UTC(2026, 9, 28, 17, 0)), "1h 30m"); // 22:30 IST
  assert.equal(untilIstMidnight(Date.UTC(2026, 9, 28, 18, 29, 30)), "1m"); // 30 s left
});

test("batch and share text", () => {
  assert.equal(batch(2027), "Batch ’27");
  assert.equal(batch(null), null);
  const text = challengeShareText("Asha", 4, 95_000, "ABC123");
  assert.match(text, /^Asha scored 4\/5 in 1:35 on Apticks\./);
  assert.match(text, /\/c\/ABC123$/);
});

test("companies have unique slugs and resolve by slug", () => {
  assert.equal(new Set(COMPANIES.map((c) => c.slug)).size, COMPANIES.length);
  assert.equal(companyBySlug("tcs-nqt")?.name, "TCS NQT");
  assert.equal(companyBySlug("nope"), null);
});
