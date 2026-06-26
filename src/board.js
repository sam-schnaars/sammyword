// Board generation, adjacency, and scoring for Sammy Word.
// Modeled on Game Pigeon's "Word Hunt": connect adjacent (incl. diagonal)
// letters to spell words. Boards can be arbitrary shapes on a grid — a "mask"
// marks which cells exist; the rest are holes.

export const ROUND_SECONDS = 80

// Game Pigeon "Word Hunt" length -> points table.
const SCORE_BY_LENGTH = { 3: 100, 4: 400, 5: 800, 6: 1400, 7: 1800 }

export function scoreForWord(word) {
  const len = word.length
  if (len < 3) return 0
  return SCORE_BY_LENGTH[len] ?? 2200 // 8+ letters all score 2200
}

// Build a map from an ASCII template: '#' is a playable cell, anything else
// (e.g. '.') is a hole. Every row must be the same width.
function makeMap(id, name, rowsArr) {
  const rows = rowsArr.length
  const cols = rowsArr[0].length
  const mask = []
  for (const line of rowsArr) for (const ch of line) mask.push(ch === '#')
  return { id, name, rows, cols, mask, cells: mask.filter(Boolean).length }
}

export const MAPS = [
  makeMap('classic', 'Map 1', [
    '####',
    '####',
    '####',
    '####',
  ]),
  makeMap('donut', 'Map 2', [
    '.####.',
    '######',
    '##..##',
    '##..##',
    '######',
    '.####.',
  ]),
  makeMap('plus', 'Map 3', [
    '..##..',
    '..##..',
    '######',
    '######',
    '..##..',
    '..##..',
  ]),
  makeMap('diamond', 'Map 4', [
    '..##..',
    '.####.',
    '######',
    '######',
    '.####.',
    '..##..',
  ]),
]

export const getMap = (id) => MAPS.find((m) => m.id === id) || MAPS[0]

// Weighted letter bag (Scrabble-ish distribution) — keeps a healthy vowel ratio
// for any board size.
const LETTER_BAG = (() => {
  const freq = {
    A: 9, B: 2, C: 2, D: 4, E: 12, F: 2, G: 3, H: 2, I: 9, J: 1, K: 1, L: 4,
    M: 2, N: 6, O: 8, P: 2, Q: 1, R: 6, S: 4, T: 6, U: 4, V: 2, W: 2, X: 1,
    Y: 2, Z: 1,
  }
  let bag = ''
  for (const [k, v] of Object.entries(freq)) bag += k.repeat(v)
  return bag
})()

const VOWELS = new Set(['A', 'E', 'I', 'O', 'U'])
const randLetter = () => LETTER_BAG[Math.floor(Math.random() * LETTER_BAG.length)]

// Flat array of length rows*cols; holes are null, playable cells are letters.
// Retries until the board has a reasonable vowel ratio.
export function generateBoard(map) {
  const n = map.rows * map.cols
  let board = new Array(n).fill(null)
  for (let attempt = 0; attempt < 40; attempt++) {
    board = new Array(n).fill(null)
    let active = 0
    let vowels = 0
    for (let i = 0; i < n; i++) {
      if (map.mask[i]) {
        const L = randLetter()
        board[i] = L
        active++
        if (VOWELS.has(L)) vowels++
      }
    }
    if (active === 0 || vowels / active >= 0.32) break
  }
  return board
}

// The playable letters in index order — what we share in a challenge link.
export const boardLetters = (board) => board.filter((c) => c != null).join('')

// Rebuild a board for `map` from a shared letter string.
export function boardFromLetters(map, letters) {
  const n = map.rows * map.cols
  const board = new Array(n).fill(null)
  let k = 0
  for (let i = 0; i < n; i++) {
    if (map.mask[i]) board[i] = letters[k++] || randLetter()
  }
  return board
}

// Two cell indices are adjacent if they touch horizontally, vertically, or
// diagonally on a grid `cols` wide.
export function areAdjacent(a, b, cols) {
  const ar = Math.floor(a / cols)
  const ac = a % cols
  const br = Math.floor(b / cols)
  const bc = b % cols
  const dr = Math.abs(ar - br)
  const dc = Math.abs(ac - bc)
  return dr <= 1 && dc <= 1 && !(dr === 0 && dc === 0)
}
