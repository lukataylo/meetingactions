#!/bin/bash
# Builds Piroba.app with plain swiftc — no Xcode project.
set -e
cd "$(dirname "$0")"
APP="Piroba.app"
[[ -f Piroba.icns ]] || python3 icon.py
mkdir -p "$APP/Contents/MacOS"
swiftc -O -parse-as-library -target arm64-apple-macos14.4 \
  -o "$APP/Contents/MacOS/Piroba" src/*.swift
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources" && cp Piroba.icns "$APP/Contents/Resources/"
codesign -s - --force "$APP" 2>/dev/null   # ad-hoc, so TCC remembers the mic grant
echo "built $APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$PWD/$APP"   # so piroba:// URLs resolve
