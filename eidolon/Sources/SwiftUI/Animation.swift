import UIKit
import CoreGraphics

public struct Animation: Equatable, Hashable {
    enum Curve: Equatable, Hashable { case linear, easeIn, easeOut, easeInOut, spring }
    var curve: Curve
    var duration: Double
    var delay: Double
    var legs: Float = 1
    var autoreverses = false
    /// Set when the timing is a spring or one of the newer curves: what the interpolator asks instead of `curve`.
    var timing: Timing?
    /// The moment the animation counts as over, when that is not its duration: a spring's own settling.
    var logicalEnd: Double?
    /// Set when the animation computes its own values.
    var custom: CustomAnimationBox?

    enum Timing: Equatable, Hashable {
        case curve(UnitCurve)
        case spring(Spring)
    }

    init(curve: Curve, duration: Double, delay: Double, timing: Timing? = nil) {
        self.curve = curve
        self.duration = duration
        self.delay = delay
        self.timing = timing
    }

    public static let `default` = Animation(curve: .easeInOut, duration: 0.25, delay: 0)
    public static func linear(duration: Double = 0.25) -> Animation { Animation(curve: .linear, duration: duration, delay: 0) }
    public static var linear: Animation { linear() }
    public static func easeIn(duration: Double = 0.25) -> Animation { Animation(curve: .easeIn, duration: duration, delay: 0) }
    public static var easeIn: Animation { easeIn() }
    public static func easeOut(duration: Double = 0.25) -> Animation { Animation(curve: .easeOut, duration: duration, delay: 0) }
    public static var easeOut: Animation { easeOut() }
    public static func easeInOut(duration: Double = 0.25) -> Animation { Animation(curve: .easeInOut, duration: duration, delay: 0) }
    public static var easeInOut: Animation { easeInOut() }
    public static func spring(_ spring: Spring, blendDuration: Double = 0) -> Animation {
        Animation(curve: .spring, duration: spring.response, delay: blendDuration, timing: .spring(spring))
    }
    @_disfavoredOverload
    public static func spring(response: Double = 0.5, dampingFraction: Double = 0.825, blendDuration: Double = 0) -> Animation {
        spring(Spring(response: response, dampingRatio: dampingFraction), blendDuration: blendDuration)
    }
    public static func spring(duration: Double = 0.5, bounce: Double = 0, blendDuration: Double = 0) -> Animation {
        spring(Spring(duration: duration, bounce: bounce), blendDuration: blendDuration)
    }
    public static var spring: Animation { spring() }
    @_disfavoredOverload
    public static func interactiveSpring(response: Double = 0.15, dampingFraction: Double = 0.86, blendDuration: Double = 0.25) -> Animation {
        spring(Spring(response: response, dampingRatio: dampingFraction), blendDuration: blendDuration)
    }
    public static func interactiveSpring(duration: Double = 0.15, extraBounce: Double = 0, blendDuration: Double = 0.25) -> Animation {
        spring(duration: duration, bounce: 0.15 + extraBounce, blendDuration: blendDuration)
    }
    public static var interactiveSpring: Animation { interactiveSpring() }
    public static func smooth(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        spring(duration: duration, bounce: extraBounce)
    }
    public static var smooth: Animation { smooth() }
    public static func snappy(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        spring(duration: duration, bounce: 0.15 + extraBounce)
    }
    public static var snappy: Animation { snappy() }
    public static func bouncy(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        spring(duration: duration, bounce: 0.3 + extraBounce)
    }
    public static var bouncy: Animation { bouncy() }
    public static func interpolatingSpring(mass: Double = 1.0, stiffness: Double, damping: Double, initialVelocity: Double = 0.0) -> Animation {
        spring(Spring(mass: mass, stiffness: stiffness, damping: damping))
    }
    public static func interpolatingSpring(_ spring: Spring, initialVelocity: Double = 0.0) -> Animation {
        Animation.spring(spring)
    }
    public static func interpolatingSpring(duration: Double = 0.5, bounce: Double = 0, initialVelocity: Double = 0.0) -> Animation {
        spring(Spring(duration: duration, bounce: bounce))
    }
    public static func timingCurve(_ curve: UnitCurve, duration: Double) -> Animation {
        Animation(curve: .linear, duration: duration, delay: 0, timing: .curve(curve))
    }
    public static func timingCurve(_ c0x: Double, _ c0y: Double, _ c1x: Double, _ c1y: Double, duration: Double = 0.35) -> Animation {
        // the four numbers go in as they are: a UnitPoint holds CGFloats, which are Floats on this architecture, and a
        // control point that went through one would no longer be the number it was given
        timingCurve(UnitCurve(.bezier(c0x, c0y, c1x, c1y)), duration: duration)
    }
    public func timingCurve(_ curve: UnitCurve, duration: Double) -> Animation {
        Animation.timingCurve(curve, duration: duration)
    }
    public func delay(_ delay: Double) -> Animation { with { $0.delay = delay } }
    public func speed(_ speed: Double) -> Animation { with { $0.duration = duration / max(speed, 0.0001) } }
    /// The moment the animation's own curve says it is over, which for a spring is when it settles.
    public func logicallyComplete(after duration: Double) -> Animation { with { $0.logicalEnd = duration } }

