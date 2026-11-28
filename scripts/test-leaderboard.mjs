// Checks for api/leaderboard.js against an in-memory Redis stand-in. Run: node scripts/test-leaderboard.mjs
import assert from 'node:assert/strict'
import { createHandler, entryId } from '../api/leaderboard.js'

class FakeRedis {
  m = new Map()
  h(k) { if (!this.m.has(k)) this.m.set(k, new Map()); return this.m.get(k) }
  s(k) { if (!this.m.has(k)) this.m.set(k, new Set()); return this.m.get(k) }
  z(k) { if (!this.m.has(k)) this.m.set(k, new Map()); return this.m.get(k) }
  async incr(k) { const v = (this.m.get(k) || 0) + 1; this.m.set(k, v); return v }
  async expire() { return 1 }
  async hget(k, f) { return this.m.get(k)?.get?.(f) ?? null }
  async hset(k, obj) { for (const [f, v] of Object.entries(obj)) this.h(k).set(f, v); return 1 }
  async hsetnx(k, f, v) { const h = this.h(k); if (h.has(f)) return 0; h.set(f, v); return 1 }
  async hdel(k, f) { return this.h(k).delete(f) ? 1 : 0 }
  async hgetall(k) { const h = this.m.get(k); return h && h.size ? Object.fromEntries(h) : null }
  async hincrby(k, f, n) { const h = this.h(k); const v = Number(h.get(f) || 0) + n; h.set(f, v); return v }
  async sadd(k, v) { this.s(k).add(v); return 1 }
  async smembers(k) { return [...(this.m.get(k) || [])] }
  async zadd(k, opts, { score, member }) {
    const z = this.z(k)
    if (opts.nx && z.has(member)) return 0
    z.set(member, score)
    return 1
  }
  async zrem(k, member) { return this.z(k).delete(member) ? 1 : 0 }
  async zscore(k, member) { return this.m.get(k)?.get?.(member) ?? null }
  async zcard(k) { return this.m.get(k)?.size || 0 }
  async zcount(k, min, max) {
    const num = (s, inf) => (s === '-inf' ? -Infinity : s === '+inf' ? Infinity : Number(String(s).replace('(', '')))
    const lo = num(min), hi = num(max)
    const loEx = String(min).startsWith('('), hiEx = String(max).startsWith('(')
    return [...(this.m.get(k)?.values() || [])].filter((v) => (loEx ? v > lo : v >= lo) && (hiEx ? v < hi : v <= hi)).length
  }
  async zrange(k, start, stop, { rev, withScores }) {
    const all = [...(this.m.get(k) || new Map())].sort((a, b) => (rev ? b[1] - a[1] : a[1] - b[1]) || a[0].localeCompare(b[0]))
    const out = []
    for (const [m, s] of all.slice(start, stop + 1)) out.push(m, ...(withScores ? [s] : []))
    return out
  }
}

const NOW = Date.UTC(2026, 10, 28, 18) // 2026-11-28, Sammy Word day 11
const TODAY = '2026-11-28'
const redis = new FakeRedis()
const handler = createHandler(redis, { adminToken: 'secret-admin', now: () => NOW })

let ipN = 0
async function call(method, data, { auth } = {}) {
  let status, json
  const res = { status(s) { status = s; return this }, json(j) { json = j; return this } }
  const headers = { 'x-forwarded-for': `10.0.0.${++ipN}`, authorization: auth }
  await handler(method === 'GET' ? { method, query: data, headers } : { method, body: data, query: {}, headers }, res)
  return { status, json }
}
const id = (n) => `player-${String(n).padStart(4, '0')}`
const post = (game, day, n, score, extra = {}) => call('POST', { game, day, clientId: id(n), score, ...extra })

