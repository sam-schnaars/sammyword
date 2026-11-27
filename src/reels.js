// "Scroll Recall" (working name): a daily set of 8 short reels, real
// public-domain NASA footage with a silly caption and a fact on top. Each
// reel plays ~8 s and moves on by itself unless you swipe first, and there's
// no going back. Then 5 questions about what you saw.
//
// The sets live in `reels.json`, byte-identical to the iOS copy at
// `ios/SammyWordMessages/Resources/reels.json`. Day 1 = 2026-11-18 (local),
// the same day count as the iOS game of the day.
import DATA from './reels.json'

export const REEL_SECONDS = DATA.seconds
export const SETS = DATA.sets

export function reelDay(date = new Date()) {
  const start = new Date(2026, 10, 18)
  const today = new Date(date.getFullYear(), date.getMonth(), date.getDate())
  return Math.max(1, Math.round((today - start) / 86400000) + 1)
}

export const setFor = (day) => SETS[(((day - 1) % SETS.length) + SETS.length) % SETS.length]

// FNV-1a and mulberry32, the same as board.js and iOS SeededRNG.
function hashStr(s) {
  let h = 2166136261
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

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

// The day's questions with their choices shuffled (the bank lists the right
// answer first). Seeded by day, so iOS shows the same order.
export function quizFor(day) {
  const rng = mulberry32(hashStr('reels-' + day))
  return setFor(day).quiz.map((item) => {
    const order = item.options.map((_, i) => i)
    for (let i = order.length - 1; i > 0; i--) {
      const j = Math.min(Math.floor(rng() * (i + 1)), i)
      ;[order[i], order[j]] = [order[j], order[i]]
    }
    return { q: item.q, options: order.map((i) => item.options[i]), answer: order.indexOf(item.answer) }
  })
}

// Per-device results: { [day]: score }.
const KEY = 'sw-reels'
export function savedScore(day) {
  try {
    return JSON.parse(localStorage.getItem(KEY) || '{}')[day] ?? null
  } catch {
    return null
  }
}
export function saveScore(day, score) {
  try {
    const all = JSON.parse(localStorage.getItem(KEY) || '{}')
    all[day] = score
    localStorage.setItem(KEY, JSON.stringify(all))
  } catch {
    /* private mode */
  }
}
