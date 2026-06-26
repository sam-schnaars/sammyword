#!/bin/bash
# Build the full word list from the system dictionary on macOS.
# Keeps only 3–16 letter alphabetic words, uppercases them, de-dupes, sorts.
# Output: SammyWordMessages/Resources/words.txt
set -euo pipefail

SRC="/usr/share/dict/words"
DEST="$(cd "$(dirname "$0")/.." && pwd)/SammyWordMessages/Resources/words.txt"

if [[ ! -f "$SRC" ]]; then
  echo "error: $SRC not found (expected on macOS)." >&2
  exit 1
fi

LC_ALL=C grep -E '^[A-Za-z]{3,16}$' "$SRC" \
  | tr '[:lower:]' '[:upper:]' \
  | sort -u > "$DEST"

echo "Wrote $(wc -l < "$DEST" | tr -d ' ') words to $DEST"
