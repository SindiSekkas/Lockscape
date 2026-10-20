#!/bin/zsh
# Runs the built app against the real WallpaperAgent without locking the screen: rapid
# lock/unlock bursts, a slow unlock and a crash while "locked". Unit tests cover the logic
# with a fake system; this catches macOS changes. Run it with the screen unlocked; the
# desktop wallpaper changes for a few seconds at a time and comes back.
#
# Usage: scripts/integration-test.sh image.png
set -euo pipefail
cd "$(dirname "$0")/.."

bin=build/Lockscape.app/Contents/MacOS/Lockscape
image=${1:?usage: scripts/integration-test.sh image.png}
state=/tmp/lockscape-selftest-state.plist
store=~/Library/Application\ Support/com.apple.wallpaper/Store/Index.plist
locked=com.sindisekkas.lockscape.test.locked
unlocked=com.sindisekkas.lockscape.test.unlocked

[[ -d build/Lockscape.app ]] || scripts/build.sh

fail() { echo "FAIL: $1"; pkill -f "$bin" || true; exit 1; }
providers() { plutil -p "$store" | grep -E 'Provider|Type' | tr -d ' \n'; }
desktop_url() { swift -e 'import AppKit; print(NSWorkspace.shared.desktopImageURL(for: NSScreen.main!)!.path)'; }
start() { LOCKSCAPE_TEST=1 LOCKSCAPE_IMAGE=$image LOCKSCAPE_STATE=$state $bin & pid=$!; sleep 1.5; }
post() { $bin --post "$1"; }

rm -f "$state"
providers_before=$(providers)
url_before=$(desktop_url)
[[ $url_before != "$image" ]] || fail "the lock image is already on the desktop; restore it first"

start
post $locked; sleep 0.3; post $unlocked; sleep 0.3
post $locked; post $locked; sleep 0.5; post $unlocked; post $unlocked; sleep 5
[[ -f $state ]] && fail "state not cleared after unlock"

post $locked; sleep 8; post $unlocked; sleep 4          # WallpaperAgent's deferred store writes must not undo the restore
[[ -f $state ]] && fail "state not cleared after a slow unlock"
[[ $(desktop_url) != "$image" ]] || fail "lock image still on the desktop after a slow unlock"

post $locked; sleep 2
[[ -f $state ]] || fail "state not written on lock"
[[ $(desktop_url) == "$image" ]] || fail "lock image is not on the desktop"
kill -9 $pid; sleep 0.5                       # crash while locked

start; sleep 4; kill $pid                     # relaunch must repair the desktop
[[ -f $state ]] && fail "state not cleared after recovery"
[[ $(providers) == "$providers_before" ]] || fail "wallpaper store changed: $providers_before -> $(providers)"
[[ $(desktop_url) == "$url_before" ]] || fail "desktop URL not restored"

echo "OK: lock/unlock bursts and crash recovery work, desktop wallpaper restored"
