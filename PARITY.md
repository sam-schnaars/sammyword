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
| Word Hunt (drag-to-spell, 80s timer, scoring) | `App.jsx`, `board.js` | `WordHuntGame.swift`, `GameView.swift`, `GameBoard.swift`, `Scoring.swift` | ✅ both |
| Board shapes (classic/donut/plus/diamond/heart) | `board.js` (`MAPS`, `HEART`) | `GameBoard.swift` (`GameMap.all`) | ✅ both |
| Guaranteed-solvable boards (vowel band + ≥2 core vowels + solver gate) | `board.js` (`generateBoard`) | `BoardGenerator.swift` | ✅ both |
| Dictionary + board solver | `board.js` (`buildTrie`/`solveBoard`), `public/words.txt` | `WordDictionary.swift`, `BoardGenerator.solve`, `Resources/words.txt` | ✅ both |
| Stronger, length-scaled haptics | `App.jsx` (`hapticForWord`) | `Haptics.swift` | ✅ both |
| Challenge a friend (Word Hunt) | `share.js`, `App.jsx` | `GameMessage.swift`, `RootView.swift` | ✅ both |
| Challenge carries both players' words | `share.js` (`w`), `App.jsx` | `GameMessage.swift` (`cw`), `RootView.swift` | ✅ both |
| Head-to-head results (YOU WON! mirrored word columns) | `App.jsx` (`Compare`/`ScoreDuel`) | `RootView.swift` (`GameOverView`) | ✅ both |
| Map of the Day (deterministic daily board) | `board.js` (`generateDailyBoard`/`dailyKey`), `App.jsx` (`Home`/`DailyResult`) | `BoardGenerator.dailyBoard`, `DailyStore.swift`, `RootView.swift` | ✅ both |
| Per-day personal best | `share.js` (`dailyBest`/`saveDailyBest`) | `DailyStore.swift` | ✅ both |
| Global leaderboard (Redis) | `api/leaderboard.js`, `src/leaderboard.js`, `App.jsx` (`Leaderboard`) | `Leaderboard.swift`, `RootView.swift` | ✅ both |
| Flag Match (timed flag→country quiz) | `flags.js`, `FlagMatch.jsx` | `Flags.swift`, `FlagMatchGame.swift`, `FlagMatchView.swift` | ✅ both |
| Flag Match challenge (seeded quiz + score) | `share.js` (`#f=`) | `GameMessage.swift` (`g=f`) | ✅ both |
| Mode picker (Word Hunt vs Flag Match) | `App.jsx` (`ModeSelect`) | `RootView.swift` (`ModePicker`) | ✅ both |

## Known gaps / platform differences

- **Leaderboard backend URL.** Web calls the same-origin `/api/leaderboard`
  (served by `api/leaderboard.js` on Vercel). iOS has no same origin, so
  `Leaderboard.swift` targets an absolute base URL (`LEADERBOARD_BASE`). Point
  it at the deployed host. Both degrade gracefully (hide the panel) when the
  backend is unreachable / unconfigured.
- **Challenge transport.** Web encodes challenges in the URL hash (`#c=`/`#f=`)
  for share-sheet/clipboard links. iOS encodes the same data in an `MSMessage`
  URL (query params `m/b/cs/cn/cw` for Word Hunt, `g=f` + `fs/cs/cn` for Flag
  Match). The payload fields are equivalent; only the container differs.
- **Daily determinism is per-platform.** Both use the same seeded `mulberry32`
  + `hashStr('sammyword-' + UTC-day)` algorithm and the same letter bag, so a
  given day yields the same board within a platform. Cross-platform identical
  daily boards additionally require identical dictionaries (the solver gate can
  reject/accept differently otherwise).

## Scoring tables (must match)

| Letters | Points | Flag Match |
| --- | --- | --- |
| 3 → 100, 4 → 400, 5 → 800, 6 → 1400, 7 → 1800, 8+ → 2200 | | +100 per correct answer |
