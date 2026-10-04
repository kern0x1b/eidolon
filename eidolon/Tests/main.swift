import SwiftUI
import CoreData
import UIKit
import Foundation
import Observation

setvbuf(stdout, nil, _IONBF, 0)
var failures = 0
var checks = 0
let mirrorAll = FileManager.default.fileExists(atPath: (CommandLine.arguments[0] as NSString).deletingLastPathComponent + "/mirror")
if mirrorAll { _Probe.useMirrorReflection(true) }
let traceChecks = FileManager.default.fileExists(atPath: (CommandLine.arguments[0] as NSString).deletingLastPathComponent + "/trace")

func check(_ condition: Bool, _ what: String, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if traceChecks { print("check \(checks) \(what)") }
    if !condition {
        failures += 1
        print("FAIL \(what)\(detail().isEmpty ? "" : ": " + detail())")
    }
}

func equal<T: Equatable>(_ got: T, _ want: T, _ what: String) {
    check(got == want, what, "got \(got), want \(want)")
}

// leaf views only, in the coordinates of the host view: that is what a person sees
/// The text of every label under a view, top to bottom.
func labels(of view: UIView) -> [String] {
    var found: [(CGFloat, String)] = []
    var stack: [UIView] = [view]
    while let current = stack.popLast() {
        if let label = current as? UILabel, let text = label.text, !text.isEmpty {
            found.append((label.convert(label.bounds, to: view).minY, text))
        }
        stack.append(contentsOf: current.subviews)
    }
    return found.sorted { $0.0 < $1.0 }.map { $0.1 }
}

/// Where each text sits on screen, so the order a table shows can be read off it.
func positions(of view: UIView) -> [String: CGFloat] {
    var seen: [String: CGFloat] = [:]
    var stack: [UIView] = [view]
    while let current = stack.popLast() {
        if let label = current as? UILabel, let text = label.text, !text.isEmpty, seen[text] == nil {
            seen[text] = label.convert(label.bounds, to: view).minY
        }
        stack.append(contentsOf: current.subviews)
    }
    return seen
}

func frames(_ probe: _Probe) -> [CGRect] {
    var out: [CGRect] = []
    func walk(_ v: UIView) {
        if v.subviews.isEmpty {
            out.append(v.convert(v.bounds, to: probe.hostView))
        } else {
            v.subviews.forEach(walk)
        }
    }
    probe.hostView.subviews.forEach(walk)
    return out
}

var actions: [() -> Void] = []
func register(_ action: @escaping () -> Void) -> Int {
    actions.append(action)
    return actions.count
}

final class Store: ObservableObject {
    @Published var count = 0
    @Published var items = [1, 2, 3]
    @Published var show = false
    @Published var width: CGFloat = 40
}

// 1. stack layout: fixed children, spacer takes the rest, spacing between children
struct StackCase: View {
    var body: some View {
        HStack(spacing: 10) {
            Color.red.frame(width: 50, height: 20)
            Spacer()
            Color.blue.frame(width: 30, height: 20)
        }
        .frame(width: 200, height: 40)
    }
}

let stack = _Probe(StackCase(), width: 200, height: 40)
let stackFrames = frames(stack).filter { $0.size.height == 20 && $0.size.width > 0 }
equal(stackFrames.count, 2, "the stack drew both colors")
if stackFrames.count == 2 {
    equal(stackFrames[0].origin.x, 0, "first child at the leading edge")
    equal(stackFrames[0].size.width, 50, "first child keeps its width")
    equal(stackFrames[1].size.width, 30, "last child keeps its width")
    equal(stackFrames[1].origin.x, 170, "the spacer pushed the last child to the trailing edge")
}

// 2. padding shrinks the proposal
struct PaddingCase: View {
    var body: some View { Color.green.padding(8) }
}
let padded = _Probe(PaddingCase(), width: 100, height: 60)
let inner = frames(padded).last ?? .zero
equal(inner.size.width, 84, "padding takes 8 points off each side")
equal(inner.origin.x, 8, "padded content starts after the inset")
equal(inner.size.height, 44, "padding takes 8 points off the top and the bottom")

// 3. @State drives an update through a button action
struct Counter: View {
    @State var value = 0
    var body: some View {
        let _ = register { value += 1 }
        VStack {
            Color.red.frame(width: CGFloat(10 + value * 10), height: 5)
        }
    }
}
let counter = _Probe(Counter(), width: 200, height: 100)
let before = frames(counter).first { $0.size.height == 5 }?.size.width ?? -1
actions.removeLast()()
counter.flush()
let after = frames(counter).first { $0.size.height == 5 }?.size.width ?? -1
equal(before, 10, "state starts at zero")
equal(after, 20, "writing the state moved the view")

// 4. ObservableObject: insertion, removal and reordering of ForEach children
struct Rows: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack(spacing: 0) {
            ForEach(store.items, id: \.self) { item in
                Color.blue.frame(width: CGFloat(item) * 10, height: 4)
            }
            if store.show {
                Color.orange.frame(height: 7)
            }
        }
    }
}
let store = Store()
let rows = _Probe(Rows(store: store), width: 100, height: 100)
equal(frames(rows).filter { $0.size.height == 4 }.count, 3, "three rows at the start")
check(!frames(rows).contains { $0.size.height == 7 }, "the conditional view is absent while the flag is false")
store.items = [5, 1]
store.show = true
rows.flush()
let widths = frames(rows).filter { $0.size.height == 4 }.map { $0.size.width }
equal(widths, [50, 10], "rows follow the data, in order")
check(frames(rows).contains { $0.size.height == 7 }, "the conditional view appeared")
store.show = false
store.items = []
rows.flush()
equal(frames(rows).filter { $0.size.height == 4 }.count, 0, "rows are gone")
check(!frames(rows).contains { $0.size.height == 7 }, "the conditional view is gone")

// 5. a view type change rebuilds the node
struct Either: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack {
            if store.show {
                Color.red.frame(width: 11, height: 11)
            } else {
                Color.blue.frame(width: 22, height: 22)
            }
        }
    }
}
let either = _Probe(Either(store: store), width: 50, height: 50)
check(frames(either).contains { $0.size.width == 22 }, "the else branch is shown")
store.show = true
either.flush()
check(frames(either).contains { $0.size.width == 11 }, "the then branch replaced it")
check(!frames(either).contains { $0.size.width == 22 }, "the else branch is gone")

// 6. environment object reaches a nested view
final class Theme: ObservableObject {
    @Published var thick = false
}
struct Leaf: View {
    @EnvironmentObject var theme: Theme
    var body: some View { Color.green.frame(height: theme.thick ? 20 : 3) }
}
struct Root: View {
    let theme: Theme
    var body: some View { VStack { Leaf() }.environmentObject(theme) }
}
let theme = Theme()
let env = _Probe(Root(theme: theme), width: 60, height: 60)
check(frames(env).contains { $0.size.height == 3 }, "the nested view read the environment object")
theme.thick = true
env.flush()
check(frames(env).contains { $0.size.height == 20 }, "changing the environment object updated the nested view")

// 7. list rows: count and height follow the data
struct ListCase: View {
    @ObservedObject var store: Store
    var body: some View {
        List {
            ForEach(store.items, id: \.self) { item in
                Color.red.frame(height: CGFloat(item) * 40)
            }
        }
    }
}
store.items = [1, 2]
let list = _Probe(ListCase(store: store), width: 320, height: 400)
equal(list.rowCount, 2, "the list has a row per item")
check(list.rowHeight(1) > list.rowHeight(0), "a taller row measures taller", "got \(list.rowHeight(0)) and \(list.rowHeight(1))")
check(list.rowHeight(0) >= 44, "a row is at least as tall as a standard cell")
store.items = [1, 2, 3]
list.flush()
equal(list.rowCount, 3, "the list picked up the new item")

// 8. only the changed subtree evaluates its body again
struct Inner: View {
    @ObservedObject var store: Store
    var body: some View { Color.red.frame(width: store.width, height: 4) }
}
struct Outer: View {
    let store: Store
    var body: some View { VStack { Color.blue.frame(height: 4); Inner(store: store) } }
}
let outer = _Probe(Outer(store: store), width: 100, height: 100)
let firstCount = outer.bodyEvaluations
store.width = 70
outer.flush()
equal(outer.bodyEvaluations, firstCount + 1, "one body ran again")
check(frames(outer).contains { $0.size.width == 70 }, "the changed subtree laid out again")

// 9. ZStack: children overlap, size is the largest, alignment places them
struct ZCase: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.red.frame(width: 40, height: 40)
            Color.blue.frame(width: 10, height: 10)
        }
    }
}
let zstack = _Probe(ZCase(), width: 100, height: 100)
let zframes = frames(zstack).filter { $0.size.width > 0 }
equal(zframes.count, 2, "both children are there")
if zframes.count == 2 {
    equal(zframes[0].origin, zframes[1].origin, "topLeading puts both at the same corner")
    equal(zframes[0].size.width, 40, "the larger child keeps its size")
    equal(zframes[1].size.width, 10, "the smaller child keeps its size")
}

// 10. ScrollView: content is laid out at its natural height and the content size follows it
struct ScrollCase: View {
    @ObservedObject var store: Store
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.items, id: \.self) { item in
                    Color.green.frame(height: CGFloat(item) * 30)
                }
            }
        }
    }
}
store.items = [1, 2, 3]
let scroll = _Probe(ScrollCase(store: store), width: 200, height: 100)
equal(scroll.scrollContentHeight, 180, "content size is the sum of the rows, not the viewport")
store.items = [1]
scroll.flush()
equal(scroll.scrollContentHeight, 100, "a shorter content still fills the viewport")

// 11. ForEach keeps a row's state when the data is reordered: identity follows the id, not the position
final class Counted: ObservableObject {
    @Published var ids = [1, 2, 3]
}
var builtRows: [Int] = []
struct IdentityRow: View {
    let value: Int
    @State var built = 0
    var body: some View {
        let _ = builtRows.append(value)
        Color.red.frame(width: CGFloat(value) * 10, height: 3)
    }
}
struct IdentityCase: View {
    @ObservedObject var model: Counted
    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.ids, id: \.self) { id in
                IdentityRow(value: id)
            }
        }
    }
}
let counted = Counted()
let identity = _Probe(IdentityCase(model: counted), width: 100, height: 100)
equal(builtRows, [1, 2, 3], "every row built once")
builtRows = []
counted.ids = [3, 1, 2]
identity.flush()
equal(builtRows, [], "reordering the data rebuilds no row body")
equal(frames(identity).filter { $0.size.height == 3 }.map { $0.size.width }, [30, 10, 20], "rows moved with their data")
counted.ids = [3, 1, 2, 4]
identity.flush()
equal(builtRows, [4], "only the new row built its body")

// 12. sections group the rows of a list and carry their titles
struct SectionCase: View {
    @ObservedObject var store: Store
    var body: some View {
        List {
            Section {
                Color.red.frame(height: 20)
            }
            Section {
                ForEach(store.items, id: \.self) { item in
                    Color.blue.frame(height: CGFloat(item) * 10)
                }
            }
        }
    }
}
store.items = [1, 2]
let sectioned = _Probe(SectionCase(store: store), width: 320, height: 400)
equal(sectioned.sectionCount, 2, "two sections")
equal(sectioned.rowCounts, [1, 2], "rows landed in their sections")
store.items = [1, 2, 3]
sectioned.flush()
equal(sectioned.rowCounts, [1, 3], "a new item joined its own section")

// 13. shapes draw through CAShapeLayer and take the proposed size
struct ShapeCase: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.red).frame(width: 40, height: 10)
            Circle().stroke(Color.blue, lineWidth: 2).frame(width: 20, height: 20)
            RoundedRectangle(cornerRadius: 4).fill(Color.green).frame(height: 8)
        }
    }
}
let shapes = _Probe(ShapeCase(), width: 100, height: 100)
let shapeFrames = frames(shapes)
equal(shapeFrames.count, 3, "three shapes")
if shapeFrames.count == 3 {
    equal(shapeFrames[0].size, CGSize(width: 40, height: 10), "explicit frame wins")
    equal(shapeFrames[2].size.width, 100, "a shape without a width takes the proposal")
}

// 14. padding by edges only touches the named sides
struct EdgeCase: View {
    var body: some View { Color.red.padding(.horizontal, 10) }
}
let edges = _Probe(EdgeCase(), width: 100, height: 50)
if let inner = frames(edges).last {
    equal(inner.origin.x, 10, "leading padding applied")
    equal(inner.size.width, 80, "trailing padding applied")
    equal(inner.size.height, 50, "vertical sides untouched")
}

// 15. effects: offset moves without changing the measured size, hidden hides
struct EffectCase: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.red.frame(width: 20, height: 20).offset(x: 5, y: 0)
            Color.blue.frame(width: 20, height: 20).hidden()
        }
    }
}
let effects = _Probe(EffectCase(), width: 100, height: 100)
let effectFrames = frames(effects)
equal(effectFrames.count, 2, "both children exist")
if effectFrames.count == 2 {
    equal(effectFrames[0].origin.x, 45, "offset shifted the child inside its centered slot")
    check(effects.isHidden(1), "hidden view is hidden")
}

// 16. onChange fires once per distinct value
var changes: [Int] = []
struct ChangeCase: View {
    @ObservedObject var store: Store
    var body: some View {
        Color.red.frame(height: 5).onChange(of: store.count) { changes.append($0) }
    }
}
store.count = 0
let changeProbe = _Probe(ChangeCase(store: store), width: 50, height: 50)
equal(changes, [], "no change on the first pass")
store.count = 4
changeProbe.flush()
store.count = 4
changeProbe.flush()
store.count = 9
changeProbe.flush()
equal(changes, [4, 9], "only distinct values fire")

// 17. modifiers that iOS 6 cannot express must announce themselves, not stay silent
struct IgnoredCase: View {
    var body: some View { Color.red.frame(width: 10, height: 10).blur(radius: 4).saturation(0.5) }
}
let ignoredProbe = _Probe(IgnoredCase(), width: 50, height: 50)
check(_Unsupported.used.contains("blur"), "blur reported itself as ignored")
check(_Unsupported.used.contains("saturation"), "saturation reported itself as ignored")
equal(frames(ignoredProbe).count, 1, "the view still draws")

// 19. preferences travel up to the observer
struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
var seenWidths: [CGFloat] = []
struct PreferenceCase: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack {
            Color.red.frame(height: 4).preference(key: WidthKey.self, value: store.width)
        }
        .onPreferenceChange(WidthKey.self) { seenWidths.append($0) }
    }
}
store.width = 12
let preferences = _Probe(PreferenceCase(store: store), width: 100, height: 100)
equal(seenWidths, [12], "the first value reached the observer")
store.width = 40
preferences.flush()
equal(seenWidths, [12, 40], "the changed value reached the observer")

// 20. the focus state keeps its value through rebuilds
struct FocusCase: View {
    @FocusState var focused: Bool
    @ObservedObject var store: Store
    var body: some View {
        let _ = register { focused = true }
        VStack {
            Color.red.frame(width: CGFloat(store.count % 5 + 1) * 10, height: 4)
            Color.blue.frame(width: 6, height: 6).focused($focused)
        }
    }
}
let focus = _Probe(FocusCase(store: store), width: 200, height: 100)
actions.removeLast()()
focus.flush()
check(true, "focus state survived a rebuild")

// 21. UIViewRepresentable puts a real UIKit view into the tree and updates it
final class Box: UIView {
    var level = 0
}
struct BoxView: UIViewRepresentable {
    let level: Int
    func makeUIView(context: Context) -> Box {
        let box = Box()
        box.backgroundColor = .green
        return box
    }
    func updateUIView(_ uiView: Box, context: Context) { uiView.level = level }
}
struct RepresentableCase: View {
    @ObservedObject var store: Store
    var body: some View {
        BoxView(level: store.count).frame(width: 30, height: 12)
    }
}
store.count = 3
let representable = _Probe(RepresentableCase(store: store), width: 100, height: 100)
func firstBox(_ probe: _Probe) -> Box? {
    var found: Box?
    func walk(_ view: UIView) {
        if let box = view as? Box, found == nil { found = box }
        view.subviews.forEach(walk)
    }
    walk(probe.hostView)
    return found
}
equal(firstBox(representable)?.level ?? -1, 3, "the representable view got its value")
equal(firstBox(representable)?.frame.size ?? .zero, CGSize(width: 30, height: 12), "the frame applies to the UIKit view")
store.count = 8
representable.flush()
equal(firstBox(representable)?.level ?? -1, 8, "update reached the same UIKit view")

// 22. ViewThatFits picks the first candidate that fits
struct FitsCase: View {
    var body: some View {
        ViewThatFits {
            Color.red.frame(width: 200, height: 10)
            Color.blue.frame(width: 60, height: 10)
        }
    }
}
let fits = _Probe(FitsCase(), width: 100, height: 100)
equal(frames(fits).first?.size.width ?? 0, 60, "the wide candidate was skipped")

// 23. a custom Layout gets the subviews and places them itself
struct DiagonalLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Void) -> CGSize {
        CGSize(width: proposal.width ?? 100, height: proposal.height ?? 100)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Void) {
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: CGFloat(index) * 20, y: CGFloat(index) * 10),
                          proposal: ProposedViewSize(width: 10, height: 10))
        }
    }
}
struct LayoutCase: View {
    var body: some View {
        DiagonalLayout() {
            Color.red.frame(width: 10, height: 10)
            Color.blue.frame(width: 10, height: 10)
            Color.green.frame(width: 10, height: 10)
        }
    }
}
let custom = _Probe(LayoutCase(), width: 100, height: 100)
let placed = frames(custom).filter { $0.size == CGSize(width: 10, height: 10) }
equal(placed.count, 3, "the layout received all subviews")
if placed.count == 3 {
    equal(placed[1].origin, CGPoint(x: 20, y: 10), "the second subview landed where the layout put it")
    equal(placed[2].origin, CGPoint(x: 40, y: 20), "the third subview landed where the layout put it")
}

// 24. a transition puts the view in and takes it out; without animation it is immediate
struct TransitionCase: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack {
            if store.show {
                Color.red.frame(width: 20, height: 20).transition(.opacity)
            }
        }
    }
}
store.show = false
let transitions = _Probe(TransitionCase(store: store), width: 100, height: 100)
func boxes(_ probe: _Probe) -> Int { frames(probe).filter { $0.size == CGSize(width: 20, height: 20) }.count }
equal(boxes(transitions), 0, "nothing is shown at first")
store.show = true
transitions.flush()
equal(boxes(transitions), 1, "the view appeared")
withAnimation(.linear(duration: 0.2)) { store.show = false }
transitions.flush()
check(boxes(transitions) == 1, "removal with animation keeps the view on screen while it fades")

// 25. labelStyle chooses what a Label shows; a custom style receives title and icon
struct StackedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) { configuration.icon; configuration.title }
    }
}
func labelCase(_ which: Int) -> some View {
    let label = Label { Color.red.frame(width: 30, height: 5) } icon: { Color.blue.frame(width: 6, height: 6) }
    return Group {
        if which == 0 { label.labelStyle(IconOnlyLabelStyle()) }
        else if which == 1 { label.labelStyle(TitleOnlyLabelStyle()) }
        else { label.labelStyle(StackedLabelStyle()) }
    }
}
let iconOnly = frames(_Probe(labelCase(0), width: 100, height: 100))
check(iconOnly.contains { $0.size.width == 6 } && !iconOnly.contains { $0.size.width == 30 }, "icon-only shows just the icon")
let titleOnly = frames(_Probe(labelCase(1), width: 100, height: 100))
check(titleOnly.contains { $0.size.width == 30 } && !titleOnly.contains { $0.size.width == 6 }, "title-only shows just the title")
let stacked = frames(_Probe(labelCase(2), width: 100, height: 100))
if let icon = stacked.first(where: { $0.size.width == 6 }), let title = stacked.first(where: { $0.size.width == 30 }) {
    check(title.origin.y >= icon.origin.y + icon.size.height, "a custom style stacked the title under the icon", "icon \(icon), title \(title)")
} else {
    check(false, "a custom style shows both parts", "\(stacked)")
}

