import { useEffect, useMemo, useRef, useState } from 'react'
import {
  PICKS, LIVES, TIERS, tierOf, pointsFor, shareOf, dayNumber, puzzle, judge,
  total, bestPossible, shareText, loadAll, saveDay, streak,
} from './daily.js'
import { DAYS } from './days.js'
import { COMMUNITY } from './community.js'

const fmtPct = (p) =>
  p >= 1 ? `${Math.round(p)}%` : p >= 0.1 ? `${p.toFixed(1)}%` : p >= 0.01 ? `${p.toFixed(2)}%` : '<0.01%'

function todayNumber() {
  const q = Number(new URLSearchParams(location.search).get('day'))
  return q >= 1 ? Math.floor(q) : dayNumber()
}

function useCountdown() {
  const [now, setNow] = useState(Date.now())
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(t)
  }, [])
  const d = new Date(now)
  const next = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1)
  const s = Math.max(0, Math.floor((next - now) / 1000))
  const pad = (x) => String(x).padStart(2, '0')
  return `${pad(Math.floor(s / 3600))}:${pad(Math.floor((s % 3600) / 60))}:${pad(s % 60)}`
}

export default function Daily() {
  const n = useMemo(todayNumber, [])
  const p = useMemo(() => puzzle(n), [n])
  const saved = useMemo(() => loadAll()[n], [n])
  const [banked, setBanked] = useState(saved?.banked || [])
  const [misses, setMisses] = useState(saved?.misses || [])
  const [text, setText] = useState('')
  const [flash, setFlash] = useState(null)
  const inputRef = useRef(null)

  const done = banked.length >= PICKS || misses.length >= LIVES
  const score = total(banked)
  const best = useMemo(() => bestPossible(p), [p])
  const myStreak = streak({ ...loadAll(), [n]: { done } }, n)

  useEffect(() => {
    saveDay(n, { banked, misses, done })
  }, [n, banked, misses, done])

  function submit(e) {
    e.preventDefault()
    if (done) return
    const r = judge(p, text, banked)
    if (r.kind === 'empty') return
    if (r.kind === 'repeat') {
      setFlash({ kind: 'repeat', msg: `Already got ${r.answer.display}. Try another.` })
      setText('')
      return
    }
    if (r.kind === 'miss') {
      setMisses((m) => [...m, text.trim()])
      setFlash({ kind: 'miss', msg: `"${text.trim()}" isn't on today's list.` })
    } else {
      setBanked((b) => [...b, { display: r.answer.display, pct: r.pct, points: r.points }])
      setFlash({
        kind: 'hit',
        tier: r.tier.cls,
        msg: `${r.answer.display}: ${fmtPct(r.pct)} said it. ${r.tier.label}, +${r.points}`,
      })
    }
    setText('')
    inputRef.current?.focus()
  }

  const date = new Date(Date.now() + (n - dayNumber()) * 86400000)
  const dateLabel = date.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', timeZone: 'UTC' })

  return (
    <>
      <section className="hero" aria-label="Daily Sammy">
        <header className="hero-top">
          <div className="brand">
            DAILY <span>SAMMY</span>
          </div>
          <div className="meta">
            <span>#{n}</span>
            <span>{dateLabel}</span>
            <span title="Days in a row">🔥 {myStreak}</span>
          </div>
        </header>

        <div className="stage">
          <p className="kicker">Today's prompt</p>
          <h1 className="prompt">{p.prompt}</h1>
          <p className="rule">
            Name {PICKS}. <b>The fewer people who think of it, the more it scores.</b>
          </p>

          <ol className="slots">
            {Array.from({ length: PICKS }, (_, i) => {
              const b = banked[i]
              const t = b && tierOf(b.pct)
              return (
                <li key={i} className={b ? `slot filled ${t.cls}` : 'slot'}>
                  {b ? (
                    <>
                      <span className="slot-name">{b.display}</span>
                      <span className="slot-pct">{fmtPct(b.pct)} · {t.label}</span>
                      <span className="slot-pts">+{b.points}</span>
                    </>
                  ) : (
                    <span className="slot-empty">answer {i + 1}</span>
                  )}
                </li>
              )
            })}
          </ol>

          {!done && (
            <form className="guess" onSubmit={submit}>
              <input
                ref={inputRef}
                value={text}
                onChange={(e) => setText(e.target.value)}
                placeholder="Type an answer…"
                autoFocus
                autoComplete="off"
                autoCorrect="off"
                spellCheck={false}
                aria-label="Your answer"
              />
              <button type="submit">Lock in</button>
            </form>
          )}

          <div className="status">
            <span className="lives" aria-label={`${LIVES - misses.length} lives left`}>
              {Array.from({ length: LIVES }, (_, i) => (
                <i key={i} className={i < LIVES - misses.length ? 'on' : ''} />
              ))}
            </span>
            <span className="score">
              <b>{score}</b> pts
            </span>
          </div>

          {flash && !done && (
            <p key={flash.msg} className={`flash ${flash.kind} ${flash.tier || ''}`} role="status">
              {flash.msg}
            </p>
          )}

          {done && <Results p={p} banked={banked} misses={misses} score={score} best={best} />}
        </div>

        <a className="more-hint" href="#community">
          More daily games ↓
        </a>
      </section>

      <Community />

      <footer className="foot">
        <details>
          <summary>How scoring works</summary>
          <p>
            Each answer scores <code>25 × log₂(100 ÷ share)</code>, where <i>share</i> is the % of
            players who gave it. Every time an answer gets half as common, it's worth 25 more.
          </p>
          <ul className="tier-key">
            {TIERS.map((t) => (
              <li key={t.cls}>
                {t.emoji} {t.label}: {t.min > 0 ? `${t.min}%+` : 'under 0.1%'}
                {' '}({pointsFor(t.min > 0 ? t.min : 0.05)}{t.min > 0 ? '+' : ''} pts)
              </li>
            ))}
          </ul>
          <p>A wrong answer costs a life. Three wrong and the day ends with what you've banked.</p>
        </details>
        <p className="proto">
          Prototype. Shares are seed estimates, not live player counts yet. Try another day:{' '}
          {DAYS.map((d, i) => (
            <a key={i} href={`?day=${i + 1}`} className={i + 1 === n ? 'cur' : ''}>
              {i + 1}
            </a>
          ))}
        </p>
      </footer>
    </>
  )
}

