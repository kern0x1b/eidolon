#!/bin/bash
# api-surface.sh [DIR]: what Eidolon lacks of Apple's SwiftUI, declaration by declaration.
# Dumps the API of Apple's SwiftUI (the iOS 16.4 interface, through the patched copy in fw/) and of the module built
# by ../eidolon/build.sh with swift-api-digester, and lists Apple's declarations that have no counterpart with the
# same signature. DIR (default ./api) receives apple.json, ours.json and gaps.txt; api-diff.py explains the columns.
set -e
cd "$(dirname "$0")"
source ../pkg-env.sh
O=${1:-api}
mkdir -p "$O"
DIGESTER=$SWIFTHOME/bin/swift-api-digester
$DIGESTER -dump-sdk -module SwiftUI -o "$O/apple.json" -sdk "$SDK" -target arm64-apple-ios16.4 -F "$PWD/fw" \
  -resource-dir "$RT/lib/swift" -swift-version 5 -avoid-tool-args -module-cache-path "$O/mc"
$DIGESTER -dump-sdk -module SwiftUI -o "$O/ours.json" -sdk "$SDK" -target armv7-apple-ios6.0 -I ../eidolon/out/mods $OCFLAGS \
  -resource-dir "$RT/lib/swift" -swift-version 5 -avoid-tool-args -module-cache-path "$O/mc"
python3 api-diff.py "$O/apple.json" "$O/ours.json" > "$O/gaps.txt"
sort "$O/gaps.txt" | cut -f1 | uniq -c | sort -rn | head -30
