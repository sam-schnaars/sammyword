// Concept B — "Liftoff": a rocket climb. Five prompts, one answer each; rarer
// answers boost higher. Wrong guesses/timeouts burn one of three fuel cells, and
// chaining rare answers builds a slingshot multiplier.
import { PROMPTS, TIER_POINTS, scoreGuess, sprite, hash, fit, loop, disc, shuffle, sleep, $ } from './kit.js'

const W = 128
const STAGES = 5
const SECONDS = 20
const PX_PER_KM = 0.6
const TIER = ['', 'COMMON', 'SOLID', 'RARE', 'DEEP CUT!']

const cv = $('#cv')
const g = cv.getContext('2d')
const S = { phase: 'title', alt: 0, target: 0, km: 0, fuel: 3, streak: 0, round: [], ri: 0, time: SECONDS, log: [], parts: [], busy: false }

const ROCKET = sprite(
  ['.....w.....', '....www....', '...wwwww...', '...wrrrw...', '..wwwwwww..', '..wwbbbww..', '..wbbcbbw..', '..wwbbbww..', '..wwwwwww..', '..wrrrrrw..', '..wwwwwww..', '.rwwwwwwwr.', 'rrwwwwwwwrr', 'rrwgggggwrr', 'r..ggggg..r'],
  { w: '#eef0ff', r: '#ff6ad5', b: '#2b5fb8', c: '#5ff0ff', g: '#8a8fb5' },
)

const mult = () => 1 + 0.5 * Math.min(3, S.streak)
const zone = (km) => (km < 1 ? 'LAUNCH PAD' : km < 300 ? 'TROPOSPHERE' : km < 1000 ? 'STRATOSPHERE' : km < 2500 ? 'LOW ORBIT' : km < 5000 ? 'LUNAR SPACE' : 'DEEP SPACE')

function start() {
  Object.assign(S, { phase: 'play', alt: 0, target: 0, km: 0, fuel: 3, streak: 0, round: shuffle(PROMPTS.map((_, i) => i)).slice(0, STAGES), ri: 0, log: [], parts: [], busy: false })
  $('#title').classList.add('hidden')
  $('#over').classList.add('hidden')
  $('#hud').classList.remove('hidden')
  $('#panel').classList.remove('hidden')
  beginStage()
}

function beginStage() {
  S.time = SECONDS
  S.busy = false
  $('#stage').textContent = `STAGE ${S.ri + 1}/${STAGES}`
  $('#prompt').textContent = PROMPTS[S.round[S.ri]].q
  $('#msg').textContent = ''
  $('#guess').value = ''
  $('#guess').disabled = false
  $('#guess').focus()
  hud()
}

function hud() {
  $('#alt').textContent = Math.round(S.km).toLocaleString()
  $('#zone').textContent = zone(S.km)
  $('#cells').innerHTML = [0, 1, 2].map((i) => `<i class="${i < S.fuel ? '' : 'off'}"></i>`).join('')
  $('#mult').textContent = S.streak ? `SLINGSHOT ×${mult()}` : ''
  $('#secs').textContent = Math.max(0, S.time)
  $('#timefill').style.width = `${(Math.max(0, S.time) / SECONDS) * 100}%`
  $('#timebar').classList.toggle('low', S.time <= 5)
}

function toast(big, small, tier) {
  const el = $('#toast')
  el.className = ''
  el.innerHTML = `<span class="big t${tier}">${big}</span><span class="sm t${tier}">${small}</span>`
  void el.offsetWidth
  el.className = 'on'
}

function burn(reason) {
  S.fuel -= 1
  S.streak = 0
  const sc = $('#scene')
  sc.classList.remove('shake')
  void sc.offsetWidth
  sc.classList.add('shake')
  navigator.vibrate?.([80, 40, 80])
  toast('FUEL CELL LOST', reason, 0)
  hud()
  return S.fuel <= 0
}

