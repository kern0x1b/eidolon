import UIKit
import CoreGraphics

public final class _Probe {
    let host: _HostingViewController
    public init(_ view: any View, width: CGFloat, height: CGFloat) {
        host = _HostingViewController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }
    public func flush() {
        Updates.flush()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }
    public var bodyEvaluations: Int {
        var total = 0
        func walk(_ n: Node) {
            if let c = n as? CompositeNode {
                total += c.bodyCount
                if let child = c.child { walk(child) }
            }
            if let g = n as? GroupNode { g.children.forEach(walk) }
            if let c = n as? ContainerNode, let content = c.content { walk(content) }
            if let e = n as? EnvironmentNode, let child = e.child { walk(child) }
            if let a = n as? AppearNode, let child = a.child { walk(child) }
            if let l = n as? ListNode {
                if let content = l.content { walk(content) }
            }
        }
        if let r = host.root { walk(r) }
        return total
    }
    public var hostView: UIView { host.view }
    public static var measurements: (computed: Int, cached: Int) { (LayoutCounters.misses, LayoutCounters.hits) }
    public static var phaseSeconds: (render: Double, mount: Double, layout: Double) {
        (LayoutCounters.renderTime, LayoutCounters.mountTime, LayoutCounters.layoutTime)
    }

    public var navigationDepth: Int {
        var found: UINavigationController?
        func walk(_ c: UIViewController) {
            if let n = c as? UINavigationController { found = found ?? n }
            c.children.forEach(walk)
        }
        walk(host)
        return found?.viewControllers.count ?? 0
    }

    public enum GestureEvent {
        case tap(CGPoint)
        case pressDown, pressRecognized, pressUp
        case drag(CGSize, ended: Bool)
        case pinch(CGFloat, ended: Bool)
        case rotate(Double, ended: Bool)
    }

    var gestureNodes: [GestureNode] {
        var found: [GestureNode] = []
        func walk(_ n: Node) {
            if let g = n as? GestureNode { found.append(g) }
            n.disposableChildren.forEach(walk)
        }
        if let r = host.root { walk(r) }
        return found
    }

    public var gestureCount: Int { gestureNodes.count }

    // The animations of shapes and effects are driven by a display link; a test drives them with a clock of its own.
    // The fallback that finds a view's fields by Mirror, checked against the runtime's own reflection on the same value.
    public static func useMirrorReflection(_ on: Bool) {
#if !REV_NO_FIELD_REFLECTION
        FieldReflection.forceMirror = on
#endif
    }

    public static func mirrorReflectionAgrees<V: View>(_ view: V) -> Bool {
#if REV_NO_FIELD_REFLECTION
        return true
#else
        let fast = runtimeFields(V.self), slow = FieldReflection.mirrorFields(view, of: V.self)
        return fast.count == slow.count && zip(fast, slow).allSatisfy { $0.offset == $1.offset && $0.type == $1.type }
#endif
    }

    public static func observationTracking(_ on: Bool) {
#if !REV_NO_FIELD_REFLECTION
        CompositeNode.tracksObservation = on
#endif
    }

    // What the table's delegate answers for a row's swipe, as the backports would ask it.
    public func swipeConfiguration(row: Int, leading: Bool) -> AnyObject? {
        var table: UITableView?
        func walk(_ v: UIView) { if table == nil, let t = v as? UITableView { table = t }; v.subviews.forEach(walk) }
        walk(hostView)
        guard let table, let delegate = table.delegate as? NSObject else { return nil }
        let selector = NSSelectorFromString(leading ? "tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:"
                                                    : "tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:")
        guard delegate.responds(to: selector) else { return nil }
        return delegate.perform(selector, with: table, with: IndexPath(row: row, section: 0) as NSIndexPath)?.takeUnretainedValue()
    }

    // Where the hand-over of swipe actions stands, for a phone: are the classes there, and do they answer the factory selectors.
    public static func swipeBridgeState() -> String {
        let action = NSClassFromString("UIContextualAction") as? NSObject.Type
        let configuration = NSClassFromString("UISwipeActionsConfiguration") as? NSObject.Type
        let makeAction = NSSelectorFromString("contextualActionWithStyle:title:handler:")
        let makeConfiguration = NSSelectorFromString("configurationWithActions:")
        var image = "?"
        var info = Dl_info()
        if let method = class_getInstanceMethod(UITableView.self, NSSelectorFromString("setDelegate:")),
           dladdr(unsafeBitCast(method_getImplementation(method), to: UnsafeRawPointer.self), &info) != 0, let name = info.dli_fname {
            image = String(cString: name)
        }
        let installer = objc_getClass("CharonSwipeInstaller") != nil
        let installs = UITableView.instancesRespond(to: NSSelectorFromString("charon_installSwipeActions"))
        return "installerClass=\(installer) tableInstallMethod=\(installs) setDelegateIn=\(image) "
            + "available=\(SwipeActionsBridge.available) action=\(action != nil) configuration=\(configuration != nil) "
            + "controllerResponds=\(ListController.instancesRespond(to: NSSelectorFromString("tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:"))) queries=\(ListController.swipeQueries) "
            + "makeAction=\(action?.responds(to: makeAction) ?? false) makeConfiguration=\(configuration?.responds(to: makeConfiguration) ?? false)"
    }

