import UIKit
import CoreGraphics

public enum TextInputAutocapitalization { case never, words, sentences, characters }
public enum DynamicTypeSize: Comparable, CaseIterable { case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge }
public enum BlendMode { case normal, multiply, screen, overlay, darken, lighten, difference }
public struct ButtonBorderShape: Equatable {
    enum Kind: Equatable { case automatic, capsule, roundedRectangle(CGFloat?) }
    let kind: Kind
    public static let automatic = ButtonBorderShape(kind: .automatic)
    public static let capsule = ButtonBorderShape(kind: .capsule)
    public static let roundedRectangle = ButtonBorderShape(kind: .roundedRectangle(nil))
    public static func roundedRectangle(radius: CGFloat) -> ButtonBorderShape { ButtonBorderShape(kind: .roundedRectangle(radius)) }
}

struct InputSettings {
    var autocapitalization: UITextAutocapitalizationType?
    var autocorrection: UITextAutocorrectionType?
    var keyboard: UIKeyboardType?
    var onSubmit: (() -> Void)?
    var returnKey: UIReturnKeyType?
}

extension View {
    public func autocapitalization(_ style: UITextAutocapitalizationType) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.input.autocapitalization = style }, onUpdate: nil))
    }
    public func textInputAutocapitalization(_ style: TextInputAutocapitalization?) -> some View {
        let mapped: UITextAutocapitalizationType
        switch style {
        case .never: mapped = .none
        case .words: mapped = .words
        case .characters: mapped = .allCharacters
        default: mapped = .sentences
        }
        return autocapitalization(mapped)
    }
    public func disableAutocorrection(_ disable: Bool?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.input.autocorrection = (disable ?? false) ? .no : .yes }, onUpdate: nil))
    }
    public func autocorrectionDisabled(_ disable: Bool = true) -> some View { disableAutocorrection(disable) }
    public func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.input.onSubmit = action }, onUpdate: nil))
    }

    public func textContentType(_ type: UITextContentType?) -> some View {
        ignored(self, "textContentType", "iOS 6 has no content types for text fields")
    }

    public func keyboardType(_ type: UIKeyboardType) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.input.keyboard = type }, onUpdate: nil))
    }
    public func colorScheme(_ scheme: ColorScheme) -> some View { environment(\.colorScheme, scheme) }
    public func preferredColorScheme(_ scheme: ColorScheme?) -> some View { ignored(self, "preferredColorScheme", "iOS 6 has a single appearance") }
    public func controlSize(_ size: ControlSize) -> some View { environment(\.controlSize, size) }
    public func dynamicTypeSize(_ size: DynamicTypeSize) -> some View { ignored(self, "dynamicTypeSize", "iOS 6 has no dynamic type") }
    public func drawingGroup(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear) -> some View {
        applyingToViews { $0.layer.shouldRasterize = true; $0.layer.rasterizationScale = UIScreen.main.scale }
    }
    public func edgesIgnoringSafeArea(_ edges: Edge.Set) -> some View { ignored(self, "edgesIgnoringSafeArea", "iOS 6 has no safe area") }
    public func ignoresSafeArea(_ regions: SafeAreaRegions = .all, edges: Edge.Set = .all) -> some View { ignored(self, "ignoresSafeArea", "iOS 6 has no safe area") }
    public func blendMode(_ mode: BlendMode) -> some View { ignored(self, "blendMode", "CoreAnimation of iOS 6 has no layer blend modes") }
    public func blur(radius: CGFloat, opaque: Bool = false) -> some View { ignored(self, "blur", "iOS 6 has no live blur") }
    public func brightness(_ amount: Double) -> some View { ignored(self, "brightness", "iOS 6 has no layer filters") }
    public func contrast(_ amount: Double) -> some View { ignored(self, "contrast", "iOS 6 has no layer filters") }
    public func saturation(_ amount: Double) -> some View { ignored(self, "saturation", "iOS 6 has no layer filters") }
    public func grayscale(_ amount: Double) -> some View { ignored(self, "grayscale", "iOS 6 has no layer filters") }
    public func colorInvert() -> some View { ignored(self, "colorInvert", "iOS 6 has no layer filters") }
    public func colorMultiply(_ color: Color) -> some View { ignored(self, "colorMultiply", "iOS 6 has no layer filters") }
    public func defersSystemGestures(on edges: Edge.Set) -> some View { ignored(self, "defersSystemGestures", "iOS 6 has no system edge gestures") }
    public func interactiveDismissDisabled(_ disabled: Bool = true) -> some View { ignored(self, "interactiveDismissDisabled", "iOS 6 modals are not interactively dismissible") }
    public func navigationBarTitleDisplayMode(_ mode: NavigationBarItem.TitleDisplayMode) -> some View { ignored(self, "navigationBarTitleDisplayMode", "iOS 6 navigation bars have one title style") }
    public func persistentSystemOverlays(_ visibility: Visibility) -> some View { ignored(self, "persistentSystemOverlays", "iOS 6 has no system overlays") }
    public func redacted(reason: RedactionReasons) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.redactionReasons = environment.redactionReasons.union(reason)
            environment.redactedDrawing = !environment.redactionReasons.isEmpty
        }, onUpdate: nil))
    }
    public func unredacted() -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.redactionReasons = []
            environment.redactedDrawing = false
        }, onUpdate: nil))
    }
    public func symbolRenderingMode(_ mode: SymbolRenderingMode) -> some View { ignored(self, "symbolRenderingMode", "iOS 6 has no SF Symbols") }
    public func widgetAccentable(_ accentable: Bool = true) -> some View { ignored(self, "widgetAccentable", "iOS 6 has no widgets") }
}