async function next() {
  S.busy = true
  $('#guess').disabled = true
  await sleep(1400)
  if (S.phase !== 'play') return
  S.ri += 1
  if (S.ri >= STAGES) finish('done')
  else beginStage()
}

setInterval(() => {
  if (S.phase !== 'play' || S.busy) return
  S.time -= 1
  hud()
  if (S.time <= 0) {
    S.log.push({ pi: S.round[S.ri], answer: '', tier: 0, km: 0 })
    if (burn('Out of time')) return finish('fuel')
    next()
  }
}, 1000)

$('#form').addEventListener('submit', (e) => {
  e.preventDefault()
  if (S.phase !== 'play' || S.busy) return
  const input = $('#guess')
  const text = input.value.trim()
  if (!text) return
  input.value = ''
  const pi = S.round[S.ri]
  const { answer } = scoreGuess(pi, text)
  if (!answer) {
    $('#msg').textContent = `"${text}" isn't on the list`
    if (burn('Wrong answer')) {
      S.log.push({ pi, answer: '', tier: 0, km: 0 })
      finish('fuel')
    }
    return
  }
  const m = mult()
  const km = Math.round(TIER_POINTS[answer.tier - 1] * m)
  S.km += km
  S.target = S.km * PX_PER_KM
  S.streak = answer.tier >= 3 ? S.streak + 1 : 0
  S.log.push({ pi, answer: answer.display, tier: answer.tier, km })
  toast(`+${km.toLocaleString()} KM`, `${TIER[answer.tier]}${m > 1 ? ` ×${m}` : ''} · ${answer.display}`, answer.tier)
  navigator.vibrate?.(answer.tier === 4 ? [60, 40, 120] : 30 + answer.tier * 15)
  hud()
  next()
})

function finish(why) {
  S.phase = 'over'
  $('#panel').classList.add('hidden')
  $('#hud').classList.add('hidden')
  const km = Math.round(S.km)
  const rank = km < 1000 ? 'Cloud Hopper' : km < 2500 ? 'Orbit Achiever' : km < 5000 ? 'Moonwalker' : 'Deep Space Legend'
  const rows = S.round
    .map((pi, i) => {
      const r = S.log[i]
      const best = PROMPTS[pi].answers.filter((a) => a.tier === 4).slice(0, 2).map((a) => a.display).join(', ')
      return `<div><small>${PROMPTS[pi].q}</small>${
        r ? `<b class="t${r.tier}">${r.answer || '— no answer'}</b><span class="t${r.tier}">+${r.km.toLocaleString()}</span>` : '<b class="t0">— not reached</b>'
      }${best ? `<small style="margin-top:3px">Deep cuts: ${best}</small>` : ''}</div>`
    })
    .join('')
  const el = $('#over')
  el.innerHTML = `<p class="${why === 'fuel' ? 't0' : 't2'}">${why === 'fuel' ? 'OUT OF FUEL' : 'MISSION COMPLETE'}</p>
    <div class="big-alt">${km.toLocaleString()} KM</div><p class="t4">${rank} · ${zone(km)}</p>
    <div class="recap">${rows}</div>
    <button class="btn" id="again">RELAUNCH</button><a class="back" href="./">← all concepts</a>`
  el.classList.remove('hidden')
  $('#again').addEventListener('click', start)
}

$('#start').addEventListener('click', start)

