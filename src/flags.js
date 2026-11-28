// Country bank + quiz builder for the "Flag Match" mode. The quiz is built from
// a numeric seed so a challenge link replays the exact same questions for a
// friend — no backend needed (mirrors how Word Hunt shares a board).
//
// Flags render as emoji (two regional-indicator letters from the ISO country
// code), so there are no image assets to host. Note: flag emoji don't render on
// Windows/Chrome by default, but do on iOS, macOS, and Android.

export const FLAG_ROUND_SECONDS = 60
export const FLAG_QUESTIONS = 5
export const POINTS_PER_CORRECT = 100

// The quiz ramps up: flag 1 comes from tier 1 (flags everyone knows), flag 5
// from tier 5 (obscure), and from flag 3 on, the wrong answers include
// look-alike flags (Chad vs Romania, Monaco vs Indonesia). Tiers are by how
// familiar the flag is, not population. The list and the algorithm must stay
// identical to ios/SammyWordMessages/Flags.swift so a seed gives the same quiz.
export const TIERS = 5

// { name, code, tier }: code is the ISO 3166-1 alpha-2 code.
export const COUNTRIES = [
  { name: 'United States', code: 'US', tier: 1 },
  { name: 'United Kingdom', code: 'GB', tier: 1 },
  { name: 'France', code: 'FR', tier: 1 },
  { name: 'Germany', code: 'DE', tier: 1 },
  { name: 'Italy', code: 'IT', tier: 1 },
  { name: 'Spain', code: 'ES', tier: 1 },
  { name: 'Japan', code: 'JP', tier: 1 },
  { name: 'China', code: 'CN', tier: 1 },
  { name: 'Canada', code: 'CA', tier: 1 },
  { name: 'Brazil', code: 'BR', tier: 1 },
  { name: 'Mexico', code: 'MX', tier: 1 },
  { name: 'India', code: 'IN', tier: 1 },
  { name: 'Australia', code: 'AU', tier: 1 },
  { name: 'South Korea', code: 'KR', tier: 1 },
  { name: 'Russia', code: 'RU', tier: 1 },
  { name: 'Portugal', code: 'PT', tier: 2 },
  { name: 'Netherlands', code: 'NL', tier: 2 },
  { name: 'Switzerland', code: 'CH', tier: 2 },
  { name: 'Sweden', code: 'SE', tier: 2 },
  { name: 'Norway', code: 'NO', tier: 2 },
  { name: 'Greece', code: 'GR', tier: 2 },
  { name: 'Ireland', code: 'IE', tier: 2 },
  { name: 'Turkey', code: 'TR', tier: 2 },
  { name: 'Argentina', code: 'AR', tier: 2 },
  { name: 'South Africa', code: 'ZA', tier: 2 },
  { name: 'Egypt', code: 'EG', tier: 2 },
  { name: 'Israel', code: 'IL', tier: 2 },
  { name: 'Poland', code: 'PL', tier: 2 },
  { name: 'Ukraine', code: 'UA', tier: 2 },
  { name: 'New Zealand', code: 'NZ', tier: 2 },
  { name: 'Denmark', code: 'DK', tier: 2 },
  { name: 'Belgium', code: 'BE', tier: 2 },
  { name: 'Jamaica', code: 'JM', tier: 2 },
  { name: 'Finland', code: 'FI', tier: 3 },
  { name: 'Austria', code: 'AT', tier: 3 },
  { name: 'Iceland', code: 'IS', tier: 3 },
  { name: 'Czechia', code: 'CZ', tier: 3 },
  { name: 'Hungary', code: 'HU', tier: 3 },
  { name: 'Chile', code: 'CL', tier: 3 },
  { name: 'Colombia', code: 'CO', tier: 3 },
  { name: 'Peru', code: 'PE', tier: 3 },
  { name: 'Thailand', code: 'TH', tier: 3 },
  { name: 'Vietnam', code: 'VN', tier: 3 },
  { name: 'Indonesia', code: 'ID', tier: 3 },
  { name: 'Philippines', code: 'PH', tier: 3 },
  { name: 'Malaysia', code: 'MY', tier: 3 },
  { name: 'Singapore', code: 'SG', tier: 3 },
  { name: 'Nigeria', code: 'NG', tier: 3 },
  { name: 'Kenya', code: 'KE', tier: 3 },
  { name: 'Morocco', code: 'MA', tier: 3 },
  { name: 'Saudi Arabia', code: 'SA', tier: 3 },
  { name: 'United Arab Emirates', code: 'AE', tier: 3 },
  { name: 'Cuba', code: 'CU', tier: 3 },
  { name: 'Pakistan', code: 'PK', tier: 3 },
  { name: 'Uruguay', code: 'UY', tier: 3 },
  { name: 'Romania', code: 'RO', tier: 4 },
  { name: 'Bulgaria', code: 'BG', tier: 4 },
  { name: 'Croatia', code: 'HR', tier: 4 },
  { name: 'Serbia', code: 'RS', tier: 4 },
  { name: 'Slovakia', code: 'SK', tier: 4 },
  { name: 'Slovenia', code: 'SI', tier: 4 },
  { name: 'Luxembourg', code: 'LU', tier: 4 },
  { name: 'Lithuania', code: 'LT', tier: 4 },
  { name: 'Latvia', code: 'LV', tier: 4 },
  { name: 'Estonia', code: 'EE', tier: 4 },
  { name: 'Venezuela', code: 'VE', tier: 4 },
  { name: 'Ecuador', code: 'EC', tier: 4 },
  { name: 'Bolivia', code: 'BO', tier: 4 },
  { name: 'Paraguay', code: 'PY', tier: 4 },
  { name: 'Iraq', code: 'IQ', tier: 4 },
  { name: 'Syria', code: 'SY', tier: 4 },
  { name: 'Jordan', code: 'JO', tier: 4 },
  { name: 'Kuwait', code: 'KW', tier: 4 },
  { name: 'Qatar', code: 'QA', tier: 4 },
  { name: 'Ghana', code: 'GH', tier: 4 },
  { name: 'Senegal', code: 'SN', tier: 4 },
  { name: 'Ethiopia', code: 'ET', tier: 4 },
  { name: 'Tunisia', code: 'TN', tier: 4 },
  { name: 'Algeria', code: 'DZ', tier: 4 },
  { name: 'Bangladesh', code: 'BD', tier: 4 },
  { name: 'Nepal', code: 'NP', tier: 4 },
  { name: 'Sri Lanka', code: 'LK', tier: 4 },
  { name: 'Iran', code: 'IR', tier: 4 },
  { name: 'Malta', code: 'MT', tier: 4 },
  { name: 'Chad', code: 'TD', tier: 5 },
  { name: 'Andorra', code: 'AD', tier: 5 },
  { name: 'Moldova', code: 'MD', tier: 5 },
  { name: 'Monaco', code: 'MC', tier: 5 },
  { name: 'Ivory Coast', code: 'CI', tier: 5 },
  { name: 'Mali', code: 'ML', tier: 5 },
  { name: 'Guinea', code: 'GN', tier: 5 },
  { name: 'Cameroon', code: 'CM', tier: 5 },
  { name: 'Yemen', code: 'YE', tier: 5 },
  { name: 'Sudan', code: 'SD', tier: 5 },
  { name: 'Bahrain', code: 'BH', tier: 5 },
  { name: 'Honduras', code: 'HN', tier: 5 },
  { name: 'Nicaragua', code: 'NI', tier: 5 },
  { name: 'El Salvador', code: 'SV', tier: 5 },
  { name: 'Guatemala', code: 'GT', tier: 5 },
  { name: 'Liberia', code: 'LR', tier: 5 },
  { name: 'Tajikistan', code: 'TJ', tier: 5 },
  { name: 'Bhutan', code: 'BT', tier: 5 },
  { name: 'Kiribati', code: 'KI', tier: 5 },
  { name: 'Eswatini', code: 'SZ', tier: 5 },
  { name: 'Comoros', code: 'KM', tier: 5 },
  { name: 'Tuvalu', code: 'TV', tier: 5 },
  { name: 'Nauru', code: 'NR', tier: 5 },
  { name: 'Vanuatu', code: 'VU', tier: 5 },
  { name: 'Brunei', code: 'BN', tier: 5 },
  { name: 'Liechtenstein', code: 'LI', tier: 5 },
  { name: 'San Marino', code: 'SM', tier: 5 },
  { name: 'Niger', code: 'NE', tier: 5 },
  { name: 'Palau', code: 'PW', tier: 5 },
  { name: 'Maldives', code: 'MV', tier: 5 },
]

