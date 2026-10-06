# host probes

The programs here are how a value that only Apple's framework knows was measured, kept in the tree so
the number next to it can be reproduced by whoever reads it. They build and run on the **host** — macOS
with the toolchain of `pkg-env.sh` — and are not part of the module.

```
$ swiftc -O hostrenderer.swift -o hostrenderer && ./hostrenderer
colorMode=nonLinear rendersAsynchronously=false isOpaque=true
drawsPlatformViews=true prefersDisplayCompositing=false
maxDrawableCount=3 rbColorMode=nil
```

Those are the seven defaults of `_RendererConfiguration.RasterizationOptions` in
`eidolon/Sources/SwiftUI/Rasterizations.swift`. The SDK interface declares the seven properties and a
bare `init()` and gives no value for any of them, so the framework itself is the only source there is,
and the type is underscored — which in Swift is public, so the host can name it.

`springcmp.swift` compares the port's `Spring` with Apple's `SwiftUI.Spring` over value, velocity, update and the
Animatable forms of both, for critical, under-damped and over-damped springs; the command is in its header, and
its last line is `compared N numbers; worst difference ...` after a `DIFF` line for every number that is not Apple's.
It also compares equality and hashing of springs and of the animations made of them, and, for
`Animation.interpolatingSpring`, the mass, stiffness and damping Apple's animation holds (read out of it by reflection)
and the values it answers. Those values are asked of `Animation.animate(value:time:context:)`, whose `AnimationContext`
has no public initializer, so the program builds one in memory from an `AnimationState` and `EnvironmentValues`
(a 26-byte struct on this host: the state at offset 0, the environment at 8, two flags after); if a later macOS changes
that layout, the values come out wrong or the program crashes, and the held numbers and equalities still stand alone.
The same context answers for `Animation.spring` and its named forms, asked in step order from one context (the animation
integrates from the state it kept, and a question asked cold far into it is answered wrongly): `FluidTrack` is compared with
its staircase of steps of a three-hundredth of a second and with the step after which it answers nothing, over the responses,
fractions and distances of the program, for a pair of numbers as a distance, and for the springs no one means (a response of
nothing, a negative or undamped or runaway one, a number that is not one).
