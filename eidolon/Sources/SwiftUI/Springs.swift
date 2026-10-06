import CoreGraphics

// A damped harmonic oscillator: the spring SwiftUI's newer animations are built on. It is kept the way
// it was built, because that is what decides what the other numbers read back: a spring made of a
// duration and a bounce or of a response and a ratio reports the stiffness and the damping its own pair
// implies - an over-damped one carries the factor that keeps the ratio - while a spring made of a mass, a
// stiffness and a damping reports those three as they were given. Every one of the numbers below is what
// Apple's own framework answers for the same spring (.agent-work/host/*.out hold the measurements).
public struct Spring: Hashable {
    enum Form: Hashable {
        case duration(Double, Double)
        case response(Double, Double)
        case system(Double, Double, Double)
    }
    var form: Form

    // Two springs are equal when Apple's would be: Apple's stores a spring as its damped frequency, its decay
    // constant and its mass, so the spring of a response and a ratio is the spring of a duration and the bounce
    // that makes the same ratio, whatever pair they were given as. The numbers are the ones Apple stores, to the
    // last bit (checked over sweeps of every form, `host/springcmp.swift`); an over-damped spring's frequency is
    // the negative root, a critical one's is zero.
    private var identity: (damped: Double, decay: Double, mass: Double) {
        func root(_ square: Double) -> Double { square >= 0 ? square.squareRoot() : -(-square).squareRoot() }
        if case .system(let mass, let stiffness, let damping) = form {
            let decay = damping / (2 * mass)
            return (root(stiffness / mass - decay * decay), decay, mass)
        }
        let ratio = dampingRatio
        return (2 * Double.pi * root(1 - ratio * ratio) / response, 2 * Double.pi * ratio / response, 1)
    }

    /// The spring `Animation.spring(_:)` keeps of a spring it is given: Apple's animation holds a response and a
    /// damping fraction, and takes them back out of the spring's stored numbers, so they differ in the last bit from
    /// the pair the spring was made of. The response is 2 pi over the root of the damped frequency's signed square
    /// and the decay's, the ratio the decay times that response over 2 pi, and the fraction is one less the bounce
    /// of that ratio (the bounce of an over-damped one is negative, and its fraction the reciprocal of one more);
    /// all three to the last bit of Apple's (`host/springcmp.swift`).
    var asFluid: Spring {
        let (damped, decay, _) = identity
        let response = 2 * Double.pi / ((damped >= 0 ? damped * damped : -(damped * damped)) + decay * decay).squareRoot()
        let ratio = decay * response / (2 * Double.pi)
        let bounce = ratio <= 1 ? 1 - ratio : 1 / ratio - 1
        return Spring(response: response, dampingRatio: bounce >= 0 ? 1 - bounce : 1 / (bounce + 1))
    }

    /// The numbers an animation of this spring is compared by: the ones the spring reads back as, whole, where two
    /// springs are equal by the three they are stored as.
    var heldNumbers: [Double] { [response, dampingRatio, mass, stiffness, damping] }

    public static func == (lhs: Spring, rhs: Spring) -> Bool {
        let (left, right) = (lhs.identity, rhs.identity)
        return left.damped == right.damped && left.decay == right.decay && left.mass == right.mass
    }

    public func hash(into hasher: inout Hasher) {
        let key = identity
        hasher.combine(key.damped)
        hasher.combine(key.decay)
        hasher.combine(key.mass)
    }

    /// The undamped angular frequency, `2 pi / response`.
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

