import { useCallback, useEffect, useRef, useState } from 'react'
import './App.css'
import {
  ROUND_SECONDS,
  areAdjacent,
  generateBoard,
  scoreForWord,
} from './board.js'
import {
  buildChallengeUrl,
  clearChallengeFromUrl,
  loadName,
  readChallengeFromUrl,
  saveName,
} from './share.js'

const fmtTime = (s) =>
  `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`

const pad4 = (n) => String(n).padStart(4, '0')

export default function App() {
  const [phase, setPhase] = useState('start') // 'start' | 'playing' | 'over'
  const [dictionary, setDictionary] = useState(null)
  const [board, setBoard] = useState(() => generateBoard())
  const [selection, setSelection] = useState([])
  const [found, setFound] = useState([]) // [{ word, points }]
  const [score, setScore] = useState(0)
  const [timeLeft, setTimeLeft] = useState(ROUND_SECONDS)
  const [pop, setPop] = useState(null) // { key, word, points }

  // Challenge flow: a friend's board + score parsed from the URL, if any.
  const [challenge, setChallenge] = useState(() => readChallengeFromUrl())
  const [name, setName] = useState(() => loadName())
  const [shareMsg, setShareMsg] = useState('')

  const svgRef = useRef(null)
  const tileRefs = useRef([])
  const draggingRef = useRef(false)

  useEffect(() => {
    fetch('/words.txt')
      .then((r) => r.text())
      .then((t) => setDictionary(new Set(t.split('\n').map((w) => w.trim()).filter(Boolean))))
      .catch(() => setDictionary(new Set()))
  }, [])

  useEffect(() => {
    if (phase !== 'playing') return
    if (timeLeft <= 0) {
      setPhase('over')
      return
    }
    const id = setTimeout(() => setTimeLeft((t) => t - 1), 1000)
    return () => clearTimeout(id)
  }, [phase, timeLeft])

  const currentWord = selection.map((i) => board[i]).join('')
  const foundSet = new Set(found.map((f) => f.word))
  const isWord = currentWord.length >= 3 && dictionary?.has(currentWord.toLowerCase())
  const isValid = isWord && !foundSet.has(currentWord)
  const isDupe = isWord && foundSet.has(currentWord)

  function resetRound() {
    setSelection([])
    setFound([])
    setScore(0)
    setTimeLeft(ROUND_SECONDS)
    setPop(null)
    setShareMsg('')
  }

  // Start a brand-new random game (clears any incoming challenge).
  function newGame() {
    setChallenge(null)
    clearChallengeFromUrl()
    setBoard(generateBoard())
    resetRound()
    setPhase('playing')
  }

  // Accept a friend's challenge: play their exact board.
  function acceptChallenge() {
    setBoard(challenge.board.slice())
    resetRound()
    setPhase('playing')
  }

  async function shareChallenge() {
    const trimmed = name.trim()
    saveName(trimmed)
    const url = buildChallengeUrl({ board, score, name: trimmed || 'A friend' })
    const text = `I scored ${score} on Sammy Word — can you beat it?`
    if (navigator.share) {
      try {
        await navigator.share({ title: 'Sammy Word', text, url })
        return
      } catch {
        /* user cancelled or unsupported — fall through to copy */
      }
    }
    try {
      await navigator.clipboard.writeText(url)
      setShareMsg('Challenge link copied!')
    } catch {
      setShareMsg(url)
    }
  }

  // ---- Drag selection ----
  const tileIndexFromPoint = (x, y) => {
    const el = document.elementFromPoint(x, y)?.closest('[data-tile]')
    return el ? Number(el.getAttribute('data-tile')) : null
  }

  const extendSelection = useCallback((idx) => {
    if (idx == null) return
    setSelection((sel) => {
      if (sel.length === 0) return [idx]
      if (sel.length >= 2 && idx === sel[sel.length - 2]) return sel.slice(0, -1)
      const last = sel[sel.length - 1]
      if (idx === last || sel.includes(idx) || !areAdjacent(last, idx)) return sel
      return [...sel, idx]
    })
  }, [])

  const onPointerDown = (e) => {
    if (phase !== 'playing') return
    draggingRef.current = true
    e.currentTarget.setPointerCapture?.(e.pointerId)
    extendSelection(tileIndexFromPoint(e.clientX, e.clientY))
  }
  const onPointerMove = (e) => {
    if (!draggingRef.current) return
    extendSelection(tileIndexFromPoint(e.clientX, e.clientY))
  }
  const onPointerUp = () => {
    if (!draggingRef.current) return
    draggingRef.current = false
    if (isValid) {
      const points = scoreForWord(currentWord)
      setScore((s) => s + points)
      setFound((f) => [{ word: currentWord, points }, ...f])
      const key = Date.now()
      setPop({ key, word: currentWord, points })
      setTimeout(() => setPop((p) => (p?.key === key ? null : p)), 950)
    }
    setSelection([])
  }

  const pathPoints = selection
    .map((idx) => {
      const tile = tileRefs.current[idx]
      const svg = svgRef.current
      if (!tile || !svg) return null
      const tr = tile.getBoundingClientRect()
      const sr = svg.getBoundingClientRect()
      return { x: tr.left - sr.left + tr.width / 2, y: tr.top - sr.top + tr.height / 2 }
    })
    .filter(Boolean)

  if (phase === 'start')
    return (
      <Overlay>
        {challenge ? (
          <ChallengeIntro
            challenge={challenge}
            ready={dictionary != null}
            onAccept={acceptChallenge}
            onNew={newGame}
          />
        ) : (
          <Home onStart={newGame} ready={dictionary != null} />
        )}
      </Overlay>
    )

  if (phase === 'over')
    return (
      <Overlay>
        {challenge ? (
          <Compare
            score={score}
            found={found}
            challenge={challenge}
            name={name}
            setName={setName}
            onShare={shareChallenge}
            shareMsg={shareMsg}
            onNew={newGame}
          />
        ) : (
          <Result
            score={score}
            found={found}
            name={name}
            setName={setName}
            onShare={shareChallenge}
            shareMsg={shareMsg}
            onNew={newGame}
          />
        )}
      </Overlay>
    )

  return (
    <div className="app">
      <div className="header-card">
        <div className="avatar">🙂</div>
        <div className="header-stats">
          <span className="words">WORDS: {found.length}</span>
          <span className="score">SCORE: {pad4(score)}</span>
        </div>
      </div>

      <div className={`timer-pill ${timeLeft <= 10 ? 'low' : ''}`}>{fmtTime(timeLeft)}</div>

      <div className="word-slot">
        {selection.length > 0 && (
          <span className={`word-bubble ${isValid ? 'valid' : isDupe ? 'dupe' : ''}`}>
            {currentWord}
          </span>
        )}
        {pop && selection.length === 0 && (
          <span key={pop.key} className="float-result">
            {pop.word} (+{pop.points})
          </span>
        )}
      </div>

      <div
        className="board-frame"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
      >
        <div className="grid tile-grid">
          {board.map((_, i) => (
            <div
              key={i}
              data-tile={i}
              ref={(el) => (tileRefs.current[i] = el)}
              className={`tile ${selection.includes(i) ? 'selected' : ''}`}
            />
          ))}
        </div>

        <svg className="path-svg" ref={svgRef}>
          {/* Settled segments (everything except the newest) draw instantly */}
          {pathPoints.length >= 3 && (
            <polyline
              points={pathPoints.slice(0, -1).map((p) => `${p.x},${p.y}`).join(' ')}
              fill="none"
              stroke="var(--path-red)"
              strokeWidth="9"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          )}
          {/* Newest segment animates quickly from the previous tile to the new one */}
          {pathPoints.length >= 2 && (
            <line
              key={selection[selection.length - 1]}
              className="path-seg"
              x1={pathPoints[pathPoints.length - 2].x}
              y1={pathPoints[pathPoints.length - 2].y}
              x2={pathPoints[pathPoints.length - 1].x}
              y2={pathPoints[pathPoints.length - 1].y}
              pathLength="1"
            />
          )}
        </svg>

        <div className="grid glyph-grid">
          {board.map((letter, i) => (
            <div key={i} className="glyph">{letter}</div>
          ))}
        </div>
      </div>
    </div>
  )
}

