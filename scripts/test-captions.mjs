// Checks for api/captions.js against an in-memory Redis stand-in. Run: node scripts/test-captions.mjs
import { createHandler, isBlocked, serverDay, tidy } from '../api/captions.js'
import assert from 'node:assert/strict'
import { MEMES, memeFor } from '../api/_memes.js'

// Minimal in-memory stand-in for the Upstash client methods the API uses.
class FakeRedis {
  m = new Map()
  h(k) { if (!this.m.has(k)) this.m.set(k, new Map()); return this.m.get(k) }
  s(k) { if (!this.m.has(k)) this.m.set(k, new Set()); return this.m.get(k) }
  async incr(k) { const v = (this.m.get(k) || 0) + 1; this.m.set(k, v); return v }
  async expire() { return 1 }
  async hget(k, f) { return this.m.get(k)?.get?.(f) ?? null }
  async hset(k, obj) { for (const [f, v] of Object.entries(obj)) this.h(k).set(f, v); return 1 }
  async hsetnx(k, f, v) { const h = this.h(k); if (h.has(f)) return 0; h.set(f, v); return 1 }
  async hdel(k, f) { return this.h(k).delete(f) ? 1 : 0 }
  async hgetall(k) { const h = this.m.get(k); return h && h.size ? Object.fromEntries(h) : null }
  async hincrby(k, f, n) { const h = this.h(k); const v = Number(h.get(f) || 0) + n; h.set(f, v); return v }
  async sadd(k, v) { this.s(k).add(v); return 1 }
  async srem(k, v) { return this.s(k).delete(v) ? 1 : 0 }
  async sismember(k, v) { return this.m.get(k)?.has?.(v) ? 1 : 0 }
  async smembers(k) { return [...(this.m.get(k) || [])] }
}

const NOW = Date.UTC(2026, 10, 26, 18) // day 9
const redis = new FakeRedis()
const handler = createHandler(redis, { adminToken: 'secret-admin', now: () => NOW })
const DAY = serverDay(NOW)
assert.equal(DAY, 9)

let ipN = 0
async function call(method, data, { ip, auth } = {}) {
  let status, json
  const res = { status(s) { status = s; return this }, json(j) { json = j; return this } }
  const req = method === 'GET'
    ? { method, query: data, headers: { 'x-forwarded-for': ip || '1.1.1.1', authorization: auth } }
    : { method, body: data, query: {}, headers: { 'x-forwarded-for': ip || `10.0.0.${++ipN}`, authorization: auth } }
  await handler(req, res)
  return { status, json }
}
const A = 'aaaaaaaa-1111', B = 'bbbbbbbb-2222', C = 'cccccccc-3333'
const submit = (clientId, text, name, opts) => call('POST', { action: 'submit', day: DAY, clientId, text, name }, opts)

// Not configured: still says which meme is today's
const nc = await (async () => { let j; await createHandler(null)({ method: 'GET', query: { day: '1' } }, { status() { return this }, json(x) { j = x } }); return j })()
assert.equal(nc.configured, false); assert.equal(nc.meme.name, 'Disaster Girl')

