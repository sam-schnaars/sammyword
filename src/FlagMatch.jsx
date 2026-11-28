import { useEffect, useRef, useState } from 'react'
import {
  FLAG_QUESTIONS,
  FLAG_ROUND_SECONDS,
  POINTS_PER_CORRECT,
  buildQuiz,
} from './flags.js'
import { buildFlagChallengeUrl, saveName } from './share.js'

const pad4 = (n) => String(n).padStart(4, '0')
const fmtTime = (s) =>
  `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`

// "Match the flag to its country" — a timed multiple-choice round. Plays solo,
// or against a friend's challenge (same seeded questions + their score).
export default function FlagMatch({ challenge, name, setName, onHome }) {
  const [phase, setPhase] = useState('intro') // 'intro' | 'playing' | 'over'
  const [seed, setSeed] = useState(null)
  const [quiz, setQuiz] = useState([])
  const [index, setIndex] = useState(0)
  const [score, setScore] = useState(0)
  const [correct, setCorrect] = useState(0)
  const [picked, setPicked] = useState(null) // chosen option index, or null
  const [timeLeft, setTimeLeft] = useState(FLAG_ROUND_SECONDS)
  const [shareMsg, setShareMsg] = useState('')
  const advanceRef = useRef(null)

  // Countdown — ends the round at zero.
  useEffect(() => {
    if (phase !== 'playing') return
    if (timeLeft <= 0) {
      setPhase('over')
      return
    }
    const id = setTimeout(() => setTimeLeft((t) => t - 1), 1000)
    return () => clearTimeout(id)
  }, [phase, timeLeft])

  // Clear any pending "advance to next question" timer on unmount.
  useEffect(() => () => clearTimeout(advanceRef.current), [])

  function start(useSeed) {
    const s = useSeed ?? Math.floor(Math.random() * 1e9)
    setSeed(s)
    setQuiz(buildQuiz(s, FLAG_QUESTIONS))
    setIndex(0)
    setScore(0)
    setCorrect(0)
    setPicked(null)
    setTimeLeft(FLAG_ROUND_SECONDS)
    setShareMsg('')
    setPhase('playing')
  }

  function choose(optIndex) {
    if (picked != null) return
    const q = quiz[index]
    setPicked(optIndex)
    if (optIndex === q.answer) {
      setScore((s) => s + POINTS_PER_CORRECT)
      setCorrect((c) => c + 1)
    }
    advanceRef.current = setTimeout(() => {
      if (index + 1 >= quiz.length) setPhase('over')
      else {
        setIndex((i) => i + 1)
        setPicked(null)
      }
    }, 750)
  }

  async function shareChallenge() {
    const trimmed = (name || '').trim()
    saveName(trimmed)
    const url = buildFlagChallengeUrl({ seed, score, name: trimmed || 'A friend' })
    const text = `I scored ${score} on Sammy Word — Flag Match. Can you beat it?`
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
                They scored <b>{pad4(challenge.score)}</b> on <b>Flag Match</b>.
                Match each flag to its country — can you beat it?
              </p>
              <button className="btn-start" onClick={() => start(challenge.seed)}>
                Play This Round
              </button>
            </>
          ) : (
            <>
              <h1>Flag Match</h1>
              <p>
                Match each flag to its country before the timer runs out.
                <br />
                +{POINTS_PER_CORRECT} for each correct answer.
              </p>
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
    const win = challenge && score > challenge.score
    const tie = challenge && score === challenge.score
    return (
      <Overlay>
        <div className="card">
          {challenge ? (
            <>
              <h1 className={win ? 'win' : tie ? '' : 'lose'}>
                {tie ? "It's a tie!" : win ? 'You win! 🎉' : 'You lost'}
              </h1>
              <div className="versus">
                <div className={`vs-col ${win && !tie ? 'winner' : ''}`}>
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
              <h1>Time!</h1>
              <div className="final-score">{pad4(score)}</div>
            </>
          )}
          <p>
            {correct} of {quiz.length} correct
          </p>
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
  const q = quiz[index]
  if (!q) return null
  return (
    <div className="quiz-screen">
      <div className="quiz-top">
        <button className="btn-link" onClick={onHome}>← Modes</button>
        <span className="quiz-score">SCORE {pad4(score)}</span>
        <span className={`timer-pill ${timeLeft <= 10 ? 'low' : ''}`}>{fmtTime(timeLeft)}</span>
      </div>

      <div className="quiz-progress">
        FLAG {index + 1} / {quiz.length}
      </div>
      <div className="quiz-flag">{q.flag}</div>
      <div className="quiz-prompt">Tap the matching country</div>

      <div className="quiz-choices">
        {q.options.map((opt, i) => {
          const state =
            picked == null ? '' : i === q.answer ? 'right' : i === picked ? 'wrong' : ''
          return (
            <button
              key={i}
              className={`quiz-choice ${state}`}
              disabled={picked != null}
              onClick={() => choose(i)}
            >
              {opt}
            </button>
          )
        })}
      </div>
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
