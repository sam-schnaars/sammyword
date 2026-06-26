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

// challenge: { mapId: string, letters: string, score: number, name: string }
export function encodeChallenge({ mapId, letters, score, name }) {
  return toB64Url(JSON.stringify({ m: mapId, b: letters, s: score, n: name || '' }))
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