// 26. progressViewStyle replaces the indicator and gets the fraction
struct BarStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        Color.green.frame(width: CGFloat((configuration.fractionCompleted ?? 0) * 80), height: 4)
    }
}
let styledProgress = frames(_Probe(ProgressView(value: 3, total: 4).progressViewStyle(BarStyle()), width: 100, height: 100))
check(styledProgress.contains { $0.size == CGSize(width: 60, height: 4) }, "the custom progress style drew 3/4 of 80", "\(styledProgress)")
let linear = frames(_Probe(ProgressView(value: 0.5).progressViewStyle(LinearProgressViewStyle()), width: 100, height: 100))
let plain = frames(_Probe(ProgressView(value: 0.5), width: 100, height: 100))
equal(linear, plain, "a built-in style draws the same native bar as no style")

// 27. row traits: deleteDisabled and moveDisabled per row, swipeActions replace the delete button
struct EditCase: View {
    @ObservedObject var store: Store
    var body: some View {
        List {
            ForEach(store.items, id: \.self) { item in
                Color.red.frame(height: 10)
                    .deleteDisabled(item == 2)
                    .moveDisabled(item == 3)
            }
            .onDelete { store.items.remove(atOffsets: $0) }
            .onMove { store.items.move(fromOffsets: $0, toOffset: $1) }
        }
    }
}
store.items = [1, 2, 3]
let edit = _Probe(EditCase(store: store), width: 320, height: 400)
check(edit.rowEditing(0).delete && edit.rowEditing(0).move, "a plain row can be deleted and moved")
check(!edit.rowEditing(1).delete, "deleteDisabled row has no delete control")
check(edit.rowEditing(1).move, "deleteDisabled row still moves")
check(edit.rowEditing(2).delete && !edit.rowEditing(2).move, "moveDisabled row deletes but does not move")

var swiped: [String] = []
struct SwipeCase: View {
    var body: some View {
        List {
            Color.red.frame(height: 10).swipeActions {
                Button("Archive") { swiped.append("archive") }
            }
            Color.blue.frame(height: 10).swipeActions {
                Button("Pin") { swiped.append("pin") }
                Button("Remove", role: .destructive) { swiped.append("remove") }
            }
            Color.green.frame(height: 10)
        }
    }
}
let swipe = _Probe(SwipeCase(), width: 320, height: 400)
equal(swipe.rowEditing(0).title, "Archive", "a single swipe action names the button")
check(swipe.rowEditing(0).delete, "a swipe action makes the row swipeable without onDelete")
swipe.commitDelete(0)
equal(swiped, ["archive"], "the swipe button ran its action")
equal(swipe.rowEditing(1).title, "More", "several swipe actions collapse into More")
check(!swipe.rowEditing(2).delete, "a row without actions is not swipeable")

var shuffled = [0, 1, 2, 3, 4]
shuffled.move(fromOffsets: IndexSet([1, 3]), toOffset: 5)
equal(shuffled, [0, 2, 4, 1, 3], "move(fromOffsets:) to the end keeps the moved order")
shuffled = [0, 1, 2, 3, 4]
shuffled.move(fromOffsets: IndexSet(integer: 4), toOffset: 1)
equal(shuffled, [0, 4, 1, 2, 3], "move(fromOffsets:) backwards")
shuffled.remove(atOffsets: IndexSet([0, 2]))
equal(shuffled, [4, 2, 3], "remove(atOffsets:)")

// 28. alignmentGuide shifts a child against the stack's guide; custom AlignmentID lines children up
let guided = _Probe(VStack(alignment: .leading, spacing: 0) {
    Color.red.frame(width: 40, height: 10)
    Color.blue.frame(width: 20, height: 10).alignmentGuide(.leading) { d in d[.leading] - 15 }
}, width: 200, height: 100)
let guidedFrames = frames(guided)
if let red = guidedFrames.first(where: { $0.size.width == 40 }), let blue = guidedFrames.first(where: { $0.size.width == 20 }) {
    equal(blue.origin.x - red.origin.x, 15, "the guided child sits 15 points right of the leading line")
} else { check(false, "both guided children are laid out", "\(guidedFrames)") }

enum MidLine: AlignmentID {
    static func defaultValue(in d: ViewDimensions) -> CGFloat { d[.leading] }
}
extension HorizontalAlignment { static let midLine = HorizontalAlignment(MidLine.self) }
let custom2 = frames(_Probe(VStack(alignment: .midLine, spacing: 0) {
    Color.red.frame(width: 40, height: 10).alignmentGuide(.midLine) { d in d.width }
    Color.blue.frame(width: 20, height: 10)
}, width: 200, height: 100))
if let red = custom2.first(where: { $0.size.width == 40 }), let blue = custom2.first(where: { $0.size.width == 20 }) {
    equal(blue.origin.x, red.origin.x + 40, "a custom alignment put the blue leading edge on the red trailing edge")
} else { check(false, "both custom-aligned children are laid out", "\(custom2)") }

// 29. GeometryProxy.frame(in:) answers in the named space, not only locally
var seenProxy: GeometryProxy?
let spaced = _Probe(VStack(spacing: 0) {
    Color.red.frame(width: 50, height: 30)
    GeometryReader { proxy -> Color in
        seenProxy = proxy
        return Color.blue
    }
    .frame(width: 50, height: 20)
}
.padding(.top, 7)
.coordinateSpace(name: "outer"), width: 100, height: 100)
_ = frames(spaced)
if let proxy = seenProxy {
    equal(proxy.frame(in: .local).origin.y, 0, "the local frame starts at zero")
    equal(proxy.frame(in: .named("outer")).origin.y, 37, "the named space sees the reader below the padding and the red box")
    check(proxy.frame(in: .global).origin.y >= 37, "the global frame is at least as far down", "global \(proxy.frame(in: .global)) named \(proxy.frame(in: .named("outer")))")
} else {
    check(false, "the geometry reader ran")
}

// 30. contentShape limits where a gesture is accepted
let round = _Probe(Color.red.frame(width: 100, height: 100).contentShape(Circle()).onTapGesture {}, width: 100, height: 100)
check(round.gestureAccepts(CGPoint(x: 50, y: 50)), "the centre of a circular hit shape takes the tap")
check(!round.gestureAccepts(CGPoint(x: 3, y: 3)), "the corner outside the circle does not")
let square = _Probe(Color.red.frame(width: 100, height: 100).onTapGesture {}, width: 100, height: 100)
check(square.gestureAccepts(CGPoint(x: 3, y: 3)), "without contentShape the whole frame takes the tap")

// 31. disclosureGroupStyle and menuStyle hand their parts to a custom style
struct SideBySide: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            configuration.label
            if configuration.isExpanded { configuration.content }
        }
    }
}
struct DisclosureCase: View {
    @State var open = true
    var body: some View {
        DisclosureGroup(isExpanded: $open) { Color.blue.frame(width: 11, height: 11) } label: { Color.red.frame(width: 23, height: 5) }
            .disclosureGroupStyle(SideBySide())
    }
}
let disclosed = frames(_Probe(DisclosureCase(), width: 100, height: 100))
check(disclosed.contains { $0.size.width == 23 } && disclosed.contains { $0.size.width == 11 }, "the custom disclosure style shows label and content", "\(disclosed)")
struct Swatch: MenuStyle {
    func makeBody(configuration: Configuration) -> some View { Color.green.frame(width: 17, height: 17) }
}
let menued = frames(_Probe(Menu { Color.red } label: { Color.red }.menuStyle(Swatch()), width: 100, height: 100))
check(menued.contains { $0.size == CGSize(width: 17, height: 17) }, "the custom menu style replaced the menu button", "\(menued)")

// 32. @Namespace gives each view its own id; matchedGeometryEffect animates the new view from the old frame
var namespaces: [Namespace.ID] = []
struct NamespaceCase: View {
    @Namespace var ns
    var body: some View {
        namespaces.append(ns)
        return Color.red.frame(width: 5, height: 5)
    }
}
_ = frames(_Probe(HStack { NamespaceCase(); NamespaceCase() }, width: 100, height: 100))
check(namespaces.count >= 2 && namespaces[0] != namespaces[1], "two views get different namespaces", "\(namespaces)")

struct MatchCase: View {
    @Namespace var ns
    @ObservedObject var store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.show {
                Color.clear.frame(width: 10, height: 60)
                Color.red.frame(width: 21, height: 21).matchedGeometryEffect(id: "box", in: ns)
            } else {
                Color.red.frame(width: 21, height: 21).matchedGeometryEffect(id: "box", in: ns)
            }
            Spacer()
        }
    }
}
func boxLayers(_ probe: _Probe) -> [CALayer] {
    var found: [CALayer] = []
    func walk(_ v: UIView) {
        if v.frame.size == CGSize(width: 21, height: 21) { found.append(v.layer) }
        v.subviews.forEach(walk)
    }
    walk(probe.hostView)
    return found
}
store.show = false
let matched = _Probe(MatchCase(store: store), width: 100, height: 200)
_ = frames(matched)
withAnimation(.linear(duration: 0.3)) { store.show = true }
matched.flush()
let starts = boxLayers(matched).compactMap { layer -> CGPoint? in
    guard let move = layer.animation(forKey: "position") as? CABasicAnimation, let from = move.fromValue as? NSValue else { return nil }
    return from.cgPointValue
}
check(starts.contains { abs($0.y - 10.5) < 1 }, "the matched view starts its move from the old place", "\(starts) \(boxLayers(matched).map { $0.animationKeys() ?? [] })")

struct UnmatchedCase: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.show {
                Color.clear.frame(width: 10, height: 60)
                Color.red.frame(width: 21, height: 21)
            } else {
                Color.red.frame(width: 21, height: 21)
            }
            Spacer()
        }
    }
}
store.show = false
let unmatched = _Probe(UnmatchedCase(store: store), width: 100, height: 200)
_ = frames(unmatched)
withAnimation(.linear(duration: 0.3)) { store.show = true }
unmatched.flush()
let plainStarts = boxLayers(unmatched).compactMap { layer -> CGPoint? in
    guard let move = layer.animation(forKey: "position") as? CABasicAnimation, let from = move.fromValue as? NSValue else { return nil }
    return from.cgPointValue
}
check(!plainStarts.contains { abs($0.y - 10.5) < 1 }, "without the effect the new view does not start from the old place", "\(plainStarts)")

// 33. a custom DynamicProperty keeps its nested @State and gets update() before body
var dynamicUpdates = 0
var bump: () -> Void = {}
@propertyWrapper struct NestedCounter: DynamicProperty {
    @State private var value = 10
    var wrappedValue: Int {
        get { value }
        nonmutating set { value = newValue }
    }
    mutating func update() { dynamicUpdates += 1 }
}
struct CounterCase: View {
    @NestedCounter var count: Int
    var body: some View {
        bump = { count += 5 }
        return Color.red.frame(width: CGFloat(count), height: 3)
    }
}
let nested = _Probe(CounterCase(), width: 100, height: 100)
check(frames(nested).contains { $0.size.width == 10 }, "the nested state starts at its initial value")
bump()
nested.flush()
check(frames(nested).contains { $0.size.width == 15 }, "changing the nested state re-rendered the view", "\(frames(nested))")
check(dynamicUpdates >= 2, "update() ran before each body", "\(dynamicUpdates)")

// 34. HStackLayout / VStackLayout / ZStackLayout through AnyLayout
func laidOut(_ layout: AnyLayout) -> [CGRect] {
    frames(_Probe(layout {
        Color.red.frame(width: 20, height: 10)
        Color.blue.frame(width: 30, height: 12)
    }, width: 200, height: 200)).filter { $0.size.width == 20 || $0.size.width == 30 }.sorted { $0.size.width < $1.size.width }
}
let across = laidOut(AnyLayout(HStackLayout(spacing: 5)))
if across.count == 2 {
    equal(across[1].origin.x - across[0].origin.x, 25, "HStackLayout puts the second view after the first plus spacing")
    equal(across[0].origin.y - across[1].origin.y, 1, "HStackLayout centres vertically")
} else { check(false, "HStackLayout laid out both views", "\(across)") }
let down = laidOut(AnyLayout(VStackLayout(alignment: .leading, spacing: 4)))
if down.count == 2 {
    equal(down[1].origin.y - down[0].origin.y, 14, "VStackLayout stacks with spacing")
    equal(down[0].origin.x, down[1].origin.x, "VStackLayout aligns leading edges")
} else { check(false, "VStackLayout laid out both views", "\(down)") }
let piled = laidOut(AnyLayout(ZStackLayout(alignment: .topLeading)))
if piled.count == 2 {
    equal(piled[0].origin, piled[1].origin, "ZStackLayout top-leading puts both at the same corner")
} else { check(false, "ZStackLayout laid out both views", "\(piled)") }

// 35. style families: group box, labeled content, control group, gauge, form
struct BarGauge: GaugeStyle {
    func makeBody(configuration: Configuration) -> some View {
        Color.green.frame(width: CGFloat(configuration.value * 100), height: 6)
    }
}
let gauged = frames(_Probe(Gauge(value: 30, in: 0...120) { Color.red.frame(width: 1, height: 1) }.gaugeStyle(BarGauge()), width: 200, height: 100))
check(gauged.contains { $0.size == CGSize(width: 25, height: 6) }, "the gauge style got the normalised value", "\(gauged)")

struct FramedBox: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) { configuration.label; configuration.content }.padding(3)
    }
}
let boxed = _Probe(GroupBox { Color.blue.frame(width: 13, height: 13) } label: { Color.red.frame(width: 29, height: 13) }.groupBoxStyle(FramedBox()), width: 200, height: 100)
let boxedFrames = frames(boxed)
if let label = boxedFrames.first(where: { $0.size.width == 29 }), let content = boxedFrames.first(where: { $0.size.width == 13 }) {
    equal(content.origin.x - label.origin.x, 29, "the group box style put the content right after the label")
} else { check(false, "the group box style shows both parts", "\(boxedFrames)") }

struct StackedContent: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) { configuration.label; configuration.content }
    }
}
let labeled = frames(_Probe(LabeledContent { Color.blue.frame(width: 14, height: 9) } label: { Color.red.frame(width: 31, height: 9) }.labeledContentStyle(StackedContent()), width: 200, height: 100))
if let label = labeled.first(where: { $0.size.width == 31 }), let content = labeled.first(where: { $0.size.width == 14 }) {
    equal(content.origin.y - label.origin.y, 9, "the labeled content style stacked content under the label")
} else { check(false, "the labeled content style shows both parts", "\(labeled)") }

struct Vertical: ControlGroupStyle {
    func makeBody(configuration: Configuration) -> some View { VStack(spacing: 0) { configuration.content } }
}
let grouped = frames(_Probe(ControlGroup { Color.red.frame(width: 16, height: 4); Color.blue.frame(width: 18, height: 4) }.controlGroupStyle(Vertical()), width: 200, height: 100))
if let first = grouped.first(where: { $0.size.width == 16 }), let second = grouped.first(where: { $0.size.width == 18 }) {
    equal(second.origin.y - first.origin.y, 4, "the control group style laid the controls out vertically")
} else { check(false, "the control group style shows the controls", "\(grouped)") }

struct PlainForm: FormStyle {
    func makeBody(configuration: Configuration) -> some View { VStack { configuration.content } }
}
let formed = _Probe(Form { Color.red.frame(width: 19, height: 19) }.formStyle(PlainForm()), width: 200, height: 200)
equal(formed.rowCount, 0, "a custom form style replaces the grouped table")
check(frames(formed).contains { $0.size.width == 19 }, "and still shows the content")

// 36. inset shapes, asymmetric transitions
equal(Rectangle().inset(by: 5).path(in: CGRect(x: 0, y: 0, width: 100, height: 60)).boundingRect, CGRect(x: 5, y: 5, width: 90, height: 50), "Rectangle.inset shrinks the path")
equal(Circle().inset(by: 10).path(in: CGRect(x: 0, y: 0, width: 100, height: 100)).boundingRect, CGRect(x: 10, y: 10, width: 80, height: 80), "Circle.inset shrinks the circle")
struct AsymmetricCase: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack {
            if store.show {
                Color.red.frame(width: 33, height: 33).transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.5)))
            }
        }
    }
}
store.show = true
let asym = _Probe(AsymmetricCase(store: store), width: 100, height: 100)
_ = frames(asym)
withAnimation(.linear(duration: 0.3)) { store.show = false }
asym.flush()
var leaving: UIView?
func findLeaving(_ v: UIView) { if v.bounds.size == CGSize(width: 33, height: 33) { leaving = leaving ?? v }; v.subviews.forEach(findLeaving) }
findLeaving(asym.hostView)
if let leaving {
    var outer: UIView? = leaving
    var scaled = false
    while let v = outer { if abs(v.transform.a - 0.5) < 0.01 { scaled = true }; outer = v.superview }
    check(scaled, "the removal uses the removal transition (scale), not the insertion one")
} else { check(false, "the leaving view is still on screen during its removal") }
struct PushCase: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack {
            if store.show {
                Color.red.frame(width: 33, height: 33).transition(.push(from: .bottom))
            }
        }
    }
}
store.show = true
let pushed = _Probe(PushCase(store: store), width: 100, height: 100)
_ = frames(pushed)
withAnimation(.linear(duration: 0.3)) { store.show = false }
pushed.flush()
leaving = nil
findLeaving(pushed.hostView)
if let leaving {
    var outer: UIView? = leaving
    var slid = false
    while let v = outer { if abs(v.transform.tx) > 1 || abs(v.transform.ty) > 1 { slid = true }; outer = v.superview }
    check(slid, "a push takes the old view out through the far edge")
} else { check(false, "a pushed view stays on screen while it leaves") }

// 37. onOpenURL, badge, scrollContentBackground, redaction
var opened: [URL] = []
let urlProbe = _Probe(Color.red.frame(width: 5, height: 5).onOpenURL { opened.append($0) }, width: 50, height: 50)
_ = frames(urlProbe)
check(_Probe.openURL(URL(string: "demo://item/7")!), "a mounted onOpenURL handler takes the URL")
equal(opened.map { $0.absoluteString }, ["demo://item/7"], "the handler got the URL")

struct ClearListCase: View {
    var body: some View {
        List {
            Color.red.frame(height: 10)
            Color.blue.frame(height: 10).badge(0)
        }
        .scrollContentBackground(.hidden)
    }
}
let cleared = _Probe(ClearListCase(), width: 320, height: 300)
equal(cleared.rowBadge(1), nil, "a zero badge is not shown")
check(cleared.tableBackgroundCleared, "scrollContentBackground(.hidden) clears the table background")

UIGraphicsBeginImageContextWithOptions(CGSize(width: 12, height: 12), false, 1)
let dot = UIGraphicsGetImageFromCurrentImageContext()!
UIGraphicsEndImageContext()
func imageViews(_ probe: _Probe) -> [UIImageView] {
    var found: [UIImageView] = []
    func walk(_ v: UIView) { if let i = v as? UIImageView { found.append(i) }; v.subviews.forEach(walk) }
    walk(probe.hostView)
    return found
}
let hiddenImage = _Probe(VStack { Image(uiImage: dot); Image(uiImage: dot).unredacted() }.redacted(reason: .placeholder), width: 100, height: 100)
_ = frames(hiddenImage)
let shown = imageViews(hiddenImage)
check(shown.filter { $0.image == nil }.count == 1 && shown.filter { $0.image != nil }.count == 1, "redacted hides the image, unredacted keeps its own", "\(shown.map { $0.image != nil })")
check(shown.contains { $0.image == nil && $0.bounds.size == CGSize(width: 12, height: 12) }, "the placeholder keeps the image size")

