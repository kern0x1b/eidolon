// springcmp.swift: the port's Spring against Apple's SwiftUI.Spring, number by number, on the host. The port's
// Springs.swift is compiled beside this file (it names no type of its own module but Apple's Animatable and
// VectorArithmetic, so the host's SwiftUI is imported in front of it); `Spring` is then the port's and
// `SwiftUI.Spring` is Apple's. It prints every number that differs by more than 1e-9 and the worst difference.
//   d=$(mktemp -d); (echo "import SwiftUI"; cat ../Sources/SwiftUI/Springs.swift) > $d/Springs.swift
//   cp springcmp.swift $d/main.swift && swiftc -O $d/main.swift $d/Springs.swift -o $d/springcmp && $d/springcmp
import SwiftUI
typealias Mine = Spring
typealias Apple = SwiftUI.Spring
var worst = 0.0
var count = 0
func note(_ what: String, _ mine: Double, _ apple: Double) {
    count += 1
    let d = abs(mine - apple)
    if d > worst { worst = d }
    if d > 1e-9 { print("DIFF", what, mine, apple) }
}
let forms: [(Double, Double)] = [(0.5, 0), (0.5, 0.3), (1, -0.2), (0.3, 0.9), (2, -0.7), (0.15, 0.15)]
for (duration, bounce) in forms {
    let m = Mine(duration: duration, bounce: bounce), a = Apple(duration: duration, bounce: bounce)
    for v0 in [0.0, 2.0, -3.0, 17.5] {
        for t in [0.0, 0.01, 0.1, 0.5, 1.3] {
            note("value \(duration) \(bounce) v0=\(v0) t=\(t)", m.value(target: 1.0, initialVelocity: v0, time: t), a.value(target: 1.0, initialVelocity: v0, time: t))
            note("velocity \(duration) \(bounce) v0=\(v0) t=\(t)", m.velocity(target: 1.0, initialVelocity: v0, time: t), a.velocity(target: 1.0, initialVelocity: v0, time: t))
            let tm = AnimatablePair(2.5, -1.5), vm = AnimatablePair(v0, 1 - v0)
            let rm = m.value(target: tm, initialVelocity: vm, time: t), ra = a.value(target: tm, initialVelocity: vm, time: t)
            note("pair.first", rm.first, ra.first); note("pair.second", rm.second, ra.second)
            let fm = m.velocity(fromValue: CGPoint(x: 0.2, y: 1), toValue: CGPoint(x: 1, y: 0), initialVelocity: CGPoint(x: v0, y: 1), time: t), fa = a.velocity(fromValue: CGPoint(x: 0.2, y: 1), toValue: CGPoint(x: 1, y: 0), initialVelocity: CGPoint(x: v0, y: 1), time: t)
            note("fromTo.x", Double(fm.x), Double(fa.x)); note("fromTo.y", Double(fm.y), Double(fa.y))
            let qm = m.velocity(target: tm, initialVelocity: vm, time: t), qa = a.velocity(target: tm, initialVelocity: vm, time: t)
            note("pairvel.first", qm.first, qa.first); note("pairvel.second", qm.second, qa.second)
        }
    }
    for (v, s) in [(0.0, 0.0), (0.25, 1.5), (0.25, -1.5), (1.4, 3.0)] {
        for dt in [1.0 / 60, 0.1, 0.4] {
            var vm = v, sm = s, va = v, sa = s
            m.update(value: &vm, velocity: &sm, target: 1, deltaTime: dt)
            a.update(value: &va, velocity: &sa, target: 1, deltaTime: dt)
            note("update value", vm, va); note("update velocity", sm, sa)
        }
    }
    var vm = 0.0, sm = 0.0, va = 0.0, sa = 0.0
    for _ in 0..<6 { m.update(value: &vm, velocity: &sm, target: 1, deltaTime: 1.0 / 60); a.update(value: &va, velocity: &sa, target: 1, deltaTime: 1.0 / 60) }
    note("six frames value", vm, va); note("six frames velocity", sm, sa)
}
// which springs are equal: Apple's compares what it stores (the damped frequency, the decay and the mass), so
// the spring of a response and a ratio is the spring of a duration and the bounce that is one minus it
var pairs = 0
func same(_ what: String, _ mine: Bool, _ apple: Bool) {
    pairs += 1
    if mine != apple { print("DIFF equal", what, "mine", mine, "apple", apple) }
}
for r in [0.1, 0.15, 0.25, 0.3, 0.5, 0.75, 1, 1.5, 2, 3] {
    for z in [0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.7, 0.75, 0.8, 0.825, 0.85, 0.9, 0.95, 1.0] {
        same("response \(r) ratio \(z) / duration bounce", Mine(response: r, dampingRatio: z) == Mine(duration: r, bounce: 1 - z),
             Apple(response: r, dampingRatio: z) == Apple(duration: r, bounce: 1 - z))
        same("hash response \(r) ratio \(z) / duration bounce", Mine(response: r, dampingRatio: z).hashValue == Mine(duration: r, bounce: 1 - z).hashValue,
             Apple(response: r, dampingRatio: z).hashValue == Apple(duration: r, bounce: 1 - z).hashValue)
    }
    for b in [-0.9, -0.7, -0.5, -0.3, -0.2, -0.1] {
        same("over-damped \(r) bounce \(b)", Mine(response: r, dampingRatio: 1 / (1 + b)) == Mine(duration: r, bounce: b),
             Apple(response: r, dampingRatio: 1 / (1 + b)) == Apple(duration: r, bounce: b))
    }
    same("another response", Mine(duration: r, bounce: 0.2) == Mine(duration: r * 1.01, bounce: 0.2), Apple(duration: r, bounce: 0.2) == Apple(duration: r * 1.01, bounce: 0.2))
}
for m in [0.5, 1.0, 2.0, 3.3] {
    for k in [10.0, 50, 100, 157.91367041742973, 400] {
        for c in [1.0, 5, 10, 25.132741228718345, 40, 100, 200] {
            let mine = Mine(mass: m, stiffness: k, damping: c, allowOverDamping: true), apple = Apple(mass: m, stiffness: k, damping: c, allowOverDamping: true)
            same("system \(m) \(k) \(c) with itself", mine == Mine(mass: m, stiffness: k, damping: c, allowOverDamping: true), apple == Apple(mass: m, stiffness: k, damping: c, allowOverDamping: true))
            same("system \(m) \(k) \(c) with a response spring", mine == Mine(response: 2 * Double.pi * (m / k).squareRoot(), dampingRatio: c / (2 * (m * k).squareRoot())),
                 apple == Apple(response: 2 * Double.pi * (m / k).squareRoot(), dampingRatio: c / (2 * (m * k).squareRoot())))
            same("system \(m) \(k) \(c) with the same at twice the mass", mine == Mine(mass: 2 * m, stiffness: 2 * k, damping: 2 * c, allowOverDamping: true),
                 apple == Apple(mass: 2 * m, stiffness: 2 * k, damping: 2 * c, allowOverDamping: true))
        }
    }
}
same("critical system and a duration", Mine(mass: 1, stiffness: 157.91367041742973, damping: 25.132741228718345) == Mine(duration: 0.5, bounce: 0),
     Apple(mass: 1, stiffness: 157.91367041742973, damping: 25.132741228718345) == Apple(duration: 0.5, bounce: 0))
