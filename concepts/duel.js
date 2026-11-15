// Concept C — "Quill Duel": a turn-based trivia battle in a strict four-color
// palette. Both sides answer the same prompt; rarity = damage; matching answers
// clash. The rival here is a CPU; in a real challenge it would replay a friend's
// recorded answers.
import { PROMPTS, scoreGuess, sprite, flipped, loop, disc, shuffle, sleep, $ } from './kit.js'

const C = { cream: '#f2e9d0', amber: '#d9a441', plum: '#7a3b5e', ink: '#2a1a2e' }
const ROUNDS = 5
const SECONDS = 20
const MAX_HP = 12
const DMG = [0, 1, 2, 4, 7]
const TIER = ['', 'Common', 'Solid', 'Rare', 'DEEP CUT']

const PAL = { o: C.ink, b: C.plum, c: C.cream, a: C.amber }
const OWL = sprite(
  ['..oo......oo..', '.obbo....obbo.', '.obbboooobbbo.', 'obbbbbbbbbbbbo', 'obccccbbccccbo', 'occooccccoocco', 'occooccccoocco', 'obccccaaccccbo', 'obbbbbaabbbbbo', 'obbbccccccbbbo', 'obbccccccccbbo', 'obbccccccccbbo', 'obbccccccccbbo', '.obbccccccbbo.', '..oobbbbbboo..', '...oaao.oaao..'],
  PAL,
)
const FOX = sprite(
  ['.o........o.....', 'oao......oao....', 'oaao....oaao....', 'oaaaooooaaao....', 'oaaaaaaaaaao....', 'oaccaaaaccao....', 'oacoaaaaocao....', '.oaaccccaao.....', '.oacccoccao.....', '..occcccco...oo.', '.oaaccccaao.oaao', '.oaaaccaaaooaaco', '.oaaaaaaaaoaacco', '.oaaaaaaaaoaao..', '.oaaoooaaaooo...', '.ooo...ooo......'],
  PAL,
)
const FOX_L = flipped(FOX)
const BOOK = sprite(['oooooo', 'obbbbo', 'obccbo', 'obbbbo', 'oooooo'], PAL)

const cv = $('#cv')
const g = cv.getContext('2d')
const W = 160
const H = 92
const A = { pHit: 0, rHit: 0, pDown: 0, rDown: 0, proj: null, pHop: 0, rHop: 0 }
const S = { phase: 'title', php: MAX_HP, rhp: MAX_HP, round: [], log: [], waiting: null, time: 0 }

// ---------- helpers ----------
async function say(html, hold = 900) {
  const el = $('#dialog')
  const text = html.replace(/<[^>]+>/g, '')
  for (let i = 1; i <= text.length; i += 2) {
    el.textContent = text.slice(0, i)
    await sleep(18)
  }
  el.innerHTML = html
  await sleep(hold)
}

function bars() {
  for (const [id, hp] of [['p', S.php], ['r', S.rhp]]) {
    $(`#${id}hp`).textContent = Math.max(0, hp)
    $(`#${id}hpbar i`).style.width = `${(Math.max(0, hp) / MAX_HP) * 100}%`
    $(`#${id}hpbar`).classList.toggle('low', hp <= 4)
  }
}

function rivalPick(pi) {
  const r = Math.random()
  const tier = r < 0.42 ? 1 : r < 0.74 ? 2 : r < 0.93 ? 3 : 4
  const all = PROMPTS[pi].answers
  const pool = all.filter((a) => a.tier === tier)
  const from = pool.length ? pool : all
  return from[Math.floor(Math.random() * from.length)]
}

async function throwBook(fromPlayer) {
  if (fromPlayer) A.pHop = 0.25
  else A.rHop = 0.25
  A.proj = { t: 0, fromPlayer }
  await sleep(480)
  A.proj = null
  if (fromPlayer) A.rHit = 0.5
  else A.pHit = 0.5
  navigator.vibrate?.(50)
  await sleep(350)
}