    // The response of a spring that settles in a time, by Apple's own reckoning, which is not the property's: the time is held to
    // between a hundredth of a second and ten, one that oscillates settles when its swing is `damping ratio / root(1 - ratio^2)`
    // times `e^(-decay t)` under epsilon, and one that does not (a ratio of one or over, which is taken as one) when the critical
    // spring is, `(1 + w t) e^(-w t)`; a ratio of nothing, or of a number that is not one, or too small for the epsilon, has no
    // response (as a ratio one or over is held as one). Apple's solves it by iteration to a tolerance of its own, so its answers are within a few hundred-thousandths of these.
    public init(settlingDuration: Double, dampingRatio: Double, epsilon: Double = 0.001) {
        let time = settlingDuration.isNaN ? 0.01 : min(max(settlingDuration, 0.01), 10)
        if dampingRatio >= 1 {
            // the root of ln(1 + x) - x = ln(epsilon), by Newton's method from above it
            var x = 1 - log(epsilon)
            for _ in 0..<64 {
                let next = x - (log(1 + x) - x - log(epsilon)) / (1 / (1 + x) - 1)
                if next == x { break }
                x = next
            }
            self.init(response: 2 * Double.pi * time / x, dampingRatio: 1)
            return
        }
        let decay = log(dampingRatio / ((1 - dampingRatio * dampingRatio).squareRoot() * epsilon)) / time
        guard dampingRatio > 0, decay > 0 else {
            self.init(response: .nan, dampingRatio: .nan)
            return
        }
        self.init(response: 2 * Double.pi * dampingRatio / decay, dampingRatio: dampingRatio)
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

    // The distance still to cover, for a spring that has `r` of it to go and a speed `v` toward the target, is
    // `r * a(t) - v * b(t)`: `a` is what is left of a unit distance that starts at rest, `b` what is left of a
    // distance of nothing that starts with a unit of speed toward the target (the target is reached by moving
    // against the distance, so the speed enters with a minus). Both solve the second-order system exactly, and
    // `da` and `db` are their slopes. Every component of a vector is a spring of its own, and a speed that is
    // not along the way to the target still moves the component it is in.
    private func unit(time: Double) -> (a: Double, da: Double, b: Double, db: Double) {
        if time <= 0 { return (1, 0, 0, 1) }
        let w = frequency, z = dampingRatio
        guard w.isFinite else { return (0, 0, 0, 0) }
        if z < 1 {
            let decay = z * w
            let wd = w * (1 - z * z).squareRoot()
            let e = exp(-decay * time), c = cos(wd * time), n = sin(wd * time)
            return (e * (c + decay / wd * n), -e * n * w * w / wd, e * n / wd, e * (c - decay / wd * n))
        }
        if z == 1 {
            let e = exp(-w * time)
            return (e * (1 + w * time), -e * w * w * time, time * e, e * (1 - w * time))
        }
        let root = w * (z * z - 1).squareRoot()
        let slow = -z * w + root, fast = -z * w - root
        let es = exp(slow * time), ef = exp(fast * time)
        let gap = slow - fast
        // Apple's over-damped slope is its own derivative plus the unit distance, so a speed read from a spring that
        // does not oscillate is one more than the curve's slope for every unit of distance (measured against
        // SwiftUI.Spring on macOS: velocity, update and the Animatable form all carry it, the value does not).
        return ((slow * ef - fast * es) / gap, slow * fast * (ef - es) / gap - 1, (es - ef) / gap, (slow * es - fast * ef) / gap)
    }

    // The same for a distance of one and a speed that is a share of it: what an animation of a single value follows.
    func remaining(initialVelocity: Double, time: Double) -> Double {
        let u = unit(time: time)
        return u.a - initialVelocity * u.b
    }

    // MARK: where the system is

    public func value<V: VectorArithmetic>(target: V, initialVelocity: V = .zero, time: Double) -> V {
        let u = unit(time: time)
        return V.zero + target.scaled(by: 1 - u.a) + initialVelocity.scaled(by: u.b)
    }

    public func velocity<V: VectorArithmetic>(target: V, initialVelocity: V = .zero, time: Double) -> V {
        let u = unit(time: time)
        return target.scaled(by: 0 - u.da) + initialVelocity.scaled(by: u.db)
    }

    public func force<V: VectorArithmetic>(target: V, position: V, velocity: V) -> V {
        (target - position).scaled(by: stiffness)
    }

    public func value<V: Animatable>(fromValue: V, toValue: V, initialVelocity: V, time: Double) -> V {
        var result = fromValue
        let travel = toValue.animatableData - fromValue.animatableData
        let u = unit(time: time)
        result.animatableData = fromValue.animatableData + travel.scaled(by: 1 - u.a) + initialVelocity.animatableData.scaled(by: u.b)
        return result
    }

    public func velocity<V: Animatable>(fromValue: V, toValue: V, initialVelocity: V, time: Double) -> V {
        var result = toValue
        let travel = toValue.animatableData - fromValue.animatableData
        let u = unit(time: time)
        result.animatableData = travel.scaled(by: 0 - u.da) + initialVelocity.animatableData.scaled(by: u.db)
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
        let u = unit(time: deltaTime)
        let moved = travel.scaled(by: 1 - u.a) + velocity.scaled(by: u.b)
        let speed = travel.scaled(by: 0 - u.da) + velocity.scaled(by: u.db)
        value += moved
        velocity = speed
    }

    // MARK: when it is over

    public func settlingDuration<V: VectorArithmetic>(target: V, initialVelocity: V = .zero, epsilon: Double) -> Double {
        settling(travel: target, velocity: initialVelocity, epsilon: epsilon)
    }

    public func settlingDuration<V: Animatable>(fromValue: V, toValue: V, initialVelocity: V, epsilon: Double) -> Double {
        let travel = toValue.animatableData - fromValue.animatableData
        return settling(travel: travel, velocity: initialVelocity.animatableData, epsilon: epsilon)
    }

    public var settlingDuration: Double { settling(travel: 1.0, velocity: 0.0, epsilon: 0.001) }

    // Apple's own rule, the same for every way a spring is given (`host/springcmp.swift` compares it over sweeps of the response, the
    // ratio, the distance, the speed and the epsilon). One that oscillates is settled when the envelope of its swing, the distance
    // plus what the speed adds to the decay of it, `(|d| + |decay d - v|) e^(-decay t)`, is under epsilon: the logarithm of that over
    // epsilon, over the decay, and no less than nothing; one that is not damped never is. One that does not oscillate is settled a
    // tenth of a second after the last of the tenths of a second (counted by adding them up) at which it is epsilon or more away
    // from the target where it has got to, so that a distance too small for the number it is made of to show is none.
    private func settling<A: VectorArithmetic>(travel: A, velocity: A, epsilon: Double) -> Double {
        let z = dampingRatio
        guard !z.isNaN, response > 0 else { return 0 }
        func length(_ value: A) -> Double { value.magnitudeSquared.squareRoot() }
        if z < 1 {
            let decay = z * frequency
            if decay == 0 { return .infinity }
            let time = log((length(travel) + length(travel.scaled(by: decay) - velocity)) / epsilon) / decay
            return time.isNaN ? 0 : max(time, 0)
        }
        guard epsilon > 0 else { return 0 }
        let slowest = z == 1 ? frequency : frequency * (z - (z * z - 1).squareRoot())
        guard slowest > 0 else { return .infinity }
        var time = 0.0, settled = 0.0
        for _ in 0...Spring.scanned {
            let u = unit(time: time)
            let out = length(travel - (A.zero + travel.scaled(by: 1 - u.a) + velocity.scaled(by: u.b))) >= epsilon
            time += 0.1
            if out { settled = time }
        }
        return settled == time ? 0 : settled
    }
    /// Apple looks at the first 1013 of the tenths of a second, the last of them at 101.2 s, and answers nothing (settled at once) when
    /// that last one is still out: `host/springcmp.swift` bisects the response at which it starts to, for the ratios 1 and 2 and
    /// four sets of distance, epsilon and speed, and finds the answer 101.2 s on one side of it and none on the other every time.
    private static let scanned = 1012

}

extension VectorArithmetic {
    /// The vector scaled, leaving the one it is asked of alone.
    func scaled(by share: Double) -> Self {
        var copy = self
        copy.scale(by: share)
        return copy
    }
}

/// Where an animation stands in time once `.speed`, `.delay` and `.logicallyComplete` have been applied to it, in the order
/// they were: the animation is `rate * (t - delay)` seconds into its own time `t` seconds after it was asked to begin, so a
/// speed of two halves the delay before it as well as the animation after it, and a delay after a speed is not scaled by
/// it (`host/springcmp.swift` asks Apple's for every order of two and three of them). Each of the two moves the moment of
/// logical completion, which is given in the time of the animation as it was when it was set. An animation that is not
/// moving in time (a speed of nothing or less) stays at its start and is never over.
struct Retiming: Hashable {
    var rate = 1.0
    var delay = 0.0
    var logicalEnd: Double?

