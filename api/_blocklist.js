// Words that block a caption or name from being posted. Swearing is allowed
// (Sam's call, 2026-11-26); this blocks slurs, sexual terms and self-harm
// harassment. Extend it without a deploy through the CAPTIONS_BLOCKLIST env
// var (comma-separated). Words under 5 letters only match as whole words;
// longer ones also match inside other text.
// The leading underscore keeps Vercel from serving this file as a route.
export const BLOCKED_WORDS = [
  // slurs and hate
  'nigger', 'nigga', 'faggot', 'fag', 'retard', 'retarded', 'tranny', 'chink',
  'spic', 'kike', 'wetback', 'gook', 'raghead', 'beaner', 'dyke', 'nazi',
  // sexual
  'whore', 'slut', 'cock', 'pussy', 'penis', 'vagina', 'porn', 'nude', 'nudes',
  'rape', 'rapist', 'pedo', 'pedophile',
  // self-harm harassment
  'kys', 'killyourself',
]