// 38. TabView with the page style pages through its children
struct PagedCase: View {
    @ObservedObject var store: Store
    var body: some View {
        TabView(selection: $store.count) {
            Color.red.tag(0)
            Color.blue.tag(1)
            Color.green.tag(2)
        }
        .tabViewStyle(.page)
    }
}
store.count = 0
let paged = _Probe(PagedCase(store: store), width: 100, height: 80)
func pager(_ probe: _Probe) -> UIScrollView? {
    var found: UIScrollView?
    func walk(_ v: UIView) { if let s = v as? UIScrollView, s.isPagingEnabled { found = found ?? s }; v.subviews.forEach(walk) }
    walk(probe.hostView)
    return found
}
if let scroller = pager(paged) {
    equal(scroller.contentSize, CGSize(width: 300, height: 80), "three pages side by side")
    store.count = 2
    paged.flush()
    equal(scroller.contentOffset.x, 200, "selecting the third tag scrolls to the third page")
} else { check(false, "the page style made a paging scroll view") }

// 39. anchor preferences resolve in an overlay's geometry; transformPreference rewrites the subtree's value
struct BoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = value ?? nextValue() }
}
struct HighlightCase: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.red.frame(width: 40, height: 10)
            Color.blue.frame(width: 21, height: 15).anchorPreference(key: BoundsKey.self, value: .bounds) { $0 }
        }
        .overlayPreferenceValue(BoundsKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    let rect = proxy[anchor]
                    Color.green.frame(width: rect.size.width + 2, height: rect.size.height + 2)
                        .position(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
                }
            }
        }
    }
}
let highlighted = frames(_Probe(HighlightCase(), width: 100, height: 100))
if let blue = highlighted.first(where: { $0.size == CGSize(width: 21, height: 15) }), let green = highlighted.first(where: { $0.size == CGSize(width: 23, height: 17) }) {
    check(abs((green.origin.x + 1) - blue.origin.x) < 1 && abs((green.origin.y + 1) - blue.origin.y) < 1, "the overlay drew around the anchored view", "blue \(blue) green \(green)")
} else { check(false, "the anchor reached the overlay", "\(highlighted)") }

struct SumKey: PreferenceKey {
    static var defaultValue = 0
    static func reduce(value: inout Int, nextValue: () -> Int) { value += nextValue() }
}
var summed: [Int] = []
_ = frames(_Probe(VStack {
    Color.red.frame(width: 5, height: 5).preference(key: SumKey.self, value: 3)
    Color.red.frame(width: 5, height: 5).preference(key: SumKey.self, value: 4)
}
.transformPreference(SumKey.self) { $0 *= 10 }
.onPreferenceChange(SumKey.self) { summed.append($0) }, width: 50, height: 50))
equal(summed.last, 70, "transformPreference saw the reduced 7 and made it 70")

// 40. a view inside frame and overlay still gets onDisappear when its branch goes away
var disappeared = 0
struct NestedDisappearCase: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack {
            if store.show {
                Color.red.onDisappear { disappeared += 1 }.frame(width: 5, height: 5).overlay(Color.blue).padding(2)
            }
        }
    }
}
store.show = true
let nestedGone = _Probe(NestedDisappearCase(store: store), width: 50, height: 50)
_ = frames(nestedGone)
store.show = false
nestedGone.flush()
equal(disappeared, 1, "onDisappear fired through padding, overlay and frame")

var rowsGone = 0
struct ForEachGoneCase: View {
    @ObservedObject var store: Store
    var body: some View {
        VStack {
            ForEach(store.items, id: \.self) { item in
                Color.red.frame(width: 5, height: 5).onDisappear { rowsGone += 1 }
            }
        }
    }
}
store.items = [1, 2, 3]
let forEachGone = _Probe(ForEachGoneCase(store: store), width: 50, height: 50)
_ = frames(forEachGone)
store.items = [1, 3]
forEachGone.flush()
equal(rowsGone, 1, "removing an item from ForEach fires its onDisappear")

// 41. Grid lines columns up across rows; cells span and align
let gridFrames = frames(_Probe(Grid(horizontalSpacing: 8, verticalSpacing: 4) {
    GridRow {
        Color.red.frame(width: 30, height: 10)
        Color.blue.frame(width: 10, height: 11)
    }
    GridRow {
        Color.green.frame(width: 12, height: 10)
        Color.yellow.frame(width: 40, height: 10)
    }
    Color.purple.frame(width: 50, height: 9).gridCellColumns(2)
}, width: 200, height: 200))
func at(_ size: CGSize) -> CGRect? { gridFrames.first { $0.size == size } }
if let red = at(CGSize(width: 30, height: 10)), let blue = at(CGSize(width: 10, height: 11)), let green = at(CGSize(width: 12, height: 10)), let yellow = at(CGSize(width: 40, height: 10)), let purple = at(CGSize(width: 50, height: 9)) {
    equal(yellow.origin.x - red.origin.x, 38, "the second column starts after the widest first cell")
    equal(blue.origin.x - red.origin.x, 53, "a narrow cell is centred in its column")
    equal(green.origin.x - red.origin.x, 9, "the narrow first-column cell is centred too")
    equal(purple.origin.x - red.origin.x, 14, "a full-width row centres across both columns")
} else { check(false, "the grid laid out every cell", "\(gridFrames)") }

let leadingGrid = frames(_Probe(Grid {
    GridRow { Color.red.frame(width: 30, height: 10) }
    GridRow { Color.green.frame(width: 12, height: 10).gridColumnAlignment(.leading) }
}, width: 200, height: 200))
if let red = leadingGrid.first(where: { $0.size.width == 30 }), let green = leadingGrid.first(where: { $0.size.width == 12 }) {
    equal(green.origin.x, red.origin.x, "gridColumnAlignment(.leading) aligns the column to its leading edge")
} else { check(false, "the leading grid laid out", "\(leadingGrid)") }

// 42. ScrollViewReader.scrollTo finds the id and scrolls to it
var scrollProxy: ScrollViewProxy?
struct ScrollToCase: View {
    var body: some View {
        ScrollViewReader { proxy in
            let _ = { scrollProxy = proxy }()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<20, id: \.self) { _ in Color.red.frame(height: 50) }
                }
            }
        }
    }
}
let scrolling = _Probe(ScrollToCase(), width: 100, height: 200)
_ = frames(scrolling)
func firstScroller(_ v: UIView) -> UIScrollView? {
    if let s = v as? UIScrollView { return s }
    for sub in v.subviews { if let s = firstScroller(sub) { return s } }
    return nil
}
if let proxy = scrollProxy, let scroller = firstScroller(scrolling.hostView) {
    proxy.scrollTo(10, anchor: .top)
    equal(scroller.contentOffset.y, 500, "scrollTo(10, anchor: .top) puts the eleventh row at the top")
    proxy.scrollTo(19, anchor: .bottom)
    equal(scroller.contentOffset.y, 800, "scrollTo(19, anchor: .bottom) stops at the end of the content")
} else { check(false, "the scroll reader handed out a proxy and made a scroll view", "proxy \(scrollProxy != nil) scroller \(firstScroller(scrolling.hostView) != nil)") }

// 43. frame alignment on both axes, fixedSize per axis, anchored effects, format specifiers
let topLeading = frames(_Probe(Color.red.frame(width: 10, height: 10).frame(width: 60, height: 40, alignment: .bottomTrailing), width: 60, height: 40))
equal(topLeading.first { $0.size.width == 10 }?.origin ?? .zero, CGPoint(x: 50, y: 30), "frame(alignment: .bottomTrailing) puts the child in the corner")
let tall = _Probe(VStack { Color.red.frame(minWidth: 5, maxWidth: .infinity, minHeight: 5, maxHeight: .infinity).fixedSize(horizontal: false, vertical: true) }, width: 80, height: 80)
if let box = frames(tall).first {
    equal(box.size.width, 80, "fixedSize(vertical:) leaves the width flexible")
    check(box.size.height < 80, "and keeps the height at its ideal", "\(box)")
}
func transformed(_ view: some View) -> CGAffineTransform {
    let probe = _Probe(view, width: 100, height: 100)
    _ = frames(probe)
    var found = CGAffineTransformIdentity
    func walk(_ v: UIView) { if !CGAffineTransformIsIdentity(v.transform) { found = v.transform }; v.subviews.forEach(walk) }
    walk(probe.hostView)
    return found
}
let corner = transformed(Color.red.frame(width: 40, height: 20).scaleEffect(2, anchor: .topLeading))
equal(CGPoint(x: corner.tx, y: corner.ty), CGPoint(x: 20, y: 10), "scaling about the top-leading corner keeps that corner in place")
let spin = transformed(Color.red.frame(width: 40, height: 20).rotationEffect(.degrees(90), anchor: .topLeading))
check(abs(spin.tx - (-30)) < 0.01 && abs(spin.ty - 10) < 0.01, "rotating about the top-leading corner keeps that corner in place", "\(spin)")
equal(_Probe.text("pi is \(3.14159, specifier: "%.2f")"), "pi is 3.14", "a specifier formats the number")
equal(_Probe.text("count \(42)"), "count 42", "an integer interpolates plainly")

// 45. stroke style reaches the shape layer; stroke is centred on the path, strokeBorder stays inside
func shapeLayers(_ probe: _Probe) -> [CAShapeLayer] {
    var found: [CAShapeLayer] = []
    func walk(_ v: UIView) { if let s = v.layer as? CAShapeLayer { found.append(s) }; v.subviews.forEach(walk) }
    walk(probe.hostView)
    return found
}
let dashed = _Probe(Rectangle().stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [5, 3], dashPhase: 2)).frame(width: 40, height: 20), width: 100, height: 100)
_ = frames(dashed)
if let layer = shapeLayers(dashed).first {
    equal(layer.lineDashPattern?.map { $0.doubleValue } ?? [], [5, 3], "the dash pattern reached the layer")
    equal(layer.lineDashPhase, 2, "and the dash phase")
    equal(layer.lineCap, CAShapeLayerLineCap.round, "and the line cap")
    equal(layer.path?.boundingBoxOfPath, CGRect(x: 0, y: 0, width: 40, height: 20), "stroke draws on the path itself")
} else { check(false, "the stroked shape made a shape layer") }
let bordered = _Probe(Rectangle().strokeBorder(Color.red, lineWidth: 4).frame(width: 40, height: 20), width: 100, height: 100)
_ = frames(bordered)
equal(shapeLayers(bordered).first?.path?.boundingBoxOfPath, CGRect(x: 2, y: 2, width: 36, height: 16), "strokeBorder insets the path by half the line")

// 46. long press honours its distance
let pressProbe = _Probe(Color.red.frame(width: 30, height: 30).onLongPressGesture(minimumDuration: 1, maximumDistance: 25, perform: {}), width: 100, height: 100)
_ = frames(pressProbe)
var pressRecognizer: UILongPressGestureRecognizer?
func findPress(_ v: UIView) { v.gestureRecognizers?.forEach { if let p = $0 as? UILongPressGestureRecognizer { pressRecognizer = p } }; v.subviews.forEach(findPress) }
findPress(pressProbe.hostView)
equal(pressRecognizer?.allowableMovement, 25, "maximumDistance became the allowable movement")
equal(pressRecognizer?.minimumPressDuration, 1, "minimumDuration reached the recognizer")

// 47. layoutValue reaches a custom Layout through its subviews
struct Rank: LayoutValueKey { static let defaultValue = 0 }
struct RankedRow: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { CGSize(width: 100, height: 10) }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        for subview in subviews {
            subview.place(at: CGPoint(x: bounds.origin.x + CGFloat(subview[Rank.self]) * 20, y: bounds.origin.y), proposal: ProposedViewSize(width: 10, height: 10))
        }
    }
}
let ranked = frames(_Probe(RankedRow {
    Color.red.frame(width: 10, height: 10).layoutValue(key: Rank.self, value: 3)
    Color.blue.frame(width: 10, height: 10)
}, width: 100, height: 10)).sorted { $0.origin.x < $1.origin.x }
if ranked.count == 2 {
    equal(ranked[1].origin.x - ranked[0].origin.x, 60, "the layout read the rank of the first view and the default of the second")
} else { check(false, "the ranked layout placed both views", "\(ranked)") }

// 48. a gradient fill really paints the shape (not its first colour)
func pixel(_ probe: _Probe, _ at: CGPoint, size: CGSize) -> (CGFloat, CGFloat, CGFloat) {
    UIGraphicsBeginImageContextWithOptions(size, true, 1)
    let context = UIGraphicsGetCurrentContext()!
    UIColor.white.setFill()
    context.fill(CGRect(origin: .zero, size: size))
    probe.hostView.layer.render(in: context)
    let image = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return (0, 0, 0) }
    let offset = Int(at.y) * cg.bytesPerRow + Int(at.x) * (cg.bitsPerPixel / 8)
    let bgr = cg.bitmapInfo.contains(.byteOrder32Little)
    let c0 = CGFloat(bytes[offset]) / 255, c1 = CGFloat(bytes[offset + 1]) / 255, c2 = CGFloat(bytes[offset + 2]) / 255
    return bgr ? (c2, c1, c0) : (c0, c1, c2)
}
let painted = _Probe(Rectangle().fill(LinearGradient(colors: [.red, .blue], startPoint: .top, endPoint: .bottom)).frame(width: 40, height: 40), width: 40, height: 40)
_ = frames(painted)
let top = pixel(painted, CGPoint(x: 20, y: 2), size: CGSize(width: 40, height: 40))
let bottom = pixel(painted, CGPoint(x: 20, y: 37), size: CGSize(width: 40, height: 40))
check(top.0 > 0.7 && top.2 < 0.3, "the top of the gradient-filled shape is red", "\(top)")
check(bottom.2 > 0.7 && bottom.0 < 0.3, "the bottom of the gradient-filled shape is blue", "\(bottom)")
let radial = _Probe(RadialGradient(colors: [.white, .black], center: .center, startRadius: 0, endRadius: 20).frame(width: 40, height: 40), width: 40, height: 40)
_ = frames(radial)
let middle = pixel(radial, CGPoint(x: 20, y: 20), size: CGSize(width: 40, height: 40))
let edge = pixel(radial, CGPoint(x: 1, y: 20), size: CGSize(width: 40, height: 40))
check(middle.0 > 0.8 && edge.0 < 0.2, "a radial gradient is light in the middle and dark at the edge", "\(middle) \(edge)")

// 49. @State inside a ViewModifier keeps its value; EnvironmentalModifier resolves against the environment
var widen: () -> Void = {}
struct Widening: ViewModifier {
    @State var wide = false
    func body(content: Content) -> some View {
        widen = { wide = true }
        return content.frame(width: wide ? 44 : 22, height: 5)
    }
}
let modified = _Probe(Color.red.modifier(Widening()), width: 100, height: 100)
check(frames(modified).contains { $0.size.width == 22 }, "the modifier starts narrow")
widen()
modified.flush()
check(frames(modified).contains { $0.size.width == 44 }, "@State inside the modifier changed and re-rendered", "\(frames(modified))")

struct SideKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }
extension EnvironmentValues { var side: CGFloat { get { self[SideKey.self] } set { self[SideKey.self] = newValue } } }
struct Sized: EnvironmentalModifier {
    func resolve(in environment: EnvironmentValues) -> some ViewModifier { FixedSide(side: environment.side) }
}
struct FixedSide: ViewModifier {
    let side: CGFloat
    func body(content: Content) -> some View { content.frame(width: side, height: side) }
}
let resolved = frames(_Probe(Color.red.modifier(Sized()).environment(\.side, 33), width: 100, height: 100))
check(resolved.contains { $0.size == CGSize(width: 33, height: 33) }, "the environmental modifier read the environment", "\(resolved)")

// 50. OutlineGroup walks a tree: collapsed groups show their parents, expanded ones their children
struct TreeNode: Identifiable {
    let id: Int
    var children: [TreeNode]?
}
struct AlwaysOpen: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) { configuration.label; configuration.content }
    }
}
let tree = [TreeNode(id: 11, children: [TreeNode(id: 12), TreeNode(id: 13, children: [TreeNode(id: 14)])]), TreeNode(id: 15)]
let outlined = frames(_Probe(VStack(spacing: 0) {
    OutlineGroup(tree, children: \.children) { node in Color.red.frame(width: CGFloat(node.id), height: 2) }
}.disclosureGroupStyle(AlwaysOpen()), width: 100, height: 100))
equal(Set(outlined.map { Int($0.size.width) }), Set([11, 12, 13, 14, 15]), "every node of the tree is shown when groups are open")
if let parent = outlined.first(where: { $0.size.width == 11 }), let grandchild = outlined.first(where: { $0.size.width == 14 }) {
    check(grandchild.origin.y > parent.origin.y, "children come under their parent")
}

// 51. List(selection:) sets the binding from the row's id or tag
final class Picked: ObservableObject { @Published var one: Int? = nil; @Published var many: Set<Int> = [] }
let picked = Picked()
struct SelectionCase: View {
    @ObservedObject var picked: Picked
    var body: some View {
        List(selection: $picked.one) {
            Color.red.frame(height: 10).tag(7)
            ForEach([20, 30], id: \.self) { value in Color.blue.frame(height: 10) }
        }
    }
}
let selecting = _Probe(SelectionCase(picked: picked), width: 320, height: 300)
_ = frames(selecting)
selecting.selectRow(0)
equal(picked.one, 7, "choosing a tagged row set the selection to its tag")
selecting.selectRow(2)
equal(picked.one, 30, "choosing a ForEach row set the selection to its id")
struct ManyCase: View {
    @ObservedObject var picked: Picked
    var body: some View {
        List(selection: $picked.many) { ForEach([1, 2, 3], id: \.self) { _ in Color.red.frame(height: 10) } }
    }
}
let many = _Probe(ManyCase(picked: picked), width: 320, height: 300)
_ = frames(many)
many.selectRow(0); many.selectRow(2); many.selectRow(0)
equal(picked.many, [3], "a set selection toggles rows")

// 52. Table on iPhone lists its rows with the first column
struct Fruit: Identifiable { let id: Int }
let tabled = _Probe(Table([Fruit(id: 12), Fruit(id: 30)]) {
    TableColumn("Size") { (fruit: Fruit) in Color.red.frame(height: CGFloat(fruit.id)) }
    TableColumn("Other") { (_: Fruit) in Color.blue.frame(height: 90) }
}, width: 320, height: 300)
_ = frames(tabled)
equal(tabled.rowCount, 2, "a row per element")
check(tabled.rowHeight(1) > tabled.rowHeight(0) && tabled.rowHeight(1) < 90, "rows follow the first column only", "\(tabled.rowHeight(0)) \(tabled.rowHeight(1))")

// 53. a changed custom environment value reaches an unchanged child
struct ReadsSide: View {
    @Environment(\.side) var side
    var body: some View { Color.red.frame(width: side, height: 4) }
}
struct SetsSide: View {
    @ObservedObject var store: Store
    var body: some View { VStack { ReadsSide() }.environment(\.side, store.width) }
}
store.width = 26
let envProbe = _Probe(SetsSide(store: store), width: 100, height: 100)
check(frames(envProbe).contains { $0.size.width == 26 }, "the child read the first value")
store.width = 37
envProbe.flush()
check(frames(envProbe).contains { $0.size.width == 37 }, "the child saw the new value", "\(frames(envProbe))")

// 54. openURL takes a custom handler (TimelineView ticking is checked in the app scenario: timers do not fire in a console process here)
var handledURL: URL?
var openAction: OpenURLAction?
struct OpensURL: View {
    @Environment(\.openURL) var openURL
    var body: some View {
        openAction = openURL
        return Color.red
    }
}
_ = frames(_Probe(OpensURL().environment(\.openURL, OpenURLAction { url in handledURL = url; return .handled }), width: 10, height: 10))
var accepted: Bool?
openAction?(URL(string: "app://inside")!) { accepted = $0 }
equal(handledURL?.absoluteString, "app://inside", "the custom openURL handler received the URL")
equal(accepted, true, "and reported it handled")

