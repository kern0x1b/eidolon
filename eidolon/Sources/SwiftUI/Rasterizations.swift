import UIKit
import CoreGraphics

// How a view's layer is rasterised, which is what the release of a view is made of. Apple's shape from
// the SDK of 16.4 (`SwiftUI.swiftinterface:17490` — seven stored properties and one `init()`), and
// every one of them is something `CALayer` of iOS 6 has: the drawing group set `shouldRasterize` and the
// scale of the screen, and the release of a view is drawn with the rest.
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
        maxDrawableCount = 3
    }
}

// No environment key: Apple's `RasterizationOptions` is a parameter of the APIs that take it, and
// neither SDK declares one in `EnvironmentValues` — the reverse check is what caught that the first
// version of this file had.

extension RasterizationOptions {
    /// The layer settings the release's own rasterisation asks for. `shouldRasterize` and the scale are
    /// the two `CALayer` of iOS 6 has, and a colour mode or a drawable count is a key it does not, so
    /// those do not reach it.
    func applied(to layer: CALayer) {
        layer.drawsAsynchronously = rendersAsynchronously
        layer.rasterizationScale = 0
        layer.rasterizationScale = UIScreen.main.scale
    }
}