    // SwiftUI counts every pass, forwards or back, as one repeat; Core Animation counts a forward and a back together.
    public func repeatCount(_ repeatCount: Int, autoreverses: Bool = true) -> Animation {
        with {
            $0.legs = Float(max(repeatCount, 1))
            $0.autoreverses = autoreverses
        }
    }
    public func repeatForever(autoreverses: Bool = true) -> Animation {
        with {
            $0.legs = .infinity
            $0.autoreverses = autoreverses
        }
    }

    // An entrance or an exit plays once, however the animation around it repeats.
    var once: Animation { with { $0.legs = 1; $0.autoreverses = false } }

    /// How far the animation has come at a fraction of its own length: what a frame-driven animator
    /// multiplies the difference between the old and the new value by. A spring is solved as one.
    func progress(_ t: Double) -> Double {
        switch timing {
        case .none: return Easing.apply(curve, t)
        case .curve(let unit): return unit.value(at: t)
        case .spring(let spring): return 1 - spring.remaining(initialVelocity: 0, time: t * spring.response)
        }
    }

    /// How long the animation is, counting a spring by how long it takes to settle.
    var logicalDuration: Double { logicalEnd ?? duration }

    func with(_ change: (inout Animation) -> Void) -> Animation {
        var copy = self
        change(&copy)
        return copy
    }

    var options: UIView.AnimationOptions {
        var options: UIView.AnimationOptions
        switch curve {
        case .linear: options = .curveLinear
        case .easeIn: options = .curveEaseIn
        case .easeOut: options = .curveEaseOut
        case .easeInOut, .spring: options = .curveEaseInOut
        }
        if legs > 1 { options.insert(.repeat) }
        if autoreverses { options.insert(.autoreverse) }
        return options
    }

    func run(_ animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        // A test driving the clock itself has no render server to hand the animation to.
        if ValueAnimator.manual {
            animations()
            completion?(true)
            return
        }
        if timing != nil {
            _Unsupported.note("Animation.spring", "UIView of iOS 6 animates with one of four named curves and knows no spring, so a UIView property follows the nearest of the four; the engine's own frame-by-frame animations are driven by the spring itself")
        }
        let cycles = autoreverses ? legs / 2 : legs
        UIView.animate(withDuration: duration, delay: delay, options: options, animations: {
            if self.legs > 1 && self.legs.isFinite { UIView.setAnimationRepeatCount(cycles) }
            animations()
        }, completion: completion)
    }
}

public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    let previous = Updates.pendingAnimation
    Updates.pendingAnimation = animation
    defer { Updates.pendingAnimation = previous }
    return try body()
}

struct AnimationModifier: NodeModifier {
    let animation: Animation?
    var value: AnyHashable? = nil
    var changed: ((Any?) -> Bool)? = nil
    var boxed: Any? = nil
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { AnimationNode() }
}

final class AnimationNode: Node {
    var child: Node?
    var lastValue: Any?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! AnimationModifier
        var inner = env
        if let changed = modifier.changed {
            let moved = changed(lastValue)
            inner.animation = moved ? modifier.animation : env.animation
            if moved, let animation = modifier.animation, Updates.animationForFlush == nil { Updates.animationForFlush = animation }
            lastValue = modifier.boxed
        } else {
            inner.animation = modifier.animation
        }
        child = adopt(reconcile(child, m.modifiedContent, inner))
    }
    override func mountContents() { child?.mount() }
}

extension View {
    public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        _ModifiedView(content: self, modifier: AnimationModifier(animation: animation, value: nil, changed: { last in
            guard let last else { return false }
            return (last as? V) != value
        }).withValue(value))
    }
    public func animation(_ animation: Animation?) -> some View {
        _ModifiedView(content: self, modifier: AnimationModifier(animation: animation))
    }
}

extension AnimationModifier {
    func withValue<V>(_ value: V) -> AnimationModifier {
        var copy = self
        copy.boxed = value
        return copy
    }
}
