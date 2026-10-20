#!/bin/zsh
# Fills the asset catalog's AppIcon set from one square PNG (1024x1024 or larger).
# This set is the fallback for macOS 14 and 15; macOS 26+ shows Lockscape/AppIcon.icon
# (Icon Composer format), whose layer image must fill the whole canvas.
# Usage: scripts/make-icon.sh logo.png
set -euo pipefail
cd "$(dirname "$0")/.."
source=${1:?usage: scripts/make-icon.sh logo.png}
set=Lockscape/Assets.xcassets/AppIcon.appiconset
for base in 16 32 128 256 512; do
    sips -z $base $base "$source" --out "$set/icon_${base}x${base}.png" >/dev/null
    sips -z $((base * 2)) $((base * 2)) "$source" --out "$set/icon_${base}x${base}@2x.png" >/dev/null
done
echo "Icon set written to $set"
