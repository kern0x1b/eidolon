import UIKit
import CoreGraphics

public struct Animation: Equatable {
    public enum Curve: Equatable { case linear, easeIn, easeOut, easeInOut, spring }
    var curve: Curve
    var duration: Double
    var delay: Double
    var legs: Float = 1
    var autoreverses = false

    public static let `default` = Animation(curve: .easeInOut, duration: 0.25, delay: 0)
    public static func linear(duration: Double = 0.25) -> Animation { Animation(curve: .linear, duration: duration, delay: 0) }
    public static var linear: Animation { linear() }
    public static func easeIn(duration: Double = 0.25) -> Animation { Animation(curve: .easeIn, duration: duration, delay: 0) }
    public static var easeIn: Animation { easeIn() }
    public static func easeOut(duration: Double = 0.25) -> Animation { Animation(curve: .easeOut, duration: duration, delay: 0) }
    public static var easeOut: Animation { easeOut() }
    public static func easeInOut(duration: Double = 0.25) -> Animation { Animation(curve: .easeInOut, duration: duration, delay: 0) }
    public static var easeInOut: Animation { easeInOut() }
    public static func spring(response: Double = 0.55, dampingFraction: Double = 0.825, blendDuration: Double = 0) -> Animation {
        springNote()
        return Animation(curve: .spring, duration: response, delay: 0)
    }
    public static func interactiveSpring(response: Double = 0.15, dampingFraction: Double = 0.86, blendDuration: Double = 0.25) -> Animation {
        springNote()
        return Animation(curve: .spring, duration: response, delay: 0)
    }
    static func springNote() {
        _Unsupported.note("Animation.spring", "UIView of iOS 6 has no spring animation; an ease-out curve of the same response is used and damping is not modelled")
    }
    public static func interpolatingSpring(mass: Double = 1.0, stiffness: Double, damping: Double, initialVelocity: Double = 0.0) -> Animation {
        springNote()
        return Animation(curve: .spring, duration: 2 * Double.pi * (mass / max(stiffness, 0.0001)).squareRoot(), delay: 0)
    }
    public static func timingCurve(_ c0x: Double, _ c0y: Double, _ c1x: Double, _ c1y: Double, duration: Double = 0.35) -> Animation {
        _Unsupported.note("Animation.timingCurve", "UIView of iOS 6 has four timing curves and no cubic Bézier; the nearest of them is used")
        let curves: [(Curve, [Double])] = [(.linear, [0, 0, 1, 1]), (.easeIn, [0.42, 0, 1, 1]), (.easeOut, [0, 0, 0.58, 1]), (.easeInOut, [0.42, 0, 0.58, 1])]
        let given = [c0x, c0y, c1x, c1y]
        let nearest = curves.min { left, right in
            zip(left.1, given).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) } < zip(right.1, given).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
        }
        return Animation(curve: nearest?.0 ?? .easeInOut, duration: duration, delay: 0)
    }
    public func delay(_ delay: Double) -> Animation { with { $0.delay = delay } }
    public func speed(_ speed: Double) -> Animation { with { $0.duration = duration / max(speed, 0.0001) } }

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
