#!/bin/bash
# run.sh: type-check the two table snippets against the module this tree builds — positive must compile,
# negative must be rejected. The positive one says a table can be written over a collection of rows and
# that the row value reaches through ForEach and Group as the element's own type; the negative one says a
# Text is not table content. Build the module first (eidolon/build.sh), which writes eidolon/out/mods.
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd); O=$ROOT/eidolon/out
cd "$ROOT/eidolon"
source "$ROOT/pkg-env.sh"
# The positive snippet must compile, and the negative one must be rejected for the reason it exists:
# a Text is not table content. Anything else -- a snippet that compiles, or one rejected for an
# unrelated reason -- is a failure, and this script's exit code is the gate.
status=0
check_one() {
  local name=$1 expect=$2
  local out
  out=$($SWIFTC $PKGFLAGS $OCFLAGS -I "$O/mods" -module-cache-path "$O/mc" -enforce-exclusivity=unchecked \
        -suppress-warnings -typecheck -parse-as-library -module-name TableChecks \
        "$ROOT/eidolon/tools/tabletests/$name.swift" 2>&1)
  local first
  first=$(echo "$out" | grep -m1 'error:')
  if [ "$expect" = compiles ]; then
    if [ -z "$out" ]; then printf '%-9s compiles\n' "$name:"
    else printf '%-9s FAIL -- it should compile: %s\n' "$name:" "$first"; status=1; fi
  else
    case "$first" in
      *"$expect"*) printf '%-9s rejected -- %s\n' "$name:" "$first" ;;
      *) printf '%-9s FAIL -- expected a rejection naming %s, got: %s\n' "$name:" "$expect" "${first:-it compiled}"; status=1 ;;
    esac
  fi
}
check_one positive compiles
check_one negative "conform to 'TableRowContent'"
exit $status
