// Board generation, adjacency, and scoring for Sammy Word.
// Modeled on Game Pigeon's "Word Hunt": a 4x4 grid where you connect
// adjacent (incl. diagonal) letters to spell words.

export const GRID_SIZE = 4
export const ROUND_SECONDS = 80

// Classic Boggle dice — each die contributes one face to the board, which
// keeps the letter distribution playable (vowels/consonants balanced).
const DICE = [
  'AAEEGN', 'ABBJOO', 'ACHOPS', 'AFFKPS',
  'AOOTTW', 'CIMOTU', 'DEILRX', 'DELRVY',
  'DISTTY', 'EEGHNW', 'EEINSU', 'EHRTVW',
  'EIOSST', 'ELRTTY', 'HIMNUQ', 'HLNNRZ',
]

// Game Pigeon "Word Hunt" length -> points table.
const SCORE_BY_LENGTH = { 3: 100, 4: 400, 5: 800, 6: 1400, 7: 1800 }

export function scoreForWord(word) {
  const len = word.length
  if (len < 3) return 0
  return SCORE_BY_LENGTH[len] ?? 2200 // 8+ letters all score 2200
}

function shuffle(arr) {
  const a = arr.slice()
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

// Returns a flat array of GRID_SIZE*GRID_SIZE uppercase letters.
export function generateBoard() {
  const dice = shuffle(DICE)
  return dice.map((die) => die[Math.floor(Math.random() * die.length)])
}

// Two cell indices are adjacent if they touch horizontally, vertically,
// or diagonally on the grid.
export function areAdjacent(a, b) {
  const ar = Math.floor(a / GRID_SIZE)
  const ac = a % GRID_SIZE
  const br = Math.floor(b / GRID_SIZE)
  const bc = b % GRID_SIZE
  const dr = Math.abs(ar - br)
  const dc = Math.abs(ac - bc)
  return dr <= 1 && dc <= 1 && !(dr === 0 && dc === 0)
}
