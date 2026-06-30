// Country bank + quiz builder for the "Flag Match" mode. The quiz is built from
// a numeric seed so a challenge link replays the exact same questions for a
// friend — no backend needed (mirrors how Word Hunt shares a board).
//
// Flags render as emoji (two regional-indicator letters from the ISO country
// code), so there are no image assets to host. Note: flag emoji don't render on
// Windows/Chrome by default, but do on iOS, macOS, and Android.

export const FLAG_ROUND_SECONDS = 60
export const FLAG_QUESTIONS = 12
export const POINTS_PER_CORRECT = 100

// How strongly to bias prompts toward less-populated countries. The pick weight
// is 1 / pop^POP_BIAS, so higher = the big, common-knowledge flags (China, USA,
// India…) show up less and obscure flags show up more. 0 = ignore population.
export const POP_BIAS = 0.6

// { name, code, pop } — code is the ISO 3166-1 alpha-2 code; pop is approximate
// population in millions (used only to weight which flags get asked).
export const COUNTRIES = [
  { name: 'United States', code: 'US', pop: 340 },
  { name: 'United Kingdom', code: 'GB', pop: 68 },
  { name: 'France', code: 'FR', pop: 65 },
  { name: 'Germany', code: 'DE', pop: 84 },
  { name: 'Italy', code: 'IT', pop: 59 },
  { name: 'Spain', code: 'ES', pop: 48 },
  { name: 'Portugal', code: 'PT', pop: 10 },
  { name: 'Netherlands', code: 'NL', pop: 18 },
  { name: 'Belgium', code: 'BE', pop: 12 },
  { name: 'Switzerland', code: 'CH', pop: 9 },
  { name: 'Sweden', code: 'SE', pop: 10.5 },
  { name: 'Norway', code: 'NO', pop: 5.5 },
  { name: 'Finland', code: 'FI', pop: 5.6 },
  { name: 'Denmark', code: 'DK', pop: 5.9 },
  { name: 'Ireland', code: 'IE', pop: 5.2 },
  { name: 'Iceland', code: 'IS', pop: 0.39 },
  { name: 'Poland', code: 'PL', pop: 38 },
  { name: 'Greece', code: 'GR', pop: 10.4 },
  { name: 'Austria', code: 'AT', pop: 9 },
  { name: 'Czechia', code: 'CZ', pop: 10.7 },
  { name: 'Hungary', code: 'HU', pop: 9.6 },
  { name: 'Russia', code: 'RU', pop: 144 },
  { name: 'Ukraine', code: 'UA', pop: 38 },
  { name: 'Turkey', code: 'TR', pop: 85 },
  { name: 'Canada', code: 'CA', pop: 39 },
  { name: 'Mexico', code: 'MX', pop: 128 },
  { name: 'Brazil', code: 'BR', pop: 216 },
  { name: 'Argentina', code: 'AR', pop: 46 },
  { name: 'Chile', code: 'CL', pop: 19.6 },
  { name: 'Colombia', code: 'CO', pop: 52 },
  { name: 'Peru', code: 'PE', pop: 34 },
  { name: 'Japan', code: 'JP', pop: 124 },
  { name: 'China', code: 'CN', pop: 1410 },
  { name: 'South Korea', code: 'KR', pop: 52 },
  { name: 'India', code: 'IN', pop: 1430 },
  { name: 'Thailand', code: 'TH', pop: 72 },
  { name: 'Vietnam', code: 'VN', pop: 99 },
  { name: 'Indonesia', code: 'ID', pop: 277 },
  { name: 'Philippines', code: 'PH', pop: 117 },
  { name: 'Malaysia', code: 'MY', pop: 34 },
  { name: 'Singapore', code: 'SG', pop: 5.9 },
  { name: 'Australia', code: 'AU', pop: 26 },
  { name: 'New Zealand', code: 'NZ', pop: 5.2 },
  { name: 'South Africa', code: 'ZA', pop: 60 },
  { name: 'Egypt', code: 'EG', pop: 112 },
  { name: 'Nigeria', code: 'NG', pop: 223 },
  { name: 'Kenya', code: 'KE', pop: 55 },
  { name: 'Morocco', code: 'MA', pop: 37 },
  { name: 'Saudi Arabia', code: 'SA', pop: 37 },
  { name: 'United Arab Emirates', code: 'AE', pop: 9.4 },
  { name: 'Israel', code: 'IL', pop: 9.8 },
]

// Turn a 2-letter ISO code into its flag emoji (regional indicator symbols).
export function flagEmoji(code) {
  return code
    .toUpperCase()
    .replace(/./g, (c) => String.fromCodePoint(127397 + c.charCodeAt(0)))
}

// Small, fast, seedable PRNG (same family as the board generator's).
function mulberry32(seed) {
  let a = seed >>> 0
  return function () {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

// Fisher-Yates shuffle into a new array, driven by the supplied rng.
function shuffled(arr, rng) {
  const a = [...arr]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

// Weighted sampling of `count` items without replacement, driven by `rng`.
// `items` and `weights` are parallel arrays; higher weight = more likely.
function weightedSample(items, weights, count, rng) {
  const pool = items.map((it, i) => ({ it, w: weights[i] }))
  const out = []
  while (out.length < count && pool.length) {
    const total = pool.reduce((s, p) => s + p.w, 0)
    let r = rng() * total
    let k = 0
    while (k < pool.length - 1 && r >= pool[k].w) {
      r -= pool[k].w
      k++
    }
    out.push(pool[k].it)
    pool.splice(k, 1)
  }
  return out
}

// Build a deterministic quiz from `seed`: `count` flags, each with four country
// choices (one correct + three distractors), all seeded so the same seed
// reproduces the same quiz on any device. Prompt flags are drawn weighted toward
// less-populated countries (see POP_BIAS); distractors are drawn uniformly so
// wrong options stay plausible.
export function buildQuiz(seed, count = FLAG_QUESTIONS) {
  const rng = mulberry32(seed)
  const indices = COUNTRIES.map((_, i) => i)
  const weights = COUNTRIES.map((c) => 1 / Math.pow(c.pop, POP_BIAS))
  const chosen = weightedSample(indices, weights, Math.min(count, COUNTRIES.length), rng)

  return chosen.map((i) => {
    const country = COUNTRIES[i]
    const distractors = shuffled(
      indices.filter((j) => j !== i),
      rng,
    )
      .slice(0, 3)
      .map((j) => COUNTRIES[j].name)
    const options = shuffled([country.name, ...distractors], rng)
    return {
      flag: flagEmoji(country.code),
      name: country.name,
      options,
      answer: options.indexOf(country.name),
    }
  })
}
