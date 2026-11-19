#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project GPXQuickLook.xcodeproj -scheme GPXQuickLook -configuration Release -derivedDataPath build "$@" build
codesign --verify --deep --strict 'build/Build/Products/Release/GPX QuickLook.app'
