import UIKit
import CoreGraphics

public enum ScrollAxis: Hashable, CaseIterable { case horizontal, vertical }

public struct ScrollPosition: Equatable {
    public var id: AnyHashable?
    public var anchor: UnitPoint?
    public var edge: Edge?
    public var point: UnitPoint?
    public var x: CGFloat?
    public var y: CGFloat?
    public private(set) var isPositionedByUser = false
    let idType: AnyHashable.Type?

    public init() { idType = nil }
    public init(id: AnyHashable, anchor: UnitPoint? = nil) {
        self.id = id; self.anchor = anchor; idType = AnyHashable.self
    }
    public init(idType: AnyHashable.Type) { self.idType = idType }
    public init(idType: AnyHashable.Type, edge: Edge) { self.idType = idType; self.edge = edge }
    public init(idType: AnyHashable.Type, point: UnitPoint) { self.idType = idType; self.point = point }
    public init(idType: AnyHashable.Type, x: CGFloat) { self.idType = idType; self.x = x }
    public init(idType: AnyHashable.Type, y: CGFloat) { self.idType = idType; self.y = y }
    public init(idType: AnyHashable.Type, x: CGFloat, y: CGFloat) { self.idType = idType; self.x = x; self.y = y }

    public subscript<T: Hashable>(idType: T.Type) -> T? {
        get { id as? T }
        set { id = newValue }
    }
    public var viewID: AnyHashable? { id }
    public func viewID<T: Hashable>(type: T.Type) -> T? { id as? T }

    public mutating func scrollTo(edge: Edge) { clear(); self.edge = edge }
    public mutating func scrollTo(id: AnyHashable, anchor: UnitPoint? = nil) {
        clear(); self.id = id; self.anchor = anchor
    }
    public mutating func scrollTo(point: UnitPoint) { clear(); self.point = point }
    public mutating func scrollTo(x: CGFloat) { clear(); self.x = x }
    public mutating func scrollTo(y: CGFloat) { clear(); self.y = y }
    public mutating func scrollTo(x: CGFloat, y: CGFloat) { clear(); self.x = x; self.y = y }

    mutating func clear() {
        id = nil; anchor = nil; edge = nil; point = nil; x = nil; y = nil; isPositionedByUser = false
    }
    mutating func placed(at offset: CGPoint, in content: CGSize, viewport: CGSize) {
        id = nil; anchor = nil; edge = nil
        x = content.width > viewport.width ? offset.x : nil
        y = content.height > viewport.height ? offset.y : nil
        if x == nil && y == nil { point = UnitPoint(x: 0, y: 0) }
        isPositionedByUser = true
    }

    public static func == (lhs: ScrollPosition, rhs: ScrollPosition) -> Bool {
        lhs.id == rhs.id && lhs.anchor == rhs.anchor && lhs.edge == rhs.edge
            && lhs.point == rhs.point && lhs.x == rhs.x && lhs.y == rhs.y
    }
}

public struct ScrollTargetContext {
    public var contentOffset: CGPoint?
    var scroller: UIScrollView?
    var targetOffsets: [CGPoint] = []
    public init() {}
    mutating func settle(_ offset: CGPoint) {
        guard let scroller else { return }
        let limit = CGPoint(x: max(0, scroller.contentSize.width - scroller.bounds.size.width),
                            y: max(0, scroller.contentSize.height - scroller.bounds.size.height))
        scroller.setContentOffset(CGPoint(x: min(max(0, offset.x), limit.x), y: min(max(0, offset.y), limit.y)),
                                 animated: false)
        contentOffset = scroller.contentOffset
    }
    mutating func nearestTarget(to offset: CGPoint) -> CGPoint? {
        targetOffsets.min { distance($0, offset) < distance($1, offset) }
    }
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = a.x - b.x, dy = a.y - b.y
    return dx * dx + dy * dy
}

public struct ScrollTargetProperties {
    public var offset: CGSize = .zero
    public init() {}
}

public struct ScrollTargetPropertiesContext {
    public var proposedOffset: CGPoint = .zero
    public init() {}
}

public protocol ScrollTargetLayout {}

public protocol ScrollTargetBehavior {
    func updateTarget(_ target: inout ScrollTargetContext)
}

extension ScrollTargetBehavior {
    public typealias TargetContext = ScrollTargetContext
    public typealias Properties = ScrollTargetProperties
    public typealias PropertiesContext = ScrollTargetPropertiesContext
    public func properties(context: PropertiesContext) -> Properties { Properties() }
}

// SwiftUI nests this one in the protocol, which a protocol extension cannot hold on this compiler, so it is a type of
// its own that the protocol names.
public struct ScrollTargetLimitBehavior {
    let stopsAtBoundaries: Bool
    public init(stopsAtBoundaries: Bool) { self.stopsAtBoundaries = stopsAtBoundaries }
}

extension ScrollTargetBehavior {
    public typealias LimitBehavior = ScrollTargetLimitBehavior
    public static var automatic: LimitBehavior { ScrollTargetLimitBehavior(stopsAtBoundaries: true) }
    public static var always: LimitBehavior { ScrollTargetLimitBehavior(stopsAtBoundaries: true) }
    public static var neverByNumber: LimitBehavior { ScrollTargetLimitBehavior(stopsAtBoundaries: false) }
}

