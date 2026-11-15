// Concept A — "Motherlode": a dig-down mine. Three prompts, 30s each, unlimited
// answers; every valid answer digs by rarity. Score = depth in metres.
import { PROMPTS, scoreGuess, sprite, hash, fit, loop, shuffle, $ } from './kit.js'

const T = 8 // tile px
const W = 128 // logical canvas width (16 tiles)
const SHAFTS = 3
const SECONDS = 30
const DIG = [0, 1, 3, 6, 12] // metres per tier
const TIER = ['', 'COMMON', 'SOLID', 'RARE', 'DEEP CUT!']

const cv = $('#cv')
const g = cv.getContext('2d')

const S = { phase: 'title', depth: 0, target: 0, round: [], ri: 0, time: SECONDS, found: [], used: new Set(), gems: [], parts: [] }

// ---------- sprites ----------
const MINER = sprite(
  ['...yyyy...', '..yyyyly..', '.yyyyyyyy.', '..ssssss..', '..skssks..', '..ssssss..', '.rrbbbbrr.', 'srrbbbbrrs', 's.bbbbbb.s', '..bbbbbb..', '..bb..bb..', '..dd..dd..'],
  { y: '#ffd24a', l: '#fff6c8', s: '#f2c79a', k: '#2a1a12', r: '#c8452f', b: '#3f6fb5', d: '#3a2618' },
)
const PICK = [
  sprite(['.ggg..', 'g..w..', '...w..', '..w...', '..w...', '.w....'], { g: '#c9d2dc', w: '#8a5a3b' }),
  sprite(['......', '......', 'ww...g', '..www.g', '....g.', '...g..'], { g: '#c9d2dc', w: '#8a5a3b' }),
]
const GEM = sprite(['.ccc.', 'cwccc', 'ccccd', '.ccd.', '..d..'], { c: '#5ff0ff', w: '#ffffff', d: '#1e9fc4' })

const STRATA = [
  { to: 15, base: '#8a5a3b', dark: '#74482d', light: '#a06b47', bg: '#3b2418', ore: '#2e2620', oreHi: '#4a3d33', oreP: 0.06 },
  { to: 45, base: '#6b6f7a', dark: '#585c66', light: '#80848f', bg: '#2a2c33', ore: '#e0a93a', oreHi: '#fff0a0', oreP: 0.07 },
  { to: 90, base: '#3e3a5c', dark: '#322f4b', light: '#514c78', bg: '#1a1830', ore: '#5ff0ff', oreHi: '#ffffff', oreP: 0.08 },
  { to: 1e9, base: '#5a2a2a', dark: '#451e1e', light: '#7a3a30', bg: '#210f0f', ore: '#ff8a3c', oreHi: '#ffe08a', oreP: 0.14 },
]
const stratum = (ty) => STRATA.find((s) => ty < s.to)

// ---------- game flow ----------
function start() {
  const eligible = PROMPTS.map((p, i) => i).filter((i) => PROMPTS[i].answers.length >= 12)
  Object.assign(S, { phase: 'play', depth: 0, target: 0, round: shuffle(eligible).slice(0, SHAFTS), ri: 0, found: [], gems: [], parts: [] })
  $('#title').classList.add('hidden')
  $('#over').classList.add('hidden')
  $('#hud').classList.remove('hidden')
  $('#panel').classList.remove('hidden')
  beginShaft()
}

function beginShaft() {
  S.used = new Set()
  S.time = SECONDS
  $('#shaft').textContent = `SHAFT ${S.ri + 1}/${SHAFTS}`
  $('#prompt').textContent = PROMPTS[S.round[S.ri]].q
  $('#log').innerHTML = ''
  $('#msg').textContent = 'Keep naming them — every answer digs!'
  $('#guess').value = ''
  $('#guess').focus()
  drawHud()
  if (S.ri > 0) toast(`SHAFT ${S.ri + 1}`, 'New prompt!', 2)
}

