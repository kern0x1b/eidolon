import UIKit
import CoreGraphics
#if !REV_NO_FIELD_REFLECTION
@_spi(Reflection) import Swift
#endif

public struct EnvironmentValues {
    var fontValue: UIFont?
    var foregroundColor: UIColor?
    var textAlignment: NSTextAlignment = .left
    weak var host: UIViewController?
    weak var list: ListNode?
    var listStyleGrouped = false
    var objects: [ObjectIdentifier: AnyObject] = [:]
    var values: [ObjectIdentifier: Any] = [:]
    var animation: Animation?
    public var lineLimit: Int?
    var reservesLines = false
    var scaleFactorOverride: CGFloat?
    var tint: UIColor?
    var input = InputSettings()
    var truncation: NSLineBreakMode?
    var labelsHidden = false
    public var textCase: Text.Case?
    var buttonStyle: ((ButtonStyleConfiguration) -> any View)?
    var primitiveButtonStyle: ((PrimitiveButtonStyleConfiguration) -> any View)?
    var searchSuggestions: (() -> any View)?
    var searchComplete: ((String) -> Void)?
    var toggleStyle: ((ToggleStyleConfiguration) -> any View)?
    var labelStyle: ((LabelStyleConfiguration) -> any View)?
    var progressViewStyle: ((ProgressViewStyleConfiguration) -> any View)?
    var menuStyle: ((MenuStyleConfiguration) -> any View)?
    var styles: [ObjectIdentifier: Any] = [:]
    var kerning: CGFloat?
    public var allowsTightening = false
    var scrollBackgroundHidden = false
    var redactedDrawing = false
    var paging: PagingSettings?
    var buttonBorderShape = ButtonBorderShape.automatic
    var layoutValues: [ObjectIdentifier: Any] = [:]
    var searchScope: SearchScopeSetting?
    var wheelRowHeight: CGFloat?
    var menuBorderless = false
    var splitStage: Int?
    var contentTransition = ContentTransition.identity
    var backgroundShapeStyle: AnyShapeStyle?
    var containerShapeValue: AnyShape?
    var splitPush: ((@escaping () -> Void) -> Void)?
    var headerProminent = false
    var disclosureGroupStyle: ((DisclosureGroupStyleConfiguration) -> any View)?
    var pickerPresentation = PickerPresentation.segmented
    var destinations: [ObjectIdentifier: (AnyHashable) -> any View] = [:]
    var lineSpacingOverride: CGFloat?
    var textBold = false
    var textItalic = false
    var textUnderline = false
    var textStrikethrough = false
    public var imageScale = Image.Scale.medium
    var defaults = UserDefaults.standard
    init() {}

    func isSame(_ other: EnvironmentValues) -> Bool {
        fontValue === other.fontValue && foregroundColor === other.foregroundColor
            && textAlignment == other.textAlignment
            && host === other.host && listStyleGrouped == other.listStyleGrouped
            && objects.count == other.objects.count
            && objects.allSatisfy { key, value in other.objects[key] === value }
            && sameValues(values, other.values) && animation == other.animation
            && lineLimit == other.lineLimit && reservesLines == other.reservesLines && scaleFactorOverride == other.scaleFactorOverride && tint === other.tint
            && (buttonStyle == nil) == (other.buttonStyle == nil) && (primitiveButtonStyle == nil) == (other.primitiveButtonStyle == nil) && (toggleStyle == nil) == (other.toggleStyle == nil)
            && (labelStyle == nil) == (other.labelStyle == nil) && (progressViewStyle == nil) == (other.progressViewStyle == nil)
            && styles.count == other.styles.count && kerning == other.kerning && allowsTightening == other.allowsTightening && scrollBackgroundHidden == other.scrollBackgroundHidden && redactedDrawing == other.redactedDrawing && (paging == nil) == (other.paging == nil) && buttonBorderShape == other.buttonBorderShape && (menuStyle == nil) == (other.menuStyle == nil) && (disclosureGroupStyle == nil) == (other.disclosureGroupStyle == nil)
    }
}

