#!/bin/zsh
# Packs an app into a drag-to-Applications disk image with a background: build/Lockscape-<version>.dmg
# Needs create-dmg (brew install create-dmg).
# Usage: scripts/make-dmg.sh path/to/Lockscape.app 1.2.3
set -euo pipefail
cd "$(dirname "$0")/.."
app=${1:?usage: scripts/make-dmg.sh Lockscape.app version}
version=${2:?usage: scripts/make-dmg.sh Lockscape.app version}
dmg=build/Lockscape-$version.dmg

staging=$(mktemp -d)
cp -R "$app" "$staging/"
mkdir -p build
rm -f "$dmg"
tiffutil -cathidpicheck dmg/background.png dmg/background@2x.png -out build/background.tiff

# create-dmg lays the window out through Finder, which is occasionally flaky; retry a few times.
for attempt in 1 2 3; do
    create-dmg \
        --volname Lockscape \
        --background build/background.tiff \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 128 \
        --icon Lockscape.app 160 185 \
        --app-drop-link 500 185 \
        --no-internet-enable \
        "$dmg" "$staging" && break
    [[ $attempt -lt 3 ]] || exit 1
    sleep 5
done
rm -rf "$staging"
echo "$dmg"