setInterval(() => {
  if (S.phase !== 'play') return
  S.time -= 1
  drawHud()
  if (S.time <= 0) {
    S.ri += 1
    if (S.ri >= SHAFTS) finish()
    else beginShaft()
  }
}, 1000)

function drawHud() {
  $('#depth').textContent = Math.round(S.target)
  $('#gems').textContent = S.gems.length
  $('#timefill').style.width = `${(Math.max(0, S.time) / SECONDS) * 100}%`
  $('#timebar').classList.toggle('low', S.time <= 8)
}

function toast(big, small, tier) {
  const el = $('#toast')
  el.className = ''
  el.innerHTML = `<span class="big t${tier}">${big}</span><span class="sm t${tier}">${small}</span>`
  void el.offsetWidth
  el.className = 'on'
}

$('#form').addEventListener('submit', (e) => {
  e.preventDefault()
  if (S.phase !== 'play') return
  const input = $('#guess')
  const text = input.value.trim()
  if (!text) return
  const pi = S.round[S.ri]
  const { answer } = scoreGuess(pi, text)
  input.value = ''
  if (!answer) return reject('Not on the list — try another')
  if (S.used.has(answer.display)) return reject(`Already dug ${answer.display}`)
  S.used.add(answer.display)
  const m = DIG[answer.tier]
  if (answer.tier === 4) S.gems.push({ row: Math.floor(S.target + m / 2), side: S.gems.length % 2 ? 1 : -1 })
  S.target += m
  S.found.push({ pi, answer: answer.display, tier: answer.tier, m })
  toast(`+${m}m`, `${TIER[answer.tier]} · ${answer.display}`, answer.tier)
  $('#msg').textContent = ''
  const chip = document.createElement('span')
  chip.className = `chip t${answer.tier}`
  chip.textContent = `${answer.display} +${m}`
  $('#log').prepend(chip)
  navigator.vibrate?.(answer.tier === 4 ? [60, 40, 120] : 30 + answer.tier * 15)
  drawHud()
})

function reject(text) {
  $('#msg').textContent = text
  const f = $('#form')
  f.classList.remove('shake')
  void f.offsetWidth
  f.classList.add('shake')
}

function finish() {
  S.phase = 'over'
  $('#panel').classList.add('hidden')
  $('#hud').classList.add('hidden')
  const d = Math.round(S.target)
  const rank = d < 20 ? 'Topsoil Tourist' : d < 50 ? 'Rock Hound' : d < 90 ? 'Deep Driller' : 'Core Legend'
  const rows = S.round
    .map((pi) => {
      const mine = S.found.filter((f) => f.pi === pi)
      const had = new Set(mine.map((f) => f.answer))
      const missed = PROMPTS[pi].answers.filter((a) => a.tier === 4 && !had.has(a.display)).slice(0, 3).map((a) => a.display)
      return `<div><h3>${PROMPTS[pi].q}</h3><div class="row">${
        mine.map((f) => `<span class="chip t${f.tier}">${f.answer} +${f.m}</span>`).join('') || '<span class="missed">Nothing dug</span>'
      }</div>${missed.length ? `<div class="missed">Still buried: ${missed.join(', ')}</div>` : ''}</div>`
    })
    .join('')
  const el = $('#over')
  el.innerHTML = `<p>You reached</p><div class="result-depth">${d}m</div><p class="t4">${rank} · ${S.gems.length} 💎 · ${S.found.length} answers</p>
    <div class="recap">${rows}</div>
    <button class="btn" id="again">DIG AGAIN</button><a class="back" href="./">← all concepts</a>`
  el.classList.remove('hidden')
  $('#again').addEventListener('click', start)
}

$('#start').addEventListener('click', start)