class Node {
    var viewType: Any.Type = Never.self
    var env = EnvironmentValues()
    var lastReconciledView: (any View)?
    weak var parent: Node?
    var flattened: [LayoutNode] { [] }
    func update(_ view: any View, _ env: EnvironmentValues) {
        self.env = env
        invalidateLayout()
    }
    func invalidateLayout() {
        needsMount = true
        (self as? LayoutNode)?.dropSizeCache()
        for node in flattened {
            node.dropSizeCache()
            node.needsMount = true
        }
        var node = parent
        while let current = node {
            (current as? LayoutNode)?.dropSizeCache()
            current.needsMount = true
            node = current.parent
        }
    }
    var needsMount = true
    final func mount() {
        guard needsMount else { return }
        needsMount = false
        mountContents()
    }
    func mountContents() {}
    var disposed = false
    func dispose() {
        disposed = true
        for child in disposableChildren { child.dispose() }
    }
    var disposableChildren: [Node] { [] }
    var childNodes: [Node] { disposableChildren }
    func adopt(_ node: Node) -> Node { node.parent = self; return node }
    var depth: Int { var d = 0; var p = parent; while let q = p { d += 1; p = q.parent }; return d }
    func isDescendant(of other: Node) -> Bool { var p = parent; while let q = p { if q === other { return true }; p = q.parent }; return false }
}

func reconcile(_ old: Node?, _ view: any View, _ env: EnvironmentValues) -> Node {
    if let old, old.viewType == type(of: view) {
        if env.isSame(old.env), let last = old.lastReconciledView, viewsEqual(last, view) {
            return old
        }
        old.update(view, env)
        old.lastReconciledView = view
        return old
    }
    old?.dispose()
    let node = makeNode(view, env)
    node.lastReconciledView = view
    return node
}

final class GroupNode: Node {
    var children: [Node] {
        didSet { children.forEach { $0.parent = self } }
    }
    init(children: [Node]) {
        self.children = children
        super.init()
        children.forEach { $0.parent = self }
    }
    override var flattened: [LayoutNode] { children.flatMap { $0.flattened } }
    override var disposableChildren: [Node] { children }
    var branch: Bool?
    override func update(_ view: any View, _ env: EnvironmentValues) {
        self.env = env
        var structureChanged = false
        if let conditional = view as? BranchView {
            if let branch, branch != conditional.branch {
                children.forEach { $0.dispose() }
                children = []
                structureChanged = true
            }
            branch = conditional.branch
        }
        let views = groupChildren(view as! GroupView, env)
        if views.count != children.count { structureChanged = true }
        var next: [Node] = []
        for (i, v) in views.enumerated() {
            let existing = i < children.count ? children[i] : nil
            if existing == nil || existing!.viewType != type(of: v) { structureChanged = true }
            next.append(adopt(reconcile(existing, v, env)))
        }
        for dropped in children.dropFirst(views.count) { dropped.dispose() }
        children = next
        if structureChanged { invalidateLayout() }
    }
    override func mountContents() { children.forEach { $0.mount() } }
}

protocol DynamicPropertyInstaller {
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int)
}

final class CompositeNode: Node {
    var view: any View
    var child: Node?
    var storages: [Int: AnyObject] = [:]
    var bodyCount = 0
    var renderedInFlush = -1
    init(view: any View) {
        self.view = view
        super.init()
        viewType = type(of: view)
    }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        let unchanged = env.isSame(self.env) && viewsEqual(self.view, view)
        self.view = view
        if unchanged && child != nil {
            self.env = env
            return
        }
        super.update(view, env)
        render()
    }
    func render() {
        let installed = installProperties(view, self)
        bodyCount += 1
        renderedInFlush = Updates.flushCount
        let body = (installed as? EnvironmentalBody)?.environmentalBody(env) ?? evaluateBody(installed)
        child = adopt(reconcile(child, body, env))

    }
    override func mountContents() { child?.mount() }
    func invalidate() { Updates.schedule(self) }

}

func evaluateBody<V: View>(_ view: V) -> any View { view.body }

func viewsEqual(_ a: any View, _ b: any View) -> Bool { valuesEqual(a, b) }

func valuesEqual<V: View>(_ a: V, _ b: any View) -> Bool {
    guard let b = b as? V else { return false }
    if let equatable = a as? any Equatable { return equatableEqual(equatable, b) }
    return withUnsafeBytes(of: a) { left in
        withUnsafeBytes(of: b) { right in
            left.count == right.count && left.elementsEqual(right)
        }
    }
}

func equatableEqual<E: Equatable>(_ a: E, _ b: Any) -> Bool { (b as? E).map { $0 == a } ?? false }

func installProperties<V: View>(_ view: V, _ node: CompositeNode) -> any View {
#if REV_NO_FIELD_REFLECTION
    return view
#else
    var copy = view
    withUnsafeMutableBytes(of: &copy) { raw in
        installFields(V.self, raw.baseAddress!, node, 0)
    }
    return copy
#endif
}

#if !REV_NO_FIELD_REFLECTION
enum FieldKind { case installer(DynamicPropertyInstaller.Type), dynamic(DynamicProperty.Type), modifier }

struct PropertyField {
    let offset: Int
    let type: Any.Type
    let kind: FieldKind
}

