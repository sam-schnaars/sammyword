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
- You get 80 seconds per round.

## Challenge a friend

When your round ends, enter your name and tap **Challenge a friend**. That
builds a link encoding your exact board + score in the URL hash (no backend) —
on a phone it opens the native share sheet, on desktop it copies the link.

When a friend opens the link they see *"You've been challenged!"*, play the
**same board**, and the end screen compares both scores and declares a winner.
They can **Challenge them back** on the same board to keep it going.

The link only works where the app is hosted — for friends to play it must be
deployed (e.g. GitHub Pages), not just running on `localhost`.

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
