#!/bin/zsh
# Installs /Applications/Lockscape.app (admin users can write there without sudo; others get
# ~/Applications), registers it as a login item and starts it.
#
# Usage: scripts/install.sh [image.png]
set -euo pipefail
cd "$(dirname "$0")/.."

app=/Applications/Lockscape.app
[[ -w /Applications ]] || app=~/Applications/Lockscape.app
support=~/Library/Application\ Support/Lockscape

[[ -d build/Lockscape.app ]] || scripts/build.sh
mkdir -p "$(dirname "$app")" "$support"

# Backup of the only system file the app ever rewrites: WallpaperAgent's store.
cp ~/Library/Application\ Support/com.apple.wallpaper/Store/Index.plist \
   "$support/Index.plist.backup-$(date +%Y%m%d-%H%M%S)"

pkill -x Lockscape 2>/dev/null || true
rm -rf "$app"
cp -R build/Lockscape.app "$app"

if [[ -n "${1:-}" ]]; then
    defaults write com.sindisekkas.lockscape image "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
fi

"$app/Contents/MacOS/Lockscape" --register
open "$app"
echo "Installed $app"
echo "Lock screen image: $(defaults read com.sindisekkas.lockscape image 2>/dev/null || echo 'not set, choose one from the menu')"