function Overlay({ children }) {
  return <div className="overlay-wrap">{children}</div>
}

function MiniBoard({ letters }) {
  return (
    <div className="mini-board">
      {letters.map((l, i) => (
        <div className="mini-tile" key={i}>{l}</div>
      ))}
    </div>
  )
}

function FoundList({ found }) {
  if (found.length === 0) return null
  const sorted = [...found].sort(
    (a, b) => b.points - a.points || a.word.localeCompare(b.word),
  )
  return (
    <div className="found-list">
      {sorted.map((f) => (
        <span className="found-chip" key={f.word}>
          {f.word}<span className="pts">{f.points}</span>
        </span>
      ))}
    </div>
  )
}

function NameRow({ name, setName }) {
  return (
    <input
      className="name-input"
      value={name}
      onChange={(e) => setName(e.target.value.slice(0, 16))}
      placeholder="Your name"
      maxLength={16}
    />
  )
}

function Home({ onStart, ready }) {
  const demo = ['C', 'A', 'T', 'D', 'W', 'O', 'F', 'O', 'I', 'R', 'D', 'G', 'N', 'O', 'A', 'S']
  return (
    <div className="card">
      <h1>How to play:</h1>
      <p>Connect letters together by dragging your finger. Make as many words as you can.</p>
      <MiniBoard letters={demo} />
      <button className="btn-start" onClick={onStart} disabled={!ready}>
        {ready ? 'New Game' : 'Loading…'}
      </button>
    </div>
  )
}

