// Encode/decode a "challenge" into a shareable URL so a friend can play the
// exact same board and have their score compared at the end. Everything rides
// in the URL hash — no backend needed.

function toB64Url(str) {
  const b64 = btoa(unescape(encodeURIComponent(str)))
  return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function fromB64Url(str) {
  let s = str.replace(/-/g, '+').replace(/_/g, '/')
  while (s.length % 4) s += '='
  return decodeURIComponent(escape(atob(s)))
}

// challenge: { mapId, letters, score, name, words: string[] }
// `words` is the sender's found words (lowercase), so the recipient can see what
// the sender found and the end screen can compare both word lists side by side.
export function encodeChallenge({ mapId, letters, score, name, words }) {
  return toB64Url(
    JSON.stringify({
      m: mapId,
      b: letters,
      s: score,
      n: name || '',
      w: (words || []).join(','),
    }),
  )
}

export function decodeChallenge(str) {
  try {
    const p = JSON.parse(fromB64Url(str))
    if (typeof p.b !== 'string' || p.b.length < 1) return null
    return {
      mapId: String(p.m || 'classic'),
      letters: p.b.toUpperCase(),
      score: Number(p.s) || 0,
      name: String(p.n || ''),
      words:
        typeof p.w === 'string' && p.w.length
          ? p.w.split(',').filter(Boolean)
          : [],
    }
  } catch {
    return null
  }
}

export function buildChallengeUrl(data) {
  return `${location.origin}${location.pathname}#c=${encodeChallenge(data)}`
}

export function readChallengeFromUrl() {
  const m = location.hash.match(/c=([^&]+)/)
  return m ? decodeChallenge(m[1]) : null
}

export function clearChallengeFromUrl() {
  history.replaceState(null, '', location.pathname + location.search)
}

// ---- Flag Match challenge (mode "f") ----
// A challenge replays the same seeded quiz, so we only carry the seed + score.
// flagChallenge: { seed: number, score: number, name: string }
export function encodeFlagChallenge({ seed, score, name }) {
  return toB64Url(JSON.stringify({ f: seed, s: score, n: name || '' }))
}

export function decodeFlagChallenge(str) {
  try {
    const p = JSON.parse(fromB64Url(str))
    if (typeof p.f !== 'number') return null
    return { seed: Number(p.f), score: Number(p.s) || 0, name: String(p.n || '') }
  } catch {
    return null
  }
}

export function buildFlagChallengeUrl(data) {
  return `${location.origin}${location.pathname}#f=${encodeFlagChallenge(data)}`
}

export function readFlagChallengeFromUrl() {
  const m = location.hash.match(/[#&]f=([^&]+)/)
  return m ? decodeFlagChallenge(m[1]) : null
}

// Local (this-device) personal best for the daily board, keyed by day.
// A real cross-player leaderboard needs a shared backend (e.g. Vercel KV);
// this is the zero-dependency starting point.
export function dailyBest(dayKey) {
  try {
    return Number(localStorage.getItem('sw-best-' + dayKey)) || 0
  } catch {
    return 0
  }
}

export function saveDailyBest(dayKey, score) {
  try {
    if (score > dailyBest(dayKey)) {
      localStorage.setItem('sw-best-' + dayKey, String(score))
      return true
    }
  } catch {
    /* ignore */
  }
  return false
}

const NAME_KEY = 'sw-name'
export const loadName = () => {
  try {
    return localStorage.getItem(NAME_KEY) || ''
  } catch {
    return ''
  }
}
export const saveName = (n) => {
  try {
    localStorage.setItem(NAME_KEY, n)
  } catch {
    /* ignore */
  }
}
