# Feature parity: web ↔ iOS

Sammy Word ships as **two independent codebases** that must stay feature-equal:

- **Web** — Vite + React prototype in the repo root (`src/`, `api/`).
- **iOS** — native iMessage extension in `ios/SammyWordMessages/`.

They share **no source** — every feature is hand-implemented (and hand-ported)
on each side. This file is the contract that keeps them in sync.

> **Rule:** any change that adds, removes, or alters user-facing behavior on
> either platform MUST be mirrored on the other in the same change, and this
> table MUST be updated to match. If you intentionally leave a gap, record it in
> "Known gaps" below with a reason. (See the repo `CLAUDE.md`.)

## Feature matrix

| Feature | Web files | iOS files | Status |
| --- | --- | --- | --- |
| Word Hunt (drag-to-spell, 80s timer, scoring) | `App.jsx`, `board.js` | — (removed) | 🌐 web only |
| Board shapes (classic/donut/plus/diamond/heart) | `board.js` (`MAPS`, `HEART`) | — (removed) | 🌐 web only |
| Guaranteed-"fun" boards (vowel band + ≥2 core vowels + solver gate: ≥8 words len ≥5 & ≥12 words len 4) | `board.js` (`generateBoard`, `minLong=8`/`minMid=12`) | — (removed) | 🌐 web only |
| Dictionary + board solver (curated ~57k common-word list) | `board.js` (`buildTrie`/`solveBoard`), `public/words.txt` | — (removed) | 🌐 web only |
| Length-scaled haptics | `App.jsx` (`hapticForWord`) | — (removed) | 🌐 web only |
| Challenge a friend (Word Hunt, both players' words, head-to-head results) | `share.js`, `App.jsx` (`Compare`/`ScoreDuel`) | — (removed) | 🌐 web only |
| Map of the Day + per-day best + global leaderboard | `board.js`, `share.js`, `api/leaderboard.js`, `src/leaderboard.js`, `App.jsx` | — (removed) | 🌐 web only |
| Flag Match (timed flag→country quiz) + challenge | `flags.js`, `FlagMatch.jsx`, `share.js` (`#f=`) | — (removed) | 🌐 web only |
| Deep Cut (rare-answer trivia) + challenge | `deepcut.js`, `DeepCut.jsx`, `src/deepcut.json`, `share.js` (`#d=`) | — (removed) | 🌐 web only |
| Mode picker | `App.jsx` (`ModeSelect`: Word Hunt / Flag Match / Deep Cut) | `RootView.swift` (`GameMenu`, compact bar: Krillion / Magnitudle / 100 of Us / Eraly) | ⚠️ different games |
| Game of the day home (one featured game a day in turn, day number, played-today ticks, streak) in a pixel-art look (5×7 pixel font, sprites, bevelled boxes, dusk sky) | — | `RootView.swift` (`GameMenu`), `DailyStore.swift` (`Daily`, `DailyStore.record`), `PixelArt.swift`, `Theme.swift` | ⚠️ iOS only |
| Krillion in Messages (opens straight into krillion.io's daily dive in a web view; the finished score sends itself as a picture bubble, `g=k` + `ks/kd/kr/cn`) | — | `WebGameView.swift`, `GameMessage.swift` (`WebGame`, `WebScorePayload`), `ScoreImageRenderer.swift` | ⚠️ iOS only |
| Magnitudle in Messages (magnitudle.com's Daily Question in a web view; the score out of 100 sends itself as a picture bubble, `g=m` + `ks/kd/cn`) | — | `WebGameView.swift`, `GameMessage.swift`, `ScoreImageRenderer.swift` | ⚠️ iOS only |
| 100 of Us in Messages (logicers.com/100-of-us in a web view; how far off the guess was sends itself as a picture bubble, `g=h` + `ks` = off-by, `kr` = guess.answer, `kd/cn`) | — | `WebGameView.swift`, `GameMessage.swift`, `ScoreImageRenderer.swift` | ⚠️ iOS only |
| Eraly in Messages (eraly.io's daily seven "guess the year" moments in a web view, started for you; the score out of 700 sends itself as a picture bubble, `g=e` + `ks/kd/cn`, `kr` = each round's points) | — | `WebGameView.swift`, `GameMessage.swift`, `ScoreImageRenderer.swift` | ⚠️ iOS only |

## Known gaps / platform differences

- **The two apps now carry different games (by request, 2026-11-16).** The
  owner cut the iMessage app down to hosted web games: Krillion, Magnitudle
  (replacing Size It Up) and 100 of Us, then added Eraly (2026-11-17). Word Hunt, Flag Match, Deep
  Cut and Size It Up were deleted from iOS (code, word list and Deep Cut data);
  the web prototype still has Word Hunt, Flag Match and Deep Cut and has none of
  the hosted games, because it can't host another site or send iMessage
  bubbles. Old Word Hunt / Flag Match / Deep Cut / Size It Up bubbles no longer
  decode on iOS and just open the app fresh.
- **Hosted web games (iOS only).** All four share `WebGameView`: the real site
  runs in a `WKWebView`, a per-game script injected at document start spots the
  finished result, and a round finished in front of us sends itself
  (`MSConversation.send`, falling back to staging in the input field). Opening
  the iMessage app fresh lands in Krillion; the others are behind the grid
  button. How each result is read:
  - Krillion: auto-presses "Begin descent"; reads `krillion:stats:v1` history.
  - Magnitudle: the result lives on its server, so the script reads the result
    screen ("ACTUAL ANSWER", "N /100") and waits for the counting-up score to
    hold still for 2 s. Live = the estimate box was seen first.
  - 100 of Us: reads `turnsout:v1` → `games["100-of-us"].results[day]`
    (`g` guess, `a` answer) once "Turns out" shows; score = |g − a|, lower wins.
  - Eraly: auto-presses a visible "Start the journey"; reads
    `eraly:result:<day>` (`total`, `results[].pts`) once the "N/700" screen
    shows. Live = that day's result key appeared after the page opened.
- **Game of the day + pixel-art redesign (iOS only, by request, 2026-11-18).**
  The iMessage home screen features one game a day, rotating Krillion →
  Magnitudle → 100 of Us → Eraly (Day 1 = 2026-11-18, local calendar), with the
  others under "Also today", ticks for games finished today and a streak of
  days the featured game was finished (kept on the device, ~60 days). The
  whole iMessage app moved to a pixel-art look. The web prototype keeps its
  old mode picker and look: it carries different games, so a shared rotation
  doesn't apply; restyling it is open.
- **Leaderboard backend URL.** Web calls the same-origin `/api/leaderboard`
  (served by `api/leaderboard.js` on Vercel). iOS no longer has a leaderboard.
- **Redesign concepts (web only, temporary).** `concepts/` holds three playable
  pixel-art prototypes of the rare-answer game (Motherlode, Liftoff, Quill Duel)
  served at `/mobile/concepts/`. They are exploration, not shipped modes, and are
  not linked from the app.

## Scoring tables (web)

| Letters | Points | Flag Match | Deep Cut (tier → points, from `deepcut.json`) |
| --- | --- | --- | --- |
| 3 → 100, 4 → 400, 5 → 800, 6 → 1400, 7 → 1800, 8+ → 2200 | | +100 per correct answer | Common 100, Solid 250, Rare 500, Deep cut! 1000; miss/timeout 0 |
