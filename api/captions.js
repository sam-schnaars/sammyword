// Caption the Meme board: today's captions, votes and moderation, shared by
// every player. Same setup as leaderboard.js: a Vercel function backed by the
// project's Upstash Redis. With no Redis configured it answers
// { configured: false } and the app keeps working without the board.
//
// Player actions (no accounts: each device sends a random `clientId`):
//   GET  /api/captions?day=N&clientId=X
//        Before you've submitted: { submitted: false, count }.
//        After: { submitted: true, mine, votedFor, captions: [...] }. You only
//        see other people's captions once yours is in.
//   POST { action: 'submit', day, clientId, text, name? }   one caption a day
//   POST { action: 'vote',   day, clientId, id }            one vote a day, not your own
//   POST { action: 'report', day, clientId, id }            3 reports hide a caption
//
// Moderation (header `Authorization: Bearer $CAPTIONS_ADMIN_TOKEN`):
//   GET  /api/captions?day=N&admin=1        every caption, with reports and hidden flag
//   POST { action: 'hide' | 'unhide' | 'delete', day, id }
//
// Protection: captions up to 80 characters and names up to 20, a word filter
// (`_blocklist.js`, plus CAPTIONS_BLOCKLIST, comma-separated), per-device and
// per-IP rate limits, and only today's meme (±1 day for time zones) accepts
// writes. A hidden caption still shows to its author, so they aren't tipped off.
import { Redis } from '@upstash/redis'
import { createHash } from 'node:crypto'
import { BLOCKED_WORDS } from './_blocklist.js'

export const LIMITS = {
  text: 80,
  name: 20,
  reportsToHide: 3,
  writesPerMinuteClient: 10,
  writesPerMinuteIp: 30,
  votesPerDayIp: 20,
  ttlSeconds: 60 * 60 * 24 * 14,
}

// Sammy Word day 1 = 2026-11-18 (the iOS app counts days in local time).
const DAY_ONE = Date.UTC(2026, 10, 18)
export const serverDay = (now = Date.now()) => Math.floor((now - DAY_ONE) / 86400000) + 1

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

// Collapse whitespace, drop control characters, cap the length.
export function tidy(s, max) {
  return String(s ?? '')
    .replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028-\u202e\u2060-\u206f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, max)
}

// True when the text contains a blocked word, also catching s p a c e d,
// l33t and repeated-letter spellings.
export function isBlocked(text, extra = process.env.CAPTIONS_BLOCKLIST || '') {
  const words = [...BLOCKED_WORDS, ...extra.split(',').map((w) => w.trim().toLowerCase()).filter(Boolean)]
  const flat = text
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[@4]/g, 'a').replace(/3/g, 'e').replace(/[1!|]/g, 'i').replace(/0/g, 'o')
    .replace(/[$5]/g, 's').replace(/7/g, 't')
  const joined = flat.replace(/[^a-z]/g, '').replace(/(.)\1+/g, '$1')
  const tokens = flat.split(/[^a-z]+/).map((t) => t.replace(/(.)\1+/g, '$1'))
  return words.some((w) => {
    const squeezed = w.replace(/(.)\1+/g, '$1')
    // Long words are caught inside other text; short ones only as whole words,
    // so "class" doesn't trip on "ass".
    return squeezed.length >= 5 ? joined.includes(squeezed) : tokens.includes(squeezed)
  })
}

const hashId = (clientId) => createHash('sha256').update('sw-cap:' + clientId).digest('hex').slice(0, 16)

function clientIp(req) {
  const fwd = String(req.headers?.['x-forwarded-for'] || '')
  return fwd.split(',')[0].trim() || req.socket?.remoteAddress || 'unknown'
}

const keys = (day) => ({
  caps: `cap:${day}`, // id → JSON { id, text, name, author, at }
  votes: `cap:votes:${day}`, // id → vote count
  voted: `cap:voted:${day}`, // clientId → id voted for
  mine: `cap:mine:${day}`, // clientId → own caption id
  reports: `cap:reports:${day}`, // id → report count
  reporters: `cap:reporters:${day}`, // `${clientId}|${id}` → 1
  hidden: `cap:hidden:${day}`, // set of hidden ids
})