public struct SubmitTriggers: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let text = SubmitTriggers(rawValue: 1)
    public static let search = SubmitTriggers(rawValue: 2)
}

public enum ColorRenderingMode { case nonLinear, linear, extendedLinear }
public struct SafeAreaRegions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let all = SafeAreaRegions(rawValue: 7)
    public static let container = SafeAreaRegions(rawValue: 1)
    public static let keyboard = SafeAreaRegions(rawValue: 2)
}
public struct ViewDimensions {
    public let width: CGFloat
    public let height: CGFloat
    var explicit: [String: CGFloat] = [:]
    init(width: CGFloat, height: CGFloat) { self.width = width; self.height = height }
    public subscript(guide: HorizontalAlignment) -> CGFloat {
        explicit["h:" + guide.id] ?? guide.defaultValue(ViewDimensions(width: width, height: height))
    }
    public subscript(guide: VerticalAlignment) -> CGFloat {
        explicit["v:" + guide.id] ?? guide.defaultValue(ViewDimensions(width: width, height: height))
    }
    public subscript(explicit guide: HorizontalAlignment) -> CGFloat? { explicit["h:" + guide.id] }
    public subscript(explicit guide: VerticalAlignment) -> CGFloat? { explicit["v:" + guide.id] }
}
public enum Prominence { case standard, increased }
public struct RedactionReasons: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let placeholder = RedactionReasons(rawValue: 1)
    public static let privacy = RedactionReasons(rawValue: 2)
}
public enum SubmitLabel { case done, go, send, join, route, search, `return`, next, `continue` }
public enum HorizontalEdge { case leading, trailing }
public enum SymbolRenderingMode { case monochrome, multicolor, hierarchical, palette }
public struct AnyTransition {
    var storage = TransitionSpec()
    public static let identity = AnyTransition()
    public static let opacity = AnyTransition(storage: TransitionSpec(fades: true, scale: nil, offset: nil))
    public static let scale = AnyTransition(storage: TransitionSpec(fades: false, scale: 0.1, offset: nil))
    public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition {
        AnyTransition(storage: TransitionSpec(fades: false, scale: scale, offset: nil))
    }
    public static let slide = AnyTransition.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
    public static func move(edge: Edge) -> AnyTransition {
        let offset: CGSize
        switch edge {
        case .leading: offset = CGSize(width: -320, height: 0)
        case .trailing: offset = CGSize(width: 320, height: 0)
        case .top: offset = CGSize(width: 0, height: -480)
        case .bottom: offset = CGSize(width: 0, height: 480)
        }
        return AnyTransition(storage: TransitionSpec(fades: false, scale: nil, offset: offset))
    }
    public static func offset(_ offset: CGSize) -> AnyTransition {
        AnyTransition(storage: TransitionSpec(fades: false, scale: nil, offset: offset))
    }
    public func combined(with other: AnyTransition) -> AnyTransition {
        var merged = storage
        if other.storage.fades { merged.fades = true }
        merged.scale = merged.scale ?? other.storage.scale
        merged.offset = merged.offset ?? other.storage.offset
        return AnyTransition(storage: merged)
    }
    public func animation(_ animation: Animation?) -> AnyTransition {
        var copy = self
        copy.storage.animation = animation
        return copy
    }
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition {
        var spec = insertion.storage
        spec.removals = [removal.storage]
        return AnyTransition(storage: spec)
    }
}
public enum NavigationBarItem {
    public enum TitleDisplayMode { case automatic, inline, large }
}

extension Text {
    public enum TruncationMode { case head, middle, tail }
}

extension View {
    public func truncationMode(_ mode: Text.TruncationMode) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            switch mode {
            case .head: environment.truncation = .byTruncatingHead
            case .middle: environment.truncation = .byTruncatingMiddle
            case .tail: environment.truncation = .byTruncatingTail
            }
        }, onUpdate: nil))
    }

    public func scrollDisabled(_ disabled: Bool) -> some View {
        applyingToViews { view in
            if let scroller = view as? UIScrollView { scroller.isScrollEnabled = !disabled }
        }
    }

    public func scrollIndicators(_ visibility: ScrollIndicatorVisibility, axes: Axis.Set = [.vertical, .horizontal]) -> some View {
        applyingToViews { view in
            guard let scroller = view as? UIScrollView else { return }
            let shown = visibility != .hidden && visibility != .never
            if axes.contains(.vertical) { scroller.showsVerticalScrollIndicator = shown }
            if axes.contains(.horizontal) { scroller.showsHorizontalScrollIndicator = shown }
        }
    }

    public func allowsTightening(_ flag: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.allowsTightening = flag }, onUpdate: nil))
    }
}
