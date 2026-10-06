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
print("compared", count, "numbers; worst difference", worst)