    func speeding(by speed: Double) -> Retiming {
        var next = self
        next.rate *= speed
        if speed > 0 { next.delay /= speed; next.logicalEnd = logicalEnd.map { $0 / speed } }
        return next
    }

    func delaying(by seconds: Double) -> Retiming {
        var next = self
        next.delay += seconds
        next.logicalEnd = logicalEnd.map { $0 + seconds }
        return next
    }

    func completing(after seconds: Double) -> Retiming {
        var next = self
        next.logicalEnd = seconds
        return next
    }

    /// The moment the animation is logically complete, in seconds after it was asked to begin: the one it was given, or the end of its
    /// own time of a number of seconds (a spring's response) as it was played.
    func logicalMoment(naturally seconds: Double) -> Double { logicalEnd ?? delay + outer(seconds) }

    /// The seconds of its own time an animation has been through, a number of seconds after it was asked to begin.
    func inner(at elapsed: Double) -> Double { rate > 0 ? rate * (elapsed - delay) : 0 }

    /// The seconds after its delay in which a number of seconds of its own time pass.
    func outer(_ inner: Double) -> Double { rate > 0 ? inner / rate : .infinity }
}

/// How a spring animation goes in the seconds after its delay: how far it has come, as a fraction of the distance, and whether it
/// has ended, at the time of the animation as it was retimed. When it ends is not told ahead: a spring that does not rest (or one
/// that rests after eleven hours, which Apple's animates as long) is never asked for the end of, only whether it is over by a
/// moment that has come.
struct SpringCourse {
    /// The seconds a pass takes, if it is over by this many seconds after the delay.
    let ended: (Double) -> Double?
    let at: (Double) -> Double

