import { useEffect, useRef, useState } from 'react'
import {
  DEEP_PROMPTS,
  DEEP_SECONDS,
  PROMPTS,
  TIER_LABELS,
  TIER_POINTS,
  buildRound,
  deepCuts,
  randomSeed,
  scoreGuess,
} from './deepcut.js'
import { buildDeepChallengeUrl, saveName } from './share.js'
import { hapticForWord } from './App.jsx'

const pad4 = (n) => String(n).padStart(4, '0')

// "Deep Cut" — type an answer to each prompt; rarer correct answers score more.
// Plays solo, or against a friend's challenge (same seeded prompts + their
// answers and score).
export default function DeepCut({ challenge, name, setName, onHome }) {
  const [phase, setPhase] = useState('intro') // 'intro' | 'playing' | 'over'
  const [seed, setSeed] = useState(null)
  const [round, setRound] = useState([]) // prompt indices
  const [index, setIndex] = useState(0)
  const [results, setResults] = useState([]) // [{ answer: string, points, tier }]
  const [guess, setGuess] = useState('')
  const [reveal, setReveal] = useState(null) // { answer, points, tier } | null
  const [miss, setMiss] = useState(0) // bumps to re-trigger the "not on list" shake
  const [timeLeft, setTimeLeft] = useState(DEEP_SECONDS)
  const [shareMsg, setShareMsg] = useState('')
  const advanceRef = useRef(null)
  const inputRef = useRef(null)

  const score = results.reduce((s, r) => s + r.points, 0)

  // Per-prompt countdown — a blank (0) answer at zero.
  useEffect(() => {
    if (phase !== 'playing' || reveal) return
    if (timeLeft <= 0) {
      lockIn({ answer: '', points: 0, tier: 0 })
      return
    }
    const id = setTimeout(() => setTimeLeft((t) => t - 1), 1000)
    return () => clearTimeout(id)
  }, [phase, timeLeft, reveal]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => () => clearTimeout(advanceRef.current), [])

  useEffect(() => {
    if (phase === 'playing' && !reveal) inputRef.current?.focus()
  }, [phase, index, reveal])

  function start(useSeed) {
    const s = useSeed ?? randomSeed()
    setSeed(s)
    setRound(buildRound(s))
    setIndex(0)
    setResults([])
    setGuess('')
    setReveal(null)
    setMiss(0)
    setTimeLeft(DEEP_SECONDS)
    setShareMsg('')
    setPhase('playing')
  }

  function lockIn(result) {
    setReveal(result)
    setResults((r) => [...r, result])
    advanceRef.current = setTimeout(() => {
      setReveal(null)
      setGuess('')
      setTimeLeft(DEEP_SECONDS)
      setMiss(0)
      if (index + 1 >= round.length) setPhase('over')
      else setIndex(index + 1)
    }, 1400)
  }

  function submit(e) {
    e.preventDefault()
    if (reveal || !guess.trim()) return
    const { answer, points } = scoreGuess(round[index], guess)
    if (!answer) {
      setMiss((m) => m + 1)
      setGuess('')
      return
    }
    hapticForWord(3 + answer.tier) // bigger buzz for rarer answers
    lockIn({ answer: answer.display, points, tier: answer.tier })
  }

  async function shareChallenge() {
    const trimmed = (name || '').trim()
    saveName(trimmed)
    const url = buildDeepChallengeUrl({
      seed,
      score,
      name: trimmed || 'A friend',
      answers: results.map((r) => r.answer),
    })
    const text = `I scored ${score} on Sammy Word — Deep Cut. Can you go deeper?`
    if (navigator.share) {
      try {
        await navigator.share({ title: 'Sammy Word', text, url })
        return
      } catch {
        /* cancelled / unsupported — fall through to copy */
      }
    }
    try {
      await navigator.clipboard.writeText(url)
      setShareMsg('Challenge link copied!')
    } catch {
      setShareMsg(url)
    }
  }

  // ---- Intro ----
  if (phase === 'intro')
    return (
      <Overlay>
        <div className="card">
          <button className="btn-back" onClick={onHome}>← Modes</button>
          {challenge ? (
            <>
              <h1>{challenge.name || 'A friend'} challenged you!</h1>
              <p>
                They scored <b>{pad4(challenge.score)}</b> on <b>Deep Cut</b>. Same
                prompts — can you dig up rarer answers?
              </p>
              <button className="btn-start" onClick={() => start(challenge.seed)}>
                Play This Round
              </button>
            </>
          ) : (
            <>
              <h1>Deep Cut</h1>
              <p>
                {DEEP_PROMPTS} prompts, {DEEP_SECONDS}s each.{' '}
                Any correct answer scores — but the more obscure it is, the more it's
                worth.
              </p>
              <TierLegend />
              <button className="btn-start" onClick={() => start()}>
                Play
              </button>
            </>
          )}
        </div>
      </Overlay>
    )

  // ---- Over ----
  if (phase === 'over') {
    const theirs = challenge ? challenge.answers : null
    const win = challenge && score > challenge.score
    const tie = challenge && score === challenge.score
    return (
      <Overlay>
        <div className="card dc-over">
          {challenge ? (
            <>
              <h1 className={win ? 'win' : tie ? '' : 'lose'}>
                {tie ? "It's a tie!" : win ? 'You win! 🎉' : 'You lost'}
              </h1>
              <div className="versus">
                <div className={`vs-col ${win ? 'winner' : ''}`}>
                  <span className="vs-name">You</span>
                  <span className="vs-score">{pad4(score)}</span>
                </div>
                <span className="vs-x">vs</span>
                <div className={`vs-col ${!win && !tie ? 'winner' : ''}`}>
                  <span className="vs-name">{challenge.name || 'Friend'}</span>
                  <span className="vs-score">{pad4(challenge.score)}</span>
                </div>
              </div>
            </>
          ) : (
            <>
              <h1>Done!</h1>
              <div className="final-score">{pad4(score)}</div>
            </>
          )}

          <div className="dc-recap">
            {round.map((pi, i) => {
              const mine = results[i] || { answer: '', points: 0, tier: 0 }
              const their = theirs ? scoreGuess(pi, theirs[i] || '') : null
              return (
                <div className="dc-recap-row" key={i}>
                  <div className="dc-recap-q">{PROMPTS[pi].q}</div>
                  <div className="dc-recap-answers">
                    <AnswerChip who={challenge ? 'You' : null} answer={mine.answer} tier={mine.tier} />
                    {their && (
                      <AnswerChip
                        who={challenge.name || 'Friend'}
                        answer={their.answer ? their.answer.display : ''}
                        tier={their.answer ? their.answer.tier : 0}
                      />
                    )}
                  </div>
                  <div className="dc-recap-cuts">
                    Deep cuts: {deepCuts(pi).map((a) => a.display).join(', ') || '—'}
                  </div>
                </div>
              )
            })}
          </div>

          <input
            className="name-input"
            value={name}
            onChange={(e) => setName(e.target.value.slice(0, 16))}
            placeholder="Your name"
            maxLength={16}
          />
          <button className="btn-share" onClick={shareChallenge}>
            {challenge ? 'Challenge them back' : 'Challenge a friend'}
          </button>
          {shareMsg && <p className="share-msg">{shareMsg}</p>}
          <button className="btn-start" onClick={() => start()}>
            Play Again
          </button>
          <button className="btn-link" onClick={onHome}>
            Back to modes
          </button>
        </div>
      </Overlay>
    )
  }

  // ---- Playing ----
  const pi = round[index]
  if (pi == null) return null
  return (
    <div className="quiz-screen">
      <div className="quiz-top">
        <button className="btn-link" onClick={onHome}>← Modes</button>
        <span className="quiz-score">SCORE {pad4(score)}</span>
        <span className={`timer-pill ${timeLeft <= 5 ? 'low' : ''}`}>0:{String(timeLeft).padStart(2, '0')}</span>
      </div>

      <div className="quiz-progress">
        PROMPT {index + 1} / {round.length}
      </div>
      <div className="dc-prompt">{PROMPTS[pi].q}</div>

      {reveal ? (
        <div className={`dc-reveal tier-${reveal.tier}`}>
          {reveal.tier ? (
            <>
              <span className="dc-reveal-answer">{reveal.answer}</span>
              <span className="dc-reveal-label">
                {TIER_LABELS[reveal.tier - 1]} +{reveal.points}
              </span>
            </>
          ) : (
            <span className="dc-reveal-label">Time's up — 0</span>
          )}
        </div>
      ) : (
        <form className="dc-form" onSubmit={submit}>
          <input
            ref={inputRef}
            className={`dc-input ${miss ? (miss % 2 ? 'miss' : 'miss alt') : ''}`}
            value={guess}
            onChange={(e) => setGuess(e.target.value.replace(/\|/g, '').slice(0, 40))}
            placeholder="Type an answer…"
            autoComplete="off"
            autoCorrect="off"
            autoCapitalize="words"
            spellCheck={false}
            enterKeyHint="go"
          />
          <button className="btn-start dc-go" type="submit" disabled={!guess.trim()}>
            Lock it in
          </button>
          {miss > 0 && <p className="dc-miss">Not on the list — try another</p>}
        </form>
      )}
    </div>
  )
}

function AnswerChip({ who, answer, tier }) {
  return (
    <div className={`dc-chip tier-${tier}`}>
      {who && <span className="dc-chip-who">{who}</span>}
      <span className="dc-chip-answer">{answer || '—'}</span>
      <span className="dc-chip-pts">+{tier ? TIER_POINTS[tier - 1] : 0}</span>
    </div>
  )
}

function TierLegend() {
  return (
    <div className="dc-legend">
      {TIER_LABELS.map((label, i) => (
        <div key={i} className={`dc-chip tier-${i + 1}`}>
          <span className="dc-chip-answer">{label}</span>
          <span className="dc-chip-pts">+{TIER_POINTS[i]}</span>
        </div>
      ))}
    </div>
  )
}

function Overlay({ children }) {
  return (
    <div className="overlay-wrap">
      <div className="overlay-inner">{children}</div>
    </div>
  )
}
