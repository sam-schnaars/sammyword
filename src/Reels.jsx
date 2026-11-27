import { useEffect, useMemo, useRef, useState } from 'react'
import { REEL_SECONDS, reelDay, setFor, quizFor, savedScore, saveScore } from './reels.js'
import './reels.css'

// Scroll Recall: watch today's 8 reels (each moves on after REEL_SECONDS
// unless you swipe up first, no going back), then answer 5 questions.
export default function Reels({ onHome }) {
  const day = useMemo(() => reelDay(), [])
  const set = useMemo(() => setFor(day), [day])
  const quiz = useMemo(() => quizFor(day), [day])
  const [phase, setPhase] = useState(savedScore(day) != null ? 'done' : 'intro') // intro | watch | quiz | done
  const [index, setIndex] = useState(0)
  const [muted, setMuted] = useState(true)
  const [q, setQ] = useState(0)
  const [picked, setPicked] = useState(null)
  const [answers, setAnswers] = useState([])
  const [copied, setCopied] = useState(false)

  const score = phase === 'done' && answers.length === 0 ? savedScore(day) : answers.filter(Boolean).length

  function next() {
    if (index + 1 >= set.reels.length) setPhase('quiz')
    else setIndex(index + 1)
  }

  function choose(k) {
    if (picked != null) return
    setPicked(k)
    const right = k === quiz[q].answer
    setTimeout(() => {
      const all = [...answers, right]
      setAnswers(all)
      setPicked(null)
      if (q + 1 >= quiz.length) {
        saveScore(day, all.filter(Boolean).length)
        setPhase('done')
      } else setQ(q + 1)
    }, 900)
  }

  async function share() {
    const text = `Scroll Recall #${day}: ${score}/${quiz.length} 🧠📱\n${answers.map((a) => (a ? '🟩' : '🟥')).join('')}`
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
    } catch {
      /* no clipboard */
    }
  }

  if (phase === 'watch')
    return (
      <ReelPlayer
        key={index}
        reel={set.reels[index]}
        upNext={set.reels[index + 1]}
        index={index}
        count={set.reels.length}
        muted={muted}
        onMute={() => setMuted((m) => !m)}
        onNext={next}
        onHome={onHome}
      />
    )

  return (
    <div className="reels-page">
      <div className="reels-card">
        <button className="reels-back" onClick={onHome}>← Modes</button>
        <h1>Scroll Recall</h1>
        <p className="reels-day">#{day} · {set.title}</p>

        {phase === 'intro' && (
          <>
            <p className="reels-lede">
              {set.reels.length} short reels, about {REEL_SECONDS} seconds each. Swipe up to skip ahead, or wait and
              they move on by themselves. There's no going back. Then {quiz.length} questions about what you saw.
            </p>
            <button className="reels-go" onClick={() => setPhase('watch')}>▶ Start scrolling</button>
            <p className="reels-credit">Footage: NASA (public domain).</p>
          </>
        )}

        {phase === 'quiz' && (
          <div className="reels-quiz">
            <p className="reels-qnum">Question {q + 1} / {quiz.length}</p>
            <h2>{quiz[q].q}</h2>
            <div className="reels-options">
              {quiz[q].options.map((o, k) => (
                <button
                  key={o}
                  className={
                    picked == null ? '' : k === quiz[q].answer ? 'right' : k === picked ? 'wrong' : 'dim'
                  }
                  onClick={() => choose(k)}
                >
                  {o}
                </button>
              ))}
            </div>
          </div>
        )}

        {phase === 'done' && (
          <div className="reels-done">
            <p className="reels-score">
              {score}<span>/{quiz.length}</span>
            </p>
            {answers.length > 0 && <p className="reels-row">{answers.map((a) => (a ? '🟩' : '🟥')).join('')}</p>}
            <p className="reels-lede">New reels tomorrow.</p>
            {answers.length > 0 && <button className="reels-go" onClick={share}>{copied ? 'Copied!' : 'Share'}</button>}
          </div>
        )}
      </div>
    </div>
  )
}

function ReelPlayer({ reel, upNext, index, count, muted, onMute, onNext, onHome }) {
  const videoRef = useRef(null)
  const touchY = useRef(null)
  const done = useRef(false)

  const advance = () => {
    if (done.current) return
    done.current = true
    onNext()
  }

  // Move on after REEL_SECONDS whether or not the clip loaded.
  useEffect(() => {
    const t = setTimeout(advance, REEL_SECONDS * 1000)
    const onKey = (e) => {
      if (['ArrowDown', 'ArrowRight', ' ', 'PageDown'].includes(e.key)) advance()
    }
    window.addEventListener('keydown', onKey)
    return () => {
      clearTimeout(t)
      window.removeEventListener('keydown', onKey)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (videoRef.current) videoRef.current.muted = muted
  }, [muted])

  return (
    <div
      className="reel"
      onTouchStart={(e) => (touchY.current = e.touches[0].clientY)}
      onTouchEnd={(e) => {
        if (touchY.current != null && touchY.current - e.changedTouches[0].clientY > 50) advance()
        touchY.current = null
      }}
      onWheel={(e) => e.deltaY > 40 && advance()}
    >
      <video
        ref={videoRef}
        className="reel-video"
        src={`${reel.src}#t=${reel.start}`}
        autoPlay
        muted={muted}
        playsInline
        loop
        onLoadedMetadata={(e) => {
          if (e.currentTarget.currentTime < reel.start - 0.5) e.currentTarget.currentTime = reel.start
        }}
        onTimeUpdate={(e) => {
          // Loop just the 8-second window.
          if (e.currentTarget.currentTime > reel.start + REEL_SECONDS + 1) e.currentTarget.currentTime = reel.start
        }}
      />
      {upNext && <video className="reel-preload" src={`${upNext.src}#t=${upNext.start}`} preload="auto" muted />}

      <div className="reel-top">
        <div className="reel-bars">
          {Array.from({ length: count }, (_, i) => (
            <i key={i} className={i < index ? 'seen' : i === index ? 'now' : ''} style={{ '--secs': `${REEL_SECONDS}s` }} />
          ))}
        </div>
        <div className="reel-tools">
          <button onClick={onHome} aria-label="Quit">✕</button>
          <button onClick={onMute} aria-label={muted ? 'Sound on' : 'Sound off'}>{muted ? '🔇' : '🔊'}</button>
        </div>
      </div>

      <p className="reel-caption">{reel.caption}</p>
      <div className="reel-fact">
        <p>{reel.fact}</p>
        <span>Video: {reel.credit}</span>
      </div>
      <button className="reel-skip" onClick={advance}>Swipe up ↑</button>
    </div>
  )
}