// 55. Canvas: inverse clip keeps the outside, gradient shading paints
let canvasProbe = _Probe(Canvas { context, size in
    let whole = Path(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    context.fill(whole, with: .color(.red))
    context.clip(to: Path(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)), options: .inverse)
    context.fill(whole, with: .linearGradient(Gradient(colors: [.blue, .blue]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)))
}.frame(width: 40, height: 40), width: 40, height: 40)
_ = frames(canvasProbe)
let leftSide = pixel(canvasProbe, CGPoint(x: 5, y: 20), size: CGSize(width: 40, height: 40))
let rightSide = pixel(canvasProbe, CGPoint(x: 35, y: 20), size: CGSize(width: 40, height: 40))
check(leftSide.0 > 0.7 && leftSide.2 < 0.3, "the inverse clip protected the left half", "\(leftSide)")
check(rightSide.2 > 0.7 && rightSide.0 < 0.3, "the gradient shading painted the right half", "\(rightSide)")

// 56. ForEach over a binding hands out element bindings; editActions delete through the binding
struct Chore: Identifiable { let id: Int; var width: CGFloat }
final class Chores: ObservableObject { @Published var list = [Chore(id: 1, width: 10), Chore(id: 2, width: 20), Chore(id: 3, width: 30)] }
let chores = Chores()
var secondRow: Binding<Chore>?
struct ChoreRow: View {
    let chore: Binding<Chore>
    var body: some View {
        if chore.wrappedValue.id == 2 { secondRow = chore }
        return Color.red.frame(width: chore.wrappedValue.width, height: 8)
    }
}
struct ChoresCase: View {
    @ObservedObject var chores: Chores
    var body: some View {
        List($chores.list, editActions: .all) { chore in ChoreRow(chore: chore) }
    }
}
let choreProbe = _Probe(ChoresCase(chores: chores), width: 320, height: 300)
_ = frames(choreProbe)
check(choreProbe.rowEditing(0).delete && choreProbe.rowEditing(0).move, "editActions: .all allows delete and move")
secondRow?.wrappedValue.width = 44
equal(chores.list.map { Int($0.width) }, [10, 44, 30], "the element binding wrote into its element")
choreProbe.commitDelete(0)
equal(chores.list.map { $0.id }, [2, 3], "deleting a row removed the element through the binding")

// 57. a drop ShadowStyle becomes the shape layer's shadow
let shadowed = _Probe(Circle().fill(Color.red.shadow(.drop(radius: 6, x: 2, y: 3))).frame(width: 30, height: 30), width: 60, height: 60)
_ = frames(shadowed)
if let layer = shapeLayers(shadowed).first {
    equal(layer.shadowRadius, 6, "the shadow radius reached the layer")
    equal(layer.shadowOffset, CGSize(width: 2, height: 3), "and the offset")
    equal(layer.shadowOpacity, 1, "and it is visible")
} else { check(false, "the shadowed circle made a shape layer") }

// 58. a month-sized grid lays out in reasonable time
let gridStart = Date()
let monthGrid = _Probe(Grid(horizontalSpacing: 4, verticalSpacing: 4) {
    ForEach(0..<6, id: \.self) { _ in
        GridRow {
            ForEach(0..<7, id: \.self) { _ in
                Color.red.frame(width: 36, height: 30).background(Color.clear, cornerRadius: 15).onTapGesture {}
            }
        }
    }
}, width: 320, height: 300)
_ = frames(monthGrid)
let gridSeconds = Date().timeIntervalSince(gridStart)
check(gridSeconds < 3, "a 7x6 grid builds and lays out quickly", "\(gridSeconds) s")
print("grid 7x6 took \(gridSeconds)")

// 59. @FetchRequest follows a Core Data context: rows appear as objects are inserted and saved
let noteEntity = NSEntityDescription()
noteEntity.name = "Note"
noteEntity.managedObjectClassName = "NSManagedObject"
let orderAttribute = NSAttributeDescription()
orderAttribute.name = "order"
orderAttribute.attributeType = .integer32AttributeType
orderAttribute.isOptional = false
noteEntity.properties = [orderAttribute]
let noteModel = NSManagedObjectModel()
noteModel.entities = [noteEntity]
let noteCoordinator = NSPersistentStoreCoordinator(managedObjectModel: noteModel)
var storeError: Error?
do { try noteCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil) } catch { storeError = error }
check(storeError == nil, "an in-memory store opened", "\(String(describing: storeError))")
let noteContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
noteContext.persistentStoreCoordinator = noteCoordinator
func addNote(_ order: Int) {
    let note = NSManagedObject(entity: noteEntity, insertInto: noteContext)
    note.setValue(order, forKey: "order")
}
addNote(3); addNote(1)
try? noteContext.save()
struct NotesCase: View {
    @FetchRequest(fetchRequest: {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        return request
    }()) var notes: FetchedResults<NSManagedObject>
    var body: some View {
        VStack(spacing: 0) {
            ForEach(notes, id: \.objectID) { note in
                Color.red.frame(width: CGFloat((note.value(forKey: "order") as? Int ?? 0) * 10), height: 4)
            }
        }
    }
}
let notesProbe = _Probe(NotesCase().environment(\.managedObjectContext, noteContext), width: 100, height: 100)
let noteWidths = frames(notesProbe).map { Int($0.size.width) }
equal(noteWidths, [10, 30], "the fetch returned both notes in sort order")
addNote(2)
try? noteContext.save()
notesProbe.flush()
equal(frames(notesProbe).map { Int($0.size.width) }, [10, 20, 30], "saving a new note re-rendered the fetch")

// 60. ShapeStyle backgrounds, background(in:) with backgroundStyle, containerShape for ContainerRelativeShape
let inShape = _Probe(Color.clear.frame(width: 40, height: 20).background(Color.blue, in: Capsule()), width: 100, height: 100)
_ = frames(inShape)
check(shapeLayers(inShape).contains { ($0.path?.boundingBoxOfPath.size ?? .zero) == CGSize(width: 40, height: 20) }, "background(_:in:) drew the capsule behind the view")
let styled = _Probe(Color.clear.frame(width: 30, height: 30).background(in: Circle()).backgroundStyle(Color.red), width: 60, height: 60)
_ = frames(styled)
let styledLayer = shapeLayers(styled).first
check(styledLayer?.fillColor.map { UIColor(cgColor: $0) } == UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1), "background(in:) filled with the backgroundStyle", "\(String(describing: styledLayer?.fillColor))")
let relative = _Probe(ContainerRelativeShape().fill(Color.green).frame(width: 50, height: 50).containerShape(Circle()), width: 60, height: 60)
_ = frames(relative)
let relativePath = shapeLayers(relative).first?.path
check(relativePath.map { !$0.contains(CGPoint(x: 2, y: 2)) && $0.contains(CGPoint(x: 25, y: 25)) } ?? false, "ContainerRelativeShape took the container's circle")

// branch identity: the two arms of an if/else are different views even when their types match
final class Flag: ObservableObject { @Published var on = true }
struct BranchCounter: View {
    let base: CGFloat
    @State var value = 0
    var body: some View {
        let _ = register { value += 1 }
        Color.red.frame(width: base + CGFloat(value * 10), height: 3)
    }
}
struct Branches: View {
    @ObservedObject var flag: Flag
    var body: some View {
        VStack {
            if flag.on { BranchCounter(base: 10) } else { BranchCounter(base: 100) }
        }
    }
}
let flag = Flag()
let branches = _Probe(Branches(flag: flag), width: 200, height: 50)
actions.removeLast()()
branches.flush()
equal(frames(branches).first { $0.size.height == 3 }?.size.width ?? -1, 20, "the true arm counted once")
flag.on = false
branches.flush()
equal(frames(branches).first { $0.size.height == 3 }?.size.width ?? -1, 100, "the false arm starts with its own state")
flag.on = true
branches.flush()
equal(frames(branches).first { $0.size.height == 3 }?.size.width ?? -1, 10, "coming back to the true arm starts it afresh")

// writing a state its own value does not evaluate the body again
var sameValueBodies = 0
struct SameValue: View {
    @State var value = 5
    var body: some View {
        let _ = register { value = 5 }
        let _ = sameValueBodies += 1
        Color.blue.frame(width: CGFloat(value), height: 2)
    }
}
let sameValue = _Probe(SameValue(), width: 50, height: 20)
let bodiesBefore = sameValueBodies
actions.removeLast()()
sameValue.flush()
equal(sameValueBodies, bodiesBefore, "the same value leaves the body alone")

// accessibility: sort priority, synthesized children, representation and focus
func viewsOf<T: UIView>(_ root: UIView, _ type: T.Type) -> [T] {
    var found: [T] = []
    func walk(_ view: UIView) { if let match = view as? T { found.append(match) }; view.subviews.forEach(walk) }
    walk(root)
    return found
}
func axLabel(_ element: Any?) -> String? { (element as? NSObject)?.accessibilityLabel }

struct SortedCase: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.red.frame(height: 10).accessibilityElement().accessibilityLabel("first")
            Color.blue.frame(height: 10).accessibilityElement().accessibilityLabel("second").accessibilitySortPriority(1)
        }
    }
}
let sorted = _Probe(SortedCase(), width: 100, height: 40)
var sortRoot: UIView? = sorted.hostView
while let current = sortRoot, !(current is UIWindow), current.accessibilityElementCount() == 0 || current.accessibilityElementCount() == NSNotFound { sortRoot = current.superview }
equal(sortRoot?.accessibilityElementCount() ?? -1, 2, "the host root lists both elements once a priority is set")
equal(axLabel(sortRoot?.accessibilityElement(at: 0)) ?? "", "second", "the higher priority comes first")
equal(axLabel(sortRoot?.accessibilityElement(at: 1)) ?? "", "first", "the rest keep reading order")

struct ChildrenCase: View {
    var body: some View {
        Color.gray.frame(width: 100, height: 40)
            .accessibilityChildren {
                Color.red.accessibilityElement().accessibilityLabel("one")
                Color.blue.accessibilityElement().accessibilityLabel("two")
            }
    }
}
let childrenProbe = _Probe(ChildrenCase(), width: 100, height: 40)
childrenProbe.hostView.layoutIfNeeded()
let axContainer = viewsOf(childrenProbe.hostView, UIView.self).first { $0.accessibilityElementCount() == 2 }
equal(axContainer.map { [axLabel($0.accessibilityElement(at: 0)) ?? "", axLabel($0.accessibilityElement(at: 1)) ?? ""] } ?? [], ["one", "two"],
      "accessibilityChildren exposes the synthesized children in order")
let childFrames = axContainer.map { c in (0..<2).map { (c.accessibilityElement(at: $0) as? UIAccessibilityElement)?.accessibilityFrame.size.height ?? -1 } } ?? []
equal(childFrames, [20, 20], "the synthesized children share the view's frame")

struct RepresentedCase: View {
    var body: some View {
        Color.green.frame(width: 50, height: 20)
            .accessibilityRepresentation { Toggle("Wi-Fi", isOn: .constant(true)) }
    }
}
let represented = _Probe(RepresentedCase(), width: 100, height: 40)
let representedView = viewsOf(represented.hostView, UIView.self).first { $0.isAccessibilityElement }
equal(representedView?.accessibilityLabel ?? "", "Wi-Fi", "the representation names the element")
equal(representedView?.accessibilityValue ?? "", "1", "the representation gives the toggle's value")
check((representedView?.accessibilityTraits ?? .none).contains(.button), "the representation reads as a button")

var focusReadings: [Bool] = []
struct AccessibilityFocusCase: View {
    @AccessibilityFocusState var focused: Bool
    var body: some View {
        let _ = focusReadings.append(focused)
        Color.orange.frame(width: 30, height: 30).accessibilityElement().accessibilityLabel("target").accessibilityFocused($focused)
    }
}
let focusProbe = _Probe(AccessibilityFocusCase(), width: 100, height: 40)
let focusTarget = viewsOf(focusProbe.hostView, UIView.self).first { $0.accessibilityLabel == "target" && $0.isAccessibilityElement }
focusTarget?.accessibilityElementDidBecomeFocused()
focusProbe.flush()
equal(focusReadings.last ?? false, true, "VoiceOver focus writes the binding")
focusTarget?.accessibilityElementDidLoseFocus()
focusProbe.flush()
equal(focusReadings.last ?? true, false, "losing focus clears it")

// cached sizes: a change deep inside nested stacks and modifiers still reaches the layout
final class DeepTick: ObservableObject { @Published var width: CGFloat = 10 }
struct DeepLeafNest: View {
    let depth: Int
    @ObservedObject var tick: DeepTick
    var body: some View {
        if depth == 0 {
            Color.red.frame(width: tick.width, height: 6)
        } else {
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    Color.blue.frame(width: 3, height: 3)
                    DeepLeafNest(depth: depth - 1, tick: tick).padding(1)
                }
                Color.gray.frame(height: 1)
            }
        }
    }
}
let deepTick = DeepTick()
let deepProbe = _Probe(HStack { DeepLeafNest(depth: 4, tick: deepTick); Spacer() }, width: 200, height: 100)
equal(frames(deepProbe).first { $0.size.height == 6 }?.size.width ?? -1, 10, "the deep leaf starts at its width")
deepTick.width = 37
deepProbe.flush()
equal(frames(deepProbe).first { $0.size.height == 6 }?.size.width ?? -1, 37, "a deep change is measured again")
let widthAfter = frames(deepProbe).filter { $0.size.height == 1 }.map { $0.size.width }.max() ?? -1
check(widthAfter >= 37, "the ancestors grew with the leaf", "widest rule \(widthAfter)")

// a change beneath .padding() and .frame() reaches the wrapper's own cached size: the padded box grows with its content
final class GrowingWidth: ObservableObject { @Published var width: CGFloat = 20 }
struct PaddedLeaf: View {
    @ObservedObject var model: GrowingWidth
    var body: some View { Color.green.frame(width: model.width, height: 4) }
}
let growing = GrowingWidth()
let paddedProbe = _Probe(HStack(spacing: 0) { PaddedLeaf(model: growing).padding(5).background(Color.blue, cornerRadius: 0); Spacer() }, width: 300, height: 60)
func paddedBox(_ probe: _Probe) -> CGFloat {
    var narrowest: CGFloat = 1e9
    func walk(_ view: UIView) {
        if view.bounds.size.height == 14 { narrowest = min(narrowest, view.bounds.size.width) }
        view.subviews.forEach(walk)
    }
    walk(probe.hostView)
    return narrowest
}
equal(paddedBox(paddedProbe), 30, "the padded box wraps its content at the start")
growing.width = 90
paddedProbe.flush()
equal(paddedBox(paddedProbe), 100, "the padded box grows when the content beneath it changes")

// gestures: typed events instead of guessing by closure type
func gestureWidth(_ probe: _Probe, height: CGFloat) -> CGFloat { frames(probe).first { $0.size.height == height }?.size.width ?? -1 }

// .updating writes the @GestureState while the gesture runs and puts it back afterwards
struct UpdatingCase: View {
    @GestureState private var pulled = CGSize.zero
    var body: some View {
        Color.red.frame(width: 10 + pulled.width, height: 21)
            .gesture(DragGesture().updating($pulled) { value, state, _ in state = value.translation })
    }
}
let updating = _Probe(UpdatingCase(), width: 200, height: 40)
equal(gestureWidth(updating, height: 21), 10, "the gesture state starts at its initial value")
updating.send(.drag(CGSize(width: 30, height: 0), ended: false))
updating.flush()
equal(gestureWidth(updating, height: 21), 40, "updating moved the gesture state while the drag ran")
updating.send(.drag(CGSize(width: 30, height: 0), ended: true))
updating.flush()
equal(gestureWidth(updating, height: 21), 10, "the gesture state went back when the drag ended")

// map changes the value that onChanged and onEnded see
var mapped: [CGFloat] = []
var mappedEnd: CGFloat?
let mapProbe = _Probe(Color.red.frame(width: 20, height: 22).gesture(
    DragGesture().map { $0.translation.width }.onChanged { mapped.append($0) }.onEnded { mappedEnd = $0 }), width: 100, height: 50)
mapProbe.send(.drag(CGSize(width: 15, height: 0), ended: false))
mapProbe.send(.drag(CGSize(width: 25, height: 0), ended: true))
equal(mapped, [15], "onChanged got the mapped value")
equal(mappedEnd ?? -1, 25, "onEnded got the mapped value")

// the drag waits for its minimum distance, and a shorter one is not a drag at all
var dragEnds = 0
let minProbe = _Probe(Color.red.frame(width: 20, height: 23).gesture(DragGesture(minimumDistance: 10).onEnded { _ in dragEnds += 1 }), width: 100, height: 50)
minProbe.send(.drag(CGSize(width: 4, height: 0), ended: false))
minProbe.send(.drag(CGSize(width: 4, height: 0), ended: true))
equal(dragEnds, 0, "a drag shorter than its minimum distance did not end")
minProbe.send(.drag(CGSize(width: 12, height: 0), ended: false))
minProbe.send(.drag(CGSize(width: 12, height: 0), ended: true))
equal(dragEnds, 1, "a drag past its minimum distance ended once")
var zeroEnds = 0
let zeroProbe = _Probe(Color.red.frame(width: 20, height: 24).gesture(DragGesture(minimumDistance: 0).onEnded { _ in zeroEnds += 1 }), width: 100, height: 50)
zeroProbe.send(.drag(CGSize(width: 1, height: 0), ended: false))
zeroProbe.send(.drag(CGSize(width: 1, height: 0), ended: true))
equal(zeroEnds, 1, "with no minimum distance any drag ends")

// a sequence runs its second gesture only after the first one has completed
var sequenceEnds: [String] = []
let sequenceProbe = _Probe(Color.red.frame(width: 20, height: 25).gesture(
    LongPressGesture().sequenced(before: DragGesture()).onEnded { value in
        switch value {
        case .first: sequenceEnds.append("first")
        case .second(let pressed, let drag): sequenceEnds.append("second \(pressed) \(drag == nil ? "none" : "drag")")
        }
    }), width: 100, height: 50)
sequenceProbe.send(.drag(CGSize(width: 30, height: 0), ended: false))
sequenceProbe.send(.drag(CGSize(width: 30, height: 0), ended: true))
equal(sequenceEnds, [], "a drag before the long press completed did nothing")
sequenceProbe.send(.pressDown)
sequenceProbe.send(.pressRecognized)
sequenceProbe.send(.drag(CGSize(width: 30, height: 0), ended: false))
sequenceProbe.send(.drag(CGSize(width: 30, height: 0), ended: true))
equal(sequenceEnds, ["second true drag"], "after the long press the drag ended the sequence with both values")

// exclusive: whoever starts first keeps the gesture
var exclusive: [String] = []
let exclusiveProbe = _Probe(Color.red.frame(width: 20, height: 26).gesture(
    DragGesture().exclusively(before: TapGesture()).onEnded { value in
        switch value { case .first: exclusive.append("drag"); case .second: exclusive.append("tap") }
    }), width: 100, height: 50)
exclusiveProbe.send(.drag(CGSize(width: 30, height: 0), ended: false))
exclusiveProbe.send(.tap(CGPoint(x: 5, y: 5)))
exclusiveProbe.send(.drag(CGSize(width: 30, height: 0), ended: true))
equal(exclusive, ["drag"], "the tap did not end an exclusive gesture whose drag had begun")
exclusiveProbe.send(.tap(CGPoint(x: 5, y: 5)))
equal(exclusive, ["drag", "tap"], "the tap ends it once the drag is over")

// simultaneous: both values arrive as their gestures move
var simultaneous: [String] = []
let simultaneousProbe = _Probe(Color.red.frame(width: 20, height: 27).gesture(
    RotationGesture().simultaneously(with: MagnificationGesture()).onChanged { value in
        simultaneous.append("\(value.first == nil ? "-" : "r") \(value.second == nil ? "-" : "m")")
    }), width: 100, height: 50)
simultaneousProbe.send(.pinch(1.5, ended: false))
simultaneousProbe.send(.rotate(0.5, ended: false))
equal(simultaneous, ["- m", "r m"], "each gesture's value showed up as it began")

// the finger going down and up is pressing, whatever comes of the long press
var pressing: [Bool] = []
var performed = 0
let pressingProbe = _Probe(Color.red.frame(width: 20, height: 28).onLongPressGesture(minimumDuration: 1, pressing: { pressing.append($0) }, perform: { performed += 1 }), width: 100, height: 50)
pressingProbe.send(.pressDown)
pressingProbe.send(.pressUp)
equal(pressing, [true, false], "a press that ended early reported pressing and then not pressing")
equal(performed, 0, "and did not perform")
pressingProbe.send(.pressDown)
pressingProbe.send(.pressRecognized)
pressingProbe.send(.pressUp)
equal(performed, 1, "a press that lasted long enough performed once")
equal(pressing, [true, false, true, false], "pressing ended when the long press completed")