    init(fluid spring: Spring, distance: Double, retiming: Retiming) {
        let track = FluidTrack(spring, distance: distance)
        ended = { retiming.rate > 0 ? track.end(by: retiming.rate * $0).map { $0 / retiming.rate } : nil }
        at = { track.progress(at: retiming.rate > 0 ? $0 * retiming.rate : 0) }
    }

    init(interpolating held: InterpolatingSpring, retiming: Retiming) {
        ended = SpringCourse.over(after: retiming.outer(held.settlingTime))
        at = { held.progress(at: retiming.rate > 0 ? $0 * retiming.rate : 0) }
    }

    /// What `ended` is of a pass that takes a known number of seconds, infinite for one that never ends.
    static func over(after length: Double) -> (Double) -> Double? { { length <= $0 ? length : nil } }
}

/// Where Apple's fluid spring animation (`Animation.spring`, `smooth`, `snappy`, `bouncy`, `interactiveSpring`) is, as a
/// fraction of the distance. It does not solve its spring: it steps it, a three-hundredth of a second at a time, with
/// the semi-implicit Euler step, and answers for every moment of a step the position the step began with, so the curve is a
/// staircase that differs from the exact solution by up to a fiftieth of the distance (`host/springcmp.swift` compares it with
/// Apple's, to the last digits). It is over at the first step whose state is close to the target and at rest, by
/// three tests the distance enters into, since two of them are in distance units and not in fractions: the distance left is
/// under a hundredth of it, and the acceleration and the mean of the speeds either side of the step are each under 0.06.
/// A frequency above the one at which a step carries the position half way is taken as that one, so a response under 0.0296 s
/// moves as 0.0296 s does; a spring that runs away, or has no number to run by, ends where its position stops being a number.
/// Every component of a vector is that unit solution times its own distance. There is no horizon after which it gives up: a
/// spring with a damping ratio of a hundred-thousandth rests after eleven hours and forty-eight minutes of the animation's time
/// in Apple's, and one that is not damped never does (`.agent-work/runs/54-hor/a.swift` asks Apple's at ratios of a
/// thousandth, ten-thousandth and hundred-thousandth for the step it answers nothing at: 127599, 1275690 and 12751650, the
/// steps this finds), so the steps are taken as they are asked for and the end is looked for only as far as they have gone.
final class FluidTrack {
    static let step = 1.0 / 300
    private static let highestFrequency = 0.5.squareRoot() / step

    private let stiffness: Double
    private let damping: Double
    private let size: Double
    private var positions = [0.0]
    private var speeds = [0.0]
    /// The first step not yet known to be one that does not end, and the one that does, once there is one.
    private var tested = 0
    private var ended: Int?

    init(_ spring: Spring, distance: Double) {
        let response = spring.response
        let frequency = response > 0 ? min(2 * Double.pi / response, FluidTrack.highestFrequency) : (response <= 0 ? FluidTrack.highestFrequency : .nan)
        stiffness = frequency * frequency
        damping = 2 * spring.dampingRatio * frequency
        size = abs(distance)
    }

    private func reach(_ index: Int) {
        while positions.count <= index {
            let speed = speeds[speeds.count - 1] + FluidTrack.step * (stiffness * (1 - positions[positions.count - 1]) - damping * speeds[speeds.count - 1])
            speeds.append(speed)
            positions.append(positions[positions.count - 1] + FluidTrack.step * speed)
        }
    }

    /// The fraction of the distance covered `time` seconds in, where the animation has not ended.
    func progress(at time: Double) -> Double {
        guard time > 0 else { return 0 }
        let index = Int((time / FluidTrack.step).rounded(.up)) - 1
        reach(index)
        return positions[index]
    }