// ---------- rendering ----------
const SKY = [[0, '#8fd8ff'], [60, '#6fc3ff'], [130, '#4a9fe8'], [220, '#2f72c9'], [330, '#1f4a9c'], [460, '#1b2f78'], [620, '#15185a'], [820, '#0e0b3a'], [1100, '#07051c']]
// Stepped gradient: blend between stops, then quantize into 24px-tall bands.
const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16))
const skyAt = (wy) => {
  const y = Math.max(0, Math.floor(wy / 24) * 24)
  let i = 0
  while (i < SKY.length - 2 && y >= SKY[i + 1][0]) i++
  const [y0, c0] = SKY[i]
  const [y1, c1] = SKY[i + 1]
  const k = Math.max(0, Math.min(1, (y - y0) / (y1 - y0)))
  const a = rgb(c0)
  const b = rgb(c1)
  return `rgb(${a.map((v, j) => Math.round(v + (b[j] - v) * k)).join(',')})`
}
// Things you fly past: [altitude km, x, kind]
const BODIES = [[900, 30, 'moon'], [2300, 96, 'ring'], [3800, 34, 'giant'], [5600, 90, 'galaxy'], [7600, 40, 'ring']]

function body(kind, x, y, t) {
  if (kind === 'moon') {
    disc(g, x, y, 11, '#d9dcef')
    disc(g, x - 4, y - 3, 2, '#aab0cf')
    disc(g, x + 4, y + 4, 3, '#aab0cf')
    disc(g, x + 5, y - 5, 1, '#aab0cf')
  } else if (kind === 'ring') {
    disc(g, x, y, 9, '#ffb86a')
    g.fillStyle = '#e8904a'
    g.fillRect(x - 8, y + 2, 17, 2)
    g.fillStyle = '#fff0c0'
    g.fillRect(x - 16, y - 1, 33, 1)
    g.fillRect(x - 14, y, 29, 1)
    disc(g, x, y - 3, 6, '#ffb86a')
  } else if (kind === 'giant') {
    disc(g, x, y, 15, '#ff6ad5')
    g.fillStyle = '#c93fa8'
    g.fillRect(x - 14, y - 4, 29, 3)
    g.fillRect(x - 13, y + 5, 27, 2)
    g.fillStyle = '#ffa6ea'
    g.fillRect(x - 10, y - 10, 12, 2)
  } else {
    for (let i = 0; i < 70; i++) {
      const a = i * 0.45 + t * 0.2
      const r = 2 + i * 0.28
      g.fillStyle = i % 3 ? '#5ff0ff' : '#ffffff'
      g.fillRect(Math.round(x + Math.cos(a) * r), Math.round(y + Math.sin(a) * r * 0.55), 1, 1)
    }
    disc(g, x, y, 2, '#fff6c8')
  }
}