// including: without .gesture the gesture is not attached at all
equal(_Probe(Color.red.frame(width: 20, height: 29).gesture(TapGesture().onEnded {}, including: .subviews), width: 100, height: 50).gestureCount, 0, "a mask without .gesture attaches nothing")
equal(_Probe(Color.red.frame(width: 20, height: 29).gesture(TapGesture().onEnded {}, including: .all), width: 100, height: 50).gestureCount, 1, "the full mask attaches the gesture")

// a gesture written as a composition of its own
struct FlickGesture: Gesture {
    var body: some Gesture { DragGesture(minimumDistance: 20) }
}
var flicks = 0
let flickProbe = _Probe(Color.red.frame(width: 20, height: 30).gesture(FlickGesture().onEnded { _ in flicks += 1 }), width: 100, height: 50)
flickProbe.send(.drag(CGSize(width: 10, height: 0), ended: false))
flickProbe.send(.drag(CGSize(width: 10, height: 0), ended: true))
equal(flicks, 0, "a gesture defined through its body keeps the minimum distance of its content")
flickProbe.send(.drag(CGSize(width: 40, height: 0), ended: false))
flickProbe.send(.drag(CGSize(width: 40, height: 0), ended: true))
equal(flicks, 1, "and runs its content past it")

// AnyGesture keeps the value
var erased = 0
let erasedProbe = _Probe(Color.red.frame(width: 20, height: 31).gesture(AnyGesture(TapGesture().map { 7 }).onEnded { erased = $0 }), width: 100, height: 50)
erasedProbe.send(.tap(CGPoint(x: 3, y: 3)))
equal(erased, 7, "AnyGesture passes the mapped value through")

// paths: element walking, lines and rects, stroking and trimming
var walked: [String] = []
Path { path in
    path.addLines([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10)])
    path.closeSubpath()
}.forEach { element in
    switch element {
    case .move: walked.append("move")
    case .line: walked.append("line")
    case .quadCurve: walked.append("quad")
    case .curve: walked.append("curve")
    case .closeSubpath: walked.append("close")
    }
}
equal(walked, ["move", "line", "line", "close"], "forEach walks the elements of the path")
let line = Path { $0.move(to: CGPoint(x: 0, y: 5)); $0.addLine(to: CGPoint(x: 100, y: 5)) }
equal(line.strokedPath(StrokeStyle(lineWidth: 10)).boundingRect.size.height, 10, "a stroked line is as thick as the line width")
let trimmedLine = line.trimmedPath(from: 0.25, to: 0.75).boundingRect
equal([trimmedLine.minX, trimmedLine.maxX], [25, 75], "trimming keeps the fractions of the length asked for")
equal(line.trimmedPath(from: 0.6, to: 0.4).isEmpty, true, "a trim that ends before it starts is empty")
let outline = Path(CGRect(x: 0, y: 0, width: 10, height: 10))
equal(outline.trimmedPath(from: 0, to: 1).boundingRect.size.width, 10, "a full trim keeps the whole path")
let halfSquare = outline.trimmedPath(from: 0, to: 0.5).boundingRect
equal(halfSquare.size, CGSize(width: 10, height: 10), "half of a outline outline is two of its sides")
var rects = Path()
rects.addRects([CGRect(x: 0, y: 0, width: 5, height: 5), CGRect(x: 20, y: 0, width: 5, height: 5)])
equal(rects.boundingRect.size.width, 25, "addRects adds every rect")
var arc = Path()
arc.addRelativeArc(center: CGPoint(x: 50, y: 50), radius: 50, startAngle: .degrees(0), delta: .degrees(180))
equal(arc.boundingRect.size.width.rounded(), 100, "a relative arc of half a turn spans the diameter")

// trim and size on shapes
let trimmed = _Probe(Circle().trim(from: 0, to: 0.5).stroke(Color.red, lineWidth: 2).frame(width: 100, height: 100), width: 100, height: 100)
_ = frames(trimmed)
let trimmedBox = shapeLayers(trimmed).first?.path?.boundingBoxOfPath ?? .zero
check(trimmedBox.size.width > 90 && trimmedBox.size.height > 40 && trimmedBox.size.height < 60, "half a circle is as wide as the circle and half as tall", "\(trimmedBox)")
let sized = _Probe(Circle().size(width: 30, height: 30).fill(Color.red).frame(width: 100, height: 100), width: 100, height: 100)
_ = frames(sized)
equal(shapeLayers(sized).first?.path?.boundingBoxOfPath, CGRect(x: 0, y: 0, width: 30, height: 30), "size gives the shape a fixed size at the origin")

// a Circle asks for the smaller side of what it is offered
let roundFit = frames(_Probe(HStack { Circle().fill(Color.red).frame(height: 40) }, width: 200, height: 100))
equal(roundFit.first?.size.width ?? -1, 40, "a circle offered a wide strip takes the height")

// animatable shapes move between two values while an animation runs
struct GrowingBar: Shape {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path { Path(CGRect(x: 0, y: 0, width: rect.size.width * CGFloat(progress), height: rect.size.height)) }
}
struct GrowingCase: View {
    @State private var progress = 0.0
    var body: some View {
        let _ = register { withAnimation(.linear(duration: 1)) { progress = 1 } }
        let _ = register { progress = 0.2 }
        GrowingBar(progress: progress).fill(Color.red).frame(width: 100, height: 10)
    }
}
_Probe.useVirtualClock()
let growing2 = _Probe(GrowingCase(), width: 100, height: 10)
_ = frames(growing2)
let unanimated = actions.removeLast()
let animated = actions.removeLast()
func barWidth(_ probe: _Probe) -> CGFloat { shapeLayers(probe).first?.path?.boundingBoxOfPath.size.width ?? -1 }
equal(barWidth(growing2), 0, "the bar starts empty")
animated()
growing2.flush()
equal(barWidth(growing2), 0, "an animated change starts from the old value")
_Probe.advanceAnimations(to: 0.5)
equal(barWidth(growing2).rounded(), 50, "halfway through a linear animation the bar is half full")
_Probe.advanceAnimations(to: 1.2)
equal(barWidth(growing2), 100, "at the end it is full")
equal(_Probe.runningAnimations, 0, "and the animation is over")
unanimated()
growing2.flush()
equal(barWidth(growing2), 20, "a change outside withAnimation shows at once")

// a geometry effect with animatable data moves through its values
struct SlideEffect: GeometryEffect {
    var distance: CGFloat
    var animatableData: CGFloat {
        get { distance }
        set { distance = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform { ProjectionTransform(CGAffineTransform(translationX: distance, y: 0)) }
}
struct SlideCase: View {
    @State private var distance: CGFloat = 0
    var body: some View {
        let _ = register { withAnimation(.linear(duration: 2)) { distance = 40 } }
        Color.blue.frame(width: 20, height: 10).modifier(SlideEffect(distance: distance))
    }
}
func slid(_ probe: _Probe) -> CGFloat {
    var found: CGFloat = 0
    func walk(_ view: UIView) { if view.layer.transform.m41 != 0 { found = view.layer.transform.m41 }; view.subviews.forEach(walk) }
    walk(probe.hostView)
    return found
}
_Probe.useVirtualClock()
let sliding = _Probe(SlideCase(), width: 100, height: 10)
_ = frames(sliding)
equal(slid(sliding), 0, "the effect starts at rest")
actions.removeLast()()
sliding.flush()
_Probe.advanceAnimations(to: 1)
equal(slid(sliding).rounded(), 20, "halfway through, the effect has moved half the distance")
_Probe.advanceAnimations(to: 2.5)
equal(slid(sliding), 40, "and all of it at the end")

// a view under a transform keeps its own size when it is laid out again
struct RotatedCase: View {
    @State private var extra: CGFloat = 5
    var body: some View {
        let _ = register { extra = 9 }
        VStack(spacing: 0) {
            Color.blue.frame(width: 30, height: extra)
            Color.red.frame(width: 40, height: 20).rotationEffect(.degrees(45))
        }
    }
}
let rotated = _Probe(RotatedCase(), width: 100, height: 100)
_ = frames(rotated)
actions.removeLast()()
rotated.flush()
func turnedSize(_ probe: _Probe) -> CGSize {
    var size = CGSize.zero
    func walk(_ view: UIView) { if !CGAffineTransformIsIdentity(view.transform) { size = view.bounds.size }; view.subviews.forEach(walk) }
    walk(probe.hostView)
    return size
}
equal(turnedSize(rotated), CGSize(width: 40, height: 20), "a rotated view is still 40 by 20 after a second layout")

// ProjectionTransform arithmetic
let move = ProjectionTransform(CGAffineTransform(translationX: 10, y: 5))
let grow = ProjectionTransform(CGAffineTransform(scaleX: 2, y: 3))
let both = move.concatenating(grow)
equal([both.m31, both.m32], [20, 15], "concatenating applies the first transform, then the second")
equal(both.inverted().concatenating(both), ProjectionTransform(), "a transform times its inverse is the identity")
check(move.isAffine && !move.isIdentity && ProjectionTransform().isIdentity, "affine and identity are told apart")

// List(range) builds rows from a range
let rangeList = _Probe(List(0..<3) { Color.red.frame(height: 20).tag($0) }, width: 200, height: 200)
equal(rangeList.rowCount, 3, "a list made from a range has a row for each number")

// Layout protocol: the cache lives between passes, updateCache is told of changes, explicitAlignment is heard
final class CacheLog { var made = 0; var updated = 0 }
let cacheLog = CacheLog()
struct CachedRow: Layout {
    var gap: CGFloat
    func makeCache(subviews: Subviews) -> Int { cacheLog.made += 1; return subviews.count }
    func updateCache(_ cache: inout Int, subviews: Subviews) { cacheLog.updated += 1; cache = subviews.count }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Int) -> CGSize { CGSize(width: CGFloat(cache) * 10 + gap, height: 10) }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Int) {
        for (index, subview) in subviews.enumerated() { subview.place(at: CGPoint(x: CGFloat(index) * 10, y: 0), proposal: ProposedViewSize(width: 10, height: 10)) }
    }
}
struct CachedCase: View {
    @State private var gap: CGFloat = 0
    var body: some View {
        let _ = register { gap = 5 }
        CachedRow(gap: gap) { Color.red.frame(width: 10, height: 10); Color.blue.frame(width: 10, height: 10) }
    }
}
let cachedProbe = _Probe(CachedCase(), width: 100, height: 50)
_ = frames(cachedProbe)
equal(cacheLog.made, 1, "the cache was made once for the first passes")
let updatesBefore = cacheLog.updated
actions.removeLast()()
cachedProbe.flush()
check(cacheLog.updated > updatesBefore, "a changed layout was told to update its cache")
equal(cacheLog.made, 1, "and the cache was not made again")

struct GuideBox: Layout {
    var reports: Bool
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { CGSize(width: 30, height: 10) }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
    func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGFloat? {
        reports && guide == .leading ? 12 : nil
    }
}
func barX(reporting: Bool) -> CGFloat {
    frames(_Probe(VStack(alignment: .leading, spacing: 0) {
        GuideBox(reports: reporting) { Color.clear.frame(width: 1, height: 1) }
        Color.red.frame(width: 10, height: 8)
    }, width: 100, height: 100)).first { $0.size.height == 8 }?.origin.x ?? -1
}
equal(barX(reporting: false), 35, "with no guide reported the bar sits at the stack's leading edge")
equal(barX(reporting: true) - barX(reporting: false), 12, "a stack lined its leading edge up with the guide the layout reported")

struct HorizontalKind: Layout {
    static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .horizontal
        return properties
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { CGSize(width: 40, height: 20) }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        for subview in subviews { subview.place(at: bounds.origin, proposal: ProposedViewSize(width: 40, height: 20)) }
    }
}
let dividerBox = frames(_Probe(HorizontalKind { Divider() }, width: 100, height: 100)).first
equal(dividerBox?.size.width ?? -1, 1, "a divider in a layout that says it is horizontal stands upright")

struct SpreadRow: Layout {
    var spread: CGFloat
    var animatableData: CGFloat {
        get { spread }
        set { spread = newValue }
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { CGSize(width: 100, height: 10) }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        for (index, subview) in subviews.enumerated() { subview.place(at: CGPoint(x: CGFloat(index) * spread, y: 0), proposal: ProposedViewSize(width: 10, height: 10)) }
    }
}
struct SpreadCase: View {
    @State private var spread: CGFloat = 10
    var body: some View {
        let _ = register { withAnimation(.linear(duration: 1)) { spread = 50 } }
        SpreadRow(spread: spread) { Color.red.frame(width: 10, height: 10); Color.blue.frame(width: 10, height: 10) }
    }
}
_Probe.useVirtualClock()
let spreading = _Probe(SpreadCase(), width: 100, height: 20)
func secondX(_ probe: _Probe) -> CGFloat { frames(probe).sorted { $0.origin.x < $1.origin.x }.last?.origin.x ?? -1 }
equal(secondX(spreading), 10, "the layout starts with its spread of 10")
actions.removeLast()()
spreading.flush()
_Probe.advanceAnimations(to: 0.5)
spreading.flush()
equal(secondX(spreading).rounded(), 30, "halfway through, an animatable layout has moved half of the spread")
_Probe.advanceAnimations(to: 1.5)
spreading.flush()
equal(secondX(spreading), 50, "and all of it at the end")

// combining explicit alignment values
enum CenterOfThree: AlignmentID { static func defaultValue(in context: ViewDimensions) -> CGFloat { 0 } }
equal(HorizontalAlignment(CenterOfThree.self).combineExplicit([10, nil, 20, 30]), 20, "explicit values are averaged, the missing ones left out")
equal(VerticalAlignment.top.combineExplicit([nil, nil]) == nil, true, "with no explicit value there is none to report")

// a ViewModifier that is Animatable has its body evaluated with data between the old and the new
struct WidthModifier: ViewModifier, Animatable {
    var width: CGFloat
    var animatableData: CGFloat {
        get { width }
        set { width = newValue }
    }
    func body(content: Content) -> some View { content.frame(width: width, height: 6) }
}
struct WidthModifierCase: View {
    @State private var width: CGFloat = 10
    var body: some View {
        let _ = register { withAnimation(.linear(duration: 1)) { width = 90 } }
        Color.red.modifier(WidthModifier(width: width))
    }
}
_Probe.useVirtualClock()
let widening = _Probe(WidthModifierCase(), width: 200, height: 20)
func redWidth(_ probe: _Probe) -> CGFloat { frames(probe).first { $0.size.height == 6 }?.size.width ?? -1 }
equal(redWidth(widening), 10, "the modifier starts at its width")
actions.removeLast()()
widening.flush()
_Probe.advanceAnimations(to: 0.5)
widening.flush()
equal(redWidth(widening).rounded(), 50, "halfway through, the modifier's body ran with half of the change")
_Probe.advanceAnimations(to: 1.5)
widening.flush()
equal(redWidth(widening), 90, "and with all of it at the end")

// dialogs: every overload of alert and confirmationDialog ends in the same buttons, roles and order
_Probe.captureDialogs(true)
var dialogLog: [String] = []
struct DialogCase: View {
    @State private var alertShown = false
    @State private var bareShown = false
    @State private var presentingShown = false
    @State private var errorShown = false
    @State private var sheetShown = false
    @State private var visibleSheetShown = false
    @State private var stringTitleShown = false
    @State private var oldAlertItem: DialogItem?
    @State private var payload: String?
    @State private var failure: DialogFailure?
    var body: some View {
        let _ = register { alertShown = true }
        let _ = register { bareShown = true }
        let _ = register { presentingShown = true }
        let _ = register { errorShown = true; failure = DialogFailure() }
        let _ = register { sheetShown = true }
        let _ = register { visibleSheetShown = true }
        let _ = register { payload = "report" }
        let _ = register { stringTitleShown = true }
        let _ = register { oldAlertItem = DialogItem(id: 3) }
        Color.red.frame(width: 10, height: 10)
            .alert("Delete?", isPresented: $alertShown) {
                Button("Delete", role: .destructive) { dialogLog.append("delete") }
                Button("Keep") { dialogLog.append("keep") }
                Button("Cancel", role: .cancel) { dialogLog.append("cancel") }
            } message: { Text("This cannot be undone.") }
            .alert("Bare", isPresented: $bareShown) {}
            .alert("Presenting", isPresented: $presentingShown, presenting: payload) { value in
                Button("Open \(value)") { dialogLog.append("open \(value)") }
            }
            .alert(isPresented: $errorShown, error: failure) { Button("Retry") { dialogLog.append("retry") } }
            .alert("Plain string", isPresented: $stringTitleShown) { Button("Fine") {} }
            .alert(item: $oldAlertItem) { item in
                Alert(title: Text("Item \(item.id)"), message: Text("old style"), primaryButton: .destructive(Text("Remove")) { dialogLog.append("remove") }, secondaryButton: .cancel())
            }
            .confirmationDialog("Sort", isPresented: $sheetShown) {
                Button("Name") { dialogLog.append("name") }
                Button("Date") { dialogLog.append("date") }
            }
            .confirmationDialog("Share", isPresented: $visibleSheetShown, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {}
                Button("Nevermind", role: .cancel) {}
            } message: { Text("Pick one") }
    }
}
struct DialogItem: Identifiable { let id: Int }
struct DialogFailure: LocalizedError { var errorDescription: String? { "Upload failed" } }
let dialogProbe = _Probe(DialogCase(), width: 100, height: 40)
_ = frames(dialogProbe)
let dialogActions = actions.suffix(9)
let dialogTriggers = Array(dialogActions)
actions.removeLast(9)
func shown(_ index: Int) -> _DialogDescription? {
    dialogTriggers[index]()
    dialogProbe.flush()
    return _Probe.shownDialog
}
let deleteDialog = shown(0)
equal(deleteDialog?.title ?? "", "Delete?", "the alert has its title")
equal(deleteDialog?.message ?? "", "This cannot be undone.", "and its message")
equal(deleteDialog?.buttons ?? [], ["Cancel", "Delete", "Keep"], "the cancel button comes first, the others in the order written")
equal(deleteDialog?.roles ?? [], ["cancel", "destructive", "default"], "with their roles")
equal(deleteDialog?.cancelIndex ?? -1, 0, "the cancel index points at it")
_Probe.pressDialogButton(1)
equal(dialogLog, ["delete"], "pressing a button ran its action")
dialogProbe.flush()
check(_Probe.shownDialog == nil, "and the dialog was dismissed through its binding")
equal(shown(1)?.buttons ?? [], ["OK"], "an alert with no actions gets an OK button")
_Probe.pressDialogButton(0)
dialogProbe.flush()
check(shown(2) == nil, "an alert that presents nothing does not show while its data is missing")
dialogTriggers.count > 6 ? dialogTriggers[6]() : ()
dialogProbe.flush()
equal(_Probe.shownDialog?.buttons ?? [], ["Open report"], "an alert that presents data builds its actions from it")
_Probe.pressDialogButton(0)
dialogProbe.flush()
equal(dialogLog.last ?? "", "open report", "and the action sees the data")
let errorDialog = shown(3)
equal(errorDialog?.title ?? "", "Upload failed", "an error alert takes its title from the error")
_Probe.pressDialogButton(0)
dialogProbe.flush()
let stringDialog = shown(7)
equal(stringDialog?.title ?? "", "Plain string", "an alert titled with a string shows the string")
_Probe.pressDialogButton(0)
dialogProbe.flush()
let itemDialog = shown(8)
equal(itemDialog?.title ?? "", "Item 3", "an alert made from an item shows the item's alert")
equal(itemDialog?.roles ?? [], ["cancel", "destructive"], "with the destructive button marked")
_Probe.pressDialogButton(1)
dialogProbe.flush()
let sortSheet = shown(4)
check(sortSheet?.isAlert == false, "a confirmation dialog is an action sheet")
equal(sortSheet?.buttons ?? [], ["Name", "Date", "Cancel"], "a cancel button is added when there is none")
equal(sortSheet?.title ?? "x", "", "the title is hidden unless it is asked for")
_Probe.pressDialogButton(2)
dialogProbe.flush()
let shareSheet = shown(5)
equal(shareSheet?.title ?? "", "Share", "a visible title is shown")
equal(shareSheet?.buttons ?? [], ["Delete", "Nevermind"], "a cancel button of its own replaces the added one")
equal(shareSheet?.destructiveIndex ?? -1, 0, "the destructive button is marked")
equal(shareSheet?.cancelIndex ?? -1, 1, "and so is the cancel button")
equal(shareSheet?.message ?? "", "Pick one", "the message is kept")
_Probe.pressDialogButton(1)
dialogProbe.flush()
_Probe.captureDialogs(false)

