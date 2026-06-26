# Sammy Word — iMessage Game (native iOS)

A native iOS **iMessage app** that clones GamePigeon's **Word Hunt**, used as
scaffolding (the concept will be re-themed later). Swift + SwiftUI. The game
logic is intentionally free of UIKit/Messages so it stays portable.

> This is the **native iOS** version. (The web/React prototype lives in the
> repo root and is unrelated.)

## What's here

```
ios/
  project.yml                     # XcodeGen spec (two targets)
  Scripts/fetch_words.sh          # builds the full dictionary from the Mac word list
  SammyWord/                      # container iOS app (required host)
    SammyWordApp.swift
    Info.plist
    Assets.xcassets/
  SammyWordMessages/              # the iMessage extension — the game
    MessagesViewController.swift  # MSMessagesAppViewController + UIHostingController
    GameSession.swift             # SwiftUI ↔ Messages bridge (callbacks)
    RootView.swift                # compact vs expanded
    GameView.swift                # board UI, drag selection, trail
    WordHuntGame.swift            # selection state, scoring, 80s timer
    GameBoard.swift               # tiles, Boggle dice, adjacency
    Scoring.swift                 # Word Hunt score table
    WordDictionary.swift          # loads words.txt into a Set
    GameMessage.swift             # URL encode/decode of game state
    Theme.swift                   # all colors & fonts (re-theme here)
    Info.plist                    # NSExtension config
    Resources/words.txt           # starter dictionary (run the script for the full one)
    Assets.xcassets/              # iMessage App Icon (placeholder slots)
```

## Prerequisites

- **Xcode** (Mac App Store) — full Xcode, not just Command Line Tools.
- Optional: **XcodeGen** — `brew install xcodegen`.

## Generate & open

```bash
cd ios
brew install xcodegen          # once
xcodegen generate              # creates SammyWord.xcodeproj
./Scripts/fetch_words.sh       # populate the full ~200k-word dictionary
open SammyWord.xcodeproj
```

The starter `words.txt` (a few hundred common words) is committed so the project
builds before you run the script.

### No-XcodeGen fallback

Prefer not to use XcodeGen? In Xcode: **File → New → Project → iOS → iMessage
Application**. Then delete the template's generated Swift files and drag in the
files from `SammyWord/` and `SammyWordMessages/` (add `words.txt` to the
extension target's "Copy Bundle Resources"). Set the extension's Info.plist
`NSExtensionPrincipalClass` to `$(PRODUCT_MODULE_NAME).MessagesViewController`.

## Test — fastest path: iOS Simulator (no Apple account, no signing)

1. In Xcode, select the **SammyWordMessages** scheme and any **iOS Simulator**.
2. **Run** ▶. Xcode launches the simulator's **Messages** app.
3. The simulator Messages has a built-in sample conversation. Open it, tap the
   **apps** icon next to the text field, and pick **Sammy Word** in the drawer.
4. Tap to expand, play a round, then **Challenge a friend** to insert a message.
5. Tap the **other side** of the conversation's message bubble to open it as the
   recipient — it replays the **same board**, then compares scores.

## Test on your own iPhone — FREE (no $99 program)

You do **not** need the paid Apple Developer Program to run on your own device.
Adding your Apple ID in Xcode creates a **free Personal Team**.

**Caveats (state plainly):**
- Apps signed with a free account **expire after 7 days** — reinstall to keep
  using it.
- Free accounts are limited to a **small number of App IDs**.

**Steps:**
1. Connect your iPhone via USB and **trust** the computer.
2. For **both** targets (SammyWord and SammyWordMessages):
   **Signing & Capabilities → Automatically manage signing →** add your Apple ID
   → select your **Personal Team**.
3. Use a unique reverse-DNS bundle id, e.g. `com.YOURNAME.SammyWord` (and the
   extension `com.YOURNAME.SammyWord.SammyWordMessages`). Edit these in
   `project.yml` (then re-run `xcodegen generate`) or in Xcode.
4. Select your **device** as the run destination and **Run**.
5. On the iPhone: **Settings → General → VPN & Device Management →** trust your
   developer certificate (first run only).
6. Open **Messages → a conversation →** tap the **apps** icon by the text field
   → enable **Sammy Word** in the drawer → play.

## Paid Apple Developer Program ($99/yr) — when you actually need it

Only required for:
- **TestFlight** and sharing with other people,
- **App Store** submission,
- removing the **7-day expiry**.

Enroll at **developer.apple.com → Account → Enroll** (individual enrollment for
personal use).

## Game spec (implemented)

- **4×4** board from the classic 16 **Boggle dice**; the "Qu" die is a tile whose
  value is `QU` and counts as 2 letters.
- **Drag** to connect 8-directionally adjacent tiles; backtrack by dragging onto
  the previous tile.
- Valid word = **≥3 letters**, in the dictionary, not already found.
- **Scoring:** 3→100, 4→400, 5→800, 6→1400, 7→1800, 8+→2200.
- **80-second** round with countdown; dedup'd found-words list + total score.
- **iMessage turn model:** state is serialized into `MSMessage.url`
  (`b` = tiles, `cs` = challenger score, `cn` = challenger name). Start fresh →
  play → send a challenge; open a challenge → play the same board → compare.

## Re-theming later

All colors and fonts are in **`Theme.swift`**. The game rules
(`WordHuntGame`, `GameBoard`, `Scoring`) import only Foundation/Combine, so they
move cleanly to a new concept.

## Notes / gotchas

- Dictionary comes from the system word list **`/usr/share/dict/words`** — no
  network, no guessed URLs.
- Placeholder app icons are fine for development. **Real iMessage App Icon sizes
  are required before any App Store submission** (the icon set's `Contents.json`
  slots are scaffolded; drop in PNGs later).
