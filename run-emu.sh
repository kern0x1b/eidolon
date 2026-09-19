#!/bin/bash
# run-emu.sh NAME STAGE BINARY [DEVICE] [ROOTFS]: iLEmu boot of a clone of an iOS 6 rootfs with STAGE at /var/tmp/NAME, BINARY as the guest process
[ -f "$(dirname "$0")/local.env" ] && . "$(dirname "$0")/local.env"
L=${EMULATOR_LAB:?set EMULATOR_LAB to the emulator lab checkout (see README, Requirements)}; R=$PWD/runs.noindex/$1; STAGE=$2; BIN=$3; DEV=${4:-iPhone4,1}; SRC=${5:-$HOME/.charon/firmware/rootfs/$DEV/6.1.3_10B329}
[ -e "$R" ] && { echo "run $R exists" >&2; exit 1; }
mkdir -p $R/tmp && cp -c -R "$SRC" $R/rootfs && mkdir -p $R/rootfs/var/tmp/$1 $R/rootfs/private/var/charon && cp -R $STAGE/ $R/rootfs/var/tmp/$1/
build=$(plutil -extract ProductBuildVersion raw "$SRC/System/Library/CoreServices/SystemVersion.plist")
cd $R && perl -e "alarm ${ALARM:-150}; exec @ARGV" env TMPDIR=$R/tmp VK_ICD_FILENAMES="$L/deps/build-swiftshader/Darwin/vk_swiftshader_icd.json" \
  "${ILEMU:-$($L/scripts/ilemu.sh)}" boot --rootfs $R/rootfs --device $DEV --binary /var/tmp/$1/$BIN --display headless --gles-backend software ${EMUEXTRA} \
  --host-cache $L/cache/${DEV}_$build > $R/log 2>&1
echo "exit=$?"
cp $R/rootfs/private/var/charon/swiftui-ignored.txt $R/ 2>/dev/null
[ -n "$KEEPROOT" ] || { chmod -R u+w $R/rootfs $R/tmp; rm -rf $R/rootfs $R/tmp; }