// Wait for the player's answer (or a timeout → null).
function ask(pi) {
  return new Promise((resolve) => {
    S.time = SECONDS
    const input = $('#guess')
    input.disabled = false
    $('#go').disabled = false
    input.value = ''
    input.focus()
    const tick = () => {
      $('#secs').textContent = S.time
      $('#timefill').style.width = `${(S.time / SECONDS) * 100}%`
    }
    tick()
    const done = (answer) => {
      clearInterval(timer)
      S.waiting = null
      input.disabled = true
      $('#go').disabled = true
      $('#secs').textContent = ''
      resolve(answer)
    }
    const timer = setInterval(() => {
      S.time -= 1
      tick()
      if (S.time <= 0) done(null)
    }, 1000)
    S.waiting = (text) => {
      const { answer } = scoreGuess(pi, text)
      if (!answer) {
        $('#msg').textContent = 'Not on the list — try another'
        const f = $('#form')
        f.classList.remove('shake')
        void f.offsetWidth
        f.classList.add('shake')
        return
      }
      $('#msg').textContent = ''
      done(answer)
    }
  })
}

$('#form').addEventListener('submit', (e) => {
  e.preventDefault()
  const text = $('#guess').value.trim()
  $('#guess').value = ''
  if (text && S.waiting) S.waiting(text)
})

// ---------- the fight ----------
async function fight() {
  Object.assign(S, { phase: 'play', php: MAX_HP, rhp: MAX_HP, round: shuffle(PROMPTS.map((_, i) => i)).slice(0, ROUNDS), log: [] })
  Object.assign(A, { pHit: 0, rHit: 0, pDown: 0, rDown: 0, proj: null })
  $('#title').classList.add('hidden')
  $('#over').classList.add('hidden')
  bars()
  await say('A wild <b>FOX</b> wants to out-nerd you!', 700)

  for (let i = 0; i < ROUNDS; i++) {
    const pi = S.round[i]
    $('#round').textContent = `ROUND ${i + 1}/${ROUNDS}`
    $('#prompt').textContent = PROMPTS[pi].q
    $('#dialog').innerHTML = 'Your move. Dig deep!'
    const mine = await ask(pi)
    const theirs = rivalPick(pi)
    S.log.push({ pi, mine, theirs })

    if (mine && mine.display === theirs.display) {
      await say(`CLASH! You both said <b>${mine.display}</b>. No damage!`, 1200)
    } else {
      if (mine) {
        await say(`You hurl <b>${mine.display}</b>!`, 250)
        await throwBook(true)
        S.rhp -= DMG[mine.tier]
        bars()
        await say(`${TIER[mine.tier]}! <b>${DMG[mine.tier]}</b> damage.`, 800)
      } else {
        await say('You froze up! No attack.', 800)
      }
      if (S.rhp <= 0) break
      await say(`Fox snaps back: <b>${theirs.display}</b>!`, 250)
      await throwBook(false)
      S.php -= DMG[theirs.tier]
      bars()
      await say(`${TIER[theirs.tier]}. <b>${DMG[theirs.tier]}</b> damage.`, 800)
      if (S.php <= 0) break
    }
  }
  finish()
}

async function finish() {
  const win = S.rhp <= 0 || (S.php > 0 && S.php > S.rhp)
  const draw = S.php > 0 && S.rhp > 0 && S.php === S.rhp
  if (!draw) (win ? (A.rDown = 0.01) : (A.pDown = 0.01))
  $('#prompt').innerHTML = '&nbsp;'
  await say(draw ? 'Time! It ends in a draw.' : win ? 'The fox is out-nerded!' : 'You were out-nerded…', 1300)
  S.phase = 'over'
  const rows = S.log
    .map(
      ({ pi, mine, theirs }) => `<div><small>${PROMPTS[pi].q}</small><div class="vs">
        <span>YOU: ${mine ? `${mine.display} (${DMG[mine.tier]})` : '—'}</span><span>FOX: ${theirs.display} (${DMG[theirs.tier]})</span></div></div>`,
    )
    .join('')
  const el = $('#over')
  el.innerHTML = `<div class="verdict">${draw ? 'DRAW' : win ? 'YOU WIN!' : 'YOU LOSE'}</div>
    <p>YOU ${Math.max(0, S.php)} HP · FOX ${Math.max(0, S.rhp)} HP</p>
    <div class="recap">${rows}</div>
    <button class="btn" id="again">REMATCH</button><a class="back" href="./">&lt; all concepts</a>`
  el.classList.remove('hidden')
  $('#again').addEventListener('click', fight)
}

