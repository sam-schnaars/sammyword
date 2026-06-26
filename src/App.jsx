import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import './App.css'
import {
  HEART,
  MAPS,
  ROUND_SECONDS,
  areAdjacent,
  boardFromLetters,
  boardLetters,
  buildTrie,
  dailyKey,
  generateBoard,
  generateDailyBoard,
  getMap,
  scoreForWord,
} from './board.js'
import {
  buildChallengeUrl,
  clearChallengeFromUrl,
  dailyBest,
  loadName,
  readChallengeFromUrl,
  saveDailyBest,
  saveName,
} from './share.js'
import { fetchLeaderboard, submitScore } from './leaderboard.js'

const fmtTime = (s) =>
  `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`

const pad4 = (n) => String(n).padStart(4, '0')

export default function App() {
  const [phase, setPhase] = useState('start') // 'start' | 'playing' | 'over'
  const [dictionary, setDictionary] = useState(null)
  const [mapId, setMapId] = useState('classic') // selected on the home screen
  const [map, setMap] = useState(() => getMap('classic')) // map of the active board
  const [board, setBoard] = useState(() => generateBoard(getMap('classic')))
  const [selection, setSelection] = useState([])
  const [found, setFound] = useState([]) // [{ word, points }]
  const [score, setScore] = useState(0)
  const [timeLeft, setTimeLeft] = useState(ROUND_SECONDS)
  const [pop, setPop] = useState(null) // { key, word, points }

  // Challenge flow: a friend's map + letters + score parsed from the URL, if any.
  const [challenge, setChallenge] = useState(() => readChallengeFromUrl())
  const [name, setName] = useState(() => loadName())
  const [shareMsg, setShareMsg] = useState('')

  // Map of the Day: the day key of the current daily round (null for others).
  const [dailyDate, setDailyDate] = useState(null)
  const [daily, setDaily] = useState(null) // { best, record } shown at game over

  const svgRef = useRef(null)
  const tileRefs = useRef([])
  const draggingRef = useRef(false)

  useEffect(() => {
    fetch('/words.txt')
      .then((r) => r.text())
      .then((t) => setDictionary(new Set(t.split('\n').map((w) => w.trim()).filter(Boolean))))
      .catch(() => setDictionary(new Set()))
  }, [])

  // Prefix trie for the board solver — built once when the dictionary lands,
  // then handed to the generator so boards are guaranteed to contain words.
  const solverTrie = useMemo(
    () => (dictionary && dictionary.size ? buildTrie(dictionary) : null),
    [dictionary],
  )

  useEffect(() => {
    if (phase !== 'playing') return
    if (timeLeft <= 0) {
      setPhase('over')
      return
    }
    const id = setTimeout(() => setTimeLeft((t) => t - 1), 1000)
    return () => clearTimeout(id)
  }, [phase, timeLeft])

  // Record the local personal best when a Map of the Day round ends.
  useEffect(() => {
    if (phase !== 'over' || !dailyDate || challenge) return
    const prev = dailyBest(dailyDate)
    const record = score > prev
    if (record) saveDailyBest(dailyDate, score)
    setDaily({ best: Math.max(prev, score), record })
  }, [phase]) // eslint-disable-line react-hooks/exhaustive-deps

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

  // Start a brand-new game on the selected map (clears any challenge).
  // For the Map of the Day, the board is deterministic for today.
  function newGame() {
    const isDaily = mapId === 'daily'
    const m = getMap(mapId)
    setChallenge(null)
    clearChallengeFromUrl()
    setMap(m)
    setBoard(
      isDaily
        ? generateDailyBoard(m, dailyKey(), { trie: solverTrie })
        : generateBoard(m, undefined, { trie: solverTrie }),
    )
    setDailyDate(isDaily ? dailyKey() : null)
    setDaily(null)
    resetRound()
    setPhase('playing')
  }

  // Return to the home screen so the player can pick a map again.
  function goHome() {
    setChallenge(null)
    clearChallengeFromUrl()
    setDailyDate(null)
    setDaily(null)
    setPhase('start')
  }

  // Accept a friend's challenge: play their exact map + letters.
  function acceptChallenge() {
    const m = getMap(challenge.mapId)
    setMap(m)
    setBoard(boardFromLetters(m, challenge.letters))
    setDailyDate(null)
    setDaily(null)
    resetRound()
    setPhase('playing')
  }

  async function shareChallenge() {
    const trimmed = name.trim()
    saveName(trimmed)
    const url = buildChallengeUrl({
      mapId: map.id,
      letters: boardLetters(board),
      score,
      name: trimmed || 'A friend',
    })
    const text = `I scored ${score} on Sammy Word (${map.name}) — can you beat it?`
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

  const extendSelection = useCallback(
    (idx) => {
      if (idx == null) return
      setSelection((sel) => {
        if (sel.length === 0) return [idx]
        if (sel.length >= 2 && idx === sel[sel.length - 2]) return sel.slice(0, -1)
        const last = sel[sel.length - 1]
        if (idx === last || sel.includes(idx) || !areAdjacent(last, idx, map.cols)) return sel
        return [...sel, idx]
      })
    },
    [map.cols],
  )

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
      navigator.vibrate?.(20) // small haptic tick on mobile (ignored where unsupported)
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
          <Home onStart={newGame} ready={dictionary != null} mapId={mapId} setMapId={setMapId} />
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
            onNew={goHome}
          />
        ) : dailyDate ? (
          <DailyResult
            score={score}
            found={found}
            name={name}
            setName={setName}
            onShare={shareChallenge}
            shareMsg={shareMsg}
            onNew={goHome}
            daily={daily}
            dailyDate={dailyDate}
          />
        ) : (
          <Result
            score={score}
            found={found}
            name={name}
            setName={setName}
            onShare={shareChallenge}
            shareMsg={shareMsg}
            onNew={goHome}
          />
        )}
      </Overlay>
    )

  const gridStyle = {
    gridTemplateColumns: `repeat(${map.cols}, 1fr)`,
    gridTemplateRows: `repeat(${map.rows}, 1fr)`,
    gap: map.cols <= 4 ? '10px' : '6px',
  }
  const glyphFont = `calc(min(86vw, 360px) / ${map.cols} * 0.46)`

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
        style={{ aspectRatio: `${map.cols} / ${map.rows}` }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
      >
        <div className="grid tile-grid" style={gridStyle}>
          {board.map((cell, i) =>
            cell == null ? (
              <div key={i} className="cell-hole" />
            ) : (
              <div
                key={i}
                data-tile={i}
                ref={(el) => (tileRefs.current[i] = el)}
                className={`tile ${selection.includes(i) ? 'selected' : ''}`}
              />
            ),
          )}
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

        <div className="grid glyph-grid" style={{ ...gridStyle, fontSize: glyphFont }}>
          {board.map((cell, i) =>
            cell == null ? (
              <div key={i} />
            ) : (
              <div key={i} className="glyph">{cell}</div>
            ),
          )}
        </div>
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

// Abstract shape preview (filled vs hole cells) used in the map selector.
function MiniShape({ map }) {
  return (
    <div
      className="mini-shape"
      style={{
        gridTemplateColumns: `repeat(${map.cols}, 1fr)`,
        gridTemplateRows: `repeat(${map.rows}, 1fr)`,
      }}
    >
      {map.mask.map((on, i) => (
        <span key={i} className={`ms-cell ${on ? 'on' : 'off'}`} />
      ))}
    </div>
  )
}

// Small wood-tile board (shape-aware, with letters) used in the challenge intro.
function MiniBoard({ map, board }) {
  return (
    <div
      className="mini-board"
      style={{
        gridTemplateColumns: `repeat(${map.cols}, 1fr)`,
        gridTemplateRows: `repeat(${map.rows}, 1fr)`,
        fontSize: `calc(150px / ${map.cols} * 0.5)`,
      }}
    >
      {board.map((c, i) =>
        c == null ? (
          <div key={i} className="mini-hole" />
        ) : (
          <div key={i} className="mini-tile">{c}</div>
        ),
      )}
    </div>
  )
}

function GameMode({ mapId, setMapId }) {
  return (
    <div className="mode-section">
      <div className="mode-head">GAME MODE</div>
      <div className="mode-divider" />
      <div className="mode-grid">
        {MAPS.map((m) => (
          <button
            key={m.id}
            type="button"
            className={`mode-opt ${m.id === mapId ? 'sel' : ''}`}
            onClick={() => setMapId(m.id)}
          >
            <span className="mode-name">
              {m.id === mapId && <span className="dot">•</span>}
              {m.name}
            </span>
            <MiniShape map={m} />
          </button>
        ))}
      </div>
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

function Home({ onStart, ready, mapId, setMapId }) {
  return (
    <div className="card">
      <h1>Sammy Word</h1>
      <p>Drag to connect neighboring letters and make as many words as you can.</p>

      <button
        type="button"
        className={`daily-card ${mapId === 'daily' ? 'sel' : ''}`}
        onClick={() => setMapId('daily')}
      >
        <MiniShape map={HEART} />
        <span className="daily-text">
          <span className="daily-title">❤️ Map of the Day</span>
          <span className="daily-sub">Same heart board for everyone today</span>
        </span>
      </button>

      <GameMode mapId={mapId} setMapId={setMapId} />
      <button className="btn-start" onClick={onStart} disabled={!ready}>
        {ready ? 'New Game' : 'Loading…'}
      </button>
    </div>
  )
}

function ChallengeIntro({ challenge, ready, onAccept, onNew }) {
  const map = getMap(challenge.mapId)
  const board = boardFromLetters(map, challenge.letters)
  const who = challenge.name || 'A friend'
  return (
    <div className="card">
      <h1>{who} challenged you!</h1>
      <p>
        They scored <b>{pad4(challenge.score)}</b> on the <b>{map.name}</b> board.
        Can you beat it?
      </p>
      <MiniBoard map={map} board={board} />
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

function Leaderboard({ day, score, name, setName }) {
  const [loading, setLoading] = useState(true)
  const [data, setData] = useState(null)
  const [posting, setPosting] = useState(false)
  const [posted, setPosted] = useState(false)
  const [prompting, setPrompting] = useState(false) // name popup open?

  // Only fetch for display — posting is an explicit, opt-in action so we never
  // submit a score without the player confirming their name in the popup.
  useEffect(() => {
    let alive = true
    ;(async () => {
      try {
        const d = await fetchLeaderboard(day)
        if (alive) setData(d)
      } catch {
        if (alive) setData({ configured: false, entries: [] })
      }
      if (alive) setLoading(false)
    })()
    return () => {
      alive = false
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // Called from the name popup with the confirmed name.
  async function post(entered) {
    const finalName = entered.trim() || 'Anonymous'
    setPosting(true)
    try {
      saveName(finalName)
      setName(finalName)
      await submitScore({ day, score, name: finalName })
      setData(await fetchLeaderboard(day))
      setPosted(true)
      setPrompting(false)
    } catch {
      /* ignore */
    }
    setPosting(false)
  }

  if (loading)
    return (
      <div className="lb">
        <div className="lb-head">🏆 Global Leaderboard</div>
        <p className="lb-note">Loading…</p>
      </div>
    )
  if (!data?.configured) return null // backend not provisioned yet — stay hidden

  return (
    <div className="lb">
      <div className="lb-head">🏆 Global Leaderboard</div>
      {data.entries.length === 0 ? (
        <p className="lb-note">Be the first to post a score!</p>
      ) : (
        <ol className="lb-list">
          {data.entries.map((e, i) => (
            <li key={i} className={e.you ? 'you' : ''}>
              <span className="lb-rank">{i + 1}</span>
              <span className="lb-name">{e.name}</span>
              <span className="lb-score">{pad4(e.score)}</span>
            </li>
          ))}
        </ol>
      )}
      {data.rank && <p className="lb-note">Your rank today: #{data.rank}</p>}
      {posted ? (
        <p className="lb-note posted">Posted! ✅</p>
      ) : (
        <button className="btn-share lb-post" onClick={() => setPrompting(true)}>
          Post my score
        </button>
      )}
      {prompting && (
        <NamePrompt
          initial={name}
          score={score}
          posting={posting}
          onSubmit={post}
          onCancel={() => setPrompting(false)}
        />
      )}
    </div>
  )
}

// Modal popup that asks for the player's name before posting to the leaderboard.
function NamePrompt({ initial, score, posting, onSubmit, onCancel }) {
  const [val, setVal] = useState(initial || '')
  return (
    <div className="modal-backdrop" onPointerDown={onCancel}>
      <div className="modal" onPointerDown={(e) => e.stopPropagation()}>
        <h2 className="modal-title">Post your score</h2>
        <p className="modal-sub">
          Posting <b>{pad4(score)}</b> to today’s leaderboard. What name should we show?
        </p>
        <input
          className="name-input"
          value={val}
          onChange={(e) => setVal(e.target.value.slice(0, 16))}
          onKeyDown={(e) => e.key === 'Enter' && !posting && onSubmit(val)}
          placeholder="Your name"
          maxLength={16}
          autoFocus
        />
        <button className="btn-share" onClick={() => onSubmit(val)} disabled={posting}>
          {posting ? 'Posting…' : 'Post score'}
        </button>
        <button className="btn-link" onClick={onCancel} disabled={posting}>
          Cancel
        </button>
      </div>
    </div>
  )
}

function DailyResult({ score, found, name, setName, onShare, shareMsg, onNew, daily, dailyDate }) {
  return (
    <div className="card">
      <h1>Time!</h1>
      <div className="final-score">{pad4(score)}</div>
      <p>{found.length} word{found.length === 1 ? '' : 's'} found</p>
      {daily && (
        <div className={`daily-result ${daily.record ? 'record' : ''}`}>
          {daily.record ? '❤️ New personal best today!' : '❤️ Your best today'}
          <span className="daily-best">{pad4(daily.best)}</span>
        </div>
      )}
      <Leaderboard day={dailyDate} score={score} name={name} setName={setName} />
      <button className="btn-share" onClick={onShare}>Challenge a friend</button>
      {shareMsg && <p className="share-msg">{shareMsg}</p>}
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
