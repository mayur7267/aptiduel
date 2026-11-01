# Apticks for iOS

The native iPhone app: SwiftUI, iOS 17+. It talks to the same Supabase
database functions as the website, so a player's guest account, rating,
duels and challenge links behave the same on both. Tiko is drawn from the
same shapes as the web mascot and moves with the same keyframes.

## Run it

1. Open `ios/Apticks.xcodeproj` in Xcode 26 or later.
2. Pick an iPhone simulator and press Run.

To run on a phone, set your team under Signing & Capabilities. The bundle
ID is `com.apticks.app`; change it if that ID is taken.

**Fake backend.** Add `-FakeBackend` to the scheme's launch arguments
(Product › Scheme › Edit Scheme › Run › Arguments) to run against an
in-memory backend: a guest with some history, a bot to duel and a
leaderboard. Nothing reaches production. It only exists in Debug builds.
Friend challenge links are `apticks://c/FRIEND1`, and the email code is
`123456`.

## Tests

```sh
cd ios/Packages/ApticksKit
xcodebuild test -scheme ApticksKit-Package -destination 'platform=iOS Simulator,name=iPhone 17'
```

The tests use Swift Testing. They cover:

- the game rules: tiers, outcomes and the opponent replay;
- decoding of the database's JSON;
- the SVG renderer behind question figures;
- full duels driven through the view models against the fake backend.

## Splash and onboarding

**Splash.** Every launch opens on `BrandSplash`, in DesignSystem:

1. The stopwatch's lime and orange halves fly in from either side and clash in the middle, with a flash and a shockwave.
2. The bolt cracks down the seam.
3. The button drops on top with a bounce, and the watch ticks once.
4. "Apticks" types itself out.
5. The logo rushes forward while a growing circle opens onto the app.

**Onboarding.** The first launch shows `OnboardingFeature`: six swipeable pages, each with a scene that plays when you arrive.

| Page | Scene |
| ---- | ----- |
| Hello | Tiko swings in on a trapeze, lets go, backflips and lands. The swing is a simulated damped pendulum, and the flight is a rigid body thrown at its release speed. |
| Quick Match | Tiko hops onto a wrong answer, shakes its head, then hops to the right one. It lights up with +145 and confetti. |
| Challenges | A link flies along an arc to a friend, the friend flips over to "Accepted", and a VS stamp slams down. |
| Rating | Tiko hops up six tier steps while the rating counts from 1,000 to 1,700, and a trophy pops at the top. |
| About you | Tiko drops onto a name tag and reacts as you type. The name and college are saved. |
| Ready | Tiko crouches, launches off the screen on a ballistic arc, and lands in confetti. |

Around the scenes:

- pages turn in 3D while you swipe, and their text slides at its own depth;
- titles arrive word by word;
- the background is a drifting mesh-gradient aurora (iOS 18+), with maths symbols that shift with the swipe and with the phone's tilt;
- every landing has a haptic, and Reduce Motion shows each scene's final frame.

Profile has a **Replay the intro** button.

Every scene is a pure function of time, so it can be rendered at exact moments. To render each scene and the splash into PNG filmstrips:

```sh
TEST_RUNNER_FILM_DIR=/tmp/film xcodebuild test -scheme ApticksKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:OnboardingFeatureTests/SceneFilm -only-testing:DesignSystemTests/SplashFilm
```

## Feedback

Players can report a problem, suggest an idea, or flag a question:
- from the **Help us** tile in Profile;
- from **Report this question** in answer review;
- by **shaking the phone** anywhere.

The screen, the app version and the device go along with the message. It's saved by `submit_feedback` (migration 0012) and emailed to the team by the `feedback-mail` Edge Function, in `supabase/functions`. The website has the same form.

## Profile

Profile is a grid of tiles:

| Tile | What it shows | Opens |
| ---- | ------------- | ----- |
| Player card | A drifting stripe banner with Tiko, your stats and tier | Edit profile |
| Insights | A rating chart that draws itself | Leaderboard |
| Streak | A flickering flame and your week | Daily |
| Tiko | Tiko | Tiko's settings |
| Compete | A ticker of every way to play | Quick Match |
| Practice | The four company badges | Company practice |
| Help us | Report a problem, suggest an idea | Feedback |
| Account | Whether your progress is saved | Account |

Tiles press with a spring, and the grid leans slightly as you tilt the phone.

## How it's built

The app target is only the composition root. Everything else lives in a
local Swift package, `Packages/ApticksKit`, split into modules with
one-way dependencies:

```
Apticks (app)  ─ composition root: builds the backend and view models
  │
  ├─ HomeFeature  DuelFeature  DailyFeature  LeaderboardFeature  ProfileFeature  ChallengeFeature
  │     (one module per screen family; MVVM; they never import each other)
  ├─ OnboardingFeature  the first-launch intro and its scenes
  ├─ FeedbackFeature    report a problem, suggest an idea, flag a question
  ├─ Companion      Tiko in the corner and the first-run tour
  ├─ AppCore        AppRouter (tabs and full-screen flows), shared state, Dependencies
  ├─ Tiko           the mascot
  ├─ DesignSystem   colours, type, components, motion, SVG renderer
  ├─ Networking     APIClient / AccountClient protocols
  │   ├─ NetworkingLive    Supabase implementation (only the app links it)
  │   └─ NetworkingFakes   in-memory backend for previews, UI runs and tests
  └─ Domain         models and game rules; no UI, no networking
```

- **MVVM.** Each screen has an `@Observable` view model that owns its state
  and talks to the backend through `APIClient`. Views only render.
- **Navigation.** View models navigate through `AppRouter`, so flows can be
  tested without any views.
- **Dependency injection.** Features see only the `Networking` protocols.
  `AppContainer` decides between Supabase and the fake backend.
- **Concurrency.** UI modules default to the main actor, and the
  Swift 6 language mode is on.
- **Configuration.** The backend URL and key come from
  `Configs/App.xcconfig` through `Info.plist`. Both are public by design,
  and the website ships the same ones.

### Mapping to the website

| Website                            | iOS                                    |
| ---------------------------------- | -------------------------------------- |
| `web/src/lib/api.ts`               | `Networking` + `NetworkingLive`        |
| `web/src/lib/format.ts`            | `Domain/Rules`                         |
| `web/src/components/tiko.tsx`      | `Tiko`                                 |
| `web/src/components/tiko-tour.tsx` | `Companion/TikoTour.swift`             |
| `web/src/components/companion.tsx` | `Companion/CompanionView.swift`        |
| `app/(app)/home-client.tsx`        | `HomeFeature`                          |
| `app/play`, `app/duel/[id]`        | `DuelFeature` (matchmaking, play, result) |
| `app/(app)/daily`                  | `DailyFeature`                         |
| `app/(app)/leaderboard`            | `LeaderboardFeature`                   |
| `app/(app)/profile`                | `ProfileFeature`                       |
| `app/c/[code]`                     | `ChallengeFeature`                     |

## Challenge links

`apticks://c/CODE` opens a challenge in the app. Shared links still point
at the website, so friends without the app can play in the browser.

Opening `https://aptiduel.vercel.app/c/CODE` straight in the app needs
universal links. They require a paid Apple developer account:

1. Add the Associated Domains capability with
   `applinks:aptiduel.vercel.app`.
2. Serve `web/public/.well-known/apple-app-site-association` with your
   team ID:

   ```json
   { "applinks": { "details": [{ "appIDs": ["TEAMID.com.apticks.app"], "components": [{ "/": "/c/*" }] }] } }
   ```

`AppRouter.handle(_:)` already accepts both link forms.