// Flag Match: flags right, seconds left breaks ties, first round sticks.
let r = await post('f', TODAY, 1, 5, { bonus: 12, name: 'Ada' })
assert.equal(r.status, 200)
assert.equal(r.json.rank, 1)
await post('f', TODAY, 2, 5, { bonus: 30, name: 'Bo' })
await post('f', TODAY, 3, 4, { bonus: 59, name: 'Cy' })
r = await post('f', TODAY, 1, 5, { bonus: 60, name: 'Ada L' }) // replay: score stays, name updates
assert.deepEqual(r.json.entries.map((e) => [e.name, e.score, e.bonus, e.rank]), [['Bo', 5, 30, 1], ['Ada L', 5, 12, 2], ['Cy', 4, 59, 3]])
assert.equal(r.json.rank, 2)
assert.equal(r.json.yourScore, 5)
assert.equal(r.json.yourBonus, 12)
assert.equal(r.json.count, 3)
assert.ok(r.json.entries[1].you && !r.json.entries[0].you)

// Scores are clamped to the game's range.
r = await post('f', TODAY, 4, 99, { bonus: 999 })
assert.equal(r.json.yourScore, 5)
assert.equal(r.json.yourBonus, 60)

// 100 of Us: lower wins, ties share a rank.
await post('h', '412', 1, 8)
await post('h', '412', 2, 0)
r = await post('h', '412', 3, 8)
assert.equal(r.json.lowerWins, true)
assert.deepEqual(r.json.entries.map((e) => [e.score, e.rank]), [[0, 1], [8, 2], [8, 2]])
assert.equal(r.json.rank, 2)

// Only today's puzzle accepts scores (date boards and Scroll Recall days).
assert.equal((await post('w', '2026-11-20', 1, 900)).status, 400)
assert.equal((await post('w', '2026-11-29', 1, 900)).status, 200) // ahead in some time zone
assert.equal((await post('r', '3', 1, 4)).status, 400)
assert.equal((await post('r', '11', 1, 4)).status, 200)
assert.equal((await call('GET', { game: 'w', day: '2026-11-20', clientId: id(1) })).status, 200) // reading old days is fine
assert.equal((await post('zz', TODAY, 1, 4)).status, 400)
assert.equal((await call('POST', { game: 'f', day: TODAY, clientId: 'x', score: 3 })).status, 400)

// Blocked names post as Anonymous.
r = await post('m', '90', 7, 88, { name: 'k y s' })
assert.equal(r.json.entries[0].name, 'Anonymous')

// Three reports hide a name from everyone but its owner.
const target = entryId(id(2))
for (const n of [5, 6, 5]) await call('POST', { action: 'report', game: 'f', day: TODAY, clientId: id(n), id: target })
r = await call('GET', { game: 'f', day: TODAY, clientId: id(1) })
assert.equal(r.json.entries.find((e) => e.id === target).name, 'Bo') // only 2 distinct reporters so far
await call('POST', { action: 'report', game: 'f', day: TODAY, clientId: id(8), id: target })
r = await call('GET', { game: 'f', day: TODAY, clientId: id(1) })
assert.equal(r.json.entries.find((e) => e.id === target).name, 'Player')
r = await call('GET', { game: 'f', day: TODAY, clientId: id(2) })
assert.equal(r.json.entries.find((e) => e.id === target).name, 'Bo')

// Admin removal.
assert.equal((await call('POST', { action: 'remove', game: 'f', day: TODAY, id: target })).status, 401)
r = await call('POST', { action: 'remove', game: 'f', day: TODAY, id: target }, { auth: 'Bearer secret-admin' })
assert.equal(r.status, 200)
r = await call('GET', { game: 'f', day: TODAY, clientId: id(1) })
assert.equal(r.json.entries.some((e) => e.id === target), false)

// Legacy web Map of the Day (no game): original keys.
r = await call('POST', { day: TODAY, clientId: id(1), score: 4200, name: 'Ada' })
assert.equal(r.json.game, 'wh')
assert.ok(redis.m.has(`lb:${TODAY}`))

// No Redis: boards stay hidden.
let s, j
await createHandler(null)({ method: 'GET', query: { game: 'f', day: TODAY }, headers: {} }, { status(x) { s = x; return this }, json(x) { j = x; return this } })
assert.equal(s, 200)
assert.equal(j.configured, false)

console.log('leaderboard: all checks passed')
