#!/bin/bash
# Archive Sammy Word for upload, then open it in Xcode's Organizer
# (Distribute App → App Store Connect → Upload).
#
#   scripts/archive.sh appstore 14    # web games open in Safari (App Store)
#   scripts/archive.sh testflight 15  # web games embedded in Messages (TestFlight only)
#
# Each upload needs a new, higher build number. Upload TestFlight builds to
# TestFlight only: never attach them to an App Store version, because they
# embed other people's sites.
set -euo pipefail

kind="${1:-}"; build="${2:-}"
if [[ -z "$kind" || -z "$build" ]]; then
  echo "usage: scripts/archive.sh appstore|testflight <build number>" >&2
  exit 1
fi

case "$kind" in
  appstore) flags='$(inherited)' ;;
  testflight) flags='$(inherited) HOSTED_EMBED' ;;
  *) echo "kind must be appstore or testflight" >&2; exit 1 ;;
esac

cd "$(dirname "$0")/.."
xcodegen generate >/dev/null

stamp="$(date +%Y-%m-%d)"
dest="$HOME/Library/Developer/Xcode/Archives/$stamp/SammyWord $build ($kind).xcarchive"
xcodebuild -project SammyWord.xcodeproj -scheme SammyWord -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$dest" \
  CURRENT_PROJECT_VERSION="$build" SWIFT_ACTIVE_COMPILATION_CONDITIONS="$flags" \
  -allowProvisioningUpdates archive | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)"

echo "Archived build $build ($kind) to: $dest"
