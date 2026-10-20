#!/bin/zsh
# Removes everything install.sh created. Puts the desktop wallpaper back first if the
# lock image is still on it, and removes the login item before deleting the app.
set -uo pipefail

app=/Applications/Lockscape.app
[[ -d $app ]] || app=~/Applications/Lockscape.app
bin=$app/Contents/MacOS/Lockscape
support=~/Library/Application\ Support/Lockscape

pkill -x Lockscape 2>/dev/null
sleep 0.5
if [[ -x $bin ]]; then
    [[ -f "$support/state.plist" ]] && "$bin" --restore && echo "Desktop wallpaper restored"
    "$bin" --unregister
fi

rm -rf "$app" "$support"
defaults delete com.sindisekkas.lockscape 2>/dev/null
echo "Removed the app, login item, preferences, state and wallpaper store backups"
