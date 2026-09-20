import UIKit
import QuartzCore
import CoreGraphics

// MARK: Animatable for the value types SwiftUI animates

extension CGSize: Animatable {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(width, height) }
        set { self = CGSize(width: newValue.first, height: newValue.second) }
    }
}

extension CGPoint: Animatable {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(x, y) }
        set { self = CGPoint(x: newValue.first, y: newValue.second) }
    }
}

extension CGRect: Animatable {
    public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(origin.animatableData, size.animatableData) }
        set {
            origin.animatableData = newValue.first
            size.animatableData = newValue.second
        }
    }
}

extension Angle: Animatable {
    public var animatableData: Double {
        get { radians }
        set { self = Angle(radians: newValue) }
    }
}

extension UnitPoint: Animatable {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(x, y) }
        set { self = UnitPoint(x: newValue.first, y: newValue.second) }
    }
}

// MARK: timing

enum Easing {
    static func apply(_ curve: Animation.Curve, _ t: Double) -> Double {
        switch curve {
        case .linear: return t
        case .easeIn: return bezier(0.42, 0, 1, 1, t)
        case .easeOut, .spring: return bezier(0, 0, 0.58, 1, t)
        case .easeInOut: return bezier(0.42, 0, 0.58, 1, t)
        }
    }

    // The same cubic Bézier that Core Animation's named timing curves are, solved for the time.
    static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        func sample(_ a: Double, _ b: Double, _ u: Double) -> Double {
            3 * a * (1 - u) * (1 - u) * u + 3 * b * (1 - u) * u * u + u * u * u
        }
        var low = 0.0, high = 1.0, u = x
        for _ in 0..<24 {
            let value = sample(x1, x2, u)
            if abs(value - x) < 1e-6 { break }
            if value < x { low = u } else { high = u }
            u = (low + high) / 2
        }
        return sample(y1, y2, u)
    }
}

// Drives a value from the start of an animation to its end frame by frame, for the things Core Animation cannot
// interpolate for us: the data of a custom Shape or GeometryEffect.
final class ValueAnimator {
    nonisolated(unsafe) static var clock: () -> CFTimeInterval = { CACurrentMediaTime() }
    nonisolated(unsafe) static var manual = false
    nonisolated(unsafe) static var active: [ValueAnimator] = []

    // One display link serves every running animation; it exists only while there is one, so an idle app has none.
    private final class Proxy: NSObject {
        @objc func fire() { ValueAnimator.tickAll() }
    }
    nonisolated(unsafe) private static var sharedLink: CADisplayLink?