    // The recognisers on every table in a window, for a phone: does the swipe facade of the backports show among them?
    public static func tableRecognizers(in root: UIView) -> String {
        var found: [String] = []
        func walk(_ v: UIView) {
            if let table = v as? UITableView {
                found.append((table.gestureRecognizers ?? []).map { "\(type(of: $0))(delegate \($0.delegate.map { String(describing: type(of: $0)) } ?? "nil"))" }.joined(separator: ","))
            }
            v.subviews.forEach(walk)
        }
        walk(root)
        return found.joined(separator: " | ")
    }

    public static func useVirtualClock() {
        ValueAnimator.manual = true
        ValueAnimator.clock = { 0 }
    }

    public static func advanceAnimations(to seconds: Double) {
        ValueAnimator.clock = { seconds }
        ValueAnimator.tickAll()
    }

    public static var runningAnimations: Int { ValueAnimator.active.count }

    // What the recognisers would deliver, so a test can drive a gesture without a finger.
    public func send(_ event: GestureEvent, toGesture index: Int = 0) {
        let nodes = gestureNodes
        guard index < nodes.count else { return }
        let raw: RawGestureEvent
        switch event {
        case .tap(let point): raw = .tap(point)
        case .pressDown: raw = .pressDown
        case .pressRecognized: raw = .pressRecognized
        case .pressUp: raw = .pressUp
        case .drag(let translation, let ended):
            let start = CGPoint(x: 50, y: 50)
            let location = CGPoint(x: start.x + translation.width, y: start.y + translation.height)
            raw = .drag(DragGesture.Value(time: Date(), location: location, startLocation: start, translation: translation,
                                          velocity: .zero, predictedEndLocation: location, predictedEndTranslation: translation),
                        ended ? .ended : .changed)
        case .pinch(let scale, let ended): raw = .pinch(scale, ended ? .ended : .changed)
        case .rotate(let radians, let ended): raw = .rotate(Angle(radians: radians), ended ? .ended : .changed)
        }
        nodes[index].target.inject(raw)
    }

    public func gestureAccepts(_ point: CGPoint) -> Bool {
        var found: GestureNode?
        func walk(_ n: Node) {
            if let g = n as? GestureNode { found = found ?? g; return }
            n.disposableChildren.forEach(walk)
        }
        if let r = host.root { walk(r) }
        guard let gesture = found else { return false }
        return gesture.target.accepts(gesture.uiView.convert(point, from: host.view))
    }

    var listNode: ListNode? {
        var found: ListNode?
        func walk(_ n: Node) {
            if let l = n as? ListNode { found = found ?? l }
            if let c = n as? CompositeNode, let child = c.child { walk(child) }
            if let g = n as? GroupNode { g.children.forEach(walk) }
            if let c = n as? ContainerNode, let content = c.content { walk(content) }
            if let e = n as? EnvironmentNode, let child = e.child { walk(child) }
            if let a = n as? AppearNode, let child = a.child { walk(child) }
        }
        if let r = host.root { walk(r) }
        return found
    }

    public func isHidden(_ index: Int) -> Bool {
        var found: [UIView] = []
        func walk(_ v: UIView) {
            if v.subviews.isEmpty { found.append(v) } else { v.subviews.forEach(walk) }
        }
        host.view.subviews.forEach(walk)
        guard index < found.count else { return false }
        var view: UIView? = found[index]
        while let current = view {
            if current.isHidden { return true }
            view = current.superview
        }
        return false
    }

    public var rowCount: Int { listNode?.rows.count ?? 0 }
    public var sectionCount: Int { listNode?.sections.count ?? 0 }
    public var sectionTitles: [String] { listNode?.sections.map { $0.title ?? "" } ?? [] }
    public var rowCounts: [Int] { listNode?.sections.map { $0.rows.count } ?? [] }

    public var scrollContentHeight: CGFloat {
        var found: CGFloat = 0
        func walk(_ v: UIView) {
            if let scroller = v as? UIScrollView, found == 0 { found = scroller.contentSize.height }
            v.subviews.forEach(walk)
        }
        walk(host.view)
        return found
    }

    public func rowHeight(_ index: Int) -> CGFloat {
        guard let list = listNode, index < list.rows.count else { return 0 }
        let table = list.uiView as! UITableView
        return table.delegate!.tableView!(table, heightForRowAt: IndexPath(row: index, section: 0))
    }