const parse = (v) => (typeof v === 'string' ? safeJSON(v) : v)

function safeJSON(s) {
  try {
    return JSON.parse(s)
  } catch {
    return null
  }
}

// Fixed-window counter; true while under `limit`.
async function underLimit(redis, key, limit, seconds) {
  const n = await redis.incr(key)
  if (n === 1) await redis.expire(key, seconds)
  return n <= limit
}

export function createHandler(redis, { adminToken = process.env.CAPTIONS_ADMIN_TOKEN, now = () => Date.now() } = {}) {
  return async function handler(req, res) {
    if (!redis) return res.status(200).json({ configured: false })
    const body = typeof req.body === 'string' ? safeJSON(req.body) || {} : req.body || {}
    const q = req.query || {}
    const isPost = req.method === 'POST'
    if (!isPost && req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' })

    const day = Number(isPost ? body.day : q.day)
    if (!Number.isInteger(day) || day < 1 || day > 100000) return res.status(400).json({ error: 'bad day' })
    const k = keys(day)

    const auth = String(req.headers?.authorization || '')
    const isAdmin = Boolean(adminToken) && auth === `Bearer ${adminToken}`

    try {
      // ---- Moderation ----
      if (!isPost && q.admin) {
        if (!isAdmin) return res.status(401).json({ error: 'unauthorized' })
        return res.status(200).json({ configured: true, day, captions: await listAll(redis, k) })
      }
      const action = isPost ? String(body.action || '') : ''
      if (['hide', 'unhide', 'delete'].includes(action)) {
        if (!isAdmin) return res.status(401).json({ error: 'unauthorized' })
        const id = String(body.id || '')
        if (!(await redis.hget(k.caps, id))) return res.status(404).json({ error: 'no such caption' })
        if (action === 'hide') await redis.sadd(k.hidden, id)
        if (action === 'unhide') await redis.srem(k.hidden, id)
        if (action === 'delete') {
          await redis.hdel(k.caps, id)
          await redis.hdel(k.votes, id)
          await redis.srem(k.hidden, id)
        }
        return res.status(200).json({ ok: true, action, id })
      }

      // ---- Players ----
      const clientId = tidy(isPost ? body.clientId : q.clientId, 64)
      if (!/^[A-Za-z0-9-]{8,64}$/.test(clientId)) return res.status(400).json({ error: 'bad clientId' })

      if (isPost) {
        const today = serverDay(now())
        if (Math.abs(day - today) > 1) return res.status(400).json({ error: 'that meme is closed' })
        const ip = clientIp(req)
        const minute = Math.floor(now() / 60000)
        const okClient = await underLimit(redis, `rl:c:${clientId}:${minute}`, LIMITS.writesPerMinuteClient, 120)
        const okIp = await underLimit(redis, `rl:ip:${ip}:${minute}`, LIMITS.writesPerMinuteIp, 120)
        if (!okClient || !okIp) return res.status(429).json({ error: 'slow down' })

        if (action === 'submit') {
          const text = tidy(body.text, LIMITS.text)
          const name = tidy(body.name, LIMITS.name)
          if (!text) return res.status(400).json({ error: 'empty caption' })
          if (isBlocked(text) || (name && isBlocked(name))) {
            return res.status(422).json({ error: 'blocked', message: "That caption can't be posted. Try another." })
          }
          if (await redis.hget(k.mine, clientId)) return res.status(409).json({ error: 'already submitted' })
          const id = createHash('sha256').update(`${day}:${clientId}:${now()}`).digest('hex').slice(0, 12)
          // hsetnx makes a double tap race-safe: only the first submit lands.
          const first = await redis.hsetnx(k.mine, clientId, id)
          if (!first) return res.status(409).json({ error: 'already submitted' })
          const entry = { id, text, name: name || null, author: hashId(clientId), at: now() }
          await redis.hset(k.caps, { [id]: JSON.stringify(entry) })
          await Promise.all(Object.values(k).map((key) => redis.expire(key, LIMITS.ttlSeconds)))
        } else if (action === 'vote') {
          const id = String(body.id || '')
          const mine = await redis.hget(k.mine, clientId)
          if (!mine) return res.status(403).json({ error: 'submit yours first' })
          if (id === mine) return res.status(400).json({ error: "can't vote for your own" })
          if (!(await redis.hget(k.caps, id)) || (await redis.sismember(k.hidden, id))) {
            return res.status(404).json({ error: 'no such caption' })
          }
          const okVotesIp = await underLimit(redis, `rl:v:${day}:${ip}`, LIMITS.votesPerDayIp, 60 * 60 * 48)
          if (!okVotesIp) return res.status(429).json({ error: 'too many votes from this network' })
          const first = await redis.hsetnx(k.voted, clientId, id)
          if (!first) return res.status(409).json({ error: 'already voted' })
          await redis.hincrby(k.votes, id, 1)
          await redis.expire(k.voted, LIMITS.ttlSeconds)
          await redis.expire(k.votes, LIMITS.ttlSeconds)
        } else if (action === 'report') {
          const id = String(body.id || '')
          if (!(await redis.hget(k.caps, id))) return res.status(404).json({ error: 'no such caption' })
          const first = await redis.hsetnx(k.reporters, `${clientId}|${id}`, 1)
          if (first) {
            const n = await redis.hincrby(k.reports, id, 1)
            if (n >= LIMITS.reportsToHide) await redis.sadd(k.hidden, id)
            await redis.expire(k.reports, LIMITS.ttlSeconds)
            await redis.expire(k.reporters, LIMITS.ttlSeconds)
            await redis.expire(k.hidden, LIMITS.ttlSeconds)
          }
        } else {
          return res.status(400).json({ error: 'unknown action' })
        }
      }

      return res.status(200).json(await board(redis, k, clientId))
    } catch (err) {
      return res.status(500).json({ error: 'captions error', detail: String(err?.message || err) })
    }
  }
}

// What one player sees: just a count until they've submitted, then everyone's
// captions (minus hidden ones, except their own), most votes first.
async function board(redis, k, clientId) {
  const mine = await redis.hget(k.mine, clientId)
  const all = (await redis.hgetall(k.caps)) || {}
  if (!mine) return { configured: true, submitted: false, count: Object.keys(all).length }
  const [votes, hidden, votedFor] = await Promise.all([
    redis.hgetall(k.votes),
    redis.smembers(k.hidden),
    redis.hget(k.voted, clientId),
  ])
  const hiddenSet = new Set(hidden || [])
  const captions = Object.values(all)
    .map(parse)
    .filter((c) => c && (c.id === mine || !hiddenSet.has(c.id)))
    .map((c) => ({
      id: c.id,
      text: c.text,
      name: c.name || null,
      author: c.author,
      votes: Number(votes?.[c.id] || 0),
      mine: c.id === mine,
    }))
    .sort((a, b) => b.votes - a.votes || a.text.localeCompare(b.text))
  return { configured: true, submitted: true, mine, votedFor: votedFor || null, captions }
}

async function listAll(redis, k) {
  const [all, votes, reports, hidden] = await Promise.all([
    redis.hgetall(k.caps),
    redis.hgetall(k.votes),
    redis.hgetall(k.reports),
    redis.smembers(k.hidden),
  ])
  const hiddenSet = new Set(hidden || [])
  return Object.values(all || {})
    .map(parse)
    .filter(Boolean)
    .map((c) => ({
      ...c,
      votes: Number(votes?.[c.id] || 0),
      reports: Number(reports?.[c.id] || 0),
      hidden: hiddenSet.has(c.id),
    }))
    .sort((a, b) => b.reports - a.reports || b.at - a.at)
}

const { url, token } = findRedisCreds()
export default createHandler(url && token ? new Redis({ url, token }) : null)
