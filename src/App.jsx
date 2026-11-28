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
  solveBoard,
} from './board.js'
import {
  buildChallengeUrl,
  clearChallengeFromUrl,
  loadName,
  readChallengeFromUrl,
  readDeepChallengeFromUrl,
  readFlagChallengeFromUrl,
  saveName,
} from './share.js'
import { fetchLeaderboard, submitScore } from './leaderboard.js'
import FlagMatch from './FlagMatch.jsx'
import DeepCut from './DeepCut.jsx'
import Reels from './Reels.jsx'

const fmtTime = (s) =>
  `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`

const pad4 = (n) => String(n).padStart(4, '0')

// Stronger, length-scaled haptic buzz when a word scores. Web vibration only
// fires on supporting mobile browsers (a no-op elsewhere); longer words get a
// heavier, multi-pulse pattern for extra payoff.
export function hapticForWord(len) {
  if (!navigator.vibrate) return
  if (len <= 3) navigator.vibrate(45)
  else if (len === 4) navigator.vibrate(70)
  else if (len === 5) navigator.vibrate([60, 40, 60])
  else if (len === 6) navigator.vibrate([70, 40, 90])
  else navigator.vibrate([80, 50, 80, 50, 120]) // 7+ big payoff
}

// Rebuild { word, points } rows from a bare list of words (e.g. an opponent's
// shared words), so they render through the same FoundList chips.
const wordsToFound = (words = []) =>
  words.map((word) => ({ word, points: scoreForWord(word) }))

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

  // Top-level mode: the home "mode select" screen, Word Hunt, or Flag Match.
  // A challenge link deep-jumps straight into the relevant mode.
  const [appMode, setAppMode] = useState(() => {
    if (readDeepChallengeFromUrl()) return 'deep'
    if (readFlagChallengeFromUrl()) return 'flags'
    if (readChallengeFromUrl()) return 'hunt'
    return 'menu'
  })

  // Challenge flow: a friend's map + letters + score parsed from the URL, if any.
  const [challenge, setChallenge] = useState(() => readChallengeFromUrl())
  const [flagChallenge, setFlagChallenge] = useState(() => readFlagChallengeFromUrl())
  const [deepChallenge, setDeepChallenge] = useState(() => readDeepChallengeFromUrl())
  const [name, setName] = useState(() => loadName())
  const [shareMsg, setShareMsg] = useState('')

  // Map of the Day: the day key of the current daily round (null for others).
  const [dailyDate, setDailyDate] = useState(null)

  const svgRef = useRef(null)
  const tileRefs = useRef([])
  const draggingRef = useRef(false)

  useEffect(() => {
    fetch(`${import.meta.env.BASE_URL}words.txt`)
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

  const currentWord = selection.map((i) => board[i]).join('')
  const foundSet = new Set(found.map((f) => f.word))

  // Every word the board can yield, bucketed by length — the checklist players
  // chase. Recomputed only when the board changes (solving is fast via the trie).
  const possibleByLength = useMemo(() => {
    if (!solverTrie) return null
    const counts = {}
    for (const w of solveBoard(board, map.cols, solverTrie)) {
      counts[w.length] = (counts[w.length] || 0) + 1
    }
    return counts
  }, [board, map, solverTrie])

  // How many of each length the player has found so far.
  const foundByLength = useMemo(() => {
    const counts = {}
    for (const f of found) counts[f.word.length] = (counts[f.word.length] || 0) + 1
    return counts
  }, [found])
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

  // Start a brand-new game on the given map (defaults to the last-used one).
  // For the Map of the Day, the board is deterministic for today.
  function newGame(id = mapId) {
    const isDaily = id === 'daily'
    const m = getMap(id)
    setMapId(id)
    setChallenge(null)
    clearChallengeFromUrl()
    setMap(m)
    setBoard(
      isDaily
        ? generateDailyBoard(m, dailyKey(), { trie: solverTrie })
        : generateBoard(m, undefined, { trie: solverTrie }),
    )
    setDailyDate(isDaily ? dailyKey() : null)
    resetRound()
    setPhase('playing')
  }

  // Return to the home screen so the player can pick a map again.
  function goHome() {
    setChallenge(null)
    clearChallengeFromUrl()
    setDailyDate(null)
    setPhase('start')
  }

  // End the current round early (skip the rest of the timer).
  function endGame() {
    setSelection([])
    setTimeLeft(0)
    setPhase('over')
  }

  // Accept a friend's challenge: play their exact map + letters.
  function acceptChallenge() {
    const m = getMap(challenge.mapId)
    setMap(m)
    setBoard(boardFromLetters(m, challenge.letters))
    setDailyDate(null)
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
      words: found.map((f) => f.word),
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
      hapticForWord(currentWord.length) // stronger, length-scaled buzz on mobile
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

  if (appMode === 'menu')
    return (
      <Overlay>
        <ModeSelect
          ready={dictionary != null}
          onWordHunt={() => setAppMode('hunt')}
          onFlags={() => setAppMode('flags')}
          onDeep={() => setAppMode('deep')}
          onReels={() => setAppMode('reels')}
        />
      </Overlay>
    )

  if (appMode === 'flags')
    return (
      <FlagMatch
        challenge={flagChallenge}
        name={name}
        setName={setName}
        onHome={() => {
          setFlagChallenge(null)
          clearChallengeFromUrl()
          setAppMode('menu')
        }}
      />
    )

  if (appMode === 'reels') return <Reels onHome={() => setAppMode('menu')} />

  if (appMode === 'deep')
    return (
      <DeepCut
        challenge={deepChallenge}
        name={name}
        setName={setName}
        onHome={() => {
          setDeepChallenge(null)
          clearChallengeFromUrl()
          setAppMode('menu')
        }}
      />
    )

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
          <Home
            onStart={newGame}
            ready={dictionary != null}
            mapId={mapId}
            onBack={() => setAppMode('menu')}
          />
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
        <button className="end-btn" onClick={endGame}>End Game</button>
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

      <WordGoals possible={possibleByLength} found={foundByLength} />

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

// Per-length checklist of how many words exist on the board vs. how many the
// player has traced — e.g. "4 Letter 2/8". Scrolls horizontally if it overflows.
function WordGoals({ possible, found }) {
  if (!possible) return null
  const lengths = Object.keys(possible)
    .map(Number)
    .filter((len) => len > 3)
    .sort((a, b) => a - b)
  if (lengths.length === 0) return null
  return (
    <div className="goals">
      {lengths.map((len) => {
        const total = possible[len]
        const got = found[len] || 0
        return (
          <div key={len} className={`goal ${got >= total ? 'done' : ''}`}>
            <span className="goal-len">{len} Letter</span>
            <span className="goal-count">{got}/{total}</span>
          </div>
        )
      })}
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

function GameMode({ mapId, onStart, ready }) {
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
            onClick={() => onStart(m.id)}
            disabled={!ready}
          >
            <span className="mode-name">{m.name}</span>
            <MiniShape map={m} />
          </button>
        ))}
      </div>
    </div>
  )
}

function FoundList({ found, empty = null }) {
  if (found.length === 0)
    return empty ? <p className="found-empty">{empty}</p> : null
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

// The home screen: pick which game mode to play.
function ModeSelect({ ready, onWordHunt, onFlags, onDeep, onReels }) {
  return (
    <div className="card">
      <h1>Sammy Word</h1>
      <p>Choose a game mode.</p>
      <div className="mode-list">
        <button className="mode-tile" onClick={onWordHunt} disabled={!ready}>
          <span className="mode-tile-icon">🔤</span>
          <span className="mode-tile-text">
            <span className="mode-tile-title">Word Hunt</span>
            <span className="mode-tile-sub">
              Trace letters on a board to find as many words as you can
            </span>
          </span>
        </button>
        <button className="mode-tile" onClick={onFlags}>
          <span className="mode-tile-icon">🚩</span>
          <span className="mode-tile-text">
            <span className="mode-tile-title">Flag Match</span>
            <span className="mode-tile-sub">
              Match each flag to its country against the clock
            </span>
          </span>
        </button>
        <button className="mode-tile" onClick={onDeep}>
          <span className="mode-tile-icon">💎</span>
          <span className="mode-tile-text">
            <span className="mode-tile-title">Deep Cut</span>
            <span className="mode-tile-sub">
              Name something — the more obscure your answer, the more it scores
            </span>
          </span>
        </button>
        <button className="mode-tile" onClick={onReels}>
          <span className="mode-tile-icon">📱</span>
          <span className="mode-tile-text">
            <span className="mode-tile-title">Scroll Recall</span>
            <span className="mode-tile-sub">
              Scroll today's 8 space reels, then see how much you remember
            </span>
          </span>
        </button>
      </div>
      {!ready && <p className="muted-note">Loading dictionary…</p>}
    </div>
  )
}

function Home({ onStart, ready, mapId, onBack }) {
  return (
    <div className="card">
      <button className="btn-back" onClick={onBack}>← Modes</button>
      <h1>Word Hunt</h1>
      <p>Pick a map to play. Drag to connect letters and make words!</p>

      <button
        type="button"
        className={`daily-card ${mapId === 'daily' ? 'sel' : ''}`}
        onClick={() => onStart('daily')}
        disabled={!ready}
      >
        <MiniShape map={HEART} />
        <span className="daily-text">
          <span className="daily-title">❤️ Map of the Day</span>
          <span className="daily-sub">Same heart board for everyone today</span>
        </span>
      </button>

      <GameMode mapId={mapId} onStart={onStart} ready={ready} />
      {!ready && <p className="muted-note">Loading dictionary…</p>}
    </div>
  )
}

function ChallengeIntro({ challenge, ready, onAccept, onNew }) {
  const map = getMap(challenge.mapId)
  const board = boardFromLetters(map, challenge.letters)
  const who = challenge.name || 'A friend'
  const theirFound = wordsToFound(challenge.words)
  return (
    <div className="card">
      <h1>{who} challenged you!</h1>
      <p>
        They scored <b>{pad4(challenge.score)}</b> on the <b>{map.name}</b> board.
        Can you beat it?
      </p>
      <MiniBoard map={map} board={board} />
      {theirFound.length > 0 && (
        <div className="word-col">
          <span className="word-col-head">
            {who} found {theirFound.length} word{theirFound.length === 1 ? '' : 's'}
          </span>
          <FoundList found={theirFound} />
        </div>
      )}
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
  const [prompting, setPrompting] = useState(true) // name popup auto-opens at game over

  // Only fetch for display — the name popup opens automatically and posts the
  // score as soon as the player confirms their name.
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
        // Shows the top 3 at a glance; scroll within the list to see the rest.
        <ol className="lb-list">
          {data.entries.map((e, i) => (
            <li key={i} className={`${e.you ? 'you' : ''} ${i < 3 ? 'top' : ''}`}>
              <span className="lb-rank">{i + 1}</span>
              <span className="lb-name">{e.name}</span>
              <span className="lb-score">{pad4(e.score)}</span>
            </li>
          ))}
        </ol>
      )}
      {data.rank && <p className="lb-note">Your rank today: #{data.rank}</p>}
      {posted && <p className="lb-note posted">Posted! ✅</p>}
      {!posted && !prompting && (
        <button className="btn-link" onClick={() => setPrompting(true)}>
          Post your score
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

function DailyResult({ score, found, name, setName, onShare, shareMsg, onNew, dailyDate }) {
  return (
    <div className="card">
      <h1>Time!</h1>
      <div className="final-score">{pad4(score)}</div>
      <p>{found.length} word{found.length === 1 ? '' : 's'} found</p>
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
  const headline = tie ? "IT'S A TIE!" : win ? 'YOU WON!' : 'YOU LOST'
  const theirFound = wordsToFound(challenge.words)
  return (
    <div className="card compare-card">
      <div className={`outcome ${tie ? 'tie' : win ? 'won' : 'lost'}`}>{headline}</div>
      <ScoreDuel
        mine={found}
        theirs={theirFound}
        myScore={score}
        theirScore={challenge.score}
        theirName={them}
        iWin={win && !tie}
        theyWin={!win && !tie}
      />
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

// Head-to-head results: two mirrored columns of scored word tiles (yours on the
// left, your opponent's on the right), each topped by a WORDS/SCORE header and
// truncated to a preview until "View all words" is tapped. Mirrors the
// GamePigeon results screen.
const DUEL_PREVIEW = 15
function ScoreDuel({ mine, theirs, myScore, theirScore, theirName, iWin, theyWin }) {
  const [showAll, setShowAll] = useState(false)
  const sortWords = (arr) =>
    [...arr].sort((a, b) => b.points - a.points || a.word.localeCompare(b.word))
  const mineSorted = sortWords(mine)
  const theirsSorted = sortWords(theirs)
  const limit = showAll ? Infinity : DUEL_PREVIEW
  const hidden = Math.max(mineSorted.length, theirsSorted.length) - DUEL_PREVIEW
  return (
    <>
      <div className="duel">
        <DuelColumn
          name="You"
          words={mineSorted}
          count={mine.length}
          score={myScore}
          limit={limit}
          align="left"
          winner={iWin}
        />
        <DuelColumn
          name={theirName}
          words={theirsSorted}
          count={theirs.length}
          score={theirScore}
          limit={limit}
          align="right"
          winner={theyWin}
        />
      </div>
      {hidden > 0 && (
        <button className="btn-viewall" onClick={() => setShowAll((s) => !s)}>
          {showAll ? 'Show fewer words' : 'View all words'}
        </button>
      )}
    </>
  )
}

function DuelColumn({ name, words, count, score, limit, align, winner }) {
  const shown = limit === Infinity ? words : words.slice(0, limit)
  const more = words.length - shown.length
  return (
    <div className={`duel-col ${align} ${winner ? 'winner' : ''}`}>
      <span className="duel-name">{name}</span>
      <div className="duel-head">
        <span className="duel-words">WORDS: {count}</span>
        <span className="duel-score">SCORE: {score}</span>
      </div>
      <div className="duel-list">
        {shown.map((f) => (
          <div className="duel-row" key={f.word}>
            <span className="found-chip">{f.word}</span>
            <span className="duel-pts">{f.points}</span>
          </div>
        ))}
        {shown.length === 0 && <p className="found-empty">No words</p>}
        {more > 0 && <p className="duel-more">({more} more)</p>}
      </div>
    </div>
  )
}