    private static func updateLink() {
        if manual { return }
        if active.isEmpty {
            sharedLink?.invalidate()
            sharedLink = nil
        } else if sharedLink == nil {
            let link = CADisplayLink(target: Proxy(), selector: #selector(Proxy.fire))
            link.add(to: .main, forMode: .common)
            sharedLink = link
        }
    }

    let animation: Animation
    private let apply: (Double) -> Void
    var finished: (() -> Void)?
    private var started: CFTimeInterval = 0

    init(animation: Animation, apply: @escaping (Double) -> Void) {
        self.animation = animation
        self.apply = apply
    }

    func start() {
        started = ValueAnimator.clock()
        ValueAnimator.active.append(self)
        apply(0)
        ValueAnimator.updateLink()
    }

    func stop() {
        ValueAnimator.active.removeAll { $0 === self }
        ValueAnimator.updateLink()
    }

    static func tickAll() {
        for animator in active { animator.tick() }
    }

    func tick() {
        let (value, done) = progress(at: ValueAnimator.clock())
        apply(value)
        if done {
            stop()
            finished?()
        }
    }

    // Where the animation stands at a moment: the eased value, and whether it is over.
    func progress(at now: CFTimeInterval) -> (value: Double, done: Bool) {
        let elapsed = now - started - animation.delay
        guard elapsed >= 0 else { return (0, false) }
        let length = max(animation.duration, 0.001)
        let passes = elapsed / length
        let legs = Double(animation.legs)
        if legs.isFinite && passes >= legs {
            let backAtStart = animation.autoreverses && Int(legs) % 2 == 0
            return (backAtStart ? 0 : 1, true)
        }
        let whole = floor(passes)
        let fraction = passes - whole
        let raw = animation.autoreverses ? (Int(whole) % 2 == 0 ? fraction : 1 - fraction) : fraction
        return (Easing.apply(animation.curve, raw), false)
    }
}

// MARK: interpolation of animatable values

func interpolate<A: Animatable>(from: A, to: A) -> ((Double) -> A)? {
    let start = from.animatableData
    let delta = to.animatableData - start
    guard delta.magnitudeSquared > 1e-12 else { return nil }
    return { t in
        var step = delta
        step.scale(by: t)
        var value = to
        value.animatableData = start + step
        return value
    }
}

// nil when the two shapes are of different kinds, or when nothing that animates differs between them.
func shapeInterpolator(from: any Shape, to: any Shape) -> ((Double) -> any Shape)? {
    if let left = from as? AnyShape, let right = to as? AnyShape {
        guard let inner = shapeInterpolator(from: left.base, to: right.base) else { return nil }
        return { AnyShape(inner($0)) }
    }
    func open<S: Shape>(_ start: S) -> ((Double) -> any Shape)? {
        guard let end = to as? S, let step = interpolate(from: start, to: end) else { return nil }
        return { step($0) }
    }
    return open(from)
}

func effectInterpolator(from: any GeometryEffect, to: any GeometryEffect) -> ((Double) -> any GeometryEffect)? {
    func open<E: GeometryEffect>(_ start: E) -> ((Double) -> any GeometryEffect)? {
        guard let end = to as? E, let step = interpolate(from: start, to: end) else { return nil }
        return { step($0) }
    }
    return open(from)
}

// MARK: GeometryEffect

extension ProjectionTransform {
    var layerTransform: CATransform3D {
        var t = CATransform3DIdentity
        t.m11 = m11; t.m12 = m12; t.m14 = m13
        t.m21 = m21; t.m22 = m22; t.m24 = m23
        t.m41 = m31; t.m42 = m32; t.m44 = m33
        return t
    }
}

protocol GeometryEffectViewLike {
    var effectContent: any View { get }
    var effectValue: any GeometryEffect { get }
}

public struct _GeometryEffectView<Content: View, Effect: GeometryEffect>: View, PrimitiveView, GeometryEffectViewLike {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: Content
    let effect: Effect
    var effectContent: any View { content }
    var effectValue: any GeometryEffect { effect }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = GeometryEffectNode(); n.update(self, env); return n }
}

final class ShapeAnimation {
    var from: any Shape
    var interpolate: (Double) -> any Shape
    init(from: any Shape, interpolate: @escaping (Double) -> any Shape) { self.from = from; self.interpolate = interpolate }
}

final class EffectAnimation {
    var from: any GeometryEffect
    var interpolate: (Double) -> any GeometryEffect
    init(from: any GeometryEffect, interpolate: @escaping (Double) -> any GeometryEffect) { self.from = from; self.interpolate = interpolate }
}

