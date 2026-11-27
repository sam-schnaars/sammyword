// Caption the Meme's daily templates: famous single-caption memes, loaded by
// the app straight from Imgflip's image CDN (we don't host copies). Day N
// gets MEMES[(N - 1) % MEMES.length], so everyone captions the same one.
// Edit this list to change the rotation; no app update needed. Pick templates
// that work with one caption line (no multi-panel or labelled ones).
// Sizes are from Imgflip's get_memes API (2026-11-26).
export const MEMES = [
  ['Disaster Girl', '23ls.jpg', 500, 375],
  ['This Is Fine', 'wxica.jpg', 580, 282],
  ['Hide the Pain Harold', 'gk5el.jpg', 480, 601],
  ['Roll Safe Think About It', '1h7in3.jpg', 702, 395],
  ['Waiting Skeleton', '2fm6x.jpg', 298, 403],
  ['Change My Mind', '24y43o.jpg', 482, 361],
  ['Monkey Puppet', '2gnnjh.jpg', 923, 768],
  ['Surprised Pikachu', '2kbn1e.jpg', 1893, 1893],
  ['One Does Not Simply', '1bij.jpg', 568, 335],
  ['Bad Luck Brian', '1bip.jpg', 475, 562],
  ['Futurama Fry', '1bgw.jpg', 552, 414],
  ['Ancient Aliens', '26am.jpg', 500, 437],
  ['Grandma Finds The Internet', '1bhw.jpg', 640, 480],
  ['Leonardo DiCaprio Cheers', '39t1o.jpg', 600, 400],
  ['Laughing Leo', '4acd7j.png', 470, 470],
  ['Third World Skeptical Kid', '265k.jpg', 426, 426],
  ['Star Wars Yoda', '8k0sa.jpg', 620, 714],
  ['Absolute Cinema', '8d317n.png', 936, 725],
  ['Megamind Peeking', '64sz4u.png', 540, 540],
  ['Mocking Spongebob', '1otk96.jpg', 502, 353],
  ['Bernie Once Again Asking', '3oevdk.jpg', 750, 750],
  ['Pawn Stars Best I Can Do', '19vcz0.jpg', 624, 352],
  ['Squidward Window', '145qvv.jpg', 598, 420],
  ["They Don't Know", '4pn1an.png', 671, 673],
  ["Y'all Got Any More Of That", '21uy0f.jpg', 600, 471],
  ['Oprah You Get A', 'gtj5t.jpg', 620, 465],
].map(([name, file, width, height]) => ({ name, url: `https://i.imgflip.com/${file}`, width, height }))

export const memeFor = (day) => MEMES[(((day - 1) % MEMES.length) + MEMES.length) % MEMES.length]
