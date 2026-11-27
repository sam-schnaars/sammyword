# Sammy Word

Two **independent, feature-equal** codebases for the same game:

- **Web** — Vite + React prototype: `src/` (UI/logic), `api/` (serverless), `public/words.txt`.
- **iOS** — native iMessage extension: `ios/SammyWordMessages/` (game lives here),
  `ios/SammyWord/` (host app). XcodeGen spec at `ios/project.yml`.

They share **no code**. Every feature is hand-ported to both sides.

## Parity is mandatory

`PARITY.md` is the source of truth for what exists where. **Whenever you add,
remove, or change user-facing behavior on either platform:**

1. Make the equivalent change on the **other** platform in the same task.
2. Update `PARITY.md` (the feature matrix + any scoring tables / known gaps).
3. If you must leave a temporary gap, say so explicitly and add it to
   `PARITY.md` → "Known gaps" with a reason.

Treat "ported to web only" or "ported to iOS only" as an incomplete task unless
the user explicitly scoped it to one platform.

## Verifying changes

- **Web:** `npm run build` (and `npm run dev` for a live check). The web app can
  be driven in a browser for visual verification.
- **iOS:** the project is generated with XcodeGen, so new `.swift` files under
  `ios/SammyWordMessages/` are picked up automatically — no pbxproj editing.
  After changes:

  ```bash
  cd ios
  xcodegen generate
  xcodebuild -project SammyWord.xcodeproj -scheme SammyWordMessages \
    -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
  ```

  Always run this build to confirm iOS changes compile before claiming done.

- **Seeing the iOS games:** the simulator's Messages app can't open iMessage
  apps, so the `SammyWordPreview` target runs the extension's SwiftUI screens
  as a plain app (everything except `MessagesViewController.swift`). Build the
  `SammyWordPreview` scheme, launch it in the simulator, and take screenshots
  with `xcrun simctl io booted screenshot`. It's never archived:
  `Scripts/archive.sh` builds only the SammyWord scheme.

## Conventions

- Keep game logic free of UIKit/Messages on iOS (it stays portable); only
  `MessagesViewController.swift` imports Messages/UIKit.
- Mirror file/concept names across platforms where practical (e.g. `flags.js` ↔
  `Flags.swift`) so the parity mapping stays obvious.
- Scoring tables, board shapes, the letter bag, and daily-seed algorithm must
  match byte-for-byte across platforms.
