import CoreGraphics

// A damped harmonic oscillator: the spring SwiftUI's newer animations are built on. It is kept the way
// it was built, because that is what decides what the other numbers read back: a spring made of a
// duration and a bounce or of a response and a ratio reports the stiffness and the damping its own pair
// implies — an over-damped one carries the factor that keeps the ratio — while a spring made of a mass, a
// stiffness and a damping reports those three as they were given. Every one of the numbers below is what
// Apple's own framework answers for the same spring (.agent-work/host/*.out hold the measurements).
public struct Spring: Hashable {
    enum Form: Hashable {
        case duration(Double, Double)
        case response(Double, Double)
        case system(Double, Double, Double)
    }
    var form: Form

    /// The undamped angular frequency, `2π / response`.
    var frequency: Double { 2 * Double.pi / max(response, .leastNormalMagnitude) }

    public init(response: Double, dampingRatio: Double) {
        form = .response(response, dampingRatio)
    }

    public init(duration: Double = 0.5, bounce: Double = 0) {
        form = .duration(duration, bounce)
    }

    public init(mass: Double = 1, stiffness: Double, damping: Double, allowOverDamping: Bool = false) {
        let critical = 2 * (mass * stiffness).squareRoot()
        form = .system(mass, stiffness, allowOverDamping ? damping : min(damping, critical))
    }

    public init(settlingDuration: Double, dampingRatio: Double, epsilon: Double = 0.001) {
        // The response whose settling time is the one asked for. The slower the spring, the longer it
        // takes to settle, so a bisection on the response finds it; where the answer of a spring that
        // does not oscillate is quantised, the midpoint of the range that shares it will do.
        var low = settlingDuration / 64, high = settlingDuration * 64
        for _ in 0..<80 {
            let middle = (low + high) / 2
            if Spring(response: middle, dampingRatio: dampingRatio).settling(target: 1, initialVelocity: 0, epsilon: epsilon) < settlingDuration {
                low = middle
            } else {
                high = middle
            }
        }
        self.init(response: (low + high) / 2, dampingRatio: dampingRatio)
    }

    public static func smooth(duration: Double = 0.5, extraBounce: Double = 0) -> Spring { Spring(duration: duration, bounce: extraBounce) }
    public static func snappy(duration: Double = 0.5, extraBounce: Double = 0) -> Spring { Spring(duration: duration, bounce: 0.15 + extraBounce) }
    public static func bouncy(duration: Double = 0.5, extraBounce: Double = 0) -> Spring { Spring(duration: duration, bounce: 0.3 + extraBounce) }
    public static var smooth: Spring { smooth() }
    public static var snappy: Spring { snappy() }
    public static var bouncy: Spring { bouncy() }

    // MARK: the numbers the system is described with

    public var response: Double {
        switch form {
        case .duration(let duration, _): return duration
        case .response(let response, _): return response
        case .system(let mass, let stiffness, _): return 2 * Double.pi * (mass / stiffness).squareRoot()
        }
    }
    public var duration: Double { response }
    /// How strongly the system is damped: 1 stops as fast as it can without passing the target.
    public var dampingRatio: Double {
        switch form {
        case .duration(_, let bounce):
            // Apple's own mapping of a bounce to a fraction, and the same one read backwards: none at
            // all below minus one, the reciprocal of one plus it while it is negative, one at rest, and
            // one minus it while it is positive.
            if bounce <= -1 { return .nan }
            if bounce < 0 { return 1 / (bounce + 1) }
            return 1 - min(bounce, 1)
        case .response(_, let ratio): return ratio
        case .system(let mass, let stiffness, let damping): return damping / (2 * (mass * stiffness).squareRoot())
        }
    }
    public var bounce: Double {
        let ratio = dampingRatio
        return ratio > 1 ? 1 / ratio - 1 : 1 - ratio
    }
    public var mass: Double {
        if case .system(let mass, _, _) = form { return mass }
        return 1
    }
    public var stiffness: Double {
        let ratio = dampingRatio
        guard ratio > 1 else {
            if case .system(_, let stiffness, _) = form { return stiffness }
            return frequency * frequency
        }
        // An over-damped system's stiffness is the one that keeps the ratio the spring was given.
        return frequency * frequency * (2 * ratio * ratio - 1)
    }
    public var damping: Double {
        switch form {
        case .system(_, _, let damping): return damping
        default: return 2 * frequency * dampingRatio
        }
    }