function ChallengeIntro({ challenge, ready, onAccept, onNew }) {
  const who = challenge.name || 'A friend'
  return (
    <div className="card">
      <h1>{who} challenged you!</h1>
      <p>They scored <b>{pad4(challenge.score)}</b> on this board. Can you beat it?</p>
      <MiniBoard letters={challenge.board} />
      <button className="btn-start" onClick={onAccept} disabled={!ready}>
        {ready ? 'Play This Board' : 'Loading…'}
      </button>
      <button className="btn-link" onClick={onNew}>Or start a fresh game</button>
    </div>
  )
}

function ShareBlock({ name, setName, onShare, shareMsg, label }) {
  return (
    <>
      <NameRow name={name} setName={setName} />
      <button className="btn-share" onClick={onShare}>{label}</button>
      {shareMsg && <p className="share-msg">{shareMsg}</p>}
    </>
  )
}

function Result({ score, found, name, setName, onShare, shareMsg, onNew }) {
  return (
    <div className="card">
      <h1>Time!</h1>
      <div className="final-score">{pad4(score)}</div>
      <p>{found.length} word{found.length === 1 ? '' : 's'} found</p>
      <ShareBlock
        name={name}
        setName={setName}
        onShare={onShare}
        shareMsg={shareMsg}
        label="Challenge a friend"
      />
      <FoundList found={found} />
      <button className="btn-start" onClick={onNew}>New Game</button>
    </div>
  )
}

function Compare({ score, found, challenge, name, setName, onShare, shareMsg, onNew }) {
  const them = challenge.name || 'Your friend'
  const win = score > challenge.score
  const tie = score === challenge.score
  const headline = tie ? "It's a tie!" : win ? 'You win! 🎉' : 'You lost'
  return (
    <div className="card">
      <h1 className={win ? 'win' : tie ? '' : 'lose'}>{headline}</h1>
      <div className="versus">
        <div className={`vs-col ${win && !tie ? 'winner' : ''}`}>
          <span className="vs-name">You</span>
          <span className="vs-score">{pad4(score)}</span>
        </div>
        <span className="vs-x">vs</span>
        <div className={`vs-col ${!win && !tie ? 'winner' : ''}`}>
          <span className="vs-name">{them}</span>
          <span className="vs-score">{pad4(challenge.score)}</span>
        </div>
      </div>
      <FoundList found={found} />
      <ShareBlock
        name={name}
        setName={setName}
        onShare={onShare}
        shareMsg={shareMsg}
        label="Challenge them back"
      />
      <button className="btn-start" onClick={onNew}>New Game</button>
    </div>
  )
}
