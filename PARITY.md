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
| Word Hunt (drag-to-spell, 80s timer, scoring) | `App.jsx`, `board.js` | `WordHuntView.swift`, `WordHuntGame.swift`, `Scoring.swift` | ✅ both |
| Board shapes (classic/donut/plus/diamond/heart) | `board.js` (`MAPS`, `HEART`) | `GameBoard.swift` (`GameMap`; iOS plays the classic 4×4 only) | ⚠️ web picks shapes |
| Guaranteed-"fun" boards (vowel band + ≥2 core vowels + solver gate: ≥8 words len ≥5 & ≥12 words len 4) | `board.js` (`generateBoard`, `minLong=8`/`minMid=12`) | `BoardGenerator.swift` | ✅ both |
| Daily board (same board for everyone, seeded from the UTC day) | `board.js` (`generateDailyBoard`) | `BoardGenerator.dailyBoard` | ✅ both |
| Dictionary + board solver (curated ~57k common-word list) | `board.js` (`buildTrie`/`solveBoard`), `public/words.txt` | `WordDictionary.swift`, `Resources/words.txt` | ✅ both |
| Length-scaled haptics | `App.jsx` (`hapticForWord`) | `Haptics.swift` | ✅ both |
| Challenge a friend (Word Hunt, both players' words, head-to-head results) | `share.js`, `App.jsx` (`Compare`/`ScoreDuel`) | `FriendBanner` + score bubble (`g=w`, `ks` score, `kd` day, `kr` best 3 words) | ⚠️ iOS shows score to beat, not both word lists |
| Map of the Day + per-day best + global leaderboard | `board.js`, `share.js`, `api/leaderboard.js`, `src/leaderboard.js`, `App.jsx` | — | 🌐 web only |
| Flag Match (timed flag→country quiz, 12 flags, 60 s) + challenge | `flags.js`, `FlagMatch.jsx`, `share.js` (`#f=`) | `FlagMatchView.swift`, `FlagMatchGame.swift`, `Flags.swift` (daily seed `hashStr("flags-"+UTC day)`; bubble `g=f`, `ks` = flags right) | ✅ both |
| Deep Cut (rare-answer trivia) + challenge | `deepcut.js`, `DeepCut.jsx`, `src/deepcut.json`, `share.js` (`#d=`) | — | 🌐 web only |
| Doodle (draw a secret word on a 12×12 pixel grid, friends get 6 guesses with letter hints) | — | `Doodle.swift`, `DoodleView.swift` (bubble `g=d`, `dg` drawing, `dw` scrambled word; result `ks` = guesses, 0 = gave up, `kr` = word) | ⚠️ iOS only |
| Pixel-art look (8-bit dusk sky, square bevelled boxes, pixel display font) | `pixel.css` (Silkscreen + Space Mono fonts) | `PixelArt.swift` (5×7 bitmap font, sprites) | ✅ both |
| Mode picker | `App.jsx` (`ModeSelect`: Word Hunt / Flag Match / Deep Cut) | `RootView.swift` (`GameMenu`: Our games + More daily games; compact bar scrolls all games) | ⚠️ different game lists |
| Game of the day home (one featured game a day in turn, day number, played-today ticks, streak) | — | `RootView.swift` (`GameMenu`), `DailyStore.swift` (`Daily.rotation`) | ⚠️ iOS only |
| Krillion, Magnitudle, 100 of Us, Eraly — App Store builds: open on the creator's site in Safari, then paste the share text or type the score to send a bubble | — | `ExternalGameView.swift` (`ScoreParser`), `SammyWordApp.swift` (`ForwardGameLinks`) | ⚠️ iOS only |
| Krillion, Magnitudle, 100 of Us, Eraly — TestFlight builds (`HOSTED_EMBED`): the real site in a web view; the finished score sends itself (`g=k/m/h/e` + `ks/kd/kr/cn`) | — | `WebGameView.swift`, `ScoreImageRenderer.swift` | ⚠️ iOS only |

## Known gaps / platform differences

- **Own games are back on iOS (by request, 2026-11-23).** Word Hunt and Flag
  Match were restored from git (`59445d3^`) and redrawn in the pixel style, and
  a new turn-based game, Doodle, was added. iOS plays each day's board/quiz
  (same for everyone), then lets you practice on random ones; web still lets
  you pick a board shape and keeps Deep Cut. Doodle is iOS-only because it
  needs Messages to pass the drawing between players; the web has no chat to
  send it through.
- **Two iOS builds from one codebase.** App Store builds can't embed other
  people's sites without their permission, so the four web games open in
  Safari there (a Messages extension can only open its own app, so the app
  passes the link on to Safari, for those four sites only) and the game of the
  day rotates only our own games (Word Hunt ↔ Flag Match). TestFlight builds
  are archived with `SWIFT_ACTIVE_COMPILATION_CONDITIONS="HOSTED_EMBED"`: the
  sites play inside Messages and all six daily games rotate (Word Hunt →
  Krillion → Flag Match → Magnitudle → 100 of Us → Eraly). The web prototype
  has none of the hosted games.
- **How hosted results are read (TestFlight builds).** All four share
  `WebGameView`: a per-game script injected at document start spots the
  finished result, and a round finished in front of us sends itself
  (`MSConversation.send`, falling back to staging in the input field).
  - Krillion: auto-presses "Begin descent"; reads `krillion:stats:v1` history.
  - Magnitudle: reads the result screen ("ACTUAL ANSWER", "N /100") and waits
    for the counting-up score to hold still for 2 s. Live = the estimate box
    was seen first.
  - 100 of Us: reads `turnsout:v1` → `games["100-of-us"].results[day]`
    (`g` guess, `a` answer) once "Turns out" shows; score = |g − a|, lower wins.
  - Eraly: auto-presses a visible "Start the journey"; reads
    `eraly:result:<day>` (`total`, `results[].pts`) once the "N/700" screen
    shows.
- **Game of the day (iOS only).** Day 1 = 2026-11-18, local calendar; ticks
  for games finished today and a streak of days the featured game was
  finished (kept on the device, ~60 days). The web keeps its mode picker.
- **Leaderboard backend URL.** Web calls the same-origin `/api/leaderboard`
  (served by `api/leaderboard.js` on Vercel). iOS has no leaderboard.
- **Redesign concepts (web only, temporary).** `concepts/` holds three playable
  pixel-art prototypes of the rare-answer game (Motherlode, Liftoff, Quill Duel)
  served at `/mobile/concepts/`. They are exploration, not shipped modes, and are
  not linked from the app.

## Scoring tables (both)

| Letters | Points | Flag Match | Deep Cut (tier → points, from `deepcut.json`) |
| --- | --- | --- | --- |
| 3 → 100, 4 → 400, 5 → 800, 6 → 1400, 7 → 1800, 8+ → 2200 | | Web: +100 per correct answer. iOS: flags right out of 12 (same quiz rules, the bubble shows the count) | Common 100, Solid 250, Rare 500, Deep cut! 1000; miss/timeout 0 |

Doodle (iOS): the result is how many guesses it took (1–6), 0 if the guesser gave up.
