// Community games shown under Daily Sammy. Other people's daily games, linked
// out to their own sites. `sponsor` marks a maker whose condition for being
// featured is that their ad runs on the card: the card gets a labelled ad slot.
//
// To add a game: append an entry. The grid makes room on its own.
export const COMMUNITY = [
  {
    id: 'magnitudle',
    name: 'Magnitudle',
    emoji: '🧮',
    blurb: 'One mind-bending number a day. Guess it, scored out of 100.',
    url: 'https://magnitudle.com/daily',
    sponsor: {
      // Placeholder until Magnitudle sends their creative. Size follows the
      // IAB medium rectangle so a standard ad drops in without layout changes.
      size: '300 × 250',
      note: 'Ad slot reserved for Magnitudle. Their creative goes here.',
    },
  },
]