print("compared", pairs, "pairs of springs for equality")

// Animation.spring(_:) of a spring against the animation of a pair of numbers, and against the animation of another spring:
// Apple's animation holds a response and a fraction taken back out of the spring, the port's holds `asFluid` and
// compares by `heldNumbers`
var made: [(Mine, Apple)] = []
let grid = [0.1, 0.15, 0.25, 0.3, 0.5, 0.75, 1, 1.5, 2, 3], ratios = [0.1, 0.2, 0.3, 0.5, 0.7, 0.825, 0.85, 0.9, 1.0, 1.25, 1.5, 2]
for r in grid { for z in ratios { made.append((Mine(response: r, dampingRatio: z), Apple(response: r, dampingRatio: z))) } }
for r in [0.15, 0.5, 1] { for b in [-0.7, -0.2, 0, 0.15, 0.3, 0.9] { made.append((Mine(duration: r, bounce: b), Apple(duration: r, bounce: b))) } }
for m in [0.5, 1.0, 2.0] { for k in [10.0, 100, 400] { for c in [1.0, 10, 40, 100] { made.append((Mine(mass: m, stiffness: k, damping: c, allowOverDamping: true), Apple(mass: m, stiffness: k, damping: c, allowOverDamping: true))) } } }
var animations = 0
for (mine, apple) in made {
    for r in grid { for z in ratios {
        animations += 1
        let direct = Mine(response: r, dampingRatio: z)
        same("animation of a spring and of response \(r) fraction \(z)", mine.asFluid.heldNumbers == direct.heldNumbers, Animation.spring(apple) == Animation.spring(response: r, dampingFraction: z))
    } }
}
for (mine, apple) in made {
    for (other, otherApple) in made.prefix(150) {
        animations += 1
        same("animation of a spring and of another spring", mine.asFluid.heldNumbers == other.asFluid.heldNumbers, Animation.spring(apple) == Animation.spring(otherApple))
    }
}
print("compared", animations, "pairs of animations for equality")