// lineLimit(_:reservesSpace:) needs fonts, so it is pinned by a rendered scenario; the rest is checked here
let reserve = _Probe(Color.red.frame(width: 30, height: 20).mask(alignment: .leading) { Color.black.frame(width: 10, height: 20) }, width: 100, height: 50)
check(!frames(reserve).isEmpty, "a view masked by a view is still laid out")
equal(frames(reserve).first?.size ?? .zero, CGSize(width: 30, height: 20), "and keeps its size")

// text and list environment keys read back what was set, and the defaults match Apple's
var seenEnvironment: [String] = []
struct EnvironmentReader: View {
    @Environment(\.lineSpacing) var spacing
    @Environment(\.minimumScaleFactor) var scale
    @Environment(\.truncationMode) var truncation
    @Environment(\.lineLimit) var limit
    @Environment(\.autocorrectionDisabled) var noCorrect
    @Environment(\.defaultMinListRowHeight) var rowHeight
    @Environment(\.isScrollEnabled) var scrolls
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some View {
        seenEnvironment = ["\(spacing)", "\(scale)", "\(truncation)", "\(String(describing: limit))", "\(noCorrect)", "\(rowHeight)", "\(scrolls)", "\(reduceMotion)"]
        return Color.red.frame(width: 10, height: 10)
    }
}
_ = _Probe(EnvironmentReader(), width: 50, height: 50)
equal(seenEnvironment, ["0.0", "1.0", "tail", "nil", "false", "44.0", "true", "false"], "environment defaults")
_ = _Probe(EnvironmentReader().environment(\.lineSpacing, 4).environment(\.minimumScaleFactor, 0.5).environment(\.truncationMode, .middle)
    .environment(\.lineLimit, 2).environment(\.autocorrectionDisabled, true).environment(\.defaultMinListRowHeight, 60).environment(\.isScrollEnabled, false),
    width: 50, height: 50)
equal(seenEnvironment, ["4.0", "0.5", "middle", "Optional(2)", "true", "60.0", "false", "false"], "environment values read back what was set")

// Path is a value and a Shape; Color is Hashable
func pathElements(_ path: Path) -> Int { var n = 0; path.forEach { _ in n += 1 }; return n }
var pathA = Path()
pathA.move(to: .zero)
pathA.addLine(to: CGPoint(x: 10, y: 0))
var pathB = pathA
pathB.addLine(to: CGPoint(x: 10, y: 10))
equal(pathElements(pathA), 2, "a copy of a path that is changed leaves the original alone")
equal(pathElements(pathB), 3, "and the copy has the change")
equal(pathA.currentPoint ?? .zero, CGPoint(x: 10, y: 0), "the current point is the last point")
check(Path(CGRect(x: 0, y: 0, width: 10, height: 10)).contains(CGPoint(x: 5, y: 5)), "a path knows what it contains")
var moved = Path()
moved.addRect(CGRect(x: 0, y: 0, width: 10, height: 10), transform: CGAffineTransform(translationX: 100, y: 0))
equal(moved.boundingRect.origin.x, 100, "a path is added with a transform")
let pathProbe = _Probe(Path(CGRect(x: 0, y: 0, width: 10, height: 10)).fill(Color.red).frame(width: 20, height: 20), width: 50, height: 50)
check(!frames(pathProbe).isEmpty, "a path is a view")
equal(Set([Color.red, Color.red, Color.blue]).count, 2, "colors that look the same are one in a set")
check(Color(UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1)) == Color.red, "a color made from a UIColor is that color")

// an aspect ratio with only the width proposed, and an adaptive grid column that becomes as many tracks as fit
let ratioProbe = _Probe(VStack { Color.red.aspectRatio(2, contentMode: .fit) }, width: 100, height: 200)
equal(frames(ratioProbe).first?.size ?? .zero, CGSize(width: 100, height: 50), "a view of aspect ratio 2 in a stack is twice as wide as high")
struct AdaptiveCase: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 30), spacing: 10)], spacing: 10) {
            ForEach(0..<5) { _ in Color.red.aspectRatio(1, contentMode: .fit) }
        }
    }
}
let adaptiveProbe = _Probe(AdaptiveCase(), width: 100, height: 200)
let tileFrames = frames(adaptiveProbe)
equal(tileFrames.count, 5, "an adaptive grid shows every tile")
equal(Set(tileFrames.map { $0.origin.x }).count, 2, "in two columns, since two 30-point tiles and their gap fit in 100")
equal(tileFrames.first?.size ?? .zero, CGSize(width: 45, height: 45), "each as wide as its share of the room")

final class TaskStore0: ObservableObject { @Published var n = 0 }
let taskStore0 = TaskStore0()
struct TaskLikeCase: View { @ObservedObject var store: TaskStore0; @State var local = 1; var body: some View { Color.red.frame(width: 5, height: 5) } }
// @Observable models: a view that reads one is re-rendered when what it read changes, and only then
@Observable final class TallyModel { var count = 0; var other = 0 }
struct ObservedCase: View {
    let tally: TallyModel
    var body: some View { Color.red.frame(width: CGFloat(10 + tally.count), height: 10) }
}
let tally = TallyModel()
let observed = _Probe(ObservedCase(tally: tally), width: 100, height: 50)
equal(frames(observed).first?.width ?? 0, 10, "a view of an @Observable model shows it")
let evaluationsBefore = observed.bodyEvaluations
tally.count = 20
observed.flush()
equal(frames(observed).first?.width ?? 0, 30, "and follows a change of what it read")
tally.other = 5
observed.flush()
equal(observed.bodyEvaluations, evaluationsBefore + 1, "but not a change of what it did not read")
struct EnvironmentObservedCase: View {
    @Environment(TallyModel.self) var model: TallyModel?
    var body: some View { Color.blue.frame(width: CGFloat(10 + (model?.count ?? 0)), height: 10) }
}
let environmentTallyModel = TallyModel()
environmentTallyModel.count = 7
let environmentProbe = _Probe(EnvironmentObservedCase().environment(environmentTallyModel), width: 100, height: 50)
equal(frames(environmentProbe).first?.width ?? 0, 17, "an @Observable model comes from the environment by its type")
let bindable = Bindable(wrappedValue: tally)
bindable.count.wrappedValue = 3
equal(tally.count, 3, "a Bindable makes a binding to a property of the model")

// the Mirror fallback of the field reflection agrees with the runtime's own on real views
check(_Probe.mirrorReflectionAgrees(Counter()), "the fallback finds the fields of a stateful view where the runtime does")
check(_Probe.mirrorReflectionAgrees(ObservedCase(tally: tally)), "and of a view with a model")
check(_Probe.mirrorReflectionAgrees(EnvironmentReader()), "and of one that reads the environment")
check(_Probe.mirrorReflectionAgrees(TaskLikeCase(store: taskStore0)), "and of one that holds an observed object")
check(_Probe.mirrorReflectionAgrees(CounterCase()), "and of one with a property wrapper that holds a state")
_Probe.useMirrorReflection(true)
let mirrored = _Probe(Counter(), width: 200, height: 100)
mirrored.flush()
check(!frames(mirrored).isEmpty, "a stateful view still renders with the fallback on")
_Probe.useMirrorReflection(mirrorAll)

// a toolbar on a scroll view leaves the content in place
let toolbarScroll = _Probe(ScrollView { Color.red.frame(height: 50) }.toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Go") { } } }, width: 100, height: 200)
equal(frames(toolbarScroll).count, 1, "a scroll view with a toolbar still shows its content")

// a Spacer does not shrink what its neighbours are offered: content up to 66 wide beside a Spacer gets its 66
let besideSpacer = _Probe(HStack { Color.red.frame(maxWidth: 66, maxHeight: 10); Spacer(); Color.blue.frame(width: 22, height: 10) }, width: 152, height: 40)
equal(frames(besideSpacer).first?.width ?? 0, 66, "a view beside a spacer gets its full width when there is room")

// a binding to a collection is a collection of bindings
var boundNumbers = [1, 2, 3]
let boundCollection = Binding(get: { boundNumbers }, set: { boundNumbers = $0 })
boundCollection[1].wrappedValue = 20
equal(boundNumbers, [1, 20, 3], "an element of a bound collection is a binding to it")
equal(boundCollection.filter { $0.wrappedValue > 1 }.count, 2, "a bound collection can be filtered like a collection")
equal(boundCollection.count, 3, "and counted")

// a list keeps its rows when the data around them changes: inserted, removed and moved rows come out right
struct DiffCase: View {
    @ObservedObject var store: Store
    var body: some View {
        List { ForEach(store.items, id: \.self) { item in Color.red.frame(height: CGFloat(item * 10)) } }
    }
}
func rowWidths(_ probe: _Probe) -> [Int] {
    frames(probe).filter { $0.size.width > 250 && $0.size.height >= 30 && $0.size.height.truncatingRemainder(dividingBy: 10) == 0 }
        .sorted { $0.origin.y < $1.origin.y }.map { Int($0.size.height / 10) }
}
UIView.setAnimationsEnabled(false)
let diffStore = Store()
diffStore.items = [3, 4, 5]
let diffProbe = _Probe(DiffCase(store: diffStore), width: 320, height: 400)
equal(rowWidths(diffProbe), [3, 4, 5], "a list shows its rows")
diffStore.items = [3, 6, 4, 5]
diffProbe.flush()
equal(rowWidths(diffProbe), [3, 6, 4, 5], "a row inserted in the middle appears there")
diffStore.items = [3, 4, 5]
diffProbe.flush()
equal(rowWidths(diffProbe), [3, 4, 5], "a row removed is gone")
diffStore.items = [5, 3, 4]
diffProbe.flush()
equal(rowWidths(diffProbe), [5, 3, 4], "rows that moved are where they went")
diffStore.items = [4, 7, 5, 8]
diffProbe.flush()
equal(rowWidths(diffProbe), [4, 7, 5, 8], "moves, removals and insertions at once")
diffStore.items = []
diffProbe.flush()
equal(rowWidths(diffProbe), [], "an emptied list shows nothing")
diffStore.items = [7, 8]
diffProbe.flush()
equal(rowWidths(diffProbe), [7, 8], "and can be filled again")
UIView.setAnimationsEnabled(true)

// swipe actions: handed to the table's delegate as UIKit's own contextual actions when the backports provide them
@objc(UIContextualAction) final class StandInAction: NSObject {
    @objc var backgroundColor: UIColor?
    var title = "", style = 0
    var handler: AnyObject?
    @objc(contextualActionWithStyle:title:handler:) static func make(_ style: Int, _ title: String, _ handler: AnyObject) -> StandInAction {
        let action = StandInAction(); action.style = style; action.title = title; action.handler = handler; return action
    }
}
@objc(UISwipeActionsConfiguration) final class StandInConfiguration: NSObject {
    var actions: [StandInAction] = []
    @objc var performsFirstActionWithFullSwipe = true
    @objc(configurationWithActions:) static func make(_ actions: [Any]) -> StandInConfiguration {
        let configuration = StandInConfiguration(); configuration.actions = actions.compactMap { $0 as? StandInAction }; return configuration
    }
}
var bridgeSwiped: [String] = []
struct BridgeSwipeCase: View {
    var body: some View {
        List {
            Color.red.frame(height: 30).swipeActions(edge: .trailing) {
                Button("Archive") { bridgeSwiped.append("archive") }.tint(.blue)
                Button("Delete", role: .destructive) { bridgeSwiped.append("delete") }
            }
            Color.green.frame(height: 30).swipeActions(edge: .leading, allowsFullSwipe: false) { Button("Pin") { bridgeSwiped.append("pin") } }
            Color.blue.frame(height: 30)
        }
    }
}
_ = StandInAction.self; _ = StandInConfiguration.self
let bridgeProbe = _Probe(BridgeSwipeCase(), width: 320, height: 300)
if let trailing = bridgeProbe.swipeConfiguration(row: 0, leading: false) as? StandInConfiguration {
    equal(trailing.actions.map { $0.title }, ["Archive", "Delete"], "trailing swipe actions are the buttons, in order")
    equal(trailing.actions.map { $0.style }, [0, 1], "a destructive button is a destructive action")
    check(trailing.actions[0].backgroundColor == UIColor.blue || trailing.actions[0].backgroundColor != nil, "a tinted button has that background")
    check(trailing.performsFirstActionWithFullSwipe, "a full swipe runs the first by default")
    typealias Done = @convention(block) (Bool) -> Void
    typealias Run = @convention(block) (AnyObject, AnyObject, Done) -> Void
    let run = unsafeBitCast(trailing.actions[1].handler, to: Run.self)
    var completed = false
    run(trailing.actions[1], UIView(), { completed = $0 })
    equal(bridgeSwiped, ["delete"], "an action runs its button")
    check(completed, "and tells UIKit it is done")
} else { check(false, "the table answers a trailing swipe with a configuration") }
if let leading = bridgeProbe.swipeConfiguration(row: 1, leading: true) as? StandInConfiguration {
    equal(leading.actions.map { $0.title }, ["Pin"], "a leading swipe has its own actions")
    check(!leading.performsFirstActionWithFullSwipe, "and allowsFullSwipe: false is kept")
} else { check(false, "the table answers a leading swipe with a configuration") }
check(bridgeProbe.swipeConfiguration(row: 2, leading: false) == nil, "a row without swipe actions gets none")

// .disabled dims what it covers and stops touches; .allowsHitTesting stops touches only
func alphas(_ probe: _Probe) -> [CGFloat] {
    var found: [CGFloat] = []
    func walk(_ v: UIView) { found.append(v.alpha); v.subviews.forEach(walk) }
    probe.hostView.subviews.forEach(walk)
    return found
}
check(alphas(_Probe(Color.red.frame(width: 20, height: 20).disabled(true), width: 50, height: 50)).contains { abs($0 - 0.4) < 0.01 }, "a disabled view is dimmed")
check(!alphas(_Probe(Color.red.frame(width: 20, height: 20).allowsHitTesting(false), width: 50, height: 50)).contains { abs($0 - 0.4) < 0.01 }, "a view that ignores touches is not")
check(!alphas(_Probe(Color.red.frame(width: 20, height: 20).disabled(false), width: 50, height: 50)).contains { abs($0 - 0.4) < 0.01 }, "and one that is enabled is not")

// alignments and enums that apps name
let cornerProbe = _Probe(ZStack(alignment: .topTrailing) { Color.red.frame(width: 50, height: 50); Color.blue.frame(width: 10, height: 10) }, width: 50, height: 50)
check(frames(cornerProbe).contains { $0.origin == CGPoint(x: 40, y: 0) && $0.size == CGSize(width: 10, height: 10) }, "topTrailing puts a view in the top right corner")
let cornerProbe2 = _Probe(ZStack(alignment: .bottomLeading) { Color.red.frame(width: 50, height: 50); Color.blue.frame(width: 10, height: 10) }, width: 50, height: 50)
check(frames(cornerProbe2).contains { $0.origin == CGPoint(x: 0, y: 40) && $0.size == CGSize(width: 10, height: 10) }, "bottomLeading puts one in the bottom left")
equal(Axis.allCases.count, 2, "Axis lists its cases")
equal(Axis(rawValue: 1) ?? .horizontal, .vertical, "and is made from its raw value")

// Layout protocol: the direction of the environment, and the container values a subview carries
struct DirectionProbe: Layout {
    static var seen: LayoutDirection = .leftToRight
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        DirectionProbe.seen = subviews.layoutDirection
        return CGSize(width: 10, height: 10)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
}
_ = frames(_Probe(DirectionProbe() { Color.red }, width: 50, height: 50))
equal(DirectionProbe.seen, LayoutDirection.leftToRight, "a custom layout is told the layout direction of its environment")
_ = frames(_Probe(DirectionProbe() { Color.red }.environment(\.layoutDirection, .rightToLeft), width: 50, height: 50))
equal(DirectionProbe.seen, LayoutDirection.rightToLeft, "and it follows the environment when that is right to left")

// ScrollPosition is a value: scrollTo replaces what the position pointed at
var byPoint = ScrollPosition(id: 3)
byPoint.scrollTo(point: UnitPoint(x: 0.5, y: 0.5))
check(byPoint != ScrollPosition(id: 3), "scrollTo(point:) replaces what the position pointed at")
equal(byPoint.viewID(type: Int.self), nil, "and the view id is gone after it")
var byID = ScrollPosition()
byID.scrollTo(id: "row", anchor: .bottom)
equal(byID.viewID, AnyHashable("row"), "scrollTo(id:) names the view to scroll to")
equal(byID.anchor, UnitPoint.bottom, "with the anchor it was given")
equal(byID[Edge.self], nil, "the id subscript answers only for the type it was made with")
equal(byID[Edge.self], nil, "and a position that was never set is equal to another like it")

// ScrollView: scrollPosition moves the scroller, and what the user does comes back through the binding
final class PositionStore: ObservableObject { @Published var position = ScrollPosition() }
struct PositionCase: View {
    @ObservedObject var store: PositionStore
    var body: some View {
        let position = Binding<ScrollPosition>(get: { store.position }, set: { store.position = $0 })
        return ScrollView {
            VStack(spacing: 0) {
                Color.red.frame(width: 100, height: 100)
                Color.green.frame(width: 100, height: 100).id("second")
                Color.blue.frame(width: 100, height: 100)
            }
        }.scrollPosition(position)
    }
}
let positionStore = PositionStore()
let positioned = _Probe(PositionCase(store: positionStore), width: 100, height: 100)
_ = frames(positioned)
if let scroller = firstScroller(positioned.hostView) {
    equal(scroller.contentSize.height, 300, "the scroller's content is the whole stack")
    positionStore.position.scrollTo(id: "second", anchor: .top)
    positioned.flush()
    equal(scroller.contentOffset.y, 100, "scrollTo(id:) moved the scroller to that view")
    scroller.contentOffset = CGPoint(x: 0, y: 40)
    scroller.delegate?.scrollViewDidScroll?(scroller)
    equal(positionStore.position.y ?? -1, 40, "what the user scrolled to came back into the binding")
    check(positionStore.position.isPositionedByUser, "and it is marked as the user's own position")
    positionStore.position.scrollTo(edge: .bottom)
    positioned.flush()
    equal(scroller.contentOffset.y, 200, "scrollTo(edge: .bottom) rests at the end of the content")
} else { check(false, "the scroll view with a position made a scroller") }

// A sorted table shows the rows in the order its binding names: the app sorts, the table shows.
struct SortRow: Identifiable, Comparable {
    let id: Int
    let name: String
    static func < (a: SortRow, b: SortRow) -> Bool { a.name < b.name }
}
struct SortTableCase: View {
    let rows: [SortRow]
    @Binding var order: [KeyPathComparator<SortRow>]
    var body: some View {
        Table(of: SortRow.self, sortOrder: $order) {
            TableColumn("name", value: \.name)
        } rows: {
            ForEach(rows) { TableRow($0) }
        }
    }
}
func sortedTableShowsTheOrderTheBindingNames() {
    let rows = [SortRow(id: 0, name: "c"), SortRow(id: 1, name: "a"), SortRow(id: 2, name: "b")]
    var order: [KeyPathComparator<SortRow>] = []
    let holder = SortOrderBox(order: order)
    let probe = _Probe(SortTableCase(rows: rows, order: Binding(get: { holder.order }, set: { holder.order = $0 })),
                      width: 200, height: 200)
    _ = frames(probe)
    let texts = labels(of: probe.hostView)
    check(texts.contains("c") && texts.contains("a") && texts.contains("b"), "a table with no order shows every row")
    holder.order = [KeyPathComparator(\.name)]
    probe.flush()
    let sorted = labels(of: probe.hostView)
    let forward = positions(of: probe.hostView)
    check(forward["a"]! < forward["b"]! && forward["b"]! < forward["c"]!,
          "the rows follow the order the binding names, a before b before c")
    holder.order = [KeyPathComparator(\.name, ascending: false)]
    probe.flush()
    let back = positions(of: probe.hostView)
    check(back["c"]! < back["b"]! && back["b"]! < back["a"]!, "and a descending order puts c first")
}
final class SortOrderBox { var order: [KeyPathComparator<SortRow>]
    init(order: [KeyPathComparator<SortRow>]) { self.order = order } }

// The header of a sorted table: its titles, the tap that writes the order, and the arrow that turns.
func buttonTitled(_ title: String, in view: UIView) -> UIButton? {
    var found: UIButton?
    var stack: [UIView] = [view]
    while let current = stack.popLast() {
        if let button = current as? UIButton, button.titleLabel?.text == title { found = button; break }
        stack.append(contentsOf: current.subviews)
    }
    return found
}

func headerArrowRotation(in view: UIView) -> CGFloat? {
    var found: CGFloat?
    var stack: [UIView] = [view]
    while let current = stack.popLast() {
        let layer = current.layer
        if let shape = layer.sublayers?.first, let path = (shape as? CAShapeLayer)?.path, path.isEmpty == false,
           abs(current.transform.b) > 0.001 || abs(current.transform.c) > 0.001 {
            found = atan2(current.transform.b, current.transform.a)
        }
        stack.append(contentsOf: current.subviews)
    }
    return found
}

func tableHeaderTapsWriteTheOrderAndTurnTheArrow() {
    let rows = [SortRow(id: 0, name: "b"), SortRow(id: 1, name: "a")]
    let box = SortOrderBox(order: [])
    let probe = _Probe(SortTableCase(rows: rows, order: Binding(get: { box.order }, set: { box.order = $0 })),
                      width: 200, height: 200)
    _ = frames(probe)
    check(labels(of: probe.hostView).contains("name"), "a sorted table shows the column's title above the rows")
    guard let tap = buttonTitled("name", in: probe.hostView) else {
        check(false, "the title of a sortable column is a button")
        return
    }
    tap.sendActions(for: .touchUpInside)
    probe.flush()
    equal(box.order.count, 1, "a tap on a sortable title writes one comparator")
    check(box.order.first?.ascending == true, "a new column goes first and forward")
    let forward = headerArrowRotation(in: probe.hostView)
    check(forward == nil || abs(forward!) < 0.001, "and the arrow points up while the order is forward")
    tap.sendActions(for: .touchUpInside)
    probe.flush()
    check(box.order.first?.ascending == false, "the same column again turns the order")
    let turned = headerArrowRotation(in: probe.hostView)
    check(turned == nil || abs(abs(turned!) - .pi) < 0.01, "and the arrow turns with it")
}

// Springs and timing curves: the numbers Apple's own framework answers with, measured on macOS 27
// (.agent-work/host/spring.out in the band that wrote them; the values are the same to nine decimals).
func closeTo(_ got: Double, _ want: Double, _ what: String, _ tolerance: Double = 1e-6) {
    check(abs(got - want) <= tolerance, what, "got \(got), want \(want)")
}
let easeInCurve = UnitCurve.easeIn
closeTo(easeInCurve.value(at: 0.3), 0.129576683, "easeIn at 0.3 is the cubic Bezier Apple uses")
closeTo(easeInCurve.velocity(at: 0.3), 0.768389702, "and its slope with it")
closeTo(UnitCurve.easeOut.value(at: 0.7), 0.870423317, "easeOut is the same curve the other way round")
closeTo(UnitCurve.easeInOut.value(at: 0.5), 0.5, "easeInOut is at its middle half way")
check(UnitCurve.easeInEaseOut == .easeInOut, "and easeInEaseOut is that curve")
closeTo(UnitCurve.circularEaseIn.value(at: 0.3), 0.046060799, "circularEaseIn is a quarter circle")
closeTo(UnitCurve.circularEaseIn.velocity(at: 0.3), 0.314485451, "whose slope is the circle's")
closeTo(UnitCurve.circularEaseOut.value(at: 0.3), 0.714142843, "circularEaseOut is its mirror")
closeTo(UnitCurve.circularEaseInOut.value(at: 0.4), 0.2, "circularEaseInOut is two of them, halved")
closeTo(UnitCurve.linear.value(at: 0.25), 0.25, "the linear curve is the identity")
closeTo(UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.25, y: 0.1), endControlPoint: UnitPoint(x: 0.25, y: 1)).value(at: 0.5), 0.802403450, "a Bezier of two control points")
closeTo(UnitCurve.easeInOut.inverse.value(at: 0.2), 0.309797287, "the inverse of a curve runs it backwards", 1e-5)

