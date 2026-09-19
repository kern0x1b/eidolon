#!/bin/bash
# snapshots.sh [--accept]: render the snapshot scenarios in iLEmu and compare them with eidolon/Snapshots/reference
set -u
cd "$(dirname "$0")"
accept=${1:-}
name=snap-$(date +%H%M%S)
export PREPARE='install -d -m 0777 "$ROOTFS/private/var/charon"; : > "$ROOTFS/private/var/charon/snapshots.on"; [ -n "$IMAGES" ] && : > "$ROOTFS/private/var/charon/snapshots.png"; [ -n "$ONLY" ] && printf %s "$ONLY" > "$ROOTFS/private/var/charon/snapshots.only"; true'
DONE="snapshots done" DONE_LOG=private/var/tmp/eidolon-demo.log DEV=iPod4,1 SRC=$HOME/.charon/firmware/rootfs/iPod4,1/6.0_10A403 KEEPROOT=1 ./run-app.sh $name eidolon/out/EidolonDemo.app ${SECONDS_BUDGET:-700} >/dev/null
run=runs.noindex/$name
mkdir -p $run/shots
cp $run/rootfs/private/var/charon/eidolon-snapshots/* $run/shots/ 2>/dev/null
chmod -R u+w $run/rootfs $run/tmp 2>/dev/null; rm -rf $run/rootfs $run/tmp
grep -a "snapshot\|snapshots done" $run/eidolon-demo.log 2>/dev/null
fail=0
for shot in $run/shots/*.txt; do
  [ -e "$shot" ] || { echo "no snapshots were written"; exit 1; }
  base=$(basename $shot); reference=eidolon/Snapshots/reference/$base
  if [ ! -e "$reference" ] || [ "$accept" = --accept ]; then
    cp $shot $reference; echo "reference $base written"
  elif cmp -s $shot $reference; then
    echo "match $base"
  else
    echo "DIFFERS $base"; diff -u $reference $shot | head -20; fail=1
  fi
done
exit $fail
