#!/bin/bash
# run.sh: type-check the two table snippets against the module this tree builds — positive must compile,
# negative must be rejected. The positive one says a table can be written over a collection of rows and
# that the row value reaches through ForEach and Group as the element's own type; the negative one says a
# Text is not table content. Build the module first (eidolon/build.sh), which writes eidolon/out/mods.
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd); O=$ROOT/eidolon/out
cd "$ROOT/eidolon"
source "$ROOT/pkg-env.sh"
for f in positive negative; do
  printf '%-9s ' "$f:"
  out=$($SWIFTC $PKGFLAGS $OCFLAGS -I "$O/mods" -module-cache-path "$O/mc" -enforce-exclusivity=unchecked \
        -suppress-warnings -typecheck -parse-as-library -module-name TableChecks \
        "$ROOT/eidolon/tools/tabletests/$f.swift" 2>&1)
  if [ -z "$out" ]; then echo "compiles"; else echo "rejected -- $(echo "$out" | grep -m1 'error:')"; fi
done
