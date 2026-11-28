// Seed days for the Daily Sammy prototype.
//
// Each answer is "Display|alias|alias": pct, where pct is our estimate of the
// share of players (in %) who'd give that answer. These are hand-made guesses
// so the prototype has something to score against; the real game would start
// from them and then blend in what players actually typed (see `shareOf` in
// daily.js). An answer that isn't listed isn't accepted, so lists should be
// complete enough that an honest obscure answer is in there.
//
// Day 1 = 2026-11-24 (UTC). Days past the seed list loop back to the start.

export const DAY_ONE = '2026-11-24'

export const DAYS = [
  {
    prompt: 'Name a fruit',
    answers: {
      Apple: 24, Banana: 19, Orange: 9, Strawberry: 8, Grape: 5, Mango: 5,
      Pineapple: 3, Watermelon: 3, Peach: 2.5, Pear: 2, Cherry: 2, Kiwi: 1.8,
      Blueberry: 1.6, Lemon: 1.4, Raspberry: 1, Plum: 0.9, Papaya: 0.8,
      Coconut: 0.7, 'Grapefruit': 0.6, Lime: 0.6, Apricot: 0.5, Pomegranate: 0.5,
      Cantaloupe: 0.4, 'Dragon fruit|Dragonfruit|Pitaya': 0.4, Fig: 0.35,
      Avocado: 0.3, Tomato: 0.3, 'Passion fruit|Passionfruit': 0.25,
      'Lychee|Litchi': 0.25, Nectarine: 0.25, Blackberry: 0.25, Cranberry: 0.2,
      Guava: 0.2, Tangerine: 0.2, 'Clementine': 0.15, Date: 0.15,
      Persimmon: 0.12, Honeydew: 0.12, 'Star fruit|Starfruit|Carambola': 0.1,
      Durian: 0.1, Jackfruit: 0.1, Quince: 0.06, Kumquat: 0.06, Gooseberry: 0.05,
      Elderberry: 0.05, Rambutan: 0.04, Mangosteen: 0.04, Loquat: 0.03,
      Feijoa: 0.03, Pawpaw: 0.03, Salak: 0.02, Medlar: 0.02, Cherimoya: 0.02,
      'Soursop|Guanabana': 0.02, Jabuticaba: 0.01, Longan: 0.02, Tamarind: 0.03,
      'Ugli fruit|Ugli': 0.01, Yuzu: 0.03, Huckleberry: 0.03, Mulberry: 0.04,
    },
  },
  {
    prompt: 'Name a bird',
    answers: {
      Eagle: 14, Robin: 10, Penguin: 8, 'Blue jay|Bluejay': 6, Cardinal: 6,
      Owl: 6, Crow: 5, Pigeon: 4, Parrot: 4, Hawk: 3, Flamingo: 3, Sparrow: 3,
      Hummingbird: 2.5, Duck: 2.5, Seagull: 2, Ostrich: 2, Chicken: 2,
      Peacock: 1.8, Swan: 1.5, Falcon: 1.2, Toucan: 1, Pelican: 1, Woodpecker: 1,
      Goose: 0.9, Turkey: 0.8, Raven: 0.8, Emu: 0.6, Vulture: 0.5, Heron: 0.4,
      Stork: 0.3, Magpie: 0.3, Finch: 0.3, Canary: 0.3, Kiwi: 0.3, Starling: 0.2,
      Albatross: 0.2, Puffin: 0.2, Crane: 0.2, Dodo: 0.2, Macaw: 0.2,
      Cockatoo: 0.15, Kingfisher: 0.12, Wren: 0.12, Oriole: 0.1, Egret: 0.1,
      Osprey: 0.1, Condor: 0.1, Cassowary: 0.08, Roadrunner: 0.08, Ibis: 0.06,
      Nightingale: 0.06, Lark: 0.06, Chickadee: 0.06, Mockingbird: 0.05,
      Nuthatch: 0.03, Shoebill: 0.03, Kakapo: 0.02, Hoopoe: 0.02, Booby: 0.03,
      Tanager: 0.02, Bittern: 0.01, Plover: 0.02, Grebe: 0.02, Kestrel: 0.03,
      Lyrebird: 0.02, Quetzal: 0.02, Frigatebird: 0.01, Hornbill: 0.03,
    },
  },
  {
    prompt: 'Name a musical instrument',
    answers: {
      Guitar: 30, Piano: 25, Drums: 10, Violin: 9, Trumpet: 4, Flute: 3.5,
      Saxophone: 3, Cello: 2, Clarinet: 1.5, Harp: 1.3, Ukulele: 1, Bass: 1,
      Trombone: 0.9, Keyboard: 0.8, Tuba: 0.6, Harmonica: 0.5, Banjo: 0.5,
      Xylophone: 0.4, Accordion: 0.4, Oboe: 0.3, Viola: 0.3, Tambourine: 0.3,
      'French horn|Horn': 0.3, Recorder: 0.25, Triangle: 0.2, Bagpipes: 0.2,
      Bassoon: 0.15, Organ: 0.15, Mandolin: 0.12, Kazoo: 0.12, Sitar: 0.1,
      Marimba: 0.08, 'Double bass|Upright bass|Contrabass': 0.08, Piccolo: 0.08,
      Cowbell: 0.06, Bongos: 0.06, Didgeridoo: 0.06, Glockenspiel: 0.05,
      Harpsichord: 0.05, Theremin: 0.04, 'Steel drum|Steelpan': 0.04,
      Timpani: 0.04, Castanets: 0.03, Lute: 0.03, Zither: 0.02, Bodhran: 0.01,
      Oud: 0.01, Erhu: 0.01, Koto: 0.01, Shamisen: 0.01, Tabla: 0.02,
      'Hurdy-gurdy|Hurdy gurdy': 0.01, Ocarina: 0.03, Kalimba: 0.02, Melodica: 0.02,
      Euphonium: 0.02, Dulcimer: 0.02, Balalaika: 0.01, Celesta: 0.01,
      Cajon: 0.02, Djembe: 0.02,
    },
  },
  {
    prompt: 'Name a cheese',
    answers: {
      Cheddar: 30, Mozzarella: 14, Swiss: 7, Parmesan: 7, 'Brie': 5, 'American': 4,
      'Gouda': 4, 'Pepper jack|Pepperjack': 2.5, Feta: 2.5, Provolone: 2,
      'Colby jack|Colby': 1.5, 'Blue cheese|Blue': 1.5, Ricotta: 1.2,
      'Monterey jack|Jack': 1, 'Cream cheese': 1, 'Goat cheese|Chevre': 1,
      Gruyere: 0.8, Havarti: 0.7, Camembert: 0.6, 'Cottage cheese': 0.5,
      Muenster: 0.5, 'Gorgonzola': 0.5, Manchego: 0.4, Mascarpone: 0.4,
      Halloumi: 0.3, Asiago: 0.3, 'Roquefort': 0.3, Burrata: 0.25,
      'Pecorino|Pecorino romano': 0.2, Stilton: 0.2, Emmental: 0.15,
      Paneer: 0.15, 'Queso fresco': 0.12, Fontina: 0.1, Edam: 0.1, Limburger: 0.08,
      Jarlsberg: 0.06, Raclette: 0.06, Wensleydale: 0.05, Comte: 0.05,
      Taleggio: 0.04, Oaxaca: 0.04, 'Cotija': 0.04, Gjetost: 0.02, Reblochon: 0.02,
      Epoisses: 0.02, 'Red Leicester': 0.02, 'Caciocavallo': 0.01,
      'Casu marzu': 0.01, Labneh: 0.02, Stracchino: 0.01, Mimolette: 0.01,
    },
  },
  {
    prompt: 'Name a breed of dog',
    answers: {
      'Golden retriever|Golden': 18, 'Labrador|Lab|Labrador retriever': 16,
      'German shepherd': 10, Poodle: 7, Husky: 6, Chihuahua: 5, Bulldog: 4,
      Beagle: 4, Pug: 3, Dachshund: 3, Rottweiler: 2.5, Corgi: 2.5,
      'Pit bull|Pitbull': 2, Dalmatian: 1.5, Boxer: 1.2, 'Shih tzu': 1,
      'Border collie|Collie': 1, 'Great dane': 0.9, 'Yorkie|Yorkshire terrier': 0.9,
      Doberman: 0.8, 'Saint bernard|St bernard': 0.6, Greyhound: 0.5,
      'Bernese mountain dog|Bernese': 0.5, Maltese: 0.4, Pomeranian: 0.4,
      'Australian shepherd|Aussie': 0.4, 'Cocker spaniel': 0.3, Akita: 0.3,
      Mastiff: 0.25, 'Shiba inu|Shiba': 0.25, 'Bichon frise|Bichon': 0.2,
      Samoyed: 0.2, Bloodhound: 0.15, Weimaraner: 0.12, Whippet: 0.1,
      'Newfoundland': 0.1, Schnauzer: 0.1, 'Basset hound|Basset': 0.1,
      'Jack russell|Jack russell terrier': 0.1, Vizsla: 0.06, Malamute: 0.06,
      'Afghan hound': 0.05, Borzoi: 0.04, Basenji: 0.04, 'Shar pei': 0.04,
      'Chow chow|Chow': 0.05, Komondor: 0.02, Puli: 0.02, Leonberger: 0.02,
      Xoloitzcuintli: 0.01, 'Lagotto romagnolo|Lagotto': 0.01,
      'Kooikerhondje': 0.01, Saluki: 0.02, Keeshond: 0.02, 'Bedlington terrier': 0.01,
      'Norwegian lundehund|Lundehund': 0.01, Papillon: 0.03, Schipperke: 0.01,
    },
  },
]
