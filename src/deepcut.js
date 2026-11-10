// "Deep Cut" — a rare-answer trivia mode. Each prompt ("Name a US state") has a
// fixed list of valid answers, each tagged with a rarity tier. The more obscure
// your (correct) answer, the more it scores. A round is a handful of prompts
// picked from a numeric seed, so a challenge replays the same prompts for a
// friend — no backend needed (mirrors Flag Match).
//
// The bank lives in `deepcut.json`, which is byte-identical to the iOS copy at
// `ios/SammyWordMessages/Resources/deepcut.json`.
import BANK from './deepcut.json'

export const DEEP_PROMPTS = 5 // prompts per round
export const DEEP_SECONDS = 20 // seconds per prompt
export const TIER_POINTS = BANK.tiers // tier 1..4 → points
export const TIER_LABELS = ['Common', 'Solid', 'Rare', 'Deep cut!']

// Normalize free-typed text for matching: lowercase, strip accents, drop a
// leading "the", "&" → "and", then keep only a–z / 0–9.
export function normalize(s) {
  let t = String(s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/&/g, ' and ')
    .trim()
  if (t.startsWith('the ')) t = t.slice(4)
  return t.replace(/[^a-z0-9]/g, '')
}

// Parse "Display|alias|alias:tier" entries once.
export const PROMPTS = BANK.prompts.map((p) => ({
  q: p.q,
  answers: p.a.map((entry) => {
    const cut = entry.lastIndexOf(':')
    const names = entry.slice(0, cut).split('|')
    return {
      display: names[0],
      keys: names.map(normalize),
      tier: Number(entry.slice(cut + 1)),
    }
  }),
}))

// Levenshtein distance capped early at `max + 1`.
function editDistance(a, b, max) {
  if (Math.abs(a.length - b.length) > max) return max + 1
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j)
  for (let i = 1; i <= a.length; i++) {
    const cur = [i]
    let rowMin = i
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
      rowMin = Math.min(rowMin, cur[j])
    }
    if (rowMin > max) return max + 1
    prev = cur
  }
  return prev[b.length]
}

// Match a typed guess against a prompt. Exact (normalized) match first; then,
// for guesses of 5+ chars, forgive a single typo. Returns the answer or null.
export function matchAnswer(promptIndex, guess) {
  const g = normalize(guess)
  if (!g) return null
  const answers = PROMPTS[promptIndex].answers
  for (const a of answers) if (a.keys.includes(g)) return a
  if (g.length >= 5) {
    for (const a of answers)
      if (a.keys.some((k) => k.length >= 5 && editDistance(g, k, 1) <= 1)) return a
  }
  return null
}

// Score one typed guess: { answer, points } (answer null + 0 if invalid).
export function scoreGuess(promptIndex, guess) {
  const answer = matchAnswer(promptIndex, guess)
  return { answer, points: answer ? TIER_POINTS[answer.tier - 1] : 0 }
}

// The rarest few answers for a prompt — shown after a round as "deep cuts".
export function deepCuts(promptIndex, n = 3) {
  return PROMPTS[promptIndex].answers.filter((a) => a.tier === 4).slice(0, n)
}

// Deterministic round from `seed`: DEEP_PROMPTS distinct prompt indices.
export function buildRound(seed, count = DEEP_PROMPTS) {
  const rng = mulberry32(seed)
  const a = PROMPTS.map((_, i) => i)
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a.slice(0, Math.min(count, a.length))
}

export const randomSeed = () => Math.floor(Math.random() * 1e9)

function mulberry32(seed) {
  let a = seed >>> 0
  return function () {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}
