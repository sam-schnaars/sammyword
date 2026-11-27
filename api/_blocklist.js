// Words that block a caption or name from being posted. A starting list of
// slurs and the strongest profanity. Extend it without a deploy through the
// CAPTIONS_BLOCKLIST env var (comma-separated). Words under 5 letters only
// match as whole words; longer ones also match inside other text.
// The leading underscore keeps Vercel from serving this file as a route.
export const BLOCKED_WORDS = [
  'fuck', 'fucker', 'fucking', 'fucked', 'motherfucker', 'shit', 'shitty', 'bullshit', 'cunt', 'bitch', 'whore', 'slut',
  'nigger', 'nigga', 'faggot', 'fag', 'retard', 'retarded', 'tranny', 'chink',
  'spic', 'kike', 'wetback', 'gook', 'raghead', 'beaner', 'dyke',
  'rape', 'rapist', 'pedo', 'pedophile', 'nazi', 'kys', 'killyourself',
  'cock', 'dick', 'pussy', 'penis', 'vagina', 'porn', 'nude', 'nudes',
]