// Before submitting you only see a count
let r = await call('GET', { day: DAY, clientId: A })
assert.equal(r.json.submitted, false); assert.equal(r.json.count, 0)
assert.match(r.json.meme.url, /^https:\/\/i\.imgflip\.com\//); assert.equal(r.json.meme.name, memeFor(DAY).name)
assert.equal(memeFor(1).name, memeFor(1 + MEMES.length).name, 'rotation loops')

r = await submit(A, '  When the   meeting\nruns long  ', '')
assert.equal(r.status, 200); assert.equal(r.json.submitted, true)
assert.equal(r.json.captions[0].text, 'When the meeting runs long')
assert.equal(r.json.captions[0].name, null, 'blank name is anonymous')
const aId = r.json.mine

r = await call('GET', { day: DAY, clientId: B })
assert.equal(r.json.submitted, false); assert.equal(r.json.count, 1); assert.equal(r.json.captions, undefined, 'no peeking')

// One caption a day
assert.equal((await submit(A, 'second try')).status, 409)
// Length limits
r = await submit(B, 'x'.repeat(200), 'N'.repeat(50))
assert.equal(r.status, 200)
const bCap = r.json.captions.find((c) => c.mine)
assert.equal(bCap.text.length, 80); assert.equal(bCap.name.length, 20)
const bId = r.json.mine
// Empty and blocked
assert.equal((await submit(C, '   ')).status, 400)
assert.equal((await submit(C, 'k y s')).status, 422)
assert.equal(isBlocked('what the FUUUCK'), false, 'swearing is allowed')
assert.equal(isBlocked('sh1t happens'), false)
assert.equal(isBlocked('n4z1 stuff'), true)
assert.equal(isBlocked('p 0 r n'), true)
assert.equal(isBlocked('a classic assignment'), false)
assert.equal(isBlocked('Scunthorpe is lovely'), false)
// Closed day
assert.equal((await call('POST', { action: 'submit', day: DAY - 3, clientId: C, text: 'late' })).status, 400)

r = await submit(C, 'Monday again', 'Cee')
const cId = r.json.mine

// Voting rules
assert.equal((await call('POST', { action: 'vote', day: DAY, clientId: A, id: aId })).status, 400, 'not your own')
r = await call('POST', { action: 'vote', day: DAY, clientId: A, id: cId })
assert.equal(r.status, 200); assert.equal(r.json.votedFor, cId)
assert.equal(r.json.captions[0].id, cId); assert.equal(r.json.captions[0].votes, 1)
assert.equal((await call('POST', { action: 'vote', day: DAY, clientId: A, id: bId })).status, 409, 'one vote a day')
assert.equal((await call('POST', { action: 'vote', day: DAY, clientId: 'dddddddd-4444', id: cId })).status, 403, 'submit first')

// Reports: 3 distinct reporters hide it; a repeat report from one device doesn't count
for (const who of [A, A, C]) await call('POST', { action: 'report', day: DAY, clientId: who, id: bId })
r = await call('GET', { day: DAY, clientId: A })
assert.ok(r.json.captions.some((c) => c.id === bId), 'still visible after 2 distinct reports')
await submit('eeeeeeee-5555', 'Me too', '')
await call('POST', { action: 'report', day: DAY, clientId: 'eeeeeeee-5555', id: bId })
r = await call('GET', { day: DAY, clientId: A })
assert.ok(!r.json.captions.some((c) => c.id === bId), 'hidden after 3 reports')
r = await call('GET', { day: DAY, clientId: B })
assert.ok(r.json.captions.some((c) => c.id === bId && c.mine), 'author still sees their own')
assert.equal((await call('POST', { action: 'vote', day: DAY, clientId: C, id: bId })).status, 404, "can't vote for hidden")

// Admin
assert.equal((await call('GET', { day: DAY, admin: '1' })).status, 401)
assert.equal((await call('POST', { action: 'delete', day: DAY, id: cId }, { auth: 'Bearer wrong' })).status, 401)
r = await call('GET', { day: DAY, admin: '1' }, { auth: 'Bearer secret-admin' })
assert.equal(r.status, 200); assert.equal(r.json.captions[0].id, bId); assert.equal(r.json.captions[0].reports, 3); assert.equal(r.json.captions[0].hidden, true)
assert.equal((await call('POST', { action: 'unhide', day: DAY, id: bId }, { auth: 'Bearer secret-admin' })).status, 200)
assert.ok((await call('GET', { day: DAY, clientId: A })).json.captions.some((c) => c.id === bId), 'unhidden')
assert.equal((await call('POST', { action: 'delete', day: DAY, id: cId }, { auth: 'Bearer secret-admin' })).status, 200)
assert.ok(!(await call('GET', { day: DAY, clientId: A })).json.captions.some((c) => c.id === cId), 'deleted')

// Rate limit: 11th write in a minute from one device
let last
for (let i = 0; i < 11; i++) last = await call('POST', { action: 'report', day: DAY, clientId: 'ffffffff-6666', id: aId })
assert.equal(last.status, 429)
// Per-IP limit across devices
for (let i = 0; i < 31; i++) last = await call('POST', { action: 'report', day: DAY, clientId: `gggggggg-${1000 + i}`, id: aId }, { ip: '9.9.9.9' })
assert.equal(last.status, 429)

assert.equal(tidy('a\u0000b​c', 80), 'a b c')
assert.equal((await call('GET', { day: DAY, clientId: 'bad id!' })).status, 400)
console.log('all caption API checks passed')