function Results({ p, banked, misses, score, best }) {
  const [copied, setCopied] = useState(false)
  const [all, setAll] = useState(false)
  const countdown = useCountdown()
  const mine = new Set(banked.map((b) => b.display))
  // Show the rarest answers first: that's the fun part of the reveal.
  const board = [...p.answers].reverse()
  const shown = all ? board : board.slice(0, 12)

  async function share() {
    const t = shareText(p, banked)
    try {
      if (navigator.share && matchMedia('(pointer: coarse)').matches) await navigator.share({ text: t })
      else await navigator.clipboard.writeText(t)
      setCopied(true)
    } catch {
      /* dismissed */
    }
  }

  return (
    <div className="results">
      <div className="final">
        <div>
          <span className="final-score">{score}</span>
          <span className="final-of"> / {best} possible</span>
        </div>
        <button onClick={share}>{copied ? 'Copied!' : 'Share'}</button>
      </div>
      {misses.length > 0 && <p className="missed">Not accepted: {misses.join(', ')}</p>}
      <p className="next">Next prompt in {countdown}</p>

      <h2>Deepest cuts today</h2>
      <ul className="board">
        {shown.map((a) => {
          const pct = shareOf(a)
          const t = tierOf(pct)
          return (
            <li key={a.display} className={`${t.cls} ${mine.has(a.display) ? 'mine' : ''}`}>
              <span>{a.display}</span>
              <span className="bar" style={{ '--w': `${Math.min(100, pct * 3)}%` }} />
              <span>{fmtPct(pct)}</span>
              <span>{pointsFor(pct)}</span>
            </li>
          )
        })}
      </ul>
      <button className="link" onClick={() => setAll((x) => !x)}>
        {all ? 'Show fewer' : `Show all ${board.length} answers`}
      </button>
    </div>
  )
}

function Community() {
  return (
    <section id="community" className="community">
      <h2>Community games</h2>
      <p className="sub">Daily games by other makers we like. One play a day, every day.</p>
      <div className="cards">
        {COMMUNITY.map((g) => (
          <article key={g.id} className="card">
            <div className="card-head">
              <span className="card-emoji" aria-hidden>{g.emoji}</span>
              <h3>{g.name}</h3>
            </div>
            <p>{g.blurb}</p>
            <a className="play" href={g.url} target="_blank" rel="noopener">
              Play {g.name} ↗
            </a>
            {g.sponsor && (
              <aside className="ad-slot" data-ad-slot={g.id} aria-label={`Advertisement from ${g.name}`}>
                <span className="ad-label">Sponsored · Ad from {g.name}</span>
                <div className="ad-box">
                  <b>{g.sponsor.size}</b>
                  <span>{g.sponsor.note}</span>
                </div>
              </aside>
            )}
          </article>
        ))}
        <article className="card card-open">
          <h3>Your game here</h3>
          <p>More community daily games are on the way.</p>
        </article>
      </div>
    </section>
  )
}
