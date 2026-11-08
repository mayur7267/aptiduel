// Renders the week's posts and stories (stills.js) to PNG.
//
//   node make-stills.mjs <out dir> --raw <raw screens dir> [--only id,id]

import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const HERE = dirname(fileURLToPath(import.meta.url));
const out = resolve(process.argv[2]);
const flags = {};
for (let i = 3; i < process.argv.length; i += 2) flags[process.argv[i].slice(2)] = process.argv[i + 1];
mkdirSync(out, { recursive: true });
const work = mkdtempSync(join(tmpdir(), "apticks-stills-"));

const A = { raw: `file://${resolve(flags.raw)}`, icon: `file://${join(HERE, "assets", "icon.png")}` };
const html = `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@500;600;700;800&family=JetBrains+Mono:wght@700&family=Unbounded:wght@700;900&display=block" rel="stylesheet">
<link href="file://${join(HERE, "kit.css")}" rel="stylesheet"></head><body>
<div class="stage" id="stage"></div>
<script>window.A = ${JSON.stringify(A)};</script>
<script src="file://${join(HERE, "kit.js")}"></script>
<script src="file://${join(HERE, "stills.js")}"></script>
</body></html>`;
writeFileSync(join(work, "stills.html"), html);

const browser = await chromium.launch();
const page = await (await browser.newContext({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 })).newPage();
page.on("pageerror", (e) => console.error("page error:", e.message));
await page.goto(`file://${join(work, "stills.html")}`, { waitUntil: "networkidle" });
await page.evaluate(() => Promise.all(["900 100px Unbounded", "800 100px Inter", "600 100px Inter", "700 100px 'JetBrains Mono'"].map((f) => document.fonts.load(f))));
const ids = flags.only ? flags.only.split(",") : await page.evaluate(() => Object.keys(window.STILLS));
for (const id of ids) {
  const { w, h } = await page.evaluate((id) => window.renderStill(id), id);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: join(out, `${id}.png`), clip: { x: 0, y: 0, width: w, height: h } });
  console.log(`${id}.png  ${w} x ${h}`);
}
await browser.close();
rmSync(work, { recursive: true, force: true });
