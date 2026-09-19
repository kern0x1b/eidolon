# Changelog

All notable changes to this project are recorded here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- The SwiftUI API on the UIKit of iOS 6 (armv7): state and data flow, stacks, grids, lists, forms, tables,
  navigation, sheets, dialogs, search, gestures, animation, shapes and paths, `Canvas`, accessibility and the UIKit
  bridges, with a ledger of what is implemented, ignored or simplified that the build checks.
- A typed gesture engine (`map`, `updating`, `sequenced`, `exclusively`, `simultaneously`, gestures defined through
  `body`).
- Frame-by-frame interpolation of `animatableData` for custom shapes, geometry effects, view modifiers and layouts;
  `GeometryEffect`, `Animation.repeatForever` and `repeatCount`.
- Every overload of `alert` and `confirmationDialog`, and presentation by item (`alert(item:)`, `actionSheet(item:)`,
  `fullScreenCover(item:)`, `popover(item:)`).
- `bridge/api-surface.sh` and `bridge/api-diff.py`: a declaration-level diff against Apple's SwiftUI interface.
- The engine tests, sixteen rendered scenarios with tree references, an in-app timing scenario and an arm64
  guest-ABI check.

### Fixed

- A view with a transform is placed by size and centre, not by `frame`.
- An animated update lays out only the screens that re-rendered.
- A change beneath `.padding()` or `.frame()` resets the wrapper's own cached size.
- A nested observer whose view did not change is re-rendered when its object does.