// ---------- rendering ----------
function tile(tx, ty, sx, sy) {
  const st = stratum(ty)
  g.fillStyle = st.base
  g.fillRect(sx, sy, T, T)
  for (let i = 0; i < 3; i++) {
    const h = hash(tx, ty, i)
    g.fillStyle = h < 0.5 ? st.dark : st.light
    g.fillRect(sx + Math.floor(hash(tx, ty, i + 10) * 7), sy + Math.floor(hash(tx, ty, i + 20) * 7), h < 0.3 ? 2 : 1, 1)
  }
  if (hash(tx, ty, 99) < st.oreP) {
    g.fillStyle = st.ore
    g.fillRect(sx + 2, sy + 3, 2, 2)
    g.fillRect(sx + 4, sy + 2, 2, 2)
    g.fillStyle = st.oreHi
    g.fillRect(sx + 4, sy + 2, 1, 1)
  }
  if (ty === 0) {
    g.fillStyle = '#5fae4a'
    g.fillRect(sx, sy, T, 2)
    g.fillStyle = '#7fd05f'
    g.fillRect(sx + Math.floor(hash(tx, 0, 5) * 6), sy, 2, 1)
  }
}

function sky(H, cam, t) {
  const groundY = -cam
  const bands = ['#cdeeff', '#a5dcff', '#7cc6f7', '#5aaeea', '#4696d8']
  for (let sy = 0; sy < Math.min(H, groundY); sy++) {
    const up = groundY - sy
    g.fillStyle = bands[Math.min(bands.length - 1, Math.floor(up / 22))]
    g.fillRect(0, sy, W, 1)
  }
  // sun
  g.fillStyle = '#fff3b0'
  for (let y = -6; y <= 6; y++) {
    const w = Math.floor(Math.sqrt(36 - y * y))
    g.fillRect(100 - w, groundY - 62 + y, w * 2 + 1, 1)
  }
  // clouds
  g.fillStyle = '#ffffff'
  ;[[20, 70, 0.8], [70, 48, 0.5], [110, 84, 1.1]].forEach(([x, up, sp]) => {
    const cx = ((x + t * sp * 2) % (W + 30)) - 15
    g.fillRect(cx, groundY - up, 16, 4)
    g.fillRect(cx + 3, groundY - up - 3, 9, 3)
  })
  // far hills
  for (let x = 0; x < W; x++) {
    const h = Math.round(12 + 7 * Math.sin(x * 0.07) + 4 * Math.sin(x * 0.19 + 1))
    g.fillStyle = '#7fb0cf'
    g.fillRect(x, groundY - h, 1, h)
  }
  // shack
  const gx = 10
  g.fillStyle = '#a5673f'
  g.fillRect(gx, groundY - 14, 24, 14)
  g.fillStyle = '#7a2f25'
  for (let i = 0; i < 6; i++) g.fillRect(gx - 2 + i * 2, groundY - 15 - i, 28 - i * 4, 1)
  g.fillRect(gx - 3, groundY - 14, 30, 1)
  g.fillStyle = '#2a1a12'
  g.fillRect(gx + 4, groundY - 9, 6, 9)
  g.fillStyle = '#ffd24a'
  g.fillRect(gx + 15, groundY - 10, 5, 4)
  // tree
  g.fillStyle = '#74482d'
  g.fillRect(104, groundY - 12, 3, 12)
  g.fillStyle = '#3f8f3f'
  g.fillRect(98, groundY - 24, 15, 13)
  g.fillStyle = '#5fae4a'
  g.fillRect(100, groundY - 26, 11, 8)
  // winch frame over the shaft
  g.fillStyle = '#74482d'
  g.fillRect(52, groundY - 22, 2, 22)
  g.fillRect(74, groundY - 22, 2, 22)
  g.fillRect(50, groundY - 23, 28, 2)
  g.fillStyle = '#c9d2dc'
  g.fillRect(62, groundY - 21, 4, 3)
}

