#!/bin/bash
# surface-swiftui.sh [SDK26] > apple-26-surface.tsv
# Apple's 26.2 surface of the eight modules Eidolon re-exports, read with swift-syntax's SwiftParser
# by bridge/tools/surftool. The output is a data file api-invented.py reads when it is there; without
# it the gate falls back to its own parse of the same interfaces.
set -e
cd "$(dirname "$0")"
SDK26=${1:-${APPLE_26_SDK:-$HOME/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk}}
MODULES=${APPLE_26_MODULES:-"Swift SwiftUI SwiftUICore Foundation CoreFoundation Combine Observation CoreGraphics UIKit"}
paths=()
for m in $MODULES; do
  d=$(find "$SDK26" -name "$m.swiftmodule" -type d 2>/dev/null | head -1)
  [ -n "$d" ] && paths+=("$d"/*.swiftinterface)
done
if [ ! -d tools/surftool/swift-syntax ]; then
  git clone --depth 1 -b swift-DEVELOPMENT-SNAPSHOT-2026-09-21-a \
    https://github.com/swiftlang/swift-syntax tools/surftool/swift-syntax
fi
(cd tools/surftool && swift build -c release >/dev/null)
"tools/surftool/.build/release/surftool" "${paths[@]}"