loop((dt, t) => {
  const H = fit(cv, W)
  g.imageSmoothingEnabled = false
  const boosting = S.target - S.alt > 1.5
  S.alt += (S.target - S.alt) * Math.min(1, dt * 2.2)
  const ry = Math.round(H * (S.phase === 'title' ? 0.36 : 0.6))
  const wyAt = (sy) => S.alt + (ry - sy) // world height (px above ground) at a screen row

  // sky bands
  for (let sy = 0; sy < H; sy += 2) {
    g.fillStyle = skyAt(wyAt(sy))
    g.fillRect(0, sy, W, 2)
  }

  // stars (parallax layer), fading in with altitude
  const vis = Math.max(0, Math.min(1, (S.alt - 260) / 320))
  if (vis > 0) {
    const lay = S.alt * 0.35
    for (let cy = Math.floor(lay / 12) - 1; cy <= Math.floor((lay + H) / 12) + 1; cy++)
      for (let cx = 0; cx < 11; cx++) {
        const h = hash(cx, cy, 7)
        if (h > 0.4) continue
        const x = Math.floor(cx * 12 + hash(cx, cy, 8) * 12)
        const sy = Math.round(H - (cy * 12 + hash(cx, cy, 9) * 12 - lay))
        const tw = Math.sin(t * 2 + h * 40) > 0.6
        g.fillStyle = h < 0.05 ? '#ff6ad5' : h < 0.12 ? '#5ff0ff' : '#ffffff'
        g.globalAlpha = vis * (tw ? 1 : 0.55)
        g.fillRect(x, sy, 1, 1)
        if (h < 0.03) g.fillRect(x - 1, sy, 3, 1), g.fillRect(x, sy - 1, 1, 3)
      }
    g.globalAlpha = 1
  }

  // planets & friends
  BODIES.forEach(([km, x, kind]) => {
    const sy = ry - (km * PX_PER_KM - S.alt)
    if (sy > -40 && sy < H + 40) body(kind, x, Math.round(sy), t)
  })

  // clouds
  const cloudVis = Math.max(0, 1 - Math.max(0, S.alt - 300) / 200)
  if (cloudVis > 0) {
    g.globalAlpha = cloudVis
    g.fillStyle = '#ffffff'
    for (let i = 0; i < 14; i++) {
      const wy = 46 + i * 30
      const sy = Math.round(ry - (wy - S.alt))
      if (sy < -10 || sy > H + 10) continue
      const cx = Math.round(((hash(i, 1) * 170 + t * 3 * (i % 2 ? 1 : -1)) % 170 + 170) % 170) - 22
      g.fillRect(cx, sy, 20, 4)
      g.fillRect(cx + 4, sy - 3, 11, 3)
      g.fillRect(cx + 9, sy - 5, 5, 2)
    }
    g.globalAlpha = 1
  }

  // ground + launch tower
  const gy = Math.round(ry + S.alt)
  if (gy < H + 40) {
    for (let x = 0; x < W; x++) {
      const h = Math.round(9 + 5 * Math.sin(x * 0.08 + 2) + 3 * Math.sin(x * 0.21))
      g.fillStyle = '#3f7fb5'
      g.fillRect(x, gy - h, 1, h)
    }
    g.fillStyle = '#3d8f4a'
    g.fillRect(0, gy, W, H)
    g.fillStyle = '#5fbf5a'
    g.fillRect(0, gy, W, 2)
    g.fillStyle = '#6a6f8a'
    g.fillRect(48, gy - 2, 32, 4)
    g.fillStyle = '#8a8fb5'
    g.fillRect(40, gy - 34, 3, 34)
    g.fillRect(46, gy - 34, 3, 34)
    for (let y = 4; y < 34; y += 6) g.fillRect(40, gy - y, 9, 1)
    g.fillStyle = '#ff5c5c'
    g.fillRect(43, gy - 37, 3, 3)
  }

  // exhaust particles
  if (boosting || S.alt < 2)
    for (let i = 0; i < (boosting ? 3 : 0); i++)
      S.parts.push({ x: 61 + Math.random() * 6, y: 0, vx: (Math.random() - 0.5) * 14, vy: 50 + Math.random() * 50, life: 0.6, c: Math.random() < 0.5 ? '#ffe45e' : '#ff8a3c' })
  S.parts = S.parts.filter((p) => (p.life -= dt) > 0)
  S.parts.forEach((p) => {
    p.x += p.vx * dt
    p.y += p.vy * dt
    g.fillStyle = p.life < 0.25 ? '#8a8fb5' : p.c
    g.fillRect(Math.round(p.x), Math.round(ry + p.y), 1 + (p.life > 0.4), 1 + (p.life > 0.4))
  })

  // rocket
  const bob = boosting || S.alt < 2 ? 0 : Math.round(Math.sin(t * 2) * 1.5)
  const rx = 59
  const top = ry - 15 + bob
  g.drawImage(ROCKET, rx, top)
  const fl = boosting ? 6 + Math.floor(Math.random() * 5) : S.alt < 2 ? 0 : 2 + (Math.floor(t * 10) % 2)
  for (let i = 0; i < fl; i++) {
    const w = Math.max(1, 5 - Math.floor((i * 5) / Math.max(1, fl)))
    g.fillStyle = i < fl / 3 ? '#fff6c8' : i < (fl * 2) / 3 ? '#ffe45e' : '#ff8a3c'
    g.fillRect(rx + 5 - Math.floor(w / 2), top + 15 + i, w, 1)
  }
})
