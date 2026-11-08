# Marketing toolchain

This makes Apticks' Instagram reels, posts and stories from the real app: its screens, its duel footage and Tiko. The look is flat: solid brand colours (ink, lime, violet, orange, cream), bold type and hard offset shadows, with no glows.

| File | What it is |
|---|---|
| `kit.css`, `kit.js` | The shared look and drawing kit: Tiko (ported from `web/src/components/tiko.tsx`, with blink, hop and wave), the phone, kinetic headlines, stickers, solid-colour wipes and the end card. |
| `reels/<name>.mjs` | A reel's script for Ava (Premium), its music tempo and its sound cues. |
| `reels/<name>.js` | Its scenes, drawn per frame in Chromium and timed to Ava's words. |
| `stills.js` | The posts (1080 × 1350) and stories (1080 × 1920). |
| `audio.mjs` | The voice (macOS `say`), a synthesised music bed and sound effects, and the mix. Nothing needs licensing. |
| `make-reel.mjs`, `make-stills.mjs` | The renderers. |
| `week-1/` | The captions and the marketing plan for the first week. |

## What you need

- **Node with Playwright:** `npm i playwright`, then `npx playwright install chromium`.
- **The Ava (Premium) voice:** System Settings → Accessibility → Spoken Content → System voice → Manage Voices.
- **The encoder:** `swiftc -O ../ios/store/preview/encode.swift -o encode`.
- **The raw screens and duel frames** from `ios/store` (see `ios/store/README.md`).

## Make them

```sh
node make-reel.mjs r1-game out --raw <raw screens> --foot <duel frames> --encoder ./encode --frames out/frames-r1
node make-reel.mjs r1-game out --raw <raw screens> --foot <duel frames> --encoder ./encode --preview 2,9.5,20
node make-stills.mjs out --raw <raw screens>
```

**Outputs:**
- Each reel writes `<name>.mp4` (voice and music) and `<name>-no-music.mp4` (voice and effects, so a trending sound can go under it in Instagram).
- `--preview` renders single frames, to check a look quickly.
- With `--frames`, a remix that changes only the sound reuses the frames already drawn.

If Playwright is installed somewhere else, link this folder there and run Node with `--preserve-symlinks --preserve-symlinks-main`, so `playwright` resolves.

## A new reel

1. Copy a pair from `reels/`.
2. Write the lines (each with an `id`), then cue scenes in the `.js` file with `lineAt(id)`, `wordsAt(id)` and `lineEnd(id)`. Every cue then follows the voice, even after you edit a line.
3. Keep to the rules in `week-1/Marketing-Plan.md`:
   - no company names;
   - no numbers you don't have;
   - no "App Store" until the app is approved.
