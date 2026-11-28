// Daily leaderboards, one per game per day, backed by the project's Upstash
// Redis (same setup as captions.js). With no Redis configured it answers
// { configured: false } and the apps keep working without boards.
//
// Everyone plays the same puzzle each day, and only your first round of the
// day counts (later replays don't replace it), so the board is a fair race.
// No accounts: each device sends a random `clientId`.
//
//   GET  /api/leaderboard?game=f&day=2026-11-28&clientId=X
//        → { configured, game, day, lowerWins, count, entries: [{ id, name, score, bonus, you }],
//            rank, yourScore }
//   POST { game, day, clientId, score, bonus?, name? }   post today's score (first one sticks);
//        posting again only updates the name
//   POST { action: 'report', game, day, clientId, id }   3 reports hide a name ("Player")
//
// Moderation (header `Authorization: Bearer $CAPTIONS_ADMIN_TOKEN`):
//   POST { action: 'remove', game, day, id }             drop an entry
//
// `day` is the puzzle the score belongs to: the UTC date for boards seeded by
// date (Word Hunt, Flag Match), the Sammy Word day number for Scroll Recall,
// and the site's own puzzle number for the creators' games. Requests without
// `game` are the web's Map of the Day (`wh`), kept on its original keys.
import { Redis } from '@upstash/redis'
import { createHash } from 'node:crypto'
import { isBlocked, serverDay, tidy } from './captions.js'

// score: the headline number; bonus: a tie-breaker (higher is better, e.g.
// seconds left), stored as score + bonus/1000.
export const GAMES = {
  wh: { title: 'Word Hunt · Map of the Day', max: 999999, day: 'date' }, // web (heart board)
  w: { title: 'Word Hunt', max: 99999, day: 'date' }, // iOS daily 4×4
  f: { title: 'Flag Match', max: 5, day: 'date', bonusMax: 60 }, // flags right; bonus = seconds left
  r: { title: 'Scroll Recall', max: 5, day: 'number' },
  k: { title: 'Krillion', max: 999999, day: 'site' },
  m: { title: 'Magnitudle', max: 100, day: 'site' },
  h: { title: '100 of Us', max: 100, day: 'site', lowerWins: true }, // how far off
  e: { title: 'Eraly', max: 700, day: 'site' },
}

