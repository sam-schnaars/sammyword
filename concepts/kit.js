// Shared helpers for the redesign concepts (pixel-art prototypes of Deep Cut).
// Each concept is a standalone page that reuses the real question bank + scoring.
export * from '../src/deepcut.js'

export const $ = (s) => document.querySelector(s)
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

// Build a sprite canvas from rows of palette characters ('.' = transparent).
export function sprite(rows, pal) {
  const w = Math.max(...rows.map((r) => r.length))
  const c = document.createElement('canvas')
  c.width = w
  c.height = rows.length
  const x = c.getContext('2d')
  rows.forEach((r, y) =>
    [...r].forEach((ch, i) => {
      if (pal[ch]) {
        x.fillStyle = pal[ch]
        x.fillRect(i, y, 1, 1)
      }
    }),
  )
  return c
}

export function flipped(src) {
  const c = document.createElement('canvas')
  c.width = src.width
  c.height = src.height
  const x = c.getContext('2d')
  x.translate(src.width, 0)
  x.scale(-1, 1)
  x.drawImage(src, 0, 0)
  return c
}

// Deterministic 0..1 noise for (x, y, salt) — used for terrain, stars, ore.
export function hash(x, y, s = 0) {
  let h = (Math.imul(x | 0, 374761393) + Math.imul(y | 0, 668265263) + Math.imul(s | 0, 1442695041)) | 0
  h = Math.imul(h ^ (h >>> 13), 1274126177)
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296
}

// Size the canvas backing store to a fixed logical width; returns logical height.
export function fit(canvas, W) {
  const r = canvas.getBoundingClientRect()
  const H = Math.max(40, Math.round((W * r.height) / Math.max(1, r.width)))
  if (canvas.width !== W || canvas.height !== H) {
    canvas.width = W
    canvas.height = H
  }
  return H
}

export function loop(fn) {
  let last = performance.now()
  const f = (t) => {
    const dt = Math.min(0.05, (t - last) / 1000)
    last = t
    fn(dt, t / 1000)
    requestAnimationFrame(f)
  }
  requestAnimationFrame(f)
}

export function disc(g, cx, cy, r, color) {
  g.fillStyle = color
  for (let y = -r; y <= r; y++) {
    const w = Math.floor(Math.sqrt(r * r - y * y))
    g.fillRect(Math.round(cx - w), Math.round(cy + y), w * 2 + 1, 1)
  }
}

export function shuffle(a) {
  const b = [...a]
  for (let i = b.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[b[i], b[j]] = [b[j], b[i]]
  }
  return b
}