    public func rowEditing(_ index: Int) -> (delete: Bool, move: Bool, title: String?) {
        guard let list = listNode, index < list.rows.count else { return (false, false, nil) }
        let table = list.uiView as! UITableView
        let path = IndexPath(row: index, section: 0)
        let controller = list.controller
        return (controller.tableView(table, editingStyleForRowAt: path) == .delete,
                controller.tableView(table, canMoveRowAt: path),
                controller.tableView(table, titleForDeleteConfirmationButtonForRowAt: path))
    }

    public func commitDelete(_ index: Int) {
        guard let list = listNode else { return }
        let table = list.uiView as! UITableView
        list.controller.tableView(table, commit: .delete, forRowAt: IndexPath(row: index, section: 0))
    }

    public static func openURL(_ url: URL) -> Bool { OpenURLHandlers.deliver(url) }
    public static func text(_ key: LocalizedStringKey) -> String { key.text }

    public func rowBadge(_ index: Int) -> String? {
        guard let list = listNode, index < list.rows.count else { return nil }
        return list.rows[index].traits.badge
    }

    public func selectRow(_ index: Int) {
        guard let list = listNode else {
            var table: UITableView?
            func walk(_ v: UIView) { if let t = v as? UITableView { table = table ?? t }; v.subviews.forEach(walk) }
            walk(host.view)
            if let table { table.delegate?.tableView?(table, didSelectRowAt: IndexPath(row: index, section: 0)) }
            return
        }
        let table = list.uiView as! UITableView
        var remaining = index
        for (section, group) in list.sections.enumerated() {
            if remaining < group.rows.count {
                list.controller.tableView(table, didSelectRowAt: IndexPath(row: remaining, section: section))
                return
            }
            remaining -= group.rows.count
        }
    }

    public var tableBackgroundCleared: Bool {
        guard let table = listNode?.uiView as? UITableView else { return false }
        return table.backgroundView == nil && table.backgroundColor == .clear
    }

    public func dump() -> String {
        var lines: [String] = []
        func walk(_ v: UIView, _ depth: Int) {
            let f = v.frame
            var extra = ""
            if let l = v as? UILabel { extra = " \"\(l.text ?? "")\"" }
            if let b = v as? UIButton { extra = " button \"\(b.title(for: .normal) ?? "")\"" }
            if let s = v as? UISwitch { extra = " switch on=\(s.isOn)" }
            if let t = v as? UITextField { extra = " field \"\(t.text ?? "")\" placeholder=\"\(t.placeholder ?? "")\"" }
            if let t = v as? UITableView {
                var parts: [String] = []
                for section in 0..<t.numberOfSections {
                    let title = t.dataSource?.tableView?(t, titleForHeaderInSection: section) ?? ""
                    parts.append("\(title.isEmpty ? "-" : title):\(t.numberOfRows(inSection: section))")
                }
                extra = " table sections=[\(parts.joined(separator: " "))]"
            }
            lines.append(String(repeating: "  ", count: depth) + "\(type(of: v)) (\(Int(f.origin.x)),\(Int(f.origin.y)),\(Int(f.size.width)),\(Int(f.size.height)))\(extra)")
            for sub in v.subviews { walk(sub, depth + 1) }
        }
        walk(host.view, 0)
        return lines.joined(separator: "\n")
    }
    public func texts() -> [String] {
        var out: [String] = []
        func walk(_ v: UIView) {
            if let l = v as? UILabel, let t = l.text, !t.isEmpty { out.append(t) }
            if let b = v as? UIButton, let t = b.title(for: .normal), !t.isEmpty { out.append("[\(t)]") }
            for sub in v.subviews { walk(sub) }
        }
        walk(host.view)
        return out
    }
    public func cellTexts() -> [String] {
        var out: [String] = []
        func walk(_ v: UIView) {
            if let table = v as? UITableView {
                for row in 0..<table.numberOfRows(inSection: 0) {
                    let cell = table.dataSource!.tableView(table, cellForRowAt: IndexPath(row: row, section: 0))
                    var texts: [String] = []
                    func inner(_ x: UIView) {
                        if let l = x as? UILabel, let t = l.text, !t.isEmpty { texts.append(t) }
                        if let b = x as? UIButton, let t = b.title(for: .normal), !t.isEmpty { texts.append("[\(t)]") }
                        if let s = x as? UISwitch { texts.append("switch=\(s.isOn)") }
                        x.subviews.forEach(inner)
                    }
                    inner(cell)
                    out.append("row \(row) h=\(Int(table.delegate!.tableView!(table, heightForRowAt: IndexPath(row: row, section: 0)))): " + texts.joined(separator: " | "))
                }
            }
            for sub in v.subviews { walk(sub) }
        }
        walk(host.view)
        return out
    }
}

public func _flushTransactions() { Updates.flush() }