// Groups of flags that are easy to mix up.
export const LOOKALIKES = [
  ['TD', 'RO', 'AD', 'MD'],
  ['ID', 'MC', 'PL'],
  ['IE', 'CI', 'IT'],
  ['NL', 'LU', 'PY'],
  ['AU', 'NZ'],
  ['NO', 'IS', 'DK', 'FI', 'SE'],
  ['SN', 'ML', 'GN', 'CM'],
  ['CO', 'EC', 'VE'],
  ['SI', 'SK', 'RU', 'RS'],
  ['EG', 'IQ', 'SY', 'YE'],
  ['JO', 'SD', 'KW', 'AE'],
  ['BE', 'DE'],
  ['AT', 'LV'],
  ['HN', 'NI', 'SV', 'GT', 'AR'],
  ['GH', 'BO', 'LT', 'ET'],
  ['QA', 'BH'],
  ['HU', 'BG', 'IR', 'TJ'],
  ['US', 'LR', 'MY'],
  ['CU', 'UY', 'GR'],
  ['JP', 'BD', 'PW'],
  ['TR', 'TN'],
  ['CN', 'VN'],
  ['IN', 'NE'],
]

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

// Integer in 0..<n, matching SeededRNG.int on iOS.
function pick(n, rng) {
  return Math.min(Math.floor(rng() * n), n - 1)
}

