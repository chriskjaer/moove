#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="$PWD/dist/Moove.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift scripts/make-icon.swift
/usr/bin/iconutil -c icns dist/Moove.iconset -o "$APP/Contents/Resources/Moove.icns"
cp "$(swift build -c release --show-bin-path)/Moove" "$APP/Contents/MacOS/Moove"
cp Info.plist "$APP/Contents/Info.plist"
# A default ad-hoc requirement embeds the binary hash, changing with every
# rebuild. Use an identifier requirement for this personal local app instead.
# This is not a developer identity or a substitute for notarized distribution.
/usr/bin/codesign --force --sign - --identifier ai.chriskjaer.moove \
    --requirements '=designated => identifier "ai.chriskjaer.moove"' "$APP"
# Reusing a bundle directory leaves its modification time unchanged. Notify
# Launch Services and Finder so they reload icon metadata after a rebuild.
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
printf "\nBuilt: %s\nInstall: cp -R dist/Moove.app ~/Applications/\n" "$APP"
