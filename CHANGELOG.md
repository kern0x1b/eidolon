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
- `@Observable` models (Observation): a view is re-rendered when what its `body` read changes, and not otherwise;
  `Bindable`, `@Environment(Model.self)` and `.environment(model)`. Tracking costs under 1% of a body evaluation.
- The field reflection that finds `@State` and friends in a view checks itself once; if the runtime's entry points ever
  disagree with Swift's layout it falls back to the struct's type metadata and a Mirror, and the whole suite passes in
  that mode too.
- `Image(systemName:)` draws about eighty common SF Symbols (plus their `.fill`, `.circle` and `.square` forms) with a
  built-in glyph set, tinted like text; `Menu` labels other than text are drawn as they are and a destructive item is red.
- `TabView` opens a `ForEach` into pages and selects by tag (strings included); the page style shows visible dots.
- `Binding.init(projectedValue:)`, so `ForEach($items) { $item in … }` compiles.
- A list matches rows by the node they show: inserted, removed and moved rows are animated by the table, rows keep their
  cells, and edit state survives a change of data (before, every update reloaded the table).
- A binding to a collection is a collection of bindings (`$items.filter { … }`, `ForEach($items)`), as in SwiftUI.
- `swipeActions` on both edges, with colours (`.tint`) and `allowsFullSwipe`, handed to the table as UIKit's own
  contextual actions when the backports provide them (looked up at run time; stock iOS 6 keeps its Delete button). Checked
  against stand-in classes; not yet on a phone with the backports.
- `View` is main-actor isolated, as Apple's is, so `@MainActor` models work from `body` and property initialisers.
- The engine tests, thirty-two rendered scenarios with tree references, an in-app timing scenario and an arm64
  guest-ABI check.

### Fixed

- A `Button` whose label is not a single `Text` (an icon, a `Label`, a stack) drew an empty rounded rectangle and dropped
  its label; it now draws the label, dimmed while pressed.
- `Image(_:scale:orientation:label:)` dropped its label.
- A toolbar on a `ScrollView` (or any view that does not mount itself) left the content unmounted.
- A `Text` beside a `Spacer` was offered half the room and wrapped; a search field had no default prompt.
- `matchedGeometryEffect` sometimes did not animate: it told nodes apart by address, which a new node can reuse.
- `.tabItem { Label(…) }` lost its title; an adaptive `LazyVGrid` column was one track; `aspectRatio` with one side
  proposed took the child's own shape; a disabled toolbar `Button` was drawn with button chrome; `EditButton` in a
  toolbar did nothing.
- A view with a transform is placed by size and centre, not by `frame`.
- An animated update lays out only the screens that re-rendered.
- A change beneath `.padding()` or `.frame()` resets the wrapper's own cached size.
- A nested observer whose view did not change is re-rendered when its object does.
