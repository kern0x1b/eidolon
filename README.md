# Eidolon

**SwiftUI for iOS 6 — a from-scratch implementation of the SwiftUI API on UIKit, for armv7.**

Apple's SwiftUI cannot run on iOS 6: it has never had an armv7 build, it needs Metal, and it drags in over four hundred
system images the phone does not have. So Eidolon re-implements the *API* instead. It is a Swift module named
`SwiftUI`, built on the UIKit of iOS 6, with [OpenCombine](https://github.com/OpenCombine/OpenCombine) standing in for
Combine. An app written in ordinary SwiftUI syntax compiles against it and comes out as a native-looking iOS 6 app on a
phone from 2011.

The module keeps Apple's name on purpose: the mangled names of every symbol an app takes from SwiftUI depend on it.
Eidolon is the name of the project, the directory and the build targets.

## What works

A retained node tree over UIKit views, with a reconciler, a layout engine of its own and a scheduler that re-renders
only what changed. The areas below are exercised by tests and by rendered scenarios; the full ledger — what is
implemented, what is deliberately ignored and why, what is simplified — is in [`eidolon/README.md`](eidolon/README.md)
(in Russian) and is checked by the build.

| Area | What there is |
| --- | --- |
| Description and state | `View`, `ViewBuilder`, `@State`, `@Binding`, `@ObservedObject`, `@StateObject`, `@EnvironmentObject`, `@Environment`, `@AppStorage`, `@FocusState`, `@GestureState`, `@FetchRequest` (over Core Data) |
| Layout | stacks, `ZStack`, `Grid`, lazy stacks and grids, `ScrollView`, `GeometryReader`, alignment guides, the `Layout` protocol with a persistent cache and animatable layouts |
| Controls and text | `Text` (concatenation, styles), `Button`, `Toggle`, `TextField`, `Slider`, `Stepper`, `Picker`, `DatePicker`, `List`, `Form`, `Table`, `Menu`, `Label`, `ProgressView`, `Canvas` |
| Navigation and presentation | `NavigationView`, `NavigationStack`, `NavigationSplitView`, `TabView`, sheets, every form of `alert` and `confirmationDialog`, search |
| Gestures | typed gesture engine: `map`, `updating` with `@GestureState`, `sequenced`, `exclusively`, `simultaneously`, custom gestures through `body` |
| Animation | `withAnimation`, `repeatForever`, transitions, `matchedGeometryEffect`; the `animatableData` of custom shapes, geometry effects, view modifiers and layouts is interpolated frame by frame |
| Graphics | `Shape` and `Path` (trim, stroke, relative arcs), gradients, `GeometryEffect`, `ProjectionTransform` |
| Bridges | `UIViewRepresentable`, `UIViewControllerRepresentable`, `UIHostingController` |
| Accessibility | labels, values, traits, containers built from `accessibilityChildren`, sort priority, VoiceOver focus |

### How complete is it

Two numbers, and they measure different things.

- **By name:** 504 of Apple's 592 public types and every one of the 311 `View` modifier names are present; each API
  that iOS 6 cannot honour is *declared*, writes a line to a journal when used, and is listed with its reason. Nothing
  is a silent no-op — the build fails if an ignored or simplified API is not named in the ledger.
- **By declaration:** comparing Apple's SwiftUI interface for iOS 16.4 with this module signature by signature
  (`bridge/api-surface.sh`) finds **1284 of Apple's declarations absent and 309 present with a different signature**.
  A good part of the absent ones has nothing to correspond to on iOS 6 (widgets, documents, windows, accessibility
  rotors); the rest is the work queue.

The gap between the two is not hidden: counting by name alone overstated completeness, which is why the second measure
exists.

## How it works

- **Node tree.** Every view becomes a node. Primitive views (`Text`, `Button`, stacks) own UIKit views; composite views
  own a child node and re-evaluate `body` when their state changes.
- **Reconciliation.** A node is reused when the type of its view is unchanged, and skipped entirely when the view's bytes
  and the environment are unchanged. `if`/`else` branches are distinct identities, as in SwiftUI.
- **Dependencies.** A view's stored properties are read reflectively once per type, so `@State` and `@ObservedObject`
  find their nodes without code generation.
- **Layout.** Sizes are proposed and reported in points, cached per node, and applied to UIViews by size and centre.
  Only the nodes marked dirty are laid out again.
- **Animation.** Ordinary properties are handed to `UIView.animate`; data that UIKit cannot interpolate is driven frame
  by frame by a display-link animator.
- **Combine** is OpenCombine, built with the same Swift runtime.

## Requirements

- macOS with the [Charon](https://github.com/kern0x1b/charon) toolchain, and its packages installed into a private
  xmake global directory (`xmake-global/` in this checkout): `swift-runtime`, `libcxx`, `apple-compat`, `opencombine`,
  the iOS SDK, `llvm`, `ld64` and `ldid`. `pkg-env.sh` finds them there.
- To run the tests and rendered scenarios: an iOS 6 firmware root file system from Charon, and an emulator lab that
  provides `scripts/ilemu.sh` and the helper scripts `run-emu.sh` and `run-app.sh` call. Point `EMULATOR_LAB` at it.
- To measure on hardware: an iPhone 4S or an iPad 2 on iOS 6.1.3, reached through Charon's device tooling
  (`CHARON_MODULES` names the `modules` directory of a Charon checkout).

Machine-local paths go in `local.env` (git-ignored); nothing personal is tracked.

## Build

```bash
eidolon/build.sh        # module, demo app, tests and probe -> eidolon/out/EidolonDemo.app
```

The build begins with `eidolon/coverage.py --check`, which refuses to continue if the ledger and the code disagree.
Everything is compiled with availability checking **on**, against the same Swift runtime the app carries.

## Usage

```bash
cd eidolon
../run-emu.sh t1 out/EidolonDemo.app EidolonTests   # the engine tests, in the emulator
../snapshots.sh [--accept]                          # rendered scenarios against tree references
../perf.sh                                          # in-app timings of deeply nested layouts
python3 coverage.py --check                         # the ledger, checked against the code
../bridge/prepare-fw.sh && ../bridge/api-surface.sh # the typed API diff against Apple's interface
```

`bridge/guest-abi-check.sh` builds the module for arm64 with library evolution and links a sample app compiled against
Apple's interface with it, to prove that the symbols such an app needs are all there.

## Repository layout

| Path | Holds |
| --- | --- |
| `eidolon/` | the module (`Sources/SwiftUI`), the demo app, the engine tests, the probe, the snapshot references and the coverage ledger |
| `bridge/` | the guest-ABI check, the typed API diff against Apple's interface, and the name lists both use |
| `combine/` | build and run scripts for OpenCombine's own test suite on iOS 6, with its results |
| `rtpkg/` | the small xmake project that installs the runtime packages |
| `docs/` | the research (in Russian) |
| `*.sh`, `device.lua` | run the emulator, take snapshots and timings, reach a device |

## Documentation

| Document | About |
| --- | --- |
| [`eidolon/README.md`](eidolon/README.md) | the ledger: what is implemented, ignored, simplified or missing; measurements |
| [`docs/research.md`](docs/research.md) | why Apple's SwiftUI cannot be ported, and the design of this implementation (Russian) |
| [`bridge/README.md`](bridge/README.md) | the guest-ABI check |
| [`combine/RESULTS.md`](combine/RESULTS.md) | OpenCombine on iOS 6: 1448 of 1453 of its tests |
| [`CLAUDE.md`](CLAUDE.md) | the contributor guide |

## Trademarks

SwiftUI, UIKit, Combine, iOS and iPhone are trademarks of Apple Inc. They are used here nominatively, to say what this
project is compatible with. There is no affiliation. This repository contains no code or assets of Apple's.

## License

MIT, see `LICENSE`. Third-party dependencies and their terms are listed in `THIRD-PARTY.md`; nothing third-party is
vendored.

Built with Claude (Anthropic). This project is developed with AI assistance, openly — see the commit history.