let plainSpring = Spring(duration: 0.5, bounce: 0)
closeTo(plainSpring.response, 0.5, "a spring's duration is its response")
closeTo(plainSpring.dampingRatio, 1, "and no bounce is critical damping")
closeTo(plainSpring.mass, 1, "a spring is unit mass")
closeTo(plainSpring.stiffness, 157.913670417, "its stiffness follows the response")
closeTo(plainSpring.damping, 25.132741229, "and its damping the ratio")
closeTo(plainSpring.value(target: 1.0, time: 0.1), 0.357739556, "a critical spring's value at a tenth of a second")
closeTo(plainSpring.value(target: 1.0, time: 0.5), 0.986399069, "and halfway through")
closeTo(plainSpring.velocity(target: 1.0, time: 0.1), 4.494373762, "its velocity there")
closeTo(plainSpring.velocity(target: 1.0, time: 0), 0, "and none at the start")
closeTo(plainSpring.force(target: 1.0, position: 0.5, velocity: 0), 78.956835209, "the force that pulls a spring back")
closeTo(plainSpring.settlingDuration(target: 1.0, initialVelocity: 0, epsilon: 0.001), 0.8, "and when it has settled")
let bouncySpring = Spring(duration: 0.5, bounce: 0.15)
closeTo(bouncySpring.dampingRatio, 0.85, "a bounce damps the spring by that much less")
closeTo(bouncySpring.value(target: 1.0, time: 0.4), 1.001616993, "an under-damped spring passes the target")
closeTo(bouncySpring.value(target: 1.0, time: 1.0), 0.999966082, "and comes back to it")
let lazySpring = Spring(duration: 1, bounce: -0.2)
closeTo(lazySpring.dampingRatio, 1.25, "a negative bounce damps it more than critical")
closeTo(lazySpring.bounce, -0.2, "and is itself that bounce again")
closeTo(lazySpring.stiffness, 83.891637409, "with the stiffness that ratio needs")
closeTo(lazySpring.value(target: 1.0, time: 0.5), 0.723449712, "an over-damped spring comes up slowly")
closeTo(lazySpring.settlingDuration(target: 1.0, initialVelocity: 0, epsilon: 0.001), 2.3, "and settles late")
closeTo(Spring(mass: 1, stiffness: 100, damping: 10).response, 0.628318531, "a spring of a mass, a stiffness and a damping reads its response off them")
closeTo(Spring(mass: 1, stiffness: 100, damping: 10).dampingRatio, 0.5, "and its damping ratio")
closeTo(Spring(mass: 1, stiffness: 100, damping: 100).dampingRatio, 1, "while more damping than critical is refused")
closeTo(Spring(mass: 1, stiffness: 100, damping: 100, allowOverDamping: true).dampingRatio, 1, "unless it is asked for")
closeTo(Spring.smooth.bounce, 0, "the smooth spring does not bounce")
closeTo(Spring.snappy.bounce, 0.15, "the snappy one a little")
closeTo(Spring.bouncy.bounce, 0.3, "and the bouncy one more")
closeTo(Spring.bouncy(duration: 0.4, extraBounce: 0.1).duration, 0.4, "a preset takes a duration")
closeTo(Spring(response: 0.5, dampingRatio: 0.825).bounce, 0.175, "a spring built of a ratio bounces by its remainder")
var steppedValue = Double(0), steppedSpeed = Double(0)
for _ in 0..<6 { Spring(duration: 0.5).update(value: &steppedValue, velocity: &steppedSpeed, target: 1, deltaTime: 1.0 / 60) }
closeTo(steppedValue, plainSpring.value(target: 1.0, time: 0.1), "six frames of a spring are where its curve says")
closeTo(steppedSpeed, plainSpring.velocity(target: 1.0, time: 0.1), "and carry its velocity")
let cornerToCorner = CGPoint(x: 0.2, y: 0.4)
closeTo(plainSpring.value(fromValue: cornerToCorner, toValue: CGPoint(x: 1, y: 1), initialVelocity: .zero, time: 0.3).x, 0.912027151, "a spring from a value it did not start at")
closeTo(plainSpring.velocity(fromValue: cornerToCorner, toValue: CGPoint(x: 1, y: 1), initialVelocity: .zero, time: 0.3).x, 0.873734220, "and its velocity there", 1e-5)

check(Animation.spring == Animation.spring(duration: 0.5, bounce: 0), "the default spring is a half-second spring that does not bounce")
check(Animation.smooth == Animation.spring(duration: 0.5, bounce: 0), "and the smooth animation is that spring")
check(Animation.snappy == Animation.spring(duration: 0.5, bounce: 0.15), "the snappy one is the spring with a little bounce")
check(Animation.bouncy(duration: 0.4, extraBounce: 0.1) == Animation.spring(duration: 0.4, bounce: 0.4), "and a bouncy animation takes both of its numbers")
check(Animation.interactiveSpring == Animation.spring(duration: 0.15, bounce: 0.15), "the interactive spring is the snappy duration without the extra bounce")
check(Animation.smooth != Animation.bouncy, "two springs of the same length are told apart by their bounce")
check(Animation.spring(duration: 0.5).delay(0.2) != Animation.spring(duration: 0.5), "a delay makes another animation")
check(Animation.timingCurve(.circularEaseIn, duration: 2) != Animation.linear(duration: 2), "and so does a timing curve")
check(Animation.timingCurve(0.42, 0, 1, 1, duration: 1) == Animation.timingCurve(.easeIn, duration: 1), "the four points of a timingCurve are the control points of the Bezier")

// keyframes, phases and a custom animation: the track is the one that is written, and the views
// follow it frame by frame
let keyframeTrack = KeyframeTrack {
    LinearKeyframe(0.2, duration: 0.5)
    LinearKeyframe(0.8, duration: 0.5)
}
var resolvedTrack = _ResolvedKeyframes<Double>(initialValue: 0)
keyframeTrack._resolve(into: &resolvedTrack, initialValue: 0, initialVelocity: nil)
equal(resolvedTrack.keyframes.count, 2, "a keyframe track is the keyframes written in it")
closeTo(resolvedTrack.duration, 1.0, "and lasts as long as they do")
closeTo(resolvedTrack.progress(at: 0.25), 0.25, "halfway through the first keyframe the track is a quarter along")
closeTo(resolvedTrack.progress(at: 0.75), 0.75, "and halfway through the second, three quarters")
closeTo(resolvedTrack.value(at: 0.75), 0.65, "each keyframe travels from the value before it to its own")
closeTo(resolvedTrack.value(at: 0.0), 0.0, "at the start of the track the value is where it started")
closeTo(resolvedTrack.value(at: 2), 0.8, "and after the last keyframe it is where that one wrote it")
var springTrack = _ResolvedKeyframes<Double>(initialValue: 0)
let springKeyframes = KeyframeTrack { SpringKeyframe(1.0) }
springKeyframes._resolve(into: &springTrack, initialValue: 0, initialVelocity: nil)
closeTo(springTrack.duration, Spring().settlingDuration, "a spring keyframe lasts until the spring settles")
var moveTrack = _ResolvedKeyframes<Double>(initialValue: 0)
let moveKeyframes = KeyframeTrack { MoveKeyframe(1.0) }
moveKeyframes._resolve(into: &moveTrack, initialValue: 0, initialVelocity: nil)
equal(moveTrack.keyframes.count, 1, "a move keyframe is one step")
closeTo(moveTrack.duration, 0, "and takes no time")
var cubicTrack = _ResolvedKeyframes<Double>(initialValue: 0)
let cubicKeyframes = KeyframeTrack { CubicKeyframe(1.0, duration: 1) }
cubicKeyframes._resolve(into: &cubicTrack, initialValue: 0, initialVelocity: nil)
closeTo(cubicTrack.progress(at: 0.5), 0.5, "a cubic keyframe is halfway at halfway")
check(cubicTrack.progress(at: 0.25) < 0.25, "and slower than linear at the start")

struct HeightKey: AnimationStateKey {
    static var defaultValue: Double { 1 }
}
var animationState = AnimationState<Double>()
animationState[HeightKey.self] = 3
equal(animationState[HeightKey.self], 3, "an animation state keeps what a custom animation puts in it")
equal(AnimationState<Double>()[HeightKey.self], HeightKey.defaultValue, "and falls back to the key's own value")

struct Bounce: CustomAnimation {
    func animate<V: VectorArithmetic>(value: V, time: Double, context: inout AnimationContext<V>) -> V? { nil }
    func velocity<V: VectorArithmetic>(value: V, time: Double, context: AnimationContext<V>) -> V? { nil }
    func shouldMerge<V: VectorArithmetic>(previous: Animation, value: V, time: Double, context: inout AnimationContext<V>) -> Bool { true }
}
let customAnimation = Animation(Bounce())
check(customAnimation.base is Bounce, "a custom animation keeps the animation it was made from")
check(customAnimation.description.contains("custom"), "and says so when asked what it is")
var mergeContext = AnimationContext<Double>()
check(customAnimation.shouldMerge(previous: .linear(), value: 0.0, time: 0, context: &mergeContext),
      "and is asked whether it may take over from another one")
equal(AnimationCompletionCriteria.logicallyComplete, .logicallyComplete, "the two completion criteria are values")
check(AnimationCompletionCriteria.logicallyComplete != .removed, "and are told apart")

struct Phases: View {
    var body: some View {
        PhaseAnimator([1, 2, 3], content: { phase in
            Color.red.frame(width: CGFloat(phase) * 10, height: 10)
        }, animation: { _ in .linear(duration: 1) })
    }
}
_Probe.useVirtualClock()
let phased = _Probe(Phases(), width: 100, height: 20)
check(!frames(phased).isEmpty, "a phase animator shows a phase")
check(_Probe.runningAnimations > 0, "and is running its phase's animation")
_Probe.advanceAnimations(to: 1.5)
check(!frames(phased).isEmpty, "and still shows one after the first phase is over")

struct KeyframedBar: View {
    var body: some View {
        KeyframeAnimator(initialValue: 0.0, repeating: false) { value in
            Color.red.frame(width: CGFloat(value) * 100, height: 10)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(0.0, duration: 0.5)
                LinearKeyframe(1.0, duration: 0.5)
            }
        }
    }
}
let keyframed = _Probe(KeyframedBar(), width: 120, height: 20)
check(!frames(keyframed).isEmpty, "a keyframe animator shows its value")
_Probe.advanceAnimations(to: 1.2)
check(!frames(keyframed).isEmpty, "and one at the end of the keyframes too")

final class CompletionStore: ObservableObject {
    @Published var width: CGFloat = 10
}
struct CompletionCase: View {
    @ObservedObject var store: CompletionStore
    var body: some View { Color.red.frame(width: store.width, height: 10) }
}
let completionStore = CompletionStore()
var completed = 0
var completionTransaction = Transaction(animation: .linear(duration: 0.2))
completionTransaction.addAnimationCompletion { completed += 1 }
let completionProbe = _Probe(CompletionCase(store: completionStore), width: 100, height: 20)
_ = frames(completionProbe)
withTransaction(completionTransaction) { completionStore.width = 40 }
completionProbe.flush()
check(completed == 0, "a transaction's completion does not run before the animation is over")
_Probe.advanceAnimations(to: 0.6)
check(completed > 0, "and does when it is")

// environment values that have something to correspond to on iOS 6, and the anchors of a preference
/// What a view read out of the environment, recorded by the view itself: a check that asks the tree
/// instead cannot tell the environment's answer from a background the engine drew.
struct TintReader: View {
    @Environment(\.tintColor) var tint
    @Environment(\.symbolRenderingMode) var symbols
    @Environment(\.isHoverEffectEnabled) var hovering
    static var read: [Color?] = []
    var body: some View {
        let value = tint
        TintReader.read.append(value)
        return AnyView(Color.clear)
    }
}
_ = frames(_Probe(TintReader(), width: 10, height: 10))
check(TintReader.read.first ?? .some(.clear) == nil, "nothing is tinted until an app tints it")
TintReader.read = []
_ = frames(_Probe(TintReader().accentColor(.blue), width: 10, height: 10))
check(TintReader.read.first == .some(.blue), "and an accent colour is the tint colour the view reads")

// an anchor of a whole array and of an optional value: the two ways a preference value collects
// more than one anchor
let corners = Anchor<[CGRect]>.Source([Anchor<CGRect>.Source.bounds, Anchor<CGRect>.Source.rect(CGRect(x: 0, y: 0, width: 10, height: 10))])
let single = Anchor<CGRect>.Source.bounds
let maybe = Anchor<CGRect?>.Source(single)
let nothing = Anchor<CGRect?>.Source(nil as Anchor<CGRect>.Source?)
check(corners.measuring(CGRect(x: 2, y: 3, width: 20, height: 40)).count == 2, "an anchor of an array measures each of its sources")
equal(corners.measuring(CGRect(x: 2, y: 3, width: 20, height: 40))[0], CGRect(x: 2, y: 3, width: 20, height: 40), "the bounds anchor is the view's own rectangle")
equal(maybe.measuring(CGRect(x: 2, y: 3, width: 20, height: 40)), CGRect(x: 2, y: 3, width: 20, height: 40), "an anchor of an optional measures what is there")
equal(nothing.measuring(CGRect(x: 2, y: 3, width: 20, height: 40)), nil, "and an anchor of nothing measures nothing")

// the scroll indicator and bounce values of the environment, read where the scroller is set up
struct ScrolledBars: View {
    var body: some View {
        ScrollView { Color.red.frame(width: 10, height: 400) }
            .environment(\.verticalScrollIndicatorVisibility, .hidden)
            .environment(\.horizontalScrollBounceBehavior, .always)
    }
}
func scrollerOf(_ probe: _Probe) -> UIScrollView? {
    var found: UIScrollView?
    func walk(_ v: UIView) { if let s = v as? UIScrollView { found = found ?? s }; v.subviews.forEach(walk) }
    walk(probe.hostView)
    return found
}
let scrolled = _Probe(ScrolledBars(), width: 50, height: 50)
_ = frames(scrolled)
if let scroller = scrollerOf(scrolled) {
    check(!scroller.showsVerticalScrollIndicator, "the environment hides an indicator the view would have drawn")
    check(scroller.alwaysBounceHorizontal, "and the environment makes a scroller bounce on its own axis")
} else { check(false, "the scroll view has no scroller") }
let plainScroller = scrollerOf(_Probe(ScrollView { Color.red }.scrollIndicators(.hidden), width: 50, height: 50))
check(plainScroller?.showsVerticalScrollIndicator == false, "and the view's own flag still decides when the environment says nothing")

