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
print("compared", count, "numbers; worst difference", worst)
