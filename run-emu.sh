#!/bin/bash
# run-emu.sh [NAME]: the engine tests in the emulated device, as xmake emulate run starts them: the
# port's packages go into the image, the test binary is the guest's first process, and its exit status
# is the verdict. NAME is the run folder under runs.noindex, tests-<time> by default.
set -eu
cd "$(dirname "$0")"
name=${1:-tests-$(date +%H%M%S)}
out=$PWD/runs.noindex/$name
[ -e "$out" ] && { echo "run $out exists" >&2; exit 1; }
mkdir -p "$out"
# xmake emulate needs the packages it copies already in the store, so the port is configured and
# built here first. CHARON_REPO points the package repository at a checkout, CHARON_ADDON at the addon
# version to build with; both default to what the machine has.
xmake -P eidolon f -p iphoneos -a armv7 -y > "$out/configure.log" 2>&1
xmake -P eidolon emulate install -d iPhone4,1 -r 6.1.3 > "$out/install.log" 2>&1
status=0
xmake -P eidolon emulate -d iPhone4,1 -r 6.1.3 -s "${SECONDS_BUDGET:-240}" -t 1500 \
    run /usr/libexec/EidolonTests > "$out/run.log" 2>&1 || status=$?
cat "$out/run.log"
# The run's own files, named by the run's verdict and not by a line on the console: the verdict
# carries the absolute paths of what the test binary wrote, and the installed addon writes it, so this
# works whichever addon is in use. An older console line is used only when no verdict names a file.
folder=$(python3 -c 'import glob,json,sys,os; vs=sorted(glob.glob(os.path.expanduser("~/.charon/emulator/images.noindex")+"/*/iPhone4,1_*/run/verdict.json"), key=os.path.getmtime); print(json.load(open(vs[-1])).get("stdout","").rsplit("/results/",1)[0] if vs else "")' 2>/dev/null || true)
[ -n "$folder" ] || folder=$(sed -n 's/^run folder //p' "$out/run.log" | tail -1)
if [ -z "$folder" ] || [ ! -d "$folder/results" ]; then
  echo "the run named no results folder; its log is $out/run.log" >&2
  exit 1
fi
cp -R "$folder/results/." "$out/"
cp "$folder/verdict.json" "$out/" 2>/dev/null || true
grep -a "FAIL\|checks " "$out/test.stdout" | tail -20 || true
echo "exit=$status run folder $folder" | tee -a "$out/verdict.txt"
exit "$status"