    /// The seconds after which Apple's answers nothing more for the distance to cover, if that is no later than `time` seconds in.
    func end(by time: Double) -> Double? {
        if let n = ended { return Double(n) * FluidTrack.step <= time ? Double(n) * FluidTrack.step : nil }
        while Double(tested) * FluidTrack.step <= time {
            let n = tested
            reach(n + 1)
            let left = 1 - positions[n]
            let acceleration = stiffness * left - damping * speeds[n]
            if positions[n].isNaN || abs(left) < 0.01 && abs(acceleration) * size < 0.06 && abs(speeds[n] + speeds[n + 1]) / 2 * size < 0.06 {
                ended = n
                return Double(n) * FluidTrack.step
            }
            tested += 1
        }
        return nil
    }
}

/// What Apple's interpolating spring holds: a mass, a stiffness and a damping, exactly as they were given or as the
/// spring it was made of reads them back, and the speed it starts with, in distances per second. It is not the animation
/// of a response and a fraction, so it is never equal to one. Damping past the critical is held as given and solved as
/// critical, as Apple's solves it (`host/springcmp.swift` compares the held numbers and the solved values).
struct InterpolatingSpring: Hashable {
    var mass: Double
    var stiffness: Double
    var damping: Double
    var initialVelocity: Double

    init(mass: Double, stiffness: Double, damping: Double, initialVelocity: Double = 0) {
        self.mass = mass
        self.stiffness = stiffness
        self.damping = damping
        self.initialVelocity = initialVelocity
    }

    /// The spring an interpolating spring is made of: its mass is one, and its stiffness and damping are those of the
    /// response and fraction the spring comes back out as (`asFluid`), not the spring's own stiffness and damping, which
    /// differ in the last bits and, for an over-damped or a heavy one, in much more.
    init(_ spring: Spring, initialVelocity: Double = 0) {
        let fluid = spring.asFluid
        self.init(response: fluid.response, fraction: fluid.dampingRatio, initialVelocity: initialVelocity)
    }

    /// One made of a duration and a bounce holds the duration and the fraction of the bounce as they are.
    init(duration: Double, bounce: Double, initialVelocity: Double = 0) {
        self.init(response: duration, fraction: Spring(duration: duration, bounce: bounce).dampingRatio, initialVelocity: initialVelocity)
    }

    private init(response: Double, fraction: Double, initialVelocity: Double) {
        let frequency = 2 * Double.pi / response
        self.init(mass: 1, stiffness: frequency * frequency, damping: 2 * frequency * fraction, initialVelocity: initialVelocity)
    }

    /// The damping it is solved with: no more than the critical one, which is also what a damping that is not a number comes to.
    private var solvedDamping: Double {
        let critical = 2 * (mass * stiffness).squareRoot()
        return damping.isNaN ? critical : min(damping, critical)
    }

    var spring: Spring { Spring(mass: mass, stiffness: stiffness, damping: solvedDamping) }

    /// How far it has come, as a fraction of the distance, a number of seconds after it began. The speed it starts with is a
    /// multiple of the distance, so it is the fraction's own speed toward the target.
    func progress(at time: Double) -> Double {
        1 - spring.remaining(initialVelocity: initialVelocity, time: time)
    }

    /// The moment after which Apple's answers nothing more, as Core Animation's settling duration of the same spring
    /// (`host/springcmp.swift` asks Apple's for every one, and Core Animation for a few thousand more in `.agent-work/runs/33-end`):
    /// it does not depend on the distance. A spring that oscillates is over when the envelope of its swing is a thousandth of the
    /// distance, from the speed it starts with included; one that is critical or past it (clamped to critical), when the first of
    /// the tenths of a second is reached at which the critical solution is a thousandth of it, over at once if none of the first
    /// 1012 of them is (`horizon`). A spring with no damping never
    /// rests, and one with no mass, no stiffness, a negative damping or a number that is not one is over before it starts (a damping
    /// that is not a number is the critical one).
    var settlingTime: Double {
        guard mass > 0, mass.isFinite, stiffness > 0, stiffness.isFinite, initialVelocity.isFinite else { return 0 }
        let damping = solvedDamping
        guard damping >= 0 else { return 0 }
        guard damping > 0 else { return .infinity }
        if damping < 2 * (mass * stiffness).squareRoot() {
            let decay = damping / (2 * mass)
            let damped = (stiffness / mass - decay * decay).squareRoot()
            return log(1000 * (1 + abs(decay - initialVelocity) / damped)) / decay
        }
        let omega = (stiffness / mass).squareRoot()
        var time = 0.0
        for _ in 0..<InterpolatingSpring.horizon {
            time += 0.1
            if abs((1 + (omega - initialVelocity) * time) * exp(-omega * time)) < 0.001 { return time }
        }
        return 0
    }
    /// Core Animation counts 1012 of the tenths of a second, to 101.2 s, and a critical spring none of which is inside a thousandth is
    /// over at once: `host/springcmp.swift` bisects the stiffness at which Apple's starts to, and finds the first tenth inside at
    /// 101.2 s on the side it answers and at 101.3 s or later on the side it does not, for masses a half, one and two.
    private static let horizon = 1012
}
