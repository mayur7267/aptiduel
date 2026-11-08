# Apticks · Instagram marketing plan · week 1

## The goal

Get real students from the pilot colleges (DTU, JSPM and friends' colleges) to **play their first duel and invite a friend**. Followers are a side effect. Judge the week on taps of the link in bio and on new players, not likes.

## Set up the profile before Monday

| | |
|---|---|
| **Name** | Apticks · Aptitude Duels |
| **Username** | @apticks if it's free; otherwise @apticks.app or @playapticks |
| **Photo** | The app icon (lime bolt). It's in `marketing/assets/icon.png` in the project. |
| **Bio** | `Aptitude prep that's a game 🎮` / `1v1 duels · 5 questions · 3 minutes` / `Quant · Reasoning · Verbal` / `👇 Play free` |
| **Link** | aptiduel.vercel.app |
| **Category** | Education or App page |

**Highlights:** after the week, make three: *How it works* (Story 1, Story 4 + Reel 1), *Quizzes* (Story 3 + Reel 2), and *Duel a friend* (Story 5). Use solid lime, violet and orange covers to match the posts.

## The week

Every post stands on its own. Some show the product (what Apticks is and how it works); others are funny and still say what Apticks is.

| Day | Feed | Story | Time (IST) |
|---|---|---|---|
| Mon | **Reel 1**: Aptitude prep is boring | Story 1: Meet Apticks + link | Reel 7:30 PM · Story 8 PM |
| Tue | **Post 1**: Aptitude prep that's a game *(product)* | Story 2: Poll, which section scares you | Story 9 AM · Post 1 PM |
| Wed | **Reel 2**: Solve this in 5 seconds | Story 3: Quiz, odd one out | Story 9 AM · Reel 7:30 PM |
| Thu | **Post 2**: How Apticks works *(product)* | Story 4: See where you rank + link | Story 9 AM · Post 8 PM |
| Fri | **Reel 3**: 3 mistakes in the aptitude round | Story 5: Duel a friend + link | Reel 7:30 PM · Story 9 PM |
| Sat | **Post 4**: Daily Challenge *(product)* · **Post 6**: Chai vs duel *(funny)* | Story 6: Today's Daily is live + link | Story 9 AM · Posts 11 AM & 8 PM |
| Sun | **Post 3**: Tag the friend who says "aptitude is easy" *(funny)* · **Post 5**: Me before/after *(funny)* | Story 7: How ready are you? slider | Story 10 AM · Posts 12 PM & 8 PM |

The files are in day folders and the captions are in `Captions.md`.

## Every day (15 minutes)

1. **Reply to every comment within the first hour.** Early replies push a post to more people. Ask a question back ("Which one got you?").
2. **Share each new reel or post to your story.**
3. **On the quiz reel, reply to wrong answers kindly with the trick** ("Close! 16 sell for what 20 cost…"). Helpful replies get saves.
4. **Thank people who answer the story quiz or poll by DM**, and send the link. Don't send links to people who didn't engage; that's spam.
5. **Post in your pilot colleges' student groups and clubs** (placement cell, coding club, class groups) with the reel and one line: "Made this for our placement prep, try a duel."

## Pilot-college push (the part that matters most)

- **Ask one person per college to share Reel 1 to their story** on Monday night: your sister at JSPM, friends at DTU and the other colleges.
- **Run a college challenge on Saturday:** "Can anyone at DTU beat 5/5 on today's Daily?" Then repost the screenshots people send (with their permission).
- **Run a "Duel the founder" on Sunday:** send your own challenge link in a story. People love beating the maker.

## What to measure on Sunday night

**From Instagram Insights:**
- reach, saves, shares and profile visits per post;
- **link taps** (the most important number).

**From the app:**
- new sign-ups and first duels this week;
- how many players sent a challenge link.

The pilot metrics views (migration 0017) give these per college once that migration is applied to production.

## Decision rules for week 2

- **Most saves:** the quiz/tips format (Reel 2 or 3), so make two more of those.
- **Most shares:** the tag-a-friend/meme format, so do one a week.
- **Under 100 views on a reel:** keep the format, but change the first 2 seconds. The hook is everything.
- **Link taps but no first duels:** the problem is the landing page or sign-up, not Instagram. Fix that first.

## Rules (keep the account safe and honest)

- **Don't claim numbers you don't have.** No "10,000 students" until it's true.
- **Don't say "Download on the App Store" until Apple approves the app.** Until then, the link goes to the free web app.
- **Keep company names (TCS, Infosys and so on) out of posts and hashtags.** Say "placement tests" and "company-style practice" instead, as we do in the App Store listing.
- **Quick Match opponents can be bots, and the app labels them "BOT".** Only say "live" about friend duels, which really are live.
- **Only repost student screenshots or names with their permission.**

## Ideas for week 2

- **"5-second Friday":** a quiz reel every Friday, using the same toolchain with a new question from the bank.
- **College leaderboard shoutout:** "Top 3 at DTU this week" (with permission).
- **Tiko behind the scenes:** how the mascot was drawn.
- **One reel per section:** a quant trick, a reasoning trick and a verbal trick.

## Making more

The toolchain is in `marketing/` in the project (see `marketing/README.md`). New reels are a script plus a scene file. New posts and stories are one entry in `stills.js`.