final class GeometryEffectNode: ContainerNode {
    var effect: (any GeometryEffect)?
    var target: (any GeometryEffect)?
    var running: EffectAnimation?
    var animator: ValueAnimator?

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let described = view as! GeometryEffectViewLike
        content = adopt(reconcile(content, described.effectContent, env))
        retarget(described.effectValue, animation: Updates.animationForFlush ?? env.animation)
        applyTransform()
    }

    func retarget(_ new: any GeometryEffect, animation: Animation?) {
        defer { target = new }
        guard let shown = effect else { effect = new; return }
        if let running, let last = target, effectInterpolator(from: last, to: new) == nil {
            if let rebuilt = effectInterpolator(from: running.from, to: new) { running.interpolate = rebuilt } else { finish(at: new) }
            return
        }
        animator?.stop()
        animator = nil
        running = nil
        guard let animation, let step = effectInterpolator(from: shown, to: new) else { effect = new; return }
        let state = EffectAnimation(from: shown, interpolate: step)
        running = state
        let driver = ValueAnimator(animation: animation) { [weak self, weak state] t in
            guard let self, let state else { return }
            self.effect = state.interpolate(t)
            self.applyTransform()
        }
        driver.finished = { [weak self] in
            self?.animator = nil
            self?.running = nil
        }
        animator = driver
        driver.start()
    }

    func finish(at new: any GeometryEffect) {
        animator?.stop()
        animator = nil
        running = nil
        effect = new
    }

    // A geometry effect works in the view's own coordinates, with the origin in its top-left corner; a layer turns
    // about its anchor point, which is the middle, so the transform is moved there and back.
    func applyTransform() {
        guard let effect else { return }
        let size = uiView.bounds.size
        let value = effect.effectValue(size: size)
        let toOrigin = CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0)
        let back = CATransform3DMakeTranslation(-size.width / 2, -size.height / 2, 0)
        let wanted = CATransform3DConcat(CATransform3DConcat(toOrigin, value.layerTransform), back)
        if !CATransform3DEqualToTransform(uiView.layer.transform, wanted) { uiView.layer.transform = wanted }
    }

    override func dispose() {
        animator?.stop()
        animator = nil
        super.dispose()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }

    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        applyTransform()
    }
}

extension GeometryEffect {
    public func body(content: Content) -> some View {
        _GeometryEffectView(content: content, effect: self)
    }
}

public struct _IgnoredByLayoutEffect<Base: GeometryEffect>: GeometryEffect {
    public var base: Base
    public init(_ base: Base) { self.base = base }
    public var animatableData: Base.AnimatableData {
        get { base.animatableData }
        set { base.animatableData = newValue }
    }
    public func effectValue(size: CGSize) -> ProjectionTransform { base.effectValue(size: size) }
}

extension GeometryEffect {
    // Effects here are applied after layout, so no effect changes what the layout sees: this is what they all do.
    public func ignoredByLayout() -> _IgnoredByLayoutEffect<Self> { _IgnoredByLayoutEffect(self) }
}

extension ProjectionTransform {
    public var isIdentity: Bool { self == ProjectionTransform() }
    public var isAffine: Bool { m13 == 0 && m23 == 0 && m33 == 1 }

    public init(_ transform: CATransform3D) {
        self.init()
        m11 = transform.m11; m12 = transform.m12; m13 = transform.m14
        m21 = transform.m21; m22 = transform.m22; m23 = transform.m24
        m31 = transform.m41; m32 = transform.m42; m33 = transform.m44
    }

    public func concatenating(_ rhs: ProjectionTransform) -> ProjectionTransform {
        var result = ProjectionTransform()
        let a = [[m11, m12, m13], [m21, m22, m23], [m31, m32, m33]]
        let b = [[rhs.m11, rhs.m12, rhs.m13], [rhs.m21, rhs.m22, rhs.m23], [rhs.m31, rhs.m32, rhs.m33]]
        var c = [[CGFloat]](repeating: [0, 0, 0], count: 3)
        for row in 0..<3 { for column in 0..<3 { for k in 0..<3 { c[row][column] += a[row][k] * b[k][column] } } }
        result.m11 = c[0][0]; result.m12 = c[0][1]; result.m13 = c[0][2]
        result.m21 = c[1][0]; result.m22 = c[1][1]; result.m23 = c[1][2]
        result.m31 = c[2][0]; result.m32 = c[2][1]; result.m33 = c[2][2]
        return result
    }

    public mutating func invert() -> Bool {
        let determinant = m11 * (m22 * m33 - m23 * m32) - m12 * (m21 * m33 - m23 * m31) + m13 * (m21 * m32 - m22 * m31)
        guard abs(determinant) > 1e-12 else { return false }
        let inverse = ProjectionTransform.adjugate(self, determinant)
        self = inverse
        return true
    }

    public func inverted() -> ProjectionTransform {
        var copy = self
        return copy.invert() ? copy : self
    }