// Animation.interpolatingSpring: Apple's is a SpringAnimation holding a mass, a stiffness and a damping (the numbers of the
// spring it was made of read back, or the ones it was given), not the fluid animation of a response and a fraction. The held
// numbers are read out of it by reflection; its values are asked of it through an AnimationContext, which has no public
// initializer, so one is put together in memory from an AnimationState and EnvironmentValues (a 26-byte struct: the state at
// 0, the environment at 8, two flags after them). The port's own types are InterpolatingSpring, Springs.swift.
func makeContext<V: VectorArithmetic>(_: V.Type = Double.self) -> AnimationContext<V> {
    let memory = UnsafeMutableRawPointer.allocate(byteCount: 32, alignment: 8)
    memory.initializeMemory(as: UInt8.self, repeating: 0, count: 32)
    memory.storeBytes(of: AnimationState<V>(), toByteOffset: 0, as: AnimationState<V>.self)
    memory.storeBytes(of: EnvironmentValues(), toByteOffset: 8, as: EnvironmentValues.self)
    return memory.load(as: AnimationContext<V>.self)
}
func heldBy(_ animation: Animation) -> [Double]? {
    let fields = Mirror(reflecting: Mirror(reflecting: animation).children.first!.value).children
    guard fields.contains(where: { $0.label == "stiffness" }) else { return nil }
    let speed = Mirror(reflecting: fields.first { $0.label == "initialVelocity" }!.value).children.first!.value as! Double
    return ["mass", "stiffness", "damping"].map { name in fields.first { $0.label == name }!.value as! Double } + [speed]
}
var interpolating: [(String, InterpolatingSpring, Animation)] = []
func hold(_ spring: Mine, _ velocity: Double) -> InterpolatingSpring { InterpolatingSpring(spring, initialVelocity: velocity) }
for velocity in [0.0, 1.5, -2] {
    for (mine, apple) in made { interpolating.append(("spring v \(velocity)", hold(mine, velocity), Animation.interpolatingSpring(apple, initialVelocity: velocity))) }
    for r in [0.15, 0.5, 1] { for b in [-0.9, -0.5, -0.2, 0, 0.15, 0.3, 0.4, 0.9] {
        interpolating.append(("duration \(r) bounce \(b) v \(velocity)", InterpolatingSpring(duration: r, bounce: b, initialVelocity: velocity), Animation.interpolatingSpring(duration: r, bounce: b, initialVelocity: velocity)))
    } }
    for m in [0.5, 1.0, 2.0] { for k in [10.0, 50, 100, 400] { for c in [1.0, 5, 10, 40, 100, 3 * (m * k).squareRoot(), 2 * (m * k).squareRoot()] {
        interpolating.append(("mass \(m) stiffness \(k) damping \(c) v \(velocity)", InterpolatingSpring(mass: m, stiffness: k, damping: c, initialVelocity: velocity),
                              Animation.interpolatingSpring(mass: m, stiffness: k, damping: c, initialVelocity: velocity)))
    } } }
}
var held = 0
for (name, mine, apple) in interpolating {
    held += 1
    same("held numbers of \(name)", heldBy(apple) == [mine.mass, mine.stiffness, mine.damping, mine.initialVelocity], true)
    same("interpolating \(name) is not the animation of a spring", false, apple == Animation.spring(response: 0.5, dampingFraction: 0.7) || apple == Animation.spring(duration: 0.5, bounce: 0.3))
}
print("compared", held, "interpolating springs' held numbers")
var interpolatingPairs = 0
for (_, mine, apple) in interpolating {
    for (_, other, otherApple) in interpolating {
        interpolatingPairs += 1
        same("interpolating springs equal", mine == other, apple == otherApple)
        if apple == otherApple { same("interpolating springs hash alike", true, apple.hashValue == otherApple.hashValue) }
    }
}
print("compared", interpolatingPairs, "pairs of interpolating springs for equality")
var solved = 0
for (name, mine, apple) in interpolating {
    var context = makeContext()
    for t in [0.0, 0.01, 0.05, 0.1, 0.2, 0.4, 0.8, 1.5] {
        for distance in [1.0, 3.0, -2.0] {
            guard let got = apple.animate(value: distance, time: t, context: &context) else { continue }
            solved += 1
            note("interpolating \(name) at \(t) over \(distance)", distance * mine.progress(t / mine.spring.response), got)
        }
    }
}
print("compared", solved, "values of interpolating springs")

