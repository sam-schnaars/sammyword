// Frontend client for the global daily leaderboard (/api/leaderboard).
// Each browser gets a stable anonymous id so we can track its best score.

function getClientId() {
  try {
    let id = localStorage.getItem('sw-cid')
    if (!id) {
      id = crypto.randomUUID?.() || `id-${Math.random().toString(36).slice(2)}${Date.now().toString(36)}`
      localStorage.setItem('sw-cid', id)
    }
    return id
  } catch {
    return 'anon'
  }
}

export async function submitScore({ day, score, name }) {
  const res = await fetch('/api/leaderboard', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ day, score, name, clientId: getClientId() }),
  })
  const data = await res.json()
  if (!res.ok) throw new Error(data?.error || 'submit failed')
  return data
}

export async function fetchLeaderboard(day) {
  const res = await fetch(
    `/api/leaderboard?day=${encodeURIComponent(day)}&clientId=${encodeURIComponent(getClientId())}`,
  )
  const data = await res.json()
  if (!res.ok) throw new Error(data?.error || 'fetch failed')
  return data
}
