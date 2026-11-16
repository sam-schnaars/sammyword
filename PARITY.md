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
| Guaranteed-"fun" boards (vowel band + ≥2 core vowels + solver gate: ≥8 words len ≥5 & ≥12 words len 4) | `board.js` (`generateBoard`, `minLong=8`/`minMid=12`) | `BoardGenerator.swift` (`minLong=8`/`minMid=12`) | ✅ both |
| Dictionary + board solver (curated ~57k common-word list, byte-identical both sides) | `board.js` (`buildTrie`/`solveBoard`), `public/words.txt` | `WordDictionary.swift`, `BoardGenerator.solve`, `Resources/words.txt` | ✅ both |
| Stronger, length-scaled haptics | `App.jsx` (`hapticForWord`) | `Haptics.swift` | ✅ both |
| Challenge a friend (Word Hunt) | `share.js`, `App.jsx` | `GameMessage.swift`, `RootView.swift` | ✅ both |
| Challenge carries both players' words | `share.js` (`w`), `App.jsx` | `GameMessage.swift` (`cw`), `RootView.swift` | ✅ both |
| Head-to-head results (YOU WON! mirrored word columns) | `App.jsx` (`Compare`/`ScoreDuel`) | `RootView.swift` (`GameOverView`) | ✅ both |
| Map of the Day (deterministic daily board) | `board.js` (`generateDailyBoard`/`dailyKey`), `App.jsx` (`Home`/`DailyResult`) | `BoardGenerator.dailyBoard`, `DailyStore.swift`, `RootView.swift` | ✅ both |
| Per-day personal best | `share.js` (`dailyBest`/`saveDailyBest`) | `DailyStore.swift` | ✅ both |
| Global leaderboard (Redis) | `api/leaderboard.js`, `src/leaderboard.js`, `App.jsx` (`Leaderboard`) | `Leaderboard.swift`, `RootView.swift` | ✅ both |
| Flag Match (timed flag→country quiz) | `flags.js`, `FlagMatch.jsx` | `Flags.swift`, `FlagMatchGame.swift`, `FlagMatchView.swift` | ✅ both |
| Flag Match challenge (seeded quiz + score) | `share.js` (`#f=`) | `GameMessage.swift` (`g=f`) | ✅ both |
| Deep Cut (rare-answer trivia: 5 typed prompts × 20s, rarer correct answers score more, 1-typo forgiveness) | `deepcut.js`, `DeepCut.jsx`, `src/deepcut.json` | `DeepCut.swift`, `DeepCutGame.swift`, `DeepCutView.swift`, `Resources/deepcut.json` (byte-identical) | ✅ both |
| Deep Cut challenge (seeded prompts + score + sender's answers, head-to-head recap) | `share.js` (`#d=`) | `GameMessage.swift` (`g=d`, `ds/cs/cn/ca`) | ✅ both |
| Mode picker (Word Hunt / Flag Match / Deep Cut) | `App.jsx` (`ModeSelect`) | `RootView.swift` (`ModePicker`, compact bar) | ✅ both |
| Krillion in Messages (krillion.io in a web view; its Share/Copy result becomes a bubble, `g=k` + `kt/cn`) | — | `KrillionView.swift`, `GameMessage.swift`, `KrillionImageRenderer` | ⚠️ iOS only |

## Known gaps / platform differences

- **Krillion (iOS only, by request).** The owner scoped this to the iMessage
  app: it hosts the real krillion.io (an indie game, with the developer's
  blessing per the owner) in a `WKWebView` and turns the site's share text into
  a Messages bubble. The web app has no equivalent because it can't host
  another site or send iMessage bubbles; web players just use krillion.io.

- **Leaderboard backend URL.** Web calls the same-origin `/api/leaderboard`
  (served by `api/leaderboard.js` on Vercel). iOS has no same origin, so
  `Leaderboard.swift` targets an absolute base URL (`LEADERBOARD_BASE`). Point
  it at the deployed host. Both degrade gracefully (hide the panel) when the
  backend is unreachable / unconfigured.
- **Challenge transport.** Web encodes challenges in the URL hash (`#c=`/`#f=`)
  for share-sheet/clipboard links. iOS encodes the same data in an `MSMessage`
  URL (query params `m/b/cs/cn/cw` for Word Hunt, `g=f` + `fs/cs/cn` for Flag
  Match, `g=d` + `ds/cs/cn/ca` for Deep Cut). The payload fields are equivalent; only the container differs.
- **Auto-stage + auto-collapse on first turn (iOS only).** When a fresh
  challenge round ends (not a reply, and not the daily), the iOS results screen
  *stages* the challenge message into the Messages input, shows the score for a
  beat, then auto-collapses to the compact bar so the player lands on the staged
  message + native send arrow — the GamePigeon feel (`RootView.swift` /
  `FlagMatchView.swift` → `autoStageIfFirstTurn`, via `GameSession.requestCollapse`).
  Apple gives extensions no API to actually send, so the final send-arrow tap is
  always the user's. Editing the name cancels the auto-collapse and restores the
  "Challenge a friend" button to re-stage by name. The daily round only stages
  (no collapse) so its leaderboard stays readable. The web has no compose field
  to stage into, so it keeps its manual share button — an intentional platform
  difference, not a gap.
- **Redesign concepts (web only, temporary).** `concepts/` holds three playable
  pixel-art prototypes of the rare-answer game (Motherlode, Liftoff, Quill Duel)
  served at `/mobile/concepts/`. They are exploration, not shipped modes, and are
  not linked from the app. Whichever direction is picked gets built properly on
  both platforms; the other prototypes get deleted.
- **Daily determinism is per-platform.** Both use the same seeded `mulberry32`
  + `hashStr('sammyword-' + UTC-day)` algorithm and the same letter bag, so a
  given day yields the same board within a platform. Cross-platform identical
  daily boards additionally require identical dictionaries (the solver gate can
  reject/accept differently otherwise).

## Scoring tables (must match)

| Letters | Points | Flag Match | Deep Cut (tier → points, from `deepcut.json`) |
| --- | --- | --- | --- |
| 3 → 100, 4 → 400, 5 → 800, 6 → 1400, 7 → 1800, 8+ → 2200 | | +100 per correct answer | Common 100, Solid 250, Rare 500, Deep cut! 1000; miss/timeout 0 |