loop((dt, t) => {
  const H = fit(cv, W)
  g.imageSmoothingEnabled = false
  const digging = S.target - S.depth > 0.02
  if (digging) S.depth += Math.min(S.target - S.depth, dt * Math.max(6, (S.target - S.depth) * 4))
  const dpx = S.depth * T
  const cam = Math.round(dpx - H * (S.phase === 'title' ? 0.34 : 0.5))

  g.fillStyle = '#000'
  g.fillRect(0, 0, W, H)
  sky(H, cam, t)

  // earth
  const ty0 = Math.max(0, Math.floor(cam / T))
  const ty1 = Math.floor((cam + H) / T)
  for (let ty = ty0; ty <= ty1; ty++) for (let tx = 0; tx < 16; tx++) tile(tx, ty, tx * T, ty * T - cam)

  // dug shaft (x 56..72)
  for (let ty = ty0; ty <= Math.min(ty1, Math.ceil(S.depth)); ty++) {
    const top = ty * T
    const h = Math.min(T, dpx - top)
    if (h <= 0) continue
    g.fillStyle = stratum(ty).bg
    g.fillRect(56, top - cam, 16, h)
    g.fillStyle = '#6b4a2f' // ladder
    g.fillRect(67, top - cam, 1, h)
    g.fillRect(70, top - cam, 1, h)
    if (h > 3) g.fillRect(67, top - cam + 3, 4, 1)
    if (ty % 9 === 4 && h === T) {
      g.fillStyle = '#ffd24a55'
      g.fillRect(56, top - cam + 1, 5, 5)
      g.fillStyle = '#ffd24a'
      g.fillRect(57, top - cam + 2, 2, 3)
    }
  }
  // rope from the winch
  g.fillStyle = '#d9c9a3'
  g.fillRect(64, -21 - cam, 1, Math.max(0, dpx + 21 - 11))

  // gems set into the shaft wall
  S.gems.forEach((gm, i) => {
    if (gm.row > S.depth) return
    const x = gm.side < 0 ? 49 : 74
    const y = gm.row * T - cam + 1
    g.drawImage(GEM, x, y)
    if (Math.floor(t * 4 + i) % 3 === 0) {
      g.fillStyle = '#fff'
      g.fillRect(x + 5, y - 1, 1, 1)
      g.fillRect(x - 1, y + 3, 1, 1)
    }
  })

  // torch-light falloff underground
  if (S.depth > 4) {
    const k = Math.min(1, (S.depth - 4) / 14)
    for (let ty = ty0; ty <= ty1; ty++)
      for (let tx = 0; tx < 16; tx++) {
        const dx = tx * T + 4 - 64
        const dy = ty * T + 4 - (dpx - 6)
        const a = Math.min(0.72, Math.max(0, (Math.hypot(dx, dy * 0.8) - 26) / 70)) * k
        if (a > 0.03) {
          g.fillStyle = `rgba(8,5,14,${a.toFixed(2)})`
          g.fillRect(tx * T, ty * T - cam, T, T)
        }
      }
  }

  // miner
  const my = Math.round(dpx - cam) - 12
  g.drawImage(MINER, 59, my)
  g.drawImage(PICK[digging ? Math.floor(t * 12) % 2 : 0], 68, my + (digging ? 4 : 1))

  // dig particles
  if (digging) {
    const st = stratum(Math.floor(S.depth))
    for (let i = 0; i < 2; i++)
      S.parts.push({ x: 58 + Math.random() * 12, y: dpx, vx: (Math.random() - 0.5) * 40, vy: -20 - Math.random() * 40, life: 0.5, c: Math.random() < 0.3 ? st.ore : st.light })
  }
  S.parts = S.parts.filter((p) => (p.life -= dt) > 0)
  S.parts.forEach((p) => {
    p.x += p.vx * dt
    p.y += p.vy * dt
    p.vy += 160 * dt
    g.fillStyle = p.c
    g.fillRect(Math.round(p.x), Math.round(p.y - cam), 1, 1)
  })
})
