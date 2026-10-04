#!/bin/bash
# snapshots.sh [--accept]: render the snapshot scenarios in the emulated device and compare them with
# eidolon/Snapshots/reference. The scenarios need a key window and SpringBoard's own lifecycle, so they
# are the demo application built as the snapshot bundle (the same sources, another Info.plist) and
# started through SpringBoard by xmake emulate launch; until-exit holds the guest until it has rendered
# them all and quit. Every scenario is drawn as well as dumped, so the picture can be looked at.
# ONLY=<name> renders one scenario: it is a key of the bundle's Info.plist, so the port is configured
# with it and the bundle rebuilt.
set -eu
cd "$(dirname "$0")"
accept=${1:-}
name=snap-$(date +%H%M%S)
out=$PWD/runs.noindex/$name
mkdir -p "$out/shots"
EIDOLON_SNAPSHOT_ONLY=${ONLY:-} xmake -P eidolon f -p iphoneos -a armv7 -y > "$out/configure.log" 2>&1
status=0
xmake -P eidolon emulate -d iPod4,1 -r 6.0 -s "${SECONDS_BUDGET:-240}" -t 3000 \
    launch space.kern0x1b.eidolon.snapshots until-exit > "$out/launch.log" 2>&1 || status=$?
cat "$out/launch.log"
folder=$(sed -n 's/^run folder //p' "$out/launch.log" | tail -1)
if [ -z "$folder" ] || [ ! -d "$folder/results/eidolon-snapshots" ]; then
  echo "no snapshots were written; the launch log is $out/launch.log" >&2
  exit 1
fi
cp "$folder"/results/eidolon-snapshots/* "$out/shots/" 2>/dev/null || true
cp "$folder"/verdict.json "$out/" 2>/dev/null || true
grep -a "snapshot\|snapshots done" "$folder/results/app.stdout" 2>/dev/null || true
[ "$status" -ne 0 ] && { echo "the launch failed, exit=$status" >&2; exit "$status"; }
fail=0
for shot in "$out"/shots/*.txt; do
  [ -e "$shot" ] || { echo "no snapshots were written" >&2; exit 1; }
  base=$(basename "$shot"); reference=eidolon/Snapshots/reference/$base
  if [ ! -e "$reference" ] || [ "$accept" = --accept ]; then
    cp "$shot" "$reference"; echo "reference $base written"
  elif cmp -s "$shot" "$reference"; then
    echo "match $base"
  else
    echo "DIFFERS $base"; diff -u "$reference" "$shot" | head -20; fail=1
  fi
done
exit $fail