export const LIMITS = {
  name: 16,
  topN: 20,
  reportsToHide: 3,
  writesPerMinuteClient: 10,
  writesPerMinuteIp: 30,
  ttlSeconds: 60 * 60 * 24 * 4,
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/

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

export const entryId = (clientId) => createHash('sha256').update('sw-lb:' + clientId).digest('hex').slice(0, 16)

const utcDate = (ms) => new Date(ms).toISOString().slice(0, 10)

// Is `day` a valid puzzle for this game? `writable` also requires it to be
// today's (±1 day for time zones), for the boards we can check.
function checkDay(game, day, now, writable) {
  const kind = GAMES[game].day
  if (kind === 'date') {
    if (!DATE_RE.test(day)) return false
    if (!writable) return true
    return [-1, 0, 1].some((d) => utcDate(now + d * 86400000) === day)
  }
  if (!/^\d{1,7}$/.test(day) || Number(day) < 1) return false
  if (kind === 'number' && writable) return Math.abs(Number(day) - serverDay(now)) <= 1
  return true
}

const keys = (game, day) =>
  game === 'wh'
    ? { scores: `lb:${day}`, names: `names:${day}`, ids: `lbi:wh:${day}`, reports: `lbr:wh:${day}`, reporters: `lbrr:wh:${day}`, hidden: `lbh:wh:${day}` }
    : {
        scores: `lb:${game}:${day}`, // clientId → score (+ bonus/1000)
        names: `lbn:${game}:${day}`, // clientId → name
        ids: `lbi:${game}:${day}`, // entry id → clientId
        reports: `lbr:${game}:${day}`, // entry id → report count
        reporters: `lbrr:${game}:${day}`, // `${clientId}|${id}` → 1
        hidden: `lbh:${game}:${day}`, // entry ids whose name is hidden
      }

function clientIp(req) {
  const fwd = String(req.headers?.['x-forwarded-for'] || '')
  return fwd.split(',')[0].trim() || req.socket?.remoteAddress || 'unknown'
}

async function underLimit(redis, key, limit, seconds) {
  const n = await redis.incr(key)
  if (n === 1) await redis.expire(key, seconds)
  return n <= limit
}

function safeJSON(s) {
  try {
    return JSON.parse(s)
  } catch {
    return null
  }
}

export function createHandler(redis, { adminToken = process.env.CAPTIONS_ADMIN_TOKEN, now = () => Date.now() } = {}) {
  return async function handler(req, res) {
    const body = typeof req.body === 'string' ? safeJSON(req.body) || {} : req.body || {}
    const q = req.query || {}
    const isPost = req.method === 'POST'
    if (!isPost && req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' })
    const src = isPost ? body : q

    const game = String(src.game || 'wh')
    if (!GAMES[game]) return res.status(400).json({ error: 'bad game' })
    const cfg = GAMES[game]
    const day = String(src.day ?? '')
    const action = isPost ? String(body.action || 'post') : 'get'
    const writing = action === 'post'
    if (!checkDay(game, day, now(), writing)) {
      return res.status(400).json({ error: writing ? 'that day is closed' : 'bad day' })
    }
    if (!redis) return res.status(200).json({ configured: false, game, day, entries: [] })
    const k = keys(game, day)

    try {
      if (action === 'remove') {
        const auth = String(req.headers?.authorization || '')
        if (!adminToken || auth !== `Bearer ${adminToken}`) return res.status(401).json({ error: 'unauthorized' })
        const owner = await redis.hget(k.ids, String(body.id || ''))
        if (!owner) return res.status(404).json({ error: 'no such entry' })
        await redis.zrem(k.scores, owner)
        await redis.hdel(k.names, owner)
        return res.status(200).json({ ok: true, removed: String(body.id) })
      }

      const clientId = tidy(src.clientId, 64)
      const validClient = /^[A-Za-z0-9-]{8,64}$/.test(clientId)

      if (isPost) {
        if (!validClient) return res.status(400).json({ error: 'bad clientId' })
        const minute = Math.floor(now() / 60000)
        const okClient = await underLimit(redis, `rl:lbc:${clientId}:${minute}`, LIMITS.writesPerMinuteClient, 120)
        const okIp = await underLimit(redis, `rl:lbip:${clientIp(req)}:${minute}`, LIMITS.writesPerMinuteIp, 120)
        if (!okClient || !okIp) return res.status(429).json({ error: 'slow down' })

        if (action === 'post') {
          const raw = Number(body.score)
          if (!Number.isFinite(raw)) return res.status(400).json({ error: 'bad score' })
          const score = Math.max(0, Math.min(cfg.max, Math.floor(raw)))
          const bonus = cfg.bonusMax ? Math.max(0, Math.min(cfg.bonusMax, Math.floor(Number(body.bonus) || 0))) : 0
          let name = tidy(body.name, LIMITS.name)
          if (name && isBlocked(name)) name = ''
          // nx: the first round of the day sticks; replays only update the name.
          await redis.zadd(k.scores, { nx: true }, { score: score + bonus / 1000, member: clientId })
          await redis.hset(k.names, { [clientId]: name || 'Anonymous' })
          await redis.hset(k.ids, { [entryId(clientId)]: clientId })
          await Promise.all([k.scores, k.names, k.ids].map((key) => redis.expire(key, LIMITS.ttlSeconds)))
        } else if (action === 'report') {
          const id = String(body.id || '')
          if (!(await redis.hget(k.ids, id))) return res.status(404).json({ error: 'no such entry' })
          const first = await redis.hsetnx(k.reporters, `${clientId}|${id}`, 1)
          if (first) {
            const n = await redis.hincrby(k.reports, id, 1)
            if (n >= LIMITS.reportsToHide) await redis.sadd(k.hidden, id)
            await Promise.all([k.reports, k.reporters, k.hidden].map((key) => redis.expire(key, LIMITS.ttlSeconds)))
          }
        } else {
          return res.status(400).json({ error: 'unknown action' })
        }
      }

      return res.status(200).json(await board(redis, k, game, day, validClient ? clientId : ''))
    } catch (err) {
      return res.status(500).json({ error: 'leaderboard error', detail: String(err?.message || err) })
    }
  }
}

async function board(redis, k, game, day, clientId) {
  const cfg = GAMES[game]
  const flat = await redis.zrange(k.scores, 0, LIMITS.topN - 1, { rev: !cfg.lowerWins, withScores: true })
  const ids = []
  const raw = []
  for (let i = 0; i < flat.length; i += 2) {
    ids.push(String(flat[i]))
    raw.push(Number(flat[i + 1]))
  }
  const [names, hidden, count] = await Promise.all([
    ids.length ? redis.hgetall(k.names) : null,
    redis.smembers(k.hidden),
    redis.zcard(k.scores),
  ])
  const hiddenSet = new Set(hidden || [])
  const split = (v) => {
    const score = Math.floor(v + 1e-6)
    return { score, bonus: Math.round((v - score) * 1000) }
  }
  // Ties share a rank: 1 + how many scored strictly better.
  const rankOf = async (v) =>
    1 + (cfg.lowerWins ? await redis.zcount(k.scores, '-inf', `(${v}`) : await redis.zcount(k.scores, `(${v}`, '+inf'))
  const ranks = []
  for (let i = 0; i < raw.length; i++) ranks.push(i > 0 && raw[i] === raw[i - 1] ? ranks[i - 1] : i + 1)
  const entries = ids.map((cid, i) => {
    const id = entryId(cid)
    const shown = hiddenSet.has(id) && cid !== clientId ? 'Player' : names?.[cid] || 'Anonymous'
    return { id, name: shown, ...split(raw[i]), rank: ranks[i], you: cid === clientId }
  })

  let rank = null
  let yourScore = null
  let yourBonus = null
  if (clientId) {
    const mine = await redis.zscore(k.scores, clientId)
    if (mine != null) {
      const v = Number(mine)
      ;({ score: yourScore, bonus: yourBonus } = split(v))
      rank = await rankOf(v)
    }
  }
  return {
    configured: true,
    game,
    day,
    lowerWins: Boolean(cfg.lowerWins),
    count: Number(count) || 0,
    entries,
    rank,
    yourScore,
    yourBonus,
  }
}

const { url, token } = findRedisCreds()
export default createHandler(url && token ? new Redis({ url, token }) : null)
