# App Store assets

- `listing.md`: the name, subtitle, keywords, description and review notes for
  App Store Connect, with Apple's limits and the privacy-label answers.
- `compose.mjs`: builds the screenshots (1290 x 2796, the 6.9" iPhone size)
  from real app screens.

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
     -scheme Apticks -destination 'platform=iOS Simulator,name=iPhone 16 Plus' \
     -only-testing:ApticksUITests/StoreShotsUITests
   ```

   Any iPhone simulator works; the iPhone 16 Plus is 1290 x 2796 natively.
   The player comes from the `-FakeName`, `-FakeRating`, `-FakeCollege` and
   `-FakeGradYear` launch arguments (Debug builds only, see `AppContainer`).

2. Compose them. This needs Playwright (`npm i playwright`) and a network
   connection, for the same Google Fonts the website uses:

   ```sh
   node store/compose.mjs /tmp/raw ~/Desktop/Apticks-App-Store/Screenshots
   ```

Edit the `SHOTS` list in `compose.mjs` to change a headline, a sticker or which
screen goes where.

## Rules the screenshots follow

- They show the real app, never a mock-up of features it doesn't have.
- No other company's name appears in a headline, a sticker or the metadata.
  The company-prep and placement-countdown screens name real employers, so
  they are captured for nobody and left out on purpose.
- Captions are benefits first, in the words people search for.
