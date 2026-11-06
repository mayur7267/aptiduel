# App Store assets

- `listing.md`: the name, subtitle, keywords, description and review notes for
  App Store Connect, with Apple's limits and the privacy-label answers.
- `compose.mjs`: builds the screenshots from real app screens, in the sizes
  App Store Connect accepts plus a 4K master set.

| Set | Size | Use |
|---|---|---|
| iPhone 6.9" | 1320 x 2868 | Upload to App Store Connect (the iPhone slot) |
| 4K masters | 2160 x 4693 | Website, social, press. Not for upload: App Store Connect only takes its own sizes |
| iPad 13" | 2064 x 2752 | Only once the app runs natively on iPad (it is iPhone-only today, so Connect shows no iPad slot) |
| Wide 16:9 | 5244 x 2950 | A landscape size some upload screens list. Apple's public screenshot page doesn't, so check your Connect screen accepts it; otherwise use the 1320 x 2868 set |
| App preview | 1200 x 1600, 24 s, .mp4 | The iPad 13" portrait preview size (see "The app preview" below) |

## Remaking the screenshots

1. Capture the raw screens. This runs the app on the fake backend (no real
   data) as a named player with a college and a good rating, and saves a PNG
   per screen:

   ```sh
   # A clean status bar: 9:41, full battery and signal
   xcrun simctl status_bar booted override --time 9:41 --batteryState charged \
     --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""

   cd ios
   TEST_RUNNER_STORE_SHOTS_DIR=/tmp/raw xcodebuild test -project Apticks.xcodeproj \
     -scheme Apticks -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
     -only-testing:ApticksUITests/StoreShotsUITests
   ```

   Use a Pro Max simulator: its screen is 1320 x 2868, Apple's 6.9" size, and
   the iPhone canvas is made as large as the raw screens, so they stay sharp.
   The player comes from the `-FakeName`, `-FakeRating`, `-FakeCollege` and
   `-FakeGradYear` launch arguments (Debug builds only, see `AppContainer`).

2. Compose them. This needs Playwright (`npm i playwright`) and a network
   connection, for the same Google Fonts the website uses:

   ```sh
   node store/compose.mjs /tmp/raw out/iphone-1320x2868
   node store/compose.mjs /tmp/raw out/4k-2160x4693 --width 2160
   node store/compose.mjs /tmp/raw out/ipad-2064x2752 --device ipad
   node store/compose.mjs /tmp/raw out/wide-5244x2950 --device wide
   ```

Edit the `SHOTS` list in `compose.mjs` to change a headline, a sticker or which
screen goes where.

## Rules the screenshots follow

- They show the real app, never a mock-up of features it doesn't have.
- No other company's name appears in a headline, a sticker or the metadata.
  The company-prep and placement-countdown screens name real employers, so
  they are captured for nobody and left out on purpose.
- Captions are benefits first, in the words people search for.

## The app preview

A preview is a video, and Apple wants real footage of the app in use, so it is
made from a screen recording, not from stills:

1. Record the simulator while `StoreShotsUITests/testPreview` plays one winning
   duel at a human pace. The test writes `preview-marks.txt` (epoch seconds
   for each step) so the recording can be cut exactly.

   ```sh
   xcrun simctl io booted recordVideo --codec h264 --force raw.mov &
   TEST_RUNNER_STORE_SHOTS_DIR=/tmp/prev xcodebuild test ... -only-testing:ApticksUITests/StoreShotsUITests/testPreview
   kill -INT %1
   ```

2. Cut frames, compose them, encode (no ffmpeg needed, only Xcode's Swift):

   ```sh
   swiftc -O preview/frames.swift -o frames && swiftc -O preview/encode.swift -o encode
   ./frames raw.mov <start> <end> 30 660 /tmp/screen-frames
   node preview/compose-preview.mjs /tmp/screen-frames /tmp/out-frames '{"quick":4,"q1":5,"result":20}'
   ./encode /tmp/out-frames 30 1200 1600 preview.mp4
   ```

The preview is H.264, 30 fps, silent stereo AAC (Connect expects an audio
track), under 30 seconds. iPad previews only upload once the app runs natively
on iPad; an iPhone preview would be 886 x 1920 and needs its own composition.
