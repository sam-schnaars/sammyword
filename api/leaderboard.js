// Global daily leaderboard, backed by Redis (Upstash / Vercel KV).
// Zero-config Vercel serverless function (Node runtime). It reads whichever
// env vars the Vercel storage integration provides, and if none are set it
// responds with { configured: false } so the app degrades gracefully.
import { Redis } from '@upstash/redis'

// Find the Upstash REST URL + token regardless of the env-var prefix Vercel's
// storage integration chose (e.g. KV_REST_API_URL, UPSTASH_REDIS_REST_URL, or a
// custom-prefixed STORAGE_KV_REST_API_URL).
function findRedisCreds() {
  const e = process.env
  let url = e.KV_REST_API_URL || e.UPSTASH_REDIS_REST_URL
  let token = e.KV_REST_API_TOKEN || e.UPSTASH_REDIS_REST_TOKEN
  if (!url || !token) {
    for (const [k, v] of Object.entries(e)) {
      if (!v) continue
      if (!url && /(REST_API_URL|REDIS_REST_URL)$/.test(k)) url = v
      if (!token && /(REST_API_TOKEN|REDIS_REST_TOKEN)$/.test(k)) token = v
    }
  }
  return { url, token }
}

const { url, token } = findRedisCreds()
const redis = url && token ? new Redis({ url, token }) : null

const DAY_RE = /^\d{4}-\d{2}-\d{2}$/
const THREE_DAYS = 60 * 60 * 24 * 3
const TOP_N = 20

const clean = (s, max) => String(s ?? '').slice(0, max)

export default async function handler(req, res) {
  if (!redis) return res.status(200).json({ configured: false, entries: [] })

  const body = typeof req.body === 'string' ? safeParse(req.body) : req.body || {}
  const day = req.method === 'POST' ? body.day : req.query.day
  if (!DAY_RE.test(String(day || ''))) {
    return res.status(400).json({ error: 'bad day' })
  }

  const lbKey = `lb:${day}`
  const nameKey = `names:${day}`
  const clientId = clean(req.method === 'POST' ? body.clientId : req.query.clientId, 64)

  try {
    if (req.method === 'POST') {
      const score = Math.max(0, Math.min(999999, Math.floor(Number(body.score) || 0)))
      const name = clean(body.name, 16).trim() || 'Anonymous'
      if (!clientId) return res.status(400).json({ error: 'missing clientId' })
      // Keep only each player's best score for the day.
      await redis.zadd(lbKey, { gt: true }, { score, member: clientId })
      await redis.hset(nameKey, { [clientId]: name })
      await redis.expire(lbKey, THREE_DAYS)
      await redis.expire(nameKey, THREE_DAYS)
    } else if (req.method !== 'GET') {
      return res.status(405).json({ error: 'method not allowed' })
    }

    const flat = await redis.zrange(lbKey, 0, TOP_N - 1, { rev: true, withScores: true })
    const ids = []
    const scores = []
    for (let i = 0; i < flat.length; i += 2) {
      ids.push(String(flat[i]))
      scores.push(Number(flat[i + 1]))
    }
    const names = (ids.length ? await redis.hgetall(nameKey) : {}) || {}
    const entries = ids.map((id, i) => ({
      name: names[id] || 'Anonymous',
      score: scores[i],
      you: id === clientId,
    }))

    let rank = null
    let yourScore = null
    if (clientId) {
      yourScore = await redis.zscore(lbKey, clientId)
      if (yourScore != null) {
        const above = await redis.zcount(lbKey, `(${yourScore}`, '+inf')
        rank = above + 1
      }
    }

    return res.status(200).json({ configured: true, entries, rank, yourScore })
  } catch (err) {
    return res.status(500).json({ error: 'leaderboard error', detail: String(err?.message || err) })
  }
}

function safeParse(s) {
  try {
    return JSON.parse(s)
  } catch {
    return {}
  }
}