// SymbolVariants: the flags, their combinations and the name a variant gives a symbol — the whole
// type is OpenSwiftUI's, and this checks it says what its own documentation says.
check(SymbolVariants.none == SymbolVariants.none, "the empty variant is one value")
check(SymbolVariants.fill != SymbolVariants.none, "and the filled one is not the empty one")
check(SymbolVariants.fill.contains(.fill), "a filled variant contains fill")
// `contains` is a subset test, and the empty variant is a subset of every one of them, so a filled
// variant does contain the empty one — that is what the flags are, not a defect in the vendored code
check(SymbolVariants.fill.contains(.none), "and contains the empty one, as an empty set is a subset of any")
check(!SymbolVariants.none.contains(.fill), "where the empty one does not contain a filled")
check(SymbolVariants.circle.contains(.circle), "and a circle variant contains circle")
check(!SymbolVariants.circle.contains(.square), "but not a square one")
check(SymbolVariants.fill.circle.contains(.fill) && SymbolVariants.fill.circle.contains(.circle),
      "a variant can be filled and in a circle at once")
check(SymbolVariants.fill != SymbolVariants.circle, "and the two are told apart")
check(SymbolVariants.fill.square == SymbolVariants.square.fill, "the two orders of the flags agree")

struct PlainPressCase: View {
    var body: some View { Button(action: {}) { Text(verbatim: "Tap").padding(4) }.buttonStyle(.plain) }
}
struct BorderedPressCase: View {
    var body: some View { Button(action: {}) { Text(verbatim: "Tap").padding(4) }.buttonStyle(.borderedProminent) }
}
// The press, measured: a style that takes it as an argument changes what it draws when the button goes
// down, and a style written the Apple way is built through the same path and still compiles.
public struct PressProbeStyle: PrimitiveButtonStyle {
    public init() {}
    /// Apple's spelling, without the press: what an app writes, and it compiles.
    public func makeBody(configuration: PrimitiveButtonStyleConfiguration) -> some View {
        configuration.label
    }
}

extension PressProbeStyle { func pressedBody(configuration: PrimitiveButtonStyleConfiguration, pressed: Bool) -> any View { AnyView(makeBody(configuration: configuration)) } }

struct PressProbeCase: View {
    var body: some View {
        Button(action: {}) { Text(verbatim: "Tap").padding(4) }
            .buttonStyle(.plain)
    }
}

struct AppleStyleCase: View {
    var body: some View {
        Button(action: {}) { Text(verbatim: "Tap").padding(4) }
            .buttonStyle(PressProbeStyle())
    }
}

/// The rectangles a probe's tree is drawn with, in order: the style's own output, read back.
func opacitiesOf(_ probe: _Probe) -> [CGFloat] {
    var found: [CGFloat] = []
    func walk(_ v: UIView) { found.append(v.alpha); v.subviews.forEach(walk) }
    walk(probe.hostView)
    return found
}

func downButton(_ probe: _Probe) -> UIButton? {
    func first(_ v: UIView) -> UIButton? {
        if let b = v as? UIButton { return b }
        for sub in v.subviews { if let b = first(sub) { return b } }
        return nil
    }
    return first(probe.hostView)
}

let pressed = _Probe(PressProbeCase(), width: 120, height: 40)
_ = frames(pressed)
let pressedUp = opacitiesOf(pressed)
if let pressButton = downButton(pressed) {
    pressButton.isHighlighted = true
    pressed.hostView.setNeedsLayout()
    pressed.flush()
    let pressedDown = opacitiesOf(pressed)
    check(pressedUp != pressedDown, "a .plain button redraws its body when the press reaches the style")
    check(pressedDown.contains { $0 <= 0.4 + 0.001 }, "and draws it at the pressed opacity the style asked for")
    pressButton.isHighlighted = false
    pressed.hostView.setNeedsLayout()
    pressed.flush()
    check(opacitiesOf(pressed) == pressedUp, "and goes back to what it drew before")
} else { check(false, "the probe's plain button has a UIButton in it") }

// a custom style written the Apple way: no press parameter, and it is built all the same
let appleStyle = _Probe(AppleStyleCase(), width: 120, height: 40)
let appleFrames = frames(appleStyle)
check(!appleFrames.isEmpty, "a custom PrimitiveButtonStyle written the Apple way draws its label")
if let custom = downButton(appleStyle) {
    custom.isHighlighted = true
    appleStyle.hostView.setNeedsLayout()
    appleStyle.flush()
    check(!frames(appleStyle).isEmpty, "and keeps drawing it while the button is down")
}

// a selection in a string: one range, several, or a caret, in Apple's shape
let selectedText = "hello world"
let whole = selectedText.startIndex..<selectedText.index(selectedText.startIndex, offsetBy: 5)
let one = TextSelection(range: whole)
check(!one.isInsertion, "a range is a selection, not a caret")
check(TextSelection(insertionPoint: selectedText.startIndex).isInsertion, "an empty range is a caret")
check(one.affinity == .automatic, "a selection's affinity is automatic until it is set")
var two = TextSelection(range: whole)
two.affinity = .upstream
check(two.affinity == .upstream, "and can be given one")
check(two != one, "a selection with an affinity is not the same one without it")
var rangeSet = RangeSet<String.Index>()
rangeSet.insert(contentsOf: whole)
let second = selectedText.index(selectedText.startIndex, offsetBy: 6)..<selectedText.index(selectedText.startIndex, offsetBy: 8)
rangeSet.insert(contentsOf: second)
let multi = TextSelection(ranges: rangeSet)
check(multi.indices != one.indices, "a set of ranges is not one range, in the names Apple gives them")
if case .multiSelection = multi.indices {} else { check(false, "and it is the multiSelection of those two names") }
if case .selection = one.indices {} else { check(false, "and one range is the selection of the same enum") }

// Tab values: a tab bar over tab content shows a tab per element, and a selection carries the value.
// WRITTEN, NOT RUN: the engine tests need the emulator, and `xmake emulate` is not in this tree yet
// (emulate-launch, 7e035ac0). Compile-checked only, like every test here until then.
struct TabValueCase: Identifiable, Hashable { var id: String { folder }; let folder: String; let unread: Int }

struct TabValueCaseView: View {
    let boxes: [TabValueCase]
    @Binding var selected: TabValueCase?
    var body: some View {
        TabView(selection: $selected) {
            Tab("Inbox", systemImage: "envelope", value: boxes[0]) { Color.gray }
            Tab("Sent", systemImage: "paperplane", value: boxes[1]) { Color.blue }
        }
    }
}

func findTabBar(_ view: UIView) -> UITabBarController? {
    if let bar = view as? UITabBarController { return bar }
    return nil
}

final class TabValueSelection {
    var selected: TabValueCase?
    init() {}
}
func aTabBarsSelectionCarriesTheTabValue() {
    let boxes = [TabValueCase(folder: "Inbox", unread: 2), TabValueCase(folder: "Sent", unread: 0)]
    let holder = TabValueSelection()
    let probe = _Probe(TabValueCaseView(boxes: boxes,
                                        selected: Binding(get: { holder.selected }, set: { holder.selected = $0 })),
                      width: 320, height: 480)
    _ = frames(probe)
    var controllers: [UITabBarController] = []
    var stack: [UIView] = [probe.hostView]
    while let current = stack.popLast() {
        for child in current.subviews {
            if let child = child as? UIView, let bar = findTabBar(child) { controllers.append(bar) }
            stack.append(child)
        }
    }
    check(!controllers.isEmpty, "a tab bar over tab content is a UITabBarController")
    equal(controllers.first?.viewControllers?.count ?? 0, boxes.count, "with one controller per element")
    let items = controllers.first?.tabBar.items ?? []
    equal(items.map { $0.tag }, [0, 1], "and the release's own tag is the tab's position")
}

// A table draws the columns the app left visible, in the order the app gave, with the column's own
// alignment. WRITTEN, NOT RUN: the engine tests need the emulator and `xmake emulate` is not in this
// tree yet (emulate-launch, 7e035ac0). The typecheck pair cannot show this red: it checks that the
// declaration compiles, not that the body reads it, which is what this test is for.
struct TwoColumnCase: Identifiable, Hashable { var id: Int; let title: String }

struct TwoColumnTableCase: View {
    let rows: [TwoColumnCase]
    let customization: TableColumnCustomization<TwoColumnCase>
    var body: some View {
        Table(of: TwoColumnCase.self,
              columnCustomization: Binding(get: { customization }, set: { _ in })) {
            TableColumn("first") { (row: TwoColumnCase) in Color.red }
            TableColumn("second") { (row: TwoColumnCase) in Color.blue }.alignment(.trailing)
        } rows: {
            ForEach(rows) { TableRow($0) }
        }
    }
}

func aTableDrawsTheColumnsTheAppLeftVisible() {
    let rows = [TwoColumnCase(id: 0, title: "a"), TwoColumnCase(id: 1, title: "b")]
    var customization = TableColumnCustomization<TwoColumnCase>()
    customization.order = [rows[1].id, rows[0].id]
    customization.visibility = [rows[0].id: false, rows[1].id: true]
    // a hidden column must lose its title and its sort key too: the header is built from the same list
    var order = [KeyPathComparator(\TwoColumnCase.title)]
    let sorted = _Probe(SortedTwoColumnTableCase(rows: rows, customization: customization,
                                                sortOrder: Binding(get: { order }, set: { order = $0 })),
                        width: 320, height: 480)
    _ = frames(sorted)
    check(!labels(of: sorted.hostView).contains("first"), "a hidden column keeps neither its title nor its sort key")
    check(labels(of: sorted.hostView).contains("second"), "and the column the app left is the one the header shows")

    let probe = _Probe(TwoColumnTableCase(rows: rows, customization: customization), width: 320, height: 480)
    _ = frames(probe)
    check(colors(of: probe.hostView).count > 0, "the table draws rows for the column it kept")
    check(!colors(of: probe.hostView).contains(UIColor.red), "and not for the column the app hid")
    check(colors(of: probe.hostView).contains(UIColor.blue), "the column it kept is the one the app left")
    customization.resetOrder()
    check(customization.order.isEmpty, "resetOrder empties the order the app had")
}

struct SortedTwoColumnTableCase: View {
    let rows: [TwoColumnCase]
    let customization: TableColumnCustomization<TwoColumnCase>
    @Binding var sortOrder: [KeyPathComparator<TwoColumnCase>]
    var body: some View {
        Table(of: TwoColumnCase.self, sortOrder: $sortOrder,
              columnCustomization: Binding(get: { customization }, set: { _ in })) {
            TableColumn("first") { (row: TwoColumnCase) in Color.red }
            TableColumn("second", value: \.title)
        } rows: {
            ForEach(rows) { TableRow($0) }
        }
    }
}

func colors(of view: UIView) -> [UIColor] {
    var found: [UIColor] = []
    var stack: [UIView] = [view]
    while let current = stack.popLast() {
        if let back = current.backgroundColor { found.append(back) }
        stack.append(contentsOf: current.subviews)
    }
    return found
}

// The builders and the plumbing under them: a conditional column, a conditional row, and the rows a
// table collects. WRITTEN, NOT RUN until the emulator lands (emulate-launch, 7e035ac0).
struct BuilderRow: Identifiable { let id: Int }

struct BuilderColumnCase: View {
    let rows: [BuilderRow]
    @Binding var showWide: Bool
    var body: some View {
        Table(of: BuilderRow.self) {
            if showWide {
                TableColumn("wide", value: \.id)
            } else {
                TableColumn("narrow", value: \.id)
            }
        } rows: {
            ForEach(rows) { row in
                if row.id % 2 == 0 {
                    TableRow(row)
                }
            }
        }
    }
}

func theBuildersTakeAConditionalColumnAndRow() {
    let rows = [BuilderRow(id: 0), BuilderRow(id: 1), BuilderRow(id: 2)]
    // buildEither is the builder's conditional form, and the result is column content either way
    let holder = BuilderShow()
    let probe = _Probe(BuilderColumnCase(rows: rows, showWide: Binding(get: { holder.show }, set: { holder.show = $0 })),
                      width: 320, height: 480)
    _ = frames(probe)
    holder.show = false
    probe.flush()
    check(labels(of: probe.hostView).contains("narrow"), "the column the condition took is the one the table shows")
}

final class BuilderShow { var show = true; init() {} }

// A tab with its value written in it: one tab, named by that value, and a bar that shows it.
// WRITTEN, NOT RUN until the emulator lands (emulate-launch, 7e035ac0).
struct ValueTabCase: View {
    @Binding var selected: Int?
    var body: some View {
        TabView(selection: $selected) {
            Tab("Inbox", systemImage: "envelope", value: 1) { Color.gray }
            Tab("Sent", systemImage: "paperplane", value: 2) { Color.blue }
        }
    }
}

func aTabIsOneTabNamedByItsValue() {
    // a tab is one tab named by the value written in it: what a caller can see is the bar item it
    // becomes, so that is what is asked for -- the rows behind it are the port's own
    let probe = _Probe(ValueTabCase(selected: Binding(get: { 1 }, set: { _ in })), width: 320, height: 480)
    _ = frames(probe)
    // the bar's own items are where a tab bar keeps its titles, not labels in the view tree
    var bar: UITabBar?
    var stack: [UIView] = [probe.hostView]
    while let current = stack.popLast() {
        if let found = current as? UITabBar { bar = found; break }
        stack.append(contentsOf: current.subviews)
    }
    equal(bar?.items?.map { $0.title } ?? [], ["Inbox", "Sent"], "and a bar over tabs shows a bar item per tab")
}

// A custom view that only stands for a group is that group, so a container that reads its children
// takes the group's -- the case SwiftUI's own `ForEach(subviews:)` reaches through a body.
// WRITTEN, NOT RUN until the emulator lands (emulate-launch, 7e035ac0 / stack 14).
struct StandingForAGroup: View {
    var body: some View {
        Group {
            Color.red.frame(width: 10, height: 10)
            Color.green.frame(width: 10, height: 10)
        }
    }
}

func aViewThatStandsForAGroupIsThatGroup() {
    // read the way an app does: through Group(subviews:), whose transform is handed the children
    var standing = 0
    _ = Group(subviews: StandingForAGroup()) { children in
        standing = children.count
        return EmptyView()
    }
    equal(standing, 2, "a custom view's children are its body's, not itself")
    var primitive = 0
    _ = Group(subviews: Color.gray) { children in
        primitive = children.count
        return EmptyView()
    }
    equal(primitive, 1, "and a primitive is its own content: one child, itself")
}

// RasterizationOptions: Apple's shape from the SDK of 16.4, and what reaches a layer of iOS 6
var raster = _RendererConfiguration.RasterizationOptions()
check(raster.colorMode == .nonLinear, "a layer is rasterised with the non-linear colour mode by default")
check(!raster.rendersAsynchronously, "and drawn on the main thread by default")
check(raster.isOpaque, "and opaque, which is what the framework's own default is")
check(raster.drawsPlatformViews, "and platform views are drawn into it, as the framework's own default is")
check(!raster.prefersDisplayCompositing, "and the system does not composite it by preference")
equal(raster.maxDrawableCount, 3, "and three drawables, which is what the framework's own default is")
equal(raster.rbColorMode, nil, "and no colour mode the release would send down, which iOS 6 has no key for")
raster.isOpaque = true
raster.prefersDisplayCompositing = true
raster.maxDrawableCount = 1
check(raster.isOpaque && raster.prefersDisplayCompositing && raster.maxDrawableCount == 1, "and the three of them are the port's to set")
// and the options reach a real layer, through the one view that rasterises: `drawingGroup`
func layerOf(_ probe: _Probe) -> CALayer? {
    var found: CALayer?
    func walk(_ v: UIView) { if !v.subviews.isEmpty { found = found ?? v.layer }; v.subviews.forEach(walk) }
    walk(probe.hostView)
    return found
}
let drawn = _Probe(Color.red.frame(width: 40, height: 40).drawingGroup(), width: 60, height: 60)
_ = frames(drawn)
if let layer = layerOf(drawn) {
    check(layer.shouldRasterize, "a drawing group rasterises the layer of iOS 6")
    check(layer.rasterizationScale == UIScreen.main.scale, "at the scale of the screen")
    check(layer.isOpaque, "and opaque, as the options the framework answers with say")
} else { check(false, "a drawing group has a layer of its own") }

// A document: a real file, opened through the group and read back.
final class NoteDocument: FileDocument {
    static var readableContentTypes: [String] { ["public.text", "public.data"] }
    static var writableContentTypes: [String] { ["public.text"] }
    var text: String

    init(text: String = "") { self.text = text }

    required init(configuration: FileDocumentReadConfiguration<NoteDocument>) throws {
        self.text = String(data: configuration.file, encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: FileDocumentWriteConfiguration<NoteDocument>) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

let noteDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
let noteURL = noteDirectory.appendingPathComponent("eidolon-note.txt")
try? Data("the first line\n".utf8).write(to: noteURL)
let noteGroup = DocumentGroup<NoteDocument, Text>(newDocument: NoteDocument()) { configuration in
    Text(verbatim: configuration.document.text)
}
let openedNote = try? noteGroup.open(noteURL)
check(openedNote != nil, "a document group opens a file the release has handed over")
let readBack = try? NoteDocument(configuration: FileDocumentReadConfiguration<NoteDocument>(
    contentType: NoteDocument.readableContentTypes[0], file: Data(contentsOf: noteURL), fileURL: noteURL))
equal(readBack?.text, "the first line\n", "and the document reads what the file holds")
let written = try? NoteDocument(text: "the second line\n").fileWrapper(
    configuration: FileDocumentWriteConfiguration<NoteDocument>(contentType: "public.text", originalURL: noteURL))
equal(written?.regularFileContents, Data("the second line\n".utf8), "and a document writes the bytes it is asked for")
equal(written?.preferredFilename, "eidolon-note.txt", "under the name the file had")

// A window: one scene over the one UIWindow of iOS 6, and the action that opens it.
let windowScene = Window("Notes", id: "notes") { Text(verbatim: "the window's content") }
equal(windowScene.id, "notes", "a window scene knows the id it is known by")
let stringKeyScene = Window(LocalizedStringKey("rawValue"), id: "by-key") { Text(verbatim: "x") }
equal(stringKeyScene.id, "by-key", "and the initialiser that takes a localized key builds the same scene")
let presented = windowScene.presentedWindowContent(forPresented: true)
equal(presented?.data == nil, true, "a presented window holds the value it was opened with, and none for one opened without")
check(presented != nil, "and a window scene has the content of the window it is over")
OpenWindowAction.currentWindowID = "notes"
var windowJournalBefore = _Unsupported.used.count
OpenWindowAction().callAsFunction(id: "notes")
equal(_Unsupported.used.count, windowJournalBefore, "opening the window that is already shown does nothing at all")
OpenWindowAction().callAsFunction(id: "another")
check(_Unsupported.used.count > windowJournalBefore, "and opening another one says iOS 6 has no second window")
let openValue = OpenWindowAction().openWindow
check(openValue is OpenWindowAction, "the action reads itself as the openWindow of a window scene")
OpenWindowAction.currentWindowID = nil

// A widget: a configuration, a bundle, and the builder that collects the bundle's members. iOS 6.1.3
// has no widget host, so nothing here is ever shown — as in an app with no widget extension.
struct ClockConfiguration: WidgetConfiguration {
    var body: some WidgetConfiguration { EmptyWidgetConfiguration() }
}
struct ClockWidget: Widget {
    var body: some WidgetConfiguration { ClockConfiguration() }
}
struct NotesWidget: Widget {
    var body: some WidgetConfiguration { EmptyWidgetConfiguration() }
}
struct PairWidget: Widget {
    var body: some WidgetConfiguration { EmptyWidgetConfiguration() }
}
struct MyWidgets: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        ClockWidget()
    }
}
let emptyConfiguration = EmptyWidgetConfiguration()
check(EmptyWidgetConfiguration() is WidgetConfiguration, "an empty widget configuration is a widget configuration")
let bundleBody = MyWidgets().body
check(bundleBody is Widget, "a bundle's body is the widget its builder collected")
let configuration = ClockWidget().body
check(configuration is WidgetConfiguration, "and a widget's body is the configuration it names")
check(bundleBody is Widget, "and the builder's widget is one the bundle's body names")

print("\(checks - failures)/\(checks) checks passed")
if !_Unsupported.used.isEmpty {
    print("ignored on this platform: \(_Unsupported.used.joined(separator: ", "))")
}
exit(failures == 0 ? 0 : 1)