public struct PagingScrollTargetBehavior: ScrollTargetBehavior {
    public init() {}
    public func updateTarget(_ target: inout ScrollTargetContext) {
        guard let view = target.scroller else { return }
        let step = view.bounds.size
        target.settle(CGPoint(x: (view.contentOffset.x / max(step.width, 1)).rounded() * step.width,
                              y: (view.contentOffset.y / max(step.height, 1)).rounded() * step.height))
    }
}

public struct ViewAlignedScrollTargetBehavior: ScrollTargetBehavior {
    public let limitBehavior: LimitBehavior?
    public let anchor: UnitPoint
    public init(limitBehavior: LimitBehavior? = nil, anchor: UnitPoint = .top) {
        self.limitBehavior = limitBehavior; self.anchor = anchor
    }
    public func updateTarget(_ target: inout ScrollTargetContext) {
        guard let view = target.scroller, let resting = target.nearestTarget(to: view.contentOffset) else { return }
        target.settle(resting)
    }
}

extension ScrollTargetBehavior where Self == PagingScrollTargetBehavior {
    public static var paging: PagingScrollTargetBehavior { PagingScrollTargetBehavior() }
}

extension ScrollTargetBehavior where Self == ViewAlignedScrollTargetBehavior {
    public static func viewAligned(limitBehavior: LimitBehavior) -> ViewAlignedScrollTargetBehavior {
        ViewAlignedScrollTargetBehavior(limitBehavior: limitBehavior)
    }
    public static func viewAligned(limitBehavior: LimitBehavior, anchor: UnitPoint) -> ViewAlignedScrollTargetBehavior {
        ViewAlignedScrollTargetBehavior(limitBehavior: limitBehavior, anchor: anchor)
    }
    public static func viewAligned(anchor: UnitPoint) -> ViewAlignedScrollTargetBehavior {
        ViewAlignedScrollTargetBehavior(anchor: anchor)
    }
}

public struct AnyScrollTargetBehavior: ScrollTargetBehavior {
    public var base: any ScrollTargetBehavior
    public init(_ base: some ScrollTargetBehavior) { self.base = base }
    public func updateTarget(_ target: inout ScrollTargetContext) { base.updateTarget(&target) }
}

struct ScrollPositionRequest {
    var binding: Binding<ScrollPosition>
    var anchor: UnitPoint?
}

struct ScrollAnchors: Equatable {
    var vertical = UnitPoint.top
    var horizontal = UnitPoint.leading
}

extension View {
    public func scrollPosition(_ position: Binding<ScrollPosition>, anchor: UnitPoint? = nil) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.scrollPosition = ScrollPositionRequest(binding: position, anchor: anchor)
        }, onUpdate: nil))
    }
    public func scrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            let wanted = id
            environment.scrollPosition = ScrollPositionRequest(
                binding: Binding(get: {
                    var position = ScrollPosition()
                    position.id = wanted.wrappedValue.map { AnyHashable($0) }
                    return position
                }, set: { position in
                    if let new = position.id { wanted.wrappedValue = new.base as? ID }
                }), anchor: anchor)
        }, onUpdate: nil))
    }
    public func defaultScrollAnchor(_ anchors: UnitPoint...) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            var current = environment.scrollAnchors ?? ScrollAnchors()
            if let first = anchors.first { current.vertical = first }
            if anchors.count > 1 { current.horizontal = anchors[1] }
            environment.scrollAnchors = current
        }, onUpdate: nil))
    }
    public func defaultScrollAnchor(_ anchor: UnitPoint, for axis: ScrollAxis) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            var current = environment.scrollAnchors ?? ScrollAnchors()
            if axis == .vertical { current.vertical = anchor } else { current.horizontal = anchor }
            environment.scrollAnchors = current
        }, onUpdate: nil))
    }
    public func scrollClipDisabled(_ disabled: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.scrollClipDisabled = disabled }, onUpdate: nil))
    }
    public func scrollTargetLayout(isEnabled: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: ScrollTargetLayoutModifier(isEnabled: isEnabled))
    }
    public func scrollTargetBehavior(_ behavior: some ScrollTargetBehavior) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.scrollTarget = AnyScrollTargetBehavior(behavior) }, onUpdate: nil))
    }
}

struct ScrollTargetLayoutModifier: NodeModifier {
    let isEnabled: Bool
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ScrollTargetLayoutNode() }
}

final class ScrollTargetLayoutNode: Node {
    var child: Node?
    var isTargetLayout = false
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        isTargetLayout = (m.modifierValue as! ScrollTargetLayoutModifier).isEnabled
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func mountContents() { child?.mount() }
}

extension ScrollDismissesKeyboardMode: Equatable {}

extension GeometryProxy {
    public func bounds(of anchor: Anchor<CGRect>) -> CGRect? {
        guard let source = anchor.view, let target = node?.uiView else { return nil }
        return anchor.convert(anchor.measure(source.bounds), source, target)
    }
    // Nothing the system draws on iOS 6 has rounded corners, so no container has corner insets to report.
    public var containerCornerInsets: EdgeInsets { EdgeInsets() }
}