    // MARK: the shape of the motion, as a fraction of the distance

    // What is still to cover at a moment, for a spring that starts at zero with a given initial
    // velocity and would finish at one. The closed solution of the second-order system, which is what
    // Apple's own values follow to nine decimals.
    private func coefficients(_ w: Double, _ z: Double, _ v0: Double) -> (a: Double, b: Double, c: Double) {
        if z < 1 {
            let wd = w * (1 - z * z).squareRoot()
            return (z * w, wd, (v0 + z * w) / wd)
        }
        if z == 1 { return (w, 0, v0 + w) }
        let root = w * (z * z - 1).squareRoot()
        return (-z * w + root, -z * w - root, 0)
    }

    func remaining(initialVelocity: Double, time: Double) -> Double {
        if time <= 0 { return 1 }
        let w = frequency, z = dampingRatio
        guard w.isFinite else { return 0 }
        if z < 1 {
            let (a, b, c) = coefficients(w, z, initialVelocity)
            return exp(-a * time) * (cos(b * time) + c * sin(b * time))
        }
        if z == 1 { return exp(-w * time) * (1 + (initialVelocity + w) * time) }
        let (fast, slow, _) = coefficients(w, z, initialVelocity)
        let second = (initialVelocity - fast) / (slow - fast)
        return (1 - second) * exp(fast * time) + second * exp(slow * time)
    }

    // The same solution's slope: how fast the distance still to cover is shrinking.
    private func remainingSlope(initialVelocity: Double, time: Double) -> Double {
        if time <= 0 { return 0 }
        let w = frequency, z = dampingRatio
        guard w.isFinite else { return 0 }
        if z < 1 {
            let (a, b, c) = coefficients(w, z, initialVelocity)
            return exp(-a * time) * ((-a + b * c) * cos(b * time) + (-a * c - b) * sin(b * time))
        }
        if z == 1 {
            let slope = initialVelocity + w
            return exp(-w * time) * (slope - w * (1 + slope * time))
        }
        let (fast, slow, _) = coefficients(w, z, initialVelocity)
        let second = (initialVelocity - fast) / (slow - fast)
        return (1 - second) * fast * exp(fast * time) + second * slow * exp(slow * time)
    }

    // MARK: where the system is

    public func value<V: VectorArithmetic>(target: V, initialVelocity: V = .zero, time: Double) -> V {
        V.zero + target.scaled(by: 1 - remaining(initialVelocity: share(initialVelocity, of: target), time: time))
    }

    public func velocity<V: VectorArithmetic>(target: V, initialVelocity: V = .zero, time: Double) -> V {
        target.scaled(by: 0 - remainingSlope(initialVelocity: share(initialVelocity, of: target), time: time))
    }

    public func force<V: VectorArithmetic>(target: V, position: V, velocity: V) -> V {
        (target - position).scaled(by: stiffness)
    }

    public func value<V: Animatable>(fromValue: V, toValue: V, initialVelocity: V, time: Double) -> V {
        var result = fromValue
        let travel = toValue.animatableData - fromValue.animatableData
        result.animatableData = fromValue.animatableData + travel.scaled(by: 1 - remaining(initialVelocity: share(initialVelocity.animatableData, of: travel), time: time))
        return result
    }

