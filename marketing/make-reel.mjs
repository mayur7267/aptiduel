// Makes one Instagram reel (1080 x 1920, 30 fps): Ava speaks the lines,
// the scenes are drawn frame by frame in Chromium to match her words, and
// the frames and the mixed sound are encoded to H.264 + AAC.
//
//   node make-reel.mjs <reel> <out dir> --raw <raw screens> --foot <duel frames> --encoder <encode binary>
//                      [--preview 1.5,4,9.2]   just those moments, as PNGs
//                      [--frames <dir>]        keep the frames there, and reuse them if
//                                              they are all there already (to remix only)
//
// <reel> names reels/<reel>.mjs (the lines, music and sound cues) and
// reels/<reel>.js (the scenes). Writes <reel>.mp4, <reel>-no-music.mp4 (to
// add a trending sound in Instagram) and <reel>-timings.json.

import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { RATE, mix, speak, wordTimes, writeWav } from "./audio.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const [name, outArg] = process.argv.slice(2, 4);
const flags = {};
for (let i = 4; i < process.argv.length; i += 2) flags[process.argv[i].slice(2)] = process.argv[i + 1];
const out = resolve(outArg);
mkdirSync(out, { recursive: true });
const work = mkdtempSync(join(tmpdir(), `apticks-${name}-`));
const def = (await import(join(HERE, "reels", `${name}.mjs`))).default;

// ---- Voice-over, and when every word lands
const lines = {}, clips = [];
let cursor = def.lead ?? 0.3;
def.lines.forEach((line, i) => {
  const samples = speak(line.text, join(work, `vo-${i}.wav`), { rate: line.rate ?? def.rate });
  const t = cursor + (i === 0 ? 0 : line.gap ?? 0.3), d = samples.length / RATE;
  lines[line.id] = { t, d, text: line.text, caption: line.caption !== false, words: wordTimes(line.text, t, d) };
  clips.push({ samples, t });
  cursor = t + d;
});
const duration = Math.ceil((cursor + (def.tail ?? 2)) * 30) / 30;
const T = { lines, duration, W: 1080, H: 1920 };
writeFileSync(join(out, `${name}-timings.json`), JSON.stringify(T, null, 1));
console.log(`${name}: ${duration.toFixed(2)} s, ${def.lines.length} lines`);

// ---- Sound
const { full, voiceOnly } = mix(duration, clips, def.sfx(T), { bpm: def.bpm, drop: def.drop(T) });
writeWav(join(work, "full.wav"), ...full);
writeWav(join(work, "voice.wav"), ...voiceOnly);

// ---- Pictures
const footFrames = flags.foot ? readdirSync(flags.foot).filter((f) => f.endsWith(".png")).length : 0;
const A = { raw: `file://${resolve(flags.raw)}`, foot: flags.foot ? `file://${resolve(flags.foot)}` : "", footFrames, icon: `file://${join(HERE, "assets", "icon.png")}` };
const html = `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@500;600;700;800&family=JetBrains+Mono:wght@700&family=Unbounded:wght@700;900&display=block" rel="stylesheet">
<link href="file://${join(HERE, "kit.css")}" rel="stylesheet">
<style>.stage{width:1080px;height:1920px}</style></head><body>
<div class="stage" id="stage">${"<!--bg-->"}<div class="layer" id="world"></div><div id="cap"></div></div>
<script>window.T = ${JSON.stringify(T)}; window.A = ${JSON.stringify(A)};</script>
<script src="file://${join(HERE, "kit.js")}"></script>
<script>document.getElementById("stage").insertAdjacentHTML("afterbegin", background());</script>
<script src="file://${join(HERE, "reels", `${name}.js`)}"></script>
</body></html>`;
const page_ = join(work, "reel.html");
writeFileSync(page_, html);

const browser = await chromium.launch();
const page = await (await browser.newContext({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 })).newPage();
page.on("pageerror", (e) => console.error("page error:", e.message));
await page.goto(`file://${page_}`, { waitUntil: "networkidle" });
await page.evaluate(() => window.start());
const shot = async (t, path) => {
  await page.evaluate((t) => window.draw(t), t);
  await page.screenshot({ path, clip: { x: 0, y: 0, width: 1080, height: 1920 } });
};

if (flags.preview) {
  for (const t of flags.preview.split(",").map(Number)) await shot(t, join(out, `${name}-at-${t.toFixed(2)}.png`));
  await browser.close();
  console.log(`previews in ${out}`);
} else {
  const frames = flags.frames ? resolve(flags.frames) : join(work, "frames");
  mkdirSync(frames, { recursive: true });
  const n = Math.round(duration * 30);
  if (readdirSync(frames).filter((f) => f.endsWith(".png")).length === n) console.log(`reusing ${n} frames`);
  else for (let i = 0; i < n; i++) {
    await shot(i / 30, join(frames, `frame-${String(i).padStart(5, "0")}.png`));
    if (i % 150 === 0) console.log(`frame ${i} / ${n}`);
  }
  await browser.close();
  execFileSync(flags.encoder, [frames, "30", "1080", "1920", join(out, `${name}.mp4`), join(work, "full.wav")], { stdio: "inherit" });
  execFileSync(flags.encoder, [frames, "30", "1080", "1920", join(out, `${name}-no-music.mp4`), join(work, "voice.wav")], { stdio: "inherit" });
}
rmSync(work, { recursive: true, force: true });
