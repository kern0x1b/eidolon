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