    private static func adjugate(_ t: ProjectionTransform, _ determinant: CGFloat) -> ProjectionTransform {
        var r = ProjectionTransform()
        r.m11 = (t.m22 * t.m33 - t.m23 * t.m32) / determinant
        r.m12 = (t.m13 * t.m32 - t.m12 * t.m33) / determinant
        r.m13 = (t.m12 * t.m23 - t.m13 * t.m22) / determinant
        r.m21 = (t.m23 * t.m31 - t.m21 * t.m33) / determinant
        r.m22 = (t.m11 * t.m33 - t.m13 * t.m31) / determinant
        r.m23 = (t.m13 * t.m21 - t.m11 * t.m23) / determinant
        r.m31 = (t.m21 * t.m32 - t.m22 * t.m31) / determinant
        r.m32 = (t.m12 * t.m31 - t.m11 * t.m32) / determinant
        r.m33 = (t.m11 * t.m22 - t.m12 * t.m21) / determinant
        return r
    }
}

extension CGAffineTransform {
    public init(_ m: ProjectionTransform) {
        self.init(a: m.m11, b: m.m12, c: m.m21, d: m.m22, tx: m.m31, ty: m.m32)
    }
}

// MARK: a ViewModifier that is Animatable

protocol AnimatedModifierMaking {
    func makeAnimatedNode(_ env: EnvironmentValues) -> Node?
}

final class ModifierAnimation<M: ViewModifier & Animatable> {
    var from: M
    var interpolate: (Double) -> M
    init(from: M, interpolate: @escaping (Double) -> M) { self.from = from; self.interpolate = interpolate }
}

extension ModifiedContent: AnimatedModifierMaking where Modifier: Animatable {
    func makeAnimatedNode(_ env: EnvironmentValues) -> Node? {
        // A geometry effect animates itself, and a modifier without data has nothing to interpolate.
        if modifier is any GeometryEffect || Modifier.AnimatableData.self == EmptyAnimatableData.self { return nil }
        let node = AnimatedModifierNode<Content, Modifier>()
        node.update(self, env)
        return node
    }
}

// Every frame of an animation evaluates the body of the modifier again with data between the old and the new.
final class AnimatedModifierNode<C: View, M: ViewModifier & Animatable>: ContainerNode {
    var contentView: C?
    var shown: M?
    var target: M?
    var running: ModifierAnimation<M>?
    var animator: ValueAnimator?

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let modified = view as? ModifiedContent<C, M> else { return }
        contentView = modified.content
        retarget(modified.modifier, animation: Updates.animationForFlush ?? env.animation)
        render()
    }

    func render() {
        guard let contentView, let shown else { return }
        let body = shown.body(content: _ViewModifier_Content(content: contentView))
        content = adopt(reconcile(content, AnyView(body), env))
    }

    func retarget(_ new: M, animation: Animation?) {
        defer { target = new }
        guard let current = shown else { shown = new; return }
        if let running, let last = target, interpolate(from: last, to: new) == nil {
            if let rebuilt = interpolate(from: running.from, to: new) { running.interpolate = rebuilt } else { finish(at: new) }
            return
        }
        animator?.stop()
        animator = nil
        running = nil
        guard let animation, let step = interpolate(from: current, to: new) else { shown = new; return }
        let state = ModifierAnimation<M>(from: current, interpolate: step)
        running = state
        let driver = ValueAnimator(animation: animation) { [weak self, weak state] t in
            guard let self, let state else { return }
            self.shown = state.interpolate(t)
            self.render()
            self.invalidateLayout()
            (self.env.host as? _HostingViewController)?.contentChanged()
        }
        driver.finished = { [weak self] in
            self?.animator = nil
            self?.running = nil
        }
        animator = driver
        driver.start()
    }

    func finish(at new: M) {
        animator?.stop()
        animator = nil
        running = nil
        shown = new
    }

    override func dispose() {
        animator?.stop()
        animator = nil
        super.dispose()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }

    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}