$('#start').addEventListener('click', fight)

// title-screen mascots
{
  const h = $('#hero').getContext('2d')
  h.imageSmoothingEnabled = false
  h.drawImage(OWL, 2, 8, 28, 32 * (16 / 16) - 8)
  h.drawImage(FOX_L, 34, 8, 32 * (16 / 16) - 4, 24)
}

// ---------- rendering ----------
function scene(dt, t) {
  g.imageSmoothingEnabled = false
  g.fillStyle = C.cream
  g.fillRect(0, 0, W, H)
  // sun + rays
  disc(g, 80, 30, 17, C.amber)
  g.fillStyle = C.cream
  for (let y = 22; y < 48; y += 4) g.fillRect(60, y, 40, 1)
  // dithered sky stripes near the horizon
  g.fillStyle = C.amber
  for (let y = 50; y < 62; y += 3) for (let x = (y % 2) * 2; x < W; x += 4) g.fillRect(x, y, 2, 1)
  // hills
  for (let x = 0; x < W; x++) {
    const h = Math.round(16 + 9 * Math.sin(x * 0.045 + 1) + 4 * Math.sin(x * 0.13))
    g.fillStyle = C.plum
    g.fillRect(x, 72 - h, 1, h)
    if ((x + h) % 5 === 0) {
      g.fillStyle = C.ink
      g.fillRect(x, 72 - h + 3, 1, 2)
    }
  }
  // ground
  g.fillStyle = C.ink
  g.fillRect(0, 72, W, 20)
  g.fillStyle = C.plum
  for (let x = 0; x < W; x += 6) g.fillRect(x + ((x / 6) % 2) * 2, 78 + ((x / 6) % 3) * 3, 3, 1)
  // book-stack podiums
  for (const px of [18, 110]) {
    g.fillStyle = C.amber
    g.fillRect(px, 66, 32, 6)
    g.fillStyle = C.ink
    g.fillRect(px, 66, 32, 1)
    g.fillRect(px, 69, 32, 1)
    g.fillStyle = C.cream
    g.fillRect(px + 3, 67, 26, 2)
    g.fillRect(px + 5, 70, 22, 2)
  }

  for (const k of ['pHit', 'rHit', 'pHop', 'rHop']) A[k] = Math.max(0, A[k] - dt)
  if (A.pDown) A.pDown = Math.min(1, A.pDown + dt * 1.5)
  if (A.rDown) A.rDown = Math.min(1, A.rDown + dt * 1.5)

  const draw = (img, x, hit, hop, down, phase) => {
    if (hit > 0 && Math.floor(hit * 16) % 2) return
    const shake = hit > 0 ? (Math.floor(hit * 30) % 2 ? 2 : -2) : 0
    const idle = Math.round(Math.sin(t * 3 + phase) * 1)
    const y = 34 + idle - Math.round(Math.sin((hop / 0.25) * Math.PI) * 6) + Math.round(down * 30)
    const hgt = 32 - Math.round(down * 30)
    if (hgt > 0) g.drawImage(img, 0, 0, img.width, (hgt / 32) * img.height, x + shake, y, img.width * 2, hgt)
  }
  draw(OWL, 20, A.pHit, A.pHop, A.pDown, 0)
  draw(FOX_L, 110, A.rHit, A.rHop, A.rDown, 2)

  if (A.proj) {
    A.proj.t = Math.min(1, A.proj.t + dt / 0.48)
    const k = A.proj.fromPlayer ? A.proj.t : 1 - A.proj.t
    const x = 46 + k * 64
    const y = 46 - Math.sin(A.proj.t * Math.PI) * 26
    g.drawImage(BOOK, Math.round(x), Math.round(y), 12, 10)
  }
}
loop(scene)
