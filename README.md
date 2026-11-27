# Sammy Word

A Vite + React clone of Game Pigeon's **Word Hunt**, used as scaffolding for a
game concept that will change later. Styled to match the real game: green
patterned background, a white header card, a dark timer pill, a green board
frame with beveled wood tiles, white selected tiles, and a red drag path —
in the rounded **Fredoka** font.

## How to play

- Press **New Game**, then drag across the 4×4 grid to connect neighboring
  letters (horizontal, vertical, and diagonal).
- Words must be 3+ letters and in the dictionary. Longer words score more.
- You get 30 seconds per round.

## Challenge a friend

When your round ends, enter your name and tap **Challenge a friend**. That
builds a link encoding your exact board + score in the URL hash (no backend) —
on a phone it opens the native share sheet, on desktop it copies the link.

When a friend opens the link they see *"You've been challenged!"*, play the
**same board**, and the end screen compares both scores and declares a winner.
They can **Challenge them back** on the same board to keep it going.

The link only works where the app is hosted — for friends to play it must be
deployed (e.g. Vercel), not just running on `localhost`.

## Deep Cut

A rare-answer trivia mode. Each round is 5 prompts ("Name a US state", "Name a
noble gas"…), 20 seconds each. Type any correct answer; the more obscure it is,
the more it scores (Common 100 → Solid 250 → Rare 500 → Deep cut! 1000). An
answer not on the list can be retried; one typo is forgiven on longer answers.

The prompt bank is `src/deepcut.json` — each answer is `"Name|alias:tier"`. The
iOS copy at `ios/SammyWordMessages/Resources/deepcut.json` must stay
byte-identical (`cp src/deepcut.json ios/SammyWordMessages/Resources/`).

Challenges carry the round seed, score, and the sender's answers, so the friend
plays the same prompts and the results show both answers side by side.

## Map shapes & Map of the Day

The home screen has a **GAME MODE** picker with several board shapes (classic
4×4, donut, plus, diamond) plus a featured **❤️ Map of the Day** — a heart
board whose letters are generated deterministically from the (UTC) date, so
everyone gets the same daily board.

The daily board tracks a **personal best for the day** in `localStorage`. This
is a local, per-device best — the starting point for a leaderboard.

## Global leaderboard (Vercel + Redis)

The daily results screen shows a **global leaderboard**, served by the
serverless function `api/leaderboard.js` backed by Redis (Upstash / Vercel KV).
It stores each player's best score per UTC day in a sorted set.

The frontend (`src/leaderboard.js`) talks to it. If the datastore isn't
configured, the function returns `{ configured: false }` and the leaderboard UI
simply stays hidden — the rest of the app is unaffected.

### One-time setup (Vercel dashboard)

This is the only manual step — it needs your account and injects env vars:

1. Vercel → your project → **Storage** → **Create Database** → pick a Redis
   store (**Upstash**, free tier is fine).
2. **Connect** it to this project. Vercel adds the env vars automatically
   (`KV_REST_API_URL`/`KV_REST_API_TOKEN` or `UPSTASH_REDIS_REST_URL`/`_TOKEN`
   — the function accepts either).
3. Redeploy (a push triggers one). The leaderboard then lights up.

No leaderboard locally: `vite dev` doesn't run the serverless function, so the
panel stays hidden in dev — test it on the Vercel deployment.

## Daily Sammy (prototype)

A standalone page at `/mobile/daily/` (samarei.com/mobile/daily/ through the
proxy). One prompt a day ("Name a bird"); name 3 answers, and the fewer
players who'd say an answer, the more it scores:
`points = max(5, round(25 × log2(100 ÷ share%)))`. A wrong answer costs one of
3 lives. Below the game is a **Community games** section (`src/daily/community.js`);
Magnitudle's card carries a labelled 300×250 ad slot, as their condition for
being featured. Seed prompts and answer shares are in `src/daily/days.js`
(day 1 = 2026-11-24 UTC); `?day=N` plays another day.

## Caption the Meme board (iOS game, server here)

The iOS game Caption the Meme keeps today's captions and votes on a shared
board: `api/captions.js`, a Vercel function using the same Upstash Redis as the
leaderboard. Each device sends a random id (no accounts). You submit one
caption a day (name optional, "Anonymous" when blank); only then do you see
everyone else's, and you get one vote, never for your own.

Protection: 80-character captions and 20-character names, a word filter
(`api/_blocklist.js`, extend with the `CAPTIONS_BLOCKLIST` env var), rate limits
per device and per IP, writes only for today's meme, and a report button
(3 reports hide a caption; the author still sees it). Reporting also hides that
person's captions on the reporter's phone.

Moderation needs a `CAPTIONS_ADMIN_TOKEN` env var on the Vercel project:

```bash
# List day 9's captions, most-reported first
curl -H "Authorization: Bearer $CAPTIONS_ADMIN_TOKEN" "https://sammyword.vercel.app/api/captions?day=9&admin=1"
# Hide, unhide or delete one
curl -X POST -H "Authorization: Bearer $CAPTIONS_ADMIN_TOKEN" -H 'content-type: application/json' \
  -d '{"action":"delete","day":9,"id":"<caption id>"}' https://sammyword.vercel.app/api/captions
```

Data expires after 14 days. Run `node scripts/test-captions.mjs` to check the rules locally (no Redis needed).

## Run it

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # production build to dist/
```

## Where things live

- `src/App.jsx` — game UI, drag selection, timer, scoring, screens.
- `src/board.js` — board generation (Boggle dice), adjacency, score table.
- `src/share.js` — encode/decode a challenge (board + score + name) to/from a URL.
- `src/deepcut.js` / `src/DeepCut.jsx` / `src/deepcut.json` — Deep Cut logic, UI, and prompt bank.
- `src/App.css` / `src/index.css` — Game Pigeon styling.
- `public/words.txt` — dictionary for word validation (filtered system word list),
  fetched at runtime.

## Scoring (matches Word Hunt)

| Letters | Points |
| ------- | ------ |
| 3       | 100    |
| 4       | 400    |
| 5       | 800    |
| 6       | 1400   |
| 7       | 1800   |
| 8+      | 2200   |
