-- The port xmake emulate installs and launches: Eidolon's demo application and its engine tests, as
-- packages, so the emulator image carries them and SpringBoard lists the application by its identifier.
-- The SwiftUI module itself is charon@eidolon, which builds it from this repository's pinned commit.
set_project("eidolon")
set_version("0.1")
add_repositories("charon " .. (os.getenv("CHARON_REPO") or "https://github.com/kern0x1b/charon.git"))
add_addons("charon " .. (os.getenv("CHARON_ADDON") or "v0.8.13"))
set_config("apple_minimum", "6.0")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

-- The runtime the port carries, built with the backports: the runtime's overlays and Styx weakly import
-- later API that only the library answers, and a runtime built so hands its lifted headers to the port,
-- which then has to carry the library as well.
add_requires("charon@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
add_requires("charon@libcxx", {alias = "libcxx"})
add_requires("charon@styx", {alias = "styx", configs = {backports = true}})
add_requires("charon@eidolon", {alias = "swiftui", configs = {backports = true, backports_uikit = true}})
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {coredata = true, uikit = true}})

target("EidolonDemo")
    add_rules("@addon/charon/app", "@addon/charon/swift")
    add_files("Demo/*.swift")
    add_files("Demo/device/gesture.m")
    add_includedirs("Demo/device")
    add_packages("swiftui", "apple-backports")
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "CoreData")
    set_values("swift.flags", "-import-objc-header", path.join(os.scriptdir(), "Demo", "device", "bridge.h"))
    set_optimize("fastest")
    set_values("app.plist-file", "Info.plist")
    set_values("app.plist", "CFBundleIdentifier=space.kern0x1b.eidolon.demo", "CFBundleDisplayName=Eidolon")
    -- Every weak import of the program and of the runtime it carries is answered behind a check: the
    -- overlays are compiled with availability checking on, so later API stands behind #available, and
    -- Styx's own _CFRunLoopTimerSetTolerance is answered by the backports this program carries.
    set_values("charon.waive.weak-imports", "every weak import is reached only behind #available or carried by the backports: the runtime's overlays built with availability checking on, Styx's run-loop timer tolerance, compiler-rt's version check")
    -- Naming the backports switches verify_placed to the branch that copies the library in.
    set_values("charon.libraries", "apple-backports")
    set_values("charon.control", "control")

-- The same program as a second bundle. The scenarios need a key window and SpringBoard's own lifecycle,
-- so they are the application that renders them; what tells it to is a key of its own Info.plist, which
-- is where a port says what it wants in the guest.
target("EidolonSnapshots")
    add_rules("@addon/charon/app", "@addon/charon/swift")
    add_files("Demo/*.swift")
    add_files("Demo/device/gesture.m")
    add_includedirs("Demo/device")
    add_packages("swiftui", "apple-backports")
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "CoreData")
    set_values("swift.flags", "-import-objc-header", path.join(os.scriptdir(), "Demo", "device", "bridge.h"))
    set_optimize("fastest")
    set_values("app.plist-file", "Info.plist")
    set_values("app.plist", "CFBundleIdentifier=space.kern0x1b.eidolon.snapshots", "CFBundleDisplayName=EidolonSnapshots", "EidolonSnapshots=YES", "EidolonSnapshotImages=YES")
    -- One scenario, for a while working on it: EIDOLON_SNAPSHOT_ONLY names it at configure time.
    local only = os.getenv("EIDOLON_SNAPSHOT_ONLY")
    if only and only ~= "" then
        add_values("app.plist", "EidolonSnapshotOnly=" .. only)
    end
    set_values("charon.waive.weak-imports", "every weak import is reached only behind #available or carried by the backports: the runtime's overlays built with availability checking on, Styx's run-loop timer tolerance, compiler-rt's version check")
    set_values("charon.libraries", "apple-backports")
    set_values("charon.control", "control")

-- The engine tests: one binary and no UIApplication, so xmake emulate run starts it as the guest's first
-- process and its verdict is the exit status.
target("EidolonTests")
    add_rules("@addon/charon/daemon", "@addon/charon/swift")
    add_files("Tests/*.swift")
    add_packages("swiftui", "apple-backports")
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "CoreData")
    set_optimize("fastest")
    set_values("swift.flags", "-disable-availability-checking")
    set_values("charon.waive.weak-imports", "every weak import is reached only behind #available or carried by the backports: the runtime's overlays built with availability checking on, Styx's run-loop timer tolerance, compiler-rt's version check")
    set_values("charon.libraries", "apple-backports")
    set_values("charon.control", "control-tests")