// Look-alike country indices for `code`, in group order, without repeats.
function lookalikeIndices(code) {
  const out = []
  for (const g of LOOKALIKES) {
    if (!g.includes(code)) continue
    for (const c of g) {
      const j = COUNTRIES.findIndex((x) => x.code === c)
      if (c !== code && j >= 0 && !out.includes(j)) out.push(j)
    }
  }
  return out
}

// Build a deterministic quiz from `seed`: `count` flags, each with four
// country choices, getting harder as it goes (see TIERS above). Same seed,
// same quiz, on any device.
export function buildQuiz(seed, count = FLAG_QUESTIONS) {
  const rng = mulberry32(seed)
  const used = []
  const quiz = []
  for (let q = 0; q < count; q++) {
    const tier = 1 + Math.floor((q * TIERS) / count)
    let pool = COUNTRIES.map((_, i) => i).filter((i) => COUNTRIES[i].tier === tier && !used.includes(i))
    if (!pool.length) pool = COUNTRIES.map((_, i) => i).filter((i) => !used.includes(i))
    const i = pool[pick(pool.length, rng)]
    used.push(i)

    const lookCount = Math.min(3, Math.max(0, q - 1))
    const looks = shuffled(lookalikeIndices(COUNTRIES[i].code), rng).slice(0, lookCount)
    let near = COUNTRIES.map((_, j) => j).filter(
      (j) => j !== i && !looks.includes(j) && Math.abs(COUNTRIES[j].tier - tier) <= 1,
    )
    if (near.length < 3 - looks.length) near = COUNTRIES.map((_, j) => j).filter((j) => j !== i && !looks.includes(j))
    const fill = shuffled(near, rng).slice(0, 3 - looks.length)

    const country = COUNTRIES[i]
    const options = shuffled([i, ...looks, ...fill], rng).map((j) => COUNTRIES[j].name)
    quiz.push({
      flag: flagEmoji(country.code),
      name: country.name,
      options,
      answer: options.indexOf(country.name),
    })
  }
  return quiz
}
