#!/bin/zsh
# Builds build/Lockscape.app with Xcode (Release, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project Lockscape.xcodeproj -scheme Lockscape -configuration Release \
    -derivedDataPath build/DerivedData -quiet build
rm -rf build/Lockscape.app
cp -R build/DerivedData/Build/Products/Release/Lockscape.app build/
echo "Built build/Lockscape.app"