// the blend of a spring moves nothing in time: Apple's answers for a spring are the same whatever blend it was given
// (and its end and logical completion with them)
func answersOf(_ animation: Animation, distance: Double, at times: [Double]) -> [Double?] {
    var context = makeContext()
    return times.map { animation.animate(value: distance, time: $0, context: &context) }
}
var blended = 0
let blendTimes = (0..<240).map { (Double($0) + 0.5) / 300 }
for (r, z) in [(0.5, 0.825), (0.15, 0.86), (1.0, 0.5), (0.3, 1.0), (0.4, 1.4)] {
    let plain = answersOf(Animation.spring(response: r, dampingFraction: z), distance: 1, at: blendTimes)
    for blend in [0.1, 0.25, 1.0] {
        blended += 1
        same("blend \(blend) of response \(r) fraction \(z) moves nothing in time", true, answersOf(Animation.spring(response: r, dampingFraction: z, blendDuration: blend), distance: 1, at: blendTimes) == plain)
    }
}
print("compared", blended, "blends against none")

// the fluid spring: Apple's steps its spring a three-hundredth of a second at a time and answers a staircase, and answers nothing
// from the step whose state is close to the target and at rest; the answers come from one context, in step order, because the
// animation integrates from the state it kept (a question asked cold, far into the animation, is answered wrongly)
var fluidAsked = 0, fluidEnds = 0
func compareFluid(_ name: String, _ mine: Mine, _ apple: Animation, distance: Double, limit: Int = 3000) {
    let track = FluidTrack(mine), end = track.end(distance: distance)
    var context = makeContext()
    for k in 0..<limit {
        let t = (Double(k) + 0.5) / 300
        let got = apple.animate(value: distance, time: t, context: &context)
        let expected: Double? = t > end ? nil : distance * track.progress(at: t)
        fluidAsked += 1
        if (got == nil) != (expected == nil) { print("DIFF fluid end", name, "distance", distance, "step", k, "apple", got as Any, "mine", expected as Any); return }
        guard let got, let expected else { fluidEnds += 1; return }
        let scale = max(1, abs(got))
        note("fluid \(name) distance \(distance) step \(k)", expected / scale, got / scale)
    }
    if end < Double(limit) / 300 { print("DIFF fluid end", name, "distance", distance, "apple never within", limit, "steps; mine", end) }
}
for r in [0.1, 0.15, 0.25, 0.3, 0.5, 0.75, 1, 1.5, 2, 3] {
    for z in [0.1, 0.2, 0.3, 0.5, 0.7, 0.825, 0.9, 1, 1.25, 1.5, 2] {
        for d in [0.01, 0.3, 1, 3, 17, 100, 1000] {
            compareFluid("response \(r) fraction \(z)", Mine(response: r, dampingRatio: z), Animation.spring(response: r, dampingFraction: z), distance: d)
        }
    }
}
for (r, b) in [(0.5, 0.0), (0.5, 0.15), (0.5, 0.3), (0.15, 0.15), (0.35, -0.4)] {
    for d in [0.5, 4, 60] { compareFluid("duration \(r) bounce \(b)", Mine(duration: r, bounce: b), Animation.spring(duration: r, bounce: b), distance: d) }
}
// a response shorter than the step allows, a spring that is not damped, one that is damped by a negative, or by too much, or by nothing
for (r, z) in [(0.0, 0.8), (-1.0, 0.8), (0.0001, 0.8), (0.02, 0.5), (0.0296, 0.5), (0.03, 0.5), (0.5, 0.0), (0.5, 0.001), (0.5, -0.5), (0.5, 50), (0.5, Double.nan), (Double.nan, 0.5)] {
    compareFluid("odd response \(r) fraction \(z)", Mine(response: r, dampingRatio: z), Animation.spring(response: r, dampingFraction: z), distance: 1)
}
print("asked Apple's fluid spring", fluidAsked, "times; it ended", fluidEnds, "of its runs")
// a vector rests when its length does, and moves along its direction as the unit solution does
var vectorAsked = 0
for (r, z) in [(0.5, 0.825), (0.3, 0.4), (1.0, 1.0), (0.4, 1.5)] {
    for (x, y) in [(3.0, 4.0), (-0.3, 0.4), (60.0, -80.0), (0.003, 0.004)] {
        let track = FluidTrack(Mine(response: r, dampingRatio: z)), end = track.end(distance: (x * x + y * y).squareRoot())
        var context = makeContext(AnimatablePair<Double, Double>.self)
        let animation = Animation.spring(response: r, dampingFraction: z)
        for k in 0..<3000 {
            let t = (Double(k) + 0.5) / 300
            let got = animation.animate(value: AnimatablePair(x, y), time: t, context: &context)
            vectorAsked += 1
            same("vector \(r) \(z) \(x) \(y) step \(k) ends with its length", got == nil, t > end)
            guard let got else { break }
            note("vector.first", track.progress(at: t) * x, got.first); note("vector.second", track.progress(at: t) * y, got.second)
        }
    }
}
print("asked Apple's fluid spring", vectorAsked, "times of a pair")
print("compared", count, "numbers; worst difference", worst)
