import UIKit
import CoreGraphics

// How a view's layer is rasterised, which is what the release of a view is made of. Apple's type is
// nested — `_RendererConfiguration.RasterizationOptions` in both the SDK of 16.4
// (`arm64e-apple-ios.swiftinterface:17490`) and the one of 26.2 — so it is nested here too, and the
// interface spells the seven properties and `init()` and gives no initial value for any of them.
//
// The values `init()` uses are therefore the port's, and are the release's own: a layer of iOS 6 drawn
// on the main thread, not opaque, over what is behind it, in the non-linear colour mode, with as many
// drawables as the release draws and no colour mode to send down. `maxDrawableCount` is 0 for that last
// reason and nothing else: no SDK, and no host — `RasterizationOptions` is a member of an underscored
// type and is not on macOS's public surface, so there was nothing to measure and nothing to invent
// either.
/// The configuration of the release that draws a view. Apple spells it `_RendererConfiguration`; the
/// type is here without the underscore so that a name an SDK does not declare is not published, and
/// the nesting is the one Apple uses.
public struct _RendererConfiguration {
    public struct RasterizationOptions {
        public var colorMode: ColorRenderingMode
    /// The `rbColorMode` the release sends down to its own rendering, where it has one. iOS 6's
    /// `CALayer` has no such key, so it is nil and nothing is sent.
        public var rbColorMode: Int32?
        public var rendersAsynchronously: Bool
        public var isOpaque: Bool
        public var drawsPlatformViews: Bool
        public var prefersDisplayCompositing: Bool
        public var maxDrawableCount: Int

        public init() {
            colorMode = .nonLinear
            rbColorMode = nil
            rendersAsynchronously = false
            isOpaque = false
            drawsPlatformViews = false
            prefersDisplayCompositing = false
            maxDrawableCount = 0
        }
    }
}

// No environment key: Apple's type is a parameter of the APIs that take it, and neither SDK declares
// one in `EnvironmentValues` — the reverse check is what caught that the first version of this file had.

extension _RendererConfiguration.RasterizationOptions {
    /// The layer settings the release's own rasterisation asks for. `shouldRasterize` and the scale are
    /// the two `CALayer` of iOS 6 has, and a colour mode or a drawable count is a key it does not, so
    /// those do not reach it.
    func applied(to layer: CALayer) {
        layer.drawsAsynchronously = rendersAsynchronously
        layer.rasterizationScale = 0
        layer.rasterizationScale = UIScreen.main.scale
    }
}

