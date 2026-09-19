# pkg-env.sh: sourced by the build scripts (OpenCombine from charon@opencombine built against the same runtime) (toolchain pinned to what xmake resolved for ../rtpkg; runtime deps read from its manifest) — the charon@swift-runtime installation in ./xmake-global (one installation: runtime, libc++, compat, compiler)
STUDY=${STUDY:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}
X=$STUDY/xmake-global/.xmake/packages
RT=$(ls -d $X/s/swift-runtime/6.4.0/*/ | head -1); RT=${RT%/}
SWIFTC=$(grep -A1 'SWIFT_EXEC' $RT/manifest.txt | tail -1 | tr -d ' "')
SWIFTHOME=$(dirname $(dirname $SWIFTC))
dep_hash() { awk -v name="$1" '$0 ~ "^        (\\[\")?"name"(\"\\])? = \\{" {found=1} found && /buildhash/ {gsub(/[ ",]/, ""); split($0, a, "="); print a[2]; exit}' $RT/manifest.txt; }
LIBCXX=$X/l/libcxx/23.1.1/$(dep_hash libcxx)
COMPAT=$X/a/apple-compat/latest/$(dep_hash apple-compat)
OC=$(grep -l "$(basename $RT)" $X/o/opencombine/2023.10.11/*/manifest.txt 2>/dev/null | head -1); OC=${OC%/manifest.txt}
OCFLAGS="-I $OC/lib/swift/iphoneos -I $OC/include/COpenCombineHelpers"
OCLINK="-L$OC/lib -lOpenCombineFoundation -lOpenCombineDispatch -lOpenCombine -lCOpenCombineHelpers"
SDK=$X/i/iphoneos-sdk/16.4/2b9d2eb960474b48acc5cdb2e27db307/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk
LLVM=$X/l/llvm/23.1.1/6a8c97aaa69241df9ed69ac86f13a045
LD=$X/l/ld64/956.6/aac8ea2d04874dfdbdc0b81f5db2dd03/bin/ld
LDID=$(ls $X/l/ldid/*/*/bin/ldid | head -1)
MARK=$(grep -A1 'CHARON_SWIFT_RUNTIME_MARK' $RT/manifest.txt | tail -1 | tr -d ' "')
T=armv7-apple-ios6.0
PKGFLAGS="-target $T -clang-target $T -sdk $SDK -resource-dir $RT/lib/swift -Xfrontend -bundled-swift-runtime -runtime-compatibility-version none -plugin-path $SWIFTHOME/lib/swift/host/plugins"
RTLIBS="swiftCore swiftSwiftOnoneSupport swift_Concurrency swiftDarwin swiftObjectiveC swiftDispatch swiftCoreFoundation swiftCoreGraphics swiftFoundation swiftQuartzCore swiftUIKit swiftCoreData swiftSynchronization swift_RegexParser swift_StringProcessing swiftRegexBuilder swiftObservation"
PKGLINK="-L$RT/lib/swift/iphoneos -L$LIBCXX/lib -L$COMPAT/lib $(for l in $RTLIBS; do printf -- '-l%s ' $l; done) -lc++ -lc++abi -lapple-compat -nostdlib++ -Wl,-u,_$MARK -Wl,-rpath,@executable_path"
bundle_runtime() {
    cp $RT/lib/swift/iphoneos/*.dylib $LIBCXX/lib/libc++.1.dylib $LIBCXX/lib/libc++abi.1.dylib "$1"/
    chmod u+w "$1"/*.dylib
    for f in "$1"/*.dylib; do
        install_name_tool -id @executable_path/$(basename $f) $f 2>/dev/null
        relink_runtime $f
    done
}
relink_runtime() {
    local changes=""
    for d in $(otool -L "$1" | awk '/@rpath\//{print $1}'); do changes="$changes -change $d @executable_path/${d#@rpath/}"; done
    [ -n "$changes" ] && install_name_tool $changes "$1" 2>/dev/null
    true
}
# STYX=<install> builds against the Combine module of the Styx fork instead of OpenCombine
if [ -n "${STYX:-}" ]; then
  OCFLAGS="-D REV_STYX -I $STYX/lib/swift/iphoneos -I $STYX/include/CombineHelpers"
  OCLINK="-L$STYX/lib -lCombine -lCombineHelpers"
fi
