// Daily Sammy — one prompt a day ("Name a bird"). Name 3 different answers;
// each valid one scores by how few people give it, so "Shoebill" beats
// "Eagle" by a mile. An answer we don't accept costs one of 3 lives.
//
// Scoring: an answer given by pct% of players scores
//   points = max(5, round(25 * log2(100 / pct)))
// so 30% → 43, 10% → 83, 1% → 166, 0.1% → 249, 0.01% → 332. Every halving
// of how common an answer is adds the same 25 points, which keeps one lucky
// deep cut from swamping the day but still makes niche answers the way to win.
import { normalize, editDistance } from '../deepcut.js'
import { DAYS, DAY_ONE } from './days.js'

export const PICKS = 3 // answers to bank per day
export const LIVES = 3 // wrong answers allowed

export const TIERS = [
  { min: 5, label: 'Obvious', emoji: '⬜', cls: 'obvious' },
  { min: 1, label: 'Solid', emoji: '🟩', cls: 'solid' },
  { min: 0.1, label: 'Niche', emoji: '🟦', cls: 'niche' },
  { min: 0, label: 'Deep cut', emoji: '🟪', cls: 'deep' },
]

export const tierOf = (pct) => TIERS.find((t) => pct >= t.min)

export const pointsFor = (pct) =>
  Math.max(5, Math.round(25 * Math.log2(100 / Math.max(pct, 0.001))))

// The seed estimate counts as this many virtual players, so live tallies only
// move the needle once real players outnumber the guesswork.
const SEED_PLAYERS = 1000

// Share (in %) of players giving `answer`, blending the seed estimate with
// live tallies `{ [display]: count }` when we have them. Prototype passes {}.
export function shareOf(answer, live = {}) {
  const liveTotal = Object.values(live).reduce((a, b) => a + b, 0)
  const count = (answer.seedPct / 100) * SEED_PLAYERS + (live[answer.display] || 0)
  return (count / (SEED_PLAYERS + liveTotal)) * 100
}

// Day number (1-based) for a date, counted in UTC days from DAY_ONE.
export function dayNumber(date = new Date()) {
  const start = Date.parse(DAY_ONE + 'T00:00:00Z')
  const today = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate())
  return Math.max(1, Math.floor((today - start) / 86400000) + 1)
}

// Parsed puzzle for day `n` (loops over the seed list).
export function puzzle(n) {
  const raw = DAYS[(n - 1) % DAYS.length]
  const answers = Object.entries(raw.answers)
    .filter(([, pct]) => pct > 0)
    .map(([names, pct]) => {
      const list = names.split('|')
      return { display: list[0], keys: list.map(normalize), seedPct: pct }
    })
    .sort((a, b) => b.seedPct - a.seedPct)
  return { n, prompt: raw.prompt, answers }
}

// Match typed text to an answer: exact, then a dropped plural "s"/"es", then
// one typo for 5+ letters. Returns the answer or null.
export function match(p, text) {
  const g = normalize(text)
  if (!g) return null
  const tries = [g]
  if (g.endsWith('es')) tries.push(g.slice(0, -2))
  if (g.endsWith('s')) tries.push(g.slice(0, -1))
  for (const t of tries) {
    const hit = p.answers.find((a) => a.keys.includes(t))
    if (hit) return hit
  }
  if (g.length >= 5) {
    const hit = p.answers.find((a) =>
      a.keys.some((k) => k.length >= 5 && editDistance(g, k, 1) <= 1),
    )
    if (hit) return hit
  }
  return null
}

// Judge one guess against the current state. Returns
// { kind: 'hit', answer, pct, points, tier } | { kind: 'repeat', answer } |
// { kind: 'miss' } | { kind: 'empty' }.
export function judge(p, text, banked, live) {
  if (!normalize(text)) return { kind: 'empty' }
  const answer = match(p, text)
  if (!answer) return { kind: 'miss' }
  if (banked.some((b) => b.display === answer.display)) return { kind: 'repeat', answer }
  const pct = shareOf(answer, live)
  return { kind: 'hit', answer, pct, points: pointsFor(pct), tier: tierOf(pct) }
}

export const total = (banked) => banked.reduce((s, b) => s + b.points, 0)

// The best score possible today: the PICKS rarest answers.
export function bestPossible(p) {
  return p.answers
    .slice(-PICKS)
    .reduce((s, a) => s + pointsFor(shareOf(a)), 0)
}

export function shareText(p, banked) {
  const squares = banked.map((b) => tierOf(b.pct).emoji).join('')
  const pad = '⬛'.repeat(Math.max(0, PICKS - banked.length))
  return `Daily Sammy #${p.n} · ${p.prompt}\n${squares}${pad} ${total(banked)} pts\nsamarei.com/mobile/daily/`
}

// ---- Per-device results (localStorage) ----
const KEY = 'dailysammy:v1'

export function loadAll() {
  try {
    return JSON.parse(localStorage.getItem(KEY)) || {}
  } catch {
    return {}
  }
}

export function saveDay(n, state) {
  const all = loadAll()
  all[n] = state
  localStorage.setItem(KEY, JSON.stringify(all))
}

// Days in a row finished, ending today (or yesterday if today isn't done yet).
export function streak(all, today) {
  let d = all[today]?.done ? today : today - 1
  let s = 0
  while (all[d]?.done) {
    s++
    d--
  }
  return s
}