    public func velocity<V: Animatable>(fromValue: V, toValue: V, initialVelocity: V, time: Double) -> V {
        var result = toValue
        let travel = toValue.animatableData - fromValue.animatableData
        result.animatableData = travel.scaled(by: 0 - remainingSlope(initialVelocity: share(initialVelocity.animatableData, of: travel), time: time))
        return result
    }

    public func force<V: Animatable>(fromValue: V, toValue: V, position: V, velocity: V) -> V {
        var result = position
        result.animatableData = (toValue.animatableData - position.animatableData).scaled(by: stiffness)
        return result
    }

    /// One step of the system, exactly: where a spring that has to cover `target - value` in
    /// `deltaTime` seconds is afterwards, which is what a frame-driven animator asks for.
    public func update<V: VectorArithmetic>(value: inout V, velocity: inout V, target: V, deltaTime: Double) {
        let travel = target - value
        let start = share(velocity, of: travel)
        value += travel.scaled(by: 1 - remaining(initialVelocity: start, time: deltaTime))
        velocity = travel.scaled(by: 0 - remainingSlope(initialVelocity: start, time: deltaTime))
    }

    // MARK: when it is over

    public func settlingDuration<V: VectorArithmetic>(target: V, initialVelocity: V = .zero, epsilon: Double) -> Double {
        settling(target: magnitude(of: target), initialVelocity: share(initialVelocity, of: target), epsilon: epsilon)
    }

    public func settlingDuration<V: Animatable>(fromValue: V, toValue: V, initialVelocity: V, epsilon: Double) -> Double {
        let travel = toValue.animatableData - fromValue.animatableData
        return settling(target: magnitude(of: travel), initialVelocity: share(initialVelocity.animatableData, of: travel), epsilon: epsilon)
    }

    public var settlingDuration: Double { settling(target: 1, initialVelocity: 0, epsilon: 0.001) }

    // The time after which the spring stays within `epsilon` of the target: the last moment it is still
    // outside it. A spring that does not oscillate crosses once, and Apple's own answer for that is the
    // crossing rounded up to the next tenth of a second (measured over sweeps of the response, the
    // epsilon, the target and the damping, .agent-work/runs/settling.txt); one that oscillates is read
    // off its last swing.
    private func settling(target: Double, initialVelocity: Double, epsilon: Double) -> Double {
        let z = dampingRatio
        guard epsilon > 0, !z.isNaN, mass > 0, stiffness > 0 else { return 0 }
        let slowest = z < 1 ? z * frequency : frequency * (z - (z * z - 1).squareRoot())
        guard slowest > 0 else { return .infinity }
        let scale = max(1, target + abs(initialVelocity)) / epsilon
        let horizon = log(scale) / slowest + 8 * response
        let stepSize = min(response / 256, horizon / 2048)
        var outside = 0.0
        var t = 0.0
        while t < horizon {
            if abs(remaining(initialVelocity: initialVelocity, time: t)) * max(target, 1) > epsilon { outside = t }
            t += stepSize
        }
        guard outside > 0 else { return 0 }
        var low = outside, high = min(outside + stepSize, horizon)
        for _ in 0..<60 {
            let middle = (low + high) / 2
            if abs(remaining(initialVelocity: initialVelocity, time: middle)) * max(target, 1) > epsilon { low = middle } else { high = middle }
        }
        return z >= 1 ? (high * 10).rounded(.up) / 10 : high
    }

    // MARK: the arithmetic of a vector

    private func magnitude<A: VectorArithmetic>(of value: A) -> Double { value.magnitudeSquared.squareRoot() }
    private func share<A: VectorArithmetic>(_ velocity: A, of travel: A) -> Double {
        let length = magnitude(of: travel)
        return length > 0 ? magnitude(of: velocity) / length : 0
    }
}

extension VectorArithmetic {
    /// The vector scaled, leaving the one it is asked of alone.
    func scaled(by share: Double) -> Self {
        var copy = self
        copy.scale(by: share)
        return copy
    }
}
