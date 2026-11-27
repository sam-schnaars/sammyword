// Caption the Meme's daily pictures: public-domain paintings and NASA photos
// from Wikimedia Commons (each marked "Public domain" there, checked
// 2026-11-27). The app loads them straight from Wikimedia's image servers.
// Day N gets MEMES[(N - 1) % MEMES.length], so everyone captions the same one.
// Edit this list to change the rotation; no app update needed. Only add
// images that are public domain or CC0, and keep them suitable for all ages
// (App Store guidelines 5.2.1 and 2.3.8).
export const MEMES = [
  ["Dogs Playing Poker (Coolidge, 1903)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/8/8b/A_Friend_in_Need_1903_C.M.Coolidge.jpg/960px-A_Friend_in_Need_1903_C.M.Coolidge.jpg", 800, 573, "A Friend in Need 1903 C.M.Coolidge.jpg"],
  ["The Laughing Cavalier (Hals, 1624)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/d/d1/Frans_Hals_%E2%80%93_The_Laughing_Cavalier.jpg/960px-Frans_Hals_%E2%80%93_The_Laughing_Cavalier.jpg", 800, 977, "Frans Hals – The Laughing Cavalier.jpg"],
  ["Mona Lisa (Leonardo, c. 1503)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/e/ec/Mona_Lisa%2C_by_Leonardo_da_Vinci%2C_from_C2RMF_retouched.jpg/960px-Mona_Lisa%2C_by_Leonardo_da_Vinci%2C_from_C2RMF_retouched.jpg", 800, 1192, "Mona Lisa, by Leonardo da Vinci, from C2RMF retouched.jpg"],
  ["The Scream (Munch, 1893)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c5/Edvard_Munch%2C_1893%2C_The_Scream%2C_oil%2C_tempera_and_pastel_on_cardboard%2C_91_x_73_cm%2C_National_Gallery_of_Norway.jpg/960px-Edvard_Munch%2C_1893%2C_The_Scream%2C_oil%2C_tempera_and_pastel_on_cardboard%2C_91_x_73_cm%2C_National_Gallery_of_Norway.jpg", 800, 993, "Edvard Munch, 1893, The Scream, oil, tempera and pastel on cardboard, 91 x 73 cm, National Gallery of Norway.jpg"],
  ["Napoleon Crossing the Alps (David, 1801)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/f/fd/David_-_Napoleon_crossing_the_Alps_-_Malmaison2.jpg/960px-David_-_Napoleon_crossing_the_Alps_-_Malmaison2.jpg", 800, 974, "David - Napoleon crossing the Alps - Malmaison2.jpg"],
  ["The Cossacks Write a Letter (Repin, 1891)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/7/73/Repin_Cossacks.jpg/960px-Repin_Cossacks.jpg", 800, 472, "Repin Cossacks.jpg"],
  ["Surprised! (Rousseau, 1891)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/f/fa/Surprised-Rousseau.jpg/960px-Surprised-Rousseau.jpg", 800, 639, "Surprised-Rousseau.jpg"],
  ["Girl with a Pearl Earring (Vermeer, c. 1665)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/0/0f/1665_Girl_with_a_Pearl_Earring.jpg/960px-1665_Girl_with_a_Pearl_Earring.jpg", 800, 947, "1665 Girl with a Pearl Earring.jpg"],
  ["Whistler's Mother (Whistler, 1871)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/1/1b/Whistlers_Mother_high_res.jpg/960px-Whistlers_Mother_high_res.jpg", 800, 712, "Whistlers Mother high res.jpg"],
  ["Wanderer above the Sea of Fog (Friedrich, c. 1818)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/b/b9/Caspar_David_Friedrich_-_Wanderer_above_the_sea_of_fog.jpg/960px-Caspar_David_Friedrich_-_Wanderer_above_the_sea_of_fog.jpg", 800, 1024, "Caspar David Friedrich - Wanderer above the sea of fog.jpg"],
  ["Washington Crossing the Delaware (Leutze, 1851)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/9/95/Washington_Crossing_the_Delaware_by_Emanuel_Leutze%2C_MMA-NYC%2C_1851.jpg/960px-Washington_Crossing_the_Delaware_by_Emanuel_Leutze%2C_MMA-NYC%2C_1851.jpg", 800, 513, "Washington Crossing the Delaware by Emanuel Leutze, MMA-NYC, 1851.jpg"],
  ["Lady with an Ermine (Leonardo, c. 1490)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/f/f9/Lady_with_an_Ermine_-_Leonardo_da_Vinci_-_Google_Art_Project.jpg/960px-Lady_with_an_Ermine_-_Leonardo_da_Vinci_-_Google_Art_Project.jpg", 800, 1076, "Lady with an Ermine - Leonardo da Vinci - Google Art Project.jpg"],
  ["The Arnolfini Portrait (van Eyck, 1434)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/3/33/Van_Eyck_-_Arnolfini_Portrait.jpg/960px-Van_Eyck_-_Arnolfini_Portrait.jpg", 800, 1094, "Van Eyck - Arnolfini Portrait.jpg"],
  ["Diogenes in His Barrel (Gérôme, 1860)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/b/b1/Jean-L%C3%A9on_G%C3%A9r%C3%B4me_-_Diogenes_-_Walters_37131.jpg/960px-Jean-L%C3%A9on_G%C3%A9r%C3%B4me_-_Diogenes_-_Walters_37131.jpg", 800, 588, "Jean-Léon Gérôme - Diogenes - Walters 37131.jpg"],
  ["Henry VIII (Holbein, c. 1537)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c7/Hans_Holbein%2C_the_Younger%2C_Around_1497-1543_-_Portrait_of_Henry_VIII_of_England_-_Google_Art_Project.jpg/960px-Hans_Holbein%2C_the_Younger%2C_Around_1497-1543_-_Portrait_of_Henry_VIII_of_England_-_Google_Art_Project.jpg", 800, 1123, "Hans Holbein, the Younger, Around 1497-1543 - Portrait of Henry VIII of England - Google Art Project.jpg"],
  ["Van Gogh Self-Portrait (1887)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/4/4c/Vincent_van_Gogh_-_Self-Portrait_-_Google_Art_Project_%28454045%29.jpg/960px-Vincent_van_Gogh_-_Self-Portrait_-_Google_Art_Project_%28454045%29.jpg", 800, 1011, "Vincent van Gogh - Self-Portrait - Google Art Project (454045).jpg"],
  ["Earthrise (NASA, 1968)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/a/a8/NASA-Apollo8-Dec24-Earthrise.jpg/960px-NASA-Apollo8-Dec24-Earthrise.jpg", 800, 800, "NASA-Apollo8-Dec24-Earthrise.jpg"],
  ["Buzz Aldrin on the Moon (NASA, 1969)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/9/98/Aldrin_Apollo_11_original.jpg/960px-Aldrin_Apollo_11_original.jpg", 800, 805, "Aldrin Apollo 11 original.jpg"],
  ["The Great Wave (Hokusai, c. 1831)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/a/a5/Tsunami_by_hokusai_19th_century.jpg/960px-Tsunami_by_hokusai_19th_century.jpg", 800, 538, "Tsunami by hokusai 19th century.jpg"],
  ["The Starry Night (van Gogh, 1889)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/e/ea/Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg/960px-Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg", 800, 633, "Van Gogh - Starry Night - Google Art Project.jpg"],
  ["The Ambassadors (Holbein, 1533)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/8/88/Hans_Holbein_the_Younger_-_The_Ambassadors_-_Google_Art_Project.jpg/960px-Hans_Holbein_the_Younger_-_The_Ambassadors_-_Google_Art_Project.jpg", 800, 788, "Hans Holbein the Younger - The Ambassadors - Google Art Project.jpg"],
  ["Napoleon in His Study (David, 1812)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/5/50/Jacques-Louis_David_-_The_Emperor_Napoleon_in_His_Study_at_the_Tuileries_-_Google_Art_Project.jpg/960px-Jacques-Louis_David_-_The_Emperor_Napoleon_in_His_Study_at_the_Tuileries_-_Google_Art_Project.jpg", 800, 1334, "Jacques-Louis David - The Emperor Napoleon in His Study at the Tuileries - Google Art Project.jpg"],
  ["The Fighting Temeraire (Turner, 1839)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/3/30/The_Fighting_Temeraire%2C_JMW_Turner%2C_National_Gallery.jpg/960px-The_Fighting_Temeraire%2C_JMW_Turner%2C_National_Gallery.jpg", 800, 594, "The Fighting Temeraire, JMW Turner, National Gallery.jpg"],
  ["The Tower of Babel (Bruegel, 1563)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/f/fc/Pieter_Bruegel_the_Elder_-_The_Tower_of_Babel_%28Vienna%29_-_Google_Art_Project_-_edited.jpg/960px-Pieter_Bruegel_the_Elder_-_The_Tower_of_Babel_%28Vienna%29_-_Google_Art_Project_-_edited.jpg", 800, 585, "Pieter Bruegel the Elder - The Tower of Babel (Vienna) - Google Art Project - edited.jpg"],
  ["The Gleaners (Millet, 1857)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/1/1f/Jean-Fran%C3%A7ois_Millet_-_Gleaners_-_Google_Art_Project_2.jpg/960px-Jean-Fran%C3%A7ois_Millet_-_Gleaners_-_Google_Art_Project_2.jpg", 800, 599, "Jean-François Millet - Gleaners - Google Art Project 2.jpg"],
  ["Dance at Le Moulin de la Galette (Renoir, 1876)", "https://thumb.wikimedia.org/wikipedia/commons/thumb/2/21/Pierre-Auguste_Renoir%2C_Le_Moulin_de_la_Galette.jpg/960px-Pierre-Auguste_Renoir%2C_Le_Moulin_de_la_Galette.jpg", 800, 596, "Pierre-Auguste Renoir, Le Moulin de la Galette.jpg"],
  ["Red Fuji (Hokusai, c. 1831)", "https://upload.wikimedia.org/wikipedia/commons/7/7f/Hokusai-fuji7.png", 800, 500, "Hokusai-fuji7.png"],
].map(([name, url, width, height, source]) => ({
  name,
  url,
  width,
  height,
  source: `https://commons.wikimedia.org/wiki/File:${encodeURIComponent(source.replace(/ /g, '_'))}`,
}))

export const memeFor = (day) => MEMES[(((day - 1) % MEMES.length) + MEMES.length) % MEMES.length]
