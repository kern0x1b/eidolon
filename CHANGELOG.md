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
- Real toolbars: every placement (`principal` becomes the title, `bottomBar` and `status` the toolbar, several items per
  side in declared order), custom-view bar items for anything that is not a plain text button, `ToolbarItem(id:)`, and
  `showsByDefault`.
- `View` overloads: `navigationBarTitle(_:displayMode:)`, `lineLimit(_:reservesSpace:)`, `listRowSeparator(_:edges:)`,
  `mask` by any view with an alignment, `task(id:priority:)` that is cancelled when the view goes and restarted when the
  id changes, `navigationDestination(isPresented:)`, `toolbar(_:for:)`, Apple's `onLongPressGesture(pressing:perform:)`.
- `EnvironmentValues` keys: `lineLimit`, `lineSpacing`, `minimumScaleFactor`, `textCase`, `truncationMode`,
  `allowsTightening`, `autocorrectionDisabled`, `imageScale`, `pixelLength`, `isPresented`, `undoManager`,
  `isScrollEnabled`, `defaultMinListRowHeight` (the list honours it), `headerProminence`, `dynamicTypeSize`, and the
  accessibility settings iOS 6 has (VoiceOver, invert colours) or cannot have (read as off).
- Combine is now Styx, the fork of OpenCombine that Charon packages as `charon@styx`; the module is named `Combine`.
- `Path` is a `Shape`, so `Path { … }.stroke(…)` works; it is a real value type now (a changed copy no longer changes
  the original), takes Apple's `transform:` parameters and has `currentPoint` and `contains`.
- `Color` is `Hashable` and can be made from a `UIColor` or `CGColor`; `import SwiftUI` brings UIKit, as on iOS.
- `Text`: `bold(_:)`, `italic(_:)`, `monospaced(_:)`, `baselineOffset`, `accessibilityLabel`, `accessibilityHeading`,
  `init(_:formatter:)`; `Image` from a bundle, with a label or decorative.
- `EditButton` works in a toolbar and follows the screen's editing state (UIKit's own `editButtonItem`), and `\.editMode`
  is honoured by lists.
- `DatePicker` shows its label, takes `in:` ranges and all of Apple's initialisers.
- `View` is main-actor isolated, as Apple's is, so `@MainActor` models work from `body` and property initialisers.
- The engine tests, twenty-four rendered scenarios with tree references, an in-app timing scenario and an arm64
  guest-ABI check.

### Fixed

- A `Button` whose label is not a single `Text` (an icon, a `Label`, a stack) drew an empty rounded rectangle and dropped
  its label; it now draws the label, dimmed while pressed.
- `Image(_:scale:orientation:label:)` dropped its label.
- `.tabItem { Label(…) }` lost its title; an adaptive `LazyVGrid` column was one track; `aspectRatio` with one side
  proposed took the child's own shape; a disabled toolbar `Button` was drawn with button chrome; `EditButton` in a
  toolbar did nothing.
- A view with a transform is placed by size and centre, not by `frame`.
- An animated update lays out only the screens that re-rendered.
- A change beneath `.padding()` or `.frame()` resets the wrapper's own cached size.
- A nested observer whose view did not change is re-rendered when its object does.
