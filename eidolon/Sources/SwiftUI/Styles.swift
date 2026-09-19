import UIKit
import CoreGraphics

public struct DefaultListStyle: ListStyle { public init() {} }
public struct InsetListStyle: ListStyle { public init() {} }
public struct InsetGroupedListStyle: ListStyle { public init() {} }
public struct SidebarListStyle: ListStyle { public init() {} }

extension ListStyle where Self == PlainListStyle {
    public static var plain: PlainListStyle { PlainListStyle() }
}

extension ListStyle where Self == GroupedListStyle {
    public static var grouped: GroupedListStyle { GroupedListStyle() }
}

extension ListStyle where Self == InsetGroupedListStyle {
    public static var insetGrouped: InsetGroupedListStyle { InsetGroupedListStyle() }
}

extension ListStyle where Self == DefaultListStyle {
    public static var automatic: DefaultListStyle { DefaultListStyle() }
}

public struct PrimitiveButtonStyleConfiguration {
    public struct Label: View {
        let content: any View
        public var body: some View { AnyView(content) }
    }
    public let label: Label
    public let role: ButtonRole?
    let action: () -> Void
    public func trigger() { action() }
}

public protocol PrimitiveButtonStyle {
    associatedtype Body: View
    typealias Configuration = PrimitiveButtonStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct ButtonRole: Equatable {
    let name: String
    public static let destructive = ButtonRole(name: "destructive")
    public static let cancel = ButtonRole(name: "cancel")
}

public struct DefaultButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
            .background(configuration.isPressed ? Color(white: 0.85) : Color.white, cornerRadius: 8)
            .border(Color(white: 0.7), width: 1)
    }
}

public struct PlainButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.4 : 1)
    }
}

public struct BorderedButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        _BorderedChrome(label: configuration.label, fill: configuration.isPressed ? Color(white: 0.82) : Color(white: 0.93), text: nil)
    }
}

public struct BorderedProminentButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        _BorderedChrome(label: configuration.label,
                        fill: configuration.isPressed ? Color(red: 0.1, green: 0.3, blue: 0.7) : Color(red: 0.15, green: 0.4, blue: 0.9),
                        text: .white)
    }
}

struct _BorderedChrome: View {
    let label: ButtonStyleConfiguration.Label
    let fill: Color
    let text: Color?
    @Environment(\.self) var environment
    var body: some View {
        let padded = label.foregroundColor(text).padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        switch environment.buttonBorderShape.kind {
        case .capsule:
            return AnyView(padded.background(Capsule().fill(fill)))
        case .roundedRectangle(let radius):
            return AnyView(padded.background(RoundedRectangle(cornerRadius: radius ?? 6).fill(fill)))
        case .automatic:
            return AnyView(padded.background(fill, cornerRadius: 6))
        }
    }
}

extension ButtonStyle where Self == DefaultButtonStyle {
    public static var automatic: DefaultButtonStyle { DefaultButtonStyle() }
}

extension ButtonStyle where Self == PlainButtonStyle {
    public static var plain: PlainButtonStyle { PlainButtonStyle() }
}

extension ButtonStyle where Self == BorderedButtonStyle {
    public static var bordered: BorderedButtonStyle { BorderedButtonStyle() }
}

extension ButtonStyle where Self == BorderedProminentButtonStyle {
    public static var borderedProminent: BorderedProminentButtonStyle { BorderedProminentButtonStyle() }
}

public struct DefaultToggleStyle: ToggleStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: Binding(get: { configuration.isOn }, set: { _ in })) { configuration.label }
    }
}

public struct SwitchToggleStyle: ToggleStyle {
    public init() {}
    public init(tint: Color) {}
    public func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: Binding(get: { configuration.isOn }, set: { _ in })) { configuration.label }
    }
}

public struct ButtonToggleStyle: ToggleStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Text(configuration.isOn ? "✓" : "✗")
            configuration.label
        }
    }
}

extension ToggleStyle where Self == SwitchToggleStyle {
    public static var `switch`: SwitchToggleStyle { SwitchToggleStyle() }
}

extension ToggleStyle where Self == ButtonToggleStyle {
    public static var button: ButtonToggleStyle { ButtonToggleStyle() }
}

public struct DefaultLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { HStack(spacing: 6) { configuration.icon; configuration.title } }
}

public struct TitleOnlyLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.title }
}

public struct IconOnlyLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { configuration.icon }
}

public struct DefaultProgressViewStyle: ProgressViewStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        ProgressView(configuration)
    }
}

public struct LinearProgressViewStyle: ProgressViewStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        ProgressView(configuration)
    }
}

public struct CircularProgressViewStyle: ProgressViewStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { ProgressView() }
}

public struct DefaultMenuStyle: MenuStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { Menu(configuration) }
}

public struct DefaultDatePickerStyle: DatePickerStyle { public init() {} }
public struct SeparatorShapeStyle: ShapeStyle {
    public init() {}
    public var _uiColor: UIColor? { UIColor(white: 0.78, alpha: 1) }
}

public struct RGBColorSpace: Equatable {
    public static let sRGB = RGBColorSpace()
    public static let sRGBLinear = RGBColorSpace()
    public static let displayP3 = RGBColorSpace()
}

extension Color {
    public init(_ colorSpace: RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
    public init(_ colorSpace: RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) {
        self.init(UIColor(white: CGFloat(white), alpha: CGFloat(opacity)))
    }
    public init(white: Double, opacity: Double = 1) {
        self.init(UIColor(white: CGFloat(white), alpha: CGFloat(opacity)))
    }
    public init(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1) {
        self.init(UIColor(hue: CGFloat(hue), saturation: CGFloat(saturation), brightness: CGFloat(brightness), alpha: CGFloat(opacity)))
    }
}

public struct ProjectionTransform: Equatable {
    public var m11: CGFloat = 1, m12: CGFloat = 0, m13: CGFloat = 0
    public var m21: CGFloat = 0, m22: CGFloat = 1, m23: CGFloat = 0
    public var m31: CGFloat = 0, m32: CGFloat = 0, m33: CGFloat = 1
    public init() {}
    public init(_ transform: CGAffineTransform) {
        m11 = transform.a; m12 = transform.b
        m21 = transform.c; m22 = transform.d
        m31 = transform.tx; m32 = transform.ty
    }
}