nonisolated(unsafe) var propertyFieldCache: [ObjectIdentifier: [PropertyField]] = [:]

func propertyFields(_ type: Any.Type) -> [PropertyField] {
    if let cached = propertyFieldCache[ObjectIdentifier(type)] { return cached }
    var fields: [PropertyField] = []
    _ = _forEachField(of: type) { _, offset, fieldType, _ in
        if let installer = fieldType as? DynamicPropertyInstaller.Type {
            fields.append(PropertyField(offset: offset, type: fieldType, kind: .installer(installer)))
        } else if let dynamic = fieldType as? DynamicProperty.Type {
            fields.append(PropertyField(offset: offset, type: fieldType, kind: .dynamic(dynamic)))
        } else if fieldType is any ViewModifier.Type {
            fields.append(PropertyField(offset: offset, type: fieldType, kind: .modifier))
        }
        return true
    }
    propertyFieldCache[ObjectIdentifier(type)] = fields
    return fields
}

func installFields(_ type: Any.Type, _ base: UnsafeMutableRawPointer, _ node: CompositeNode, _ keyBase: Int) {
    for field in propertyFields(type) {
        switch field.kind {
        case .installer(let installer):
            installer.install(base + field.offset, node, keyBase + field.offset)
        case .dynamic(let dynamic):
            installFields(field.type, base + field.offset, node, keyBase + field.offset)
            updateDynamic(dynamic, base + field.offset)
        case .modifier:
            installFields(field.type, base + field.offset, node, keyBase + field.offset)
        }
    }
}

func updateDynamic<T: DynamicProperty>(_ type: T.Type, _ pointer: UnsafeMutableRawPointer) {
    pointer.assumingMemoryBound(to: T.self).pointee.update()
}
#endif

public protocol DynamicProperty {
    mutating func update()
}

extension DynamicProperty {
    public mutating func update() {}
}

enum Updates {
    static var dirty: [CompositeNode] = []
    static var scheduled = false
    static var pendingAnimation: Animation?
    static var animationForFlush: Animation?
    static var hosts: [WeakHost] = []
    static var flushCount = 0

    static func schedule(_ node: CompositeNode) {
        if !dirty.contains(where: { $0 === node }) { dirty.append(node) }
        animationForFlush = pendingAnimation ?? node.env.animation ?? animationForFlush
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { flush() }
    }

    static func flush() {
        scheduled = false
        flushCount += 1
        let nodes = dirty.sorted { $0.depth < $1.depth }
        dirty = []
        var rendered: [CompositeNode] = []
        let renderStart = CFAbsoluteTimeGetCurrent()
        for node in nodes where !node.disposed && node.renderedInFlush != flushCount {
            node.render()
            rendered.append(node)
        }
        LayoutCounters.renderTime += CFAbsoluteTimeGetCurrent() - renderStart
        hosts = hosts.filter { $0.host != nil }
        let animation = animationForFlush
        let mountStart = CFAbsoluteTimeGetCurrent()
        for h in hosts { h.host?.contentChanged() }
        LayoutCounters.mountTime += CFAbsoluteTimeGetCurrent() - mountStart
        animationForFlush = nil
        if let animation {
            // Only the screens that changed animate their layout; the others are none of this animation's business.
            let changed = hosts.compactMap { $0.host }.filter { host in rendered.contains { $0.env.host === host } }
            animation.run { for host in changed { host.view.layoutIfNeeded() } }
        }
        var lists: [ListNode] = []
        for node in rendered {
            var p: Node? = node.parent
            while let q = p {
                if let list = q as? ListNode, !lists.contains(where: { $0 === list }) { lists.append(list) }
                p = q.parent
            }
        }
        for list in lists { list.syncRows() }
    }
}

struct WeakHost { weak var host: _HostingViewController? }

func sameValues(_ a: [ObjectIdentifier: Any], _ b: [ObjectIdentifier: Any]) -> Bool {
    guard a.count == b.count else { return false }
    for (key, left) in a {
        guard let right = b[key] else { return false }
        if let l = left as? AnyHashable, let r = right as? AnyHashable {
            if l != r { return false }
        } else if type(of: left) is AnyClass, type(of: right) is AnyClass {
            if (left as AnyObject) !== (right as AnyObject) { return false }
        } else if !bytesEqual(left, right) {
            return false
        }
    }
    return true
}

func bytesEqual(_ a: Any, _ b: Any) -> Bool {
    func open<T>(_ x: T) -> Bool {
        guard let y = b as? T else { return false }
        return withUnsafeBytes(of: x) { l in withUnsafeBytes(of: y) { r in l.count == r.count && l.elementsEqual(r) } }
    }
    return _openExistential(a, do: open)
}
