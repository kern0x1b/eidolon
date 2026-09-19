import UIKit
import CoreGraphics

// Объявлено, чтобы приложение собиралось и запускалось, но пока не реализовано: каждое такое место
// один раз пишет строку в журнал и попадает в отчёт прогона. Это временное состояние, не «нет в системе».

public protocol ButtonStyle {
    associatedtype Body: View
    typealias Configuration = ButtonStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct ButtonStyleConfiguration {
    public struct Label: View {
        let content: any View
        public var body: some View { AnyView(content) }
    }
    public let label: Label
    public let isPressed: Bool
}

public protocol ToggleStyle {
    associatedtype Body: View
    typealias Configuration = ToggleStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct ToggleStyleConfiguration {
    public struct Label: View {
        let content: any View
        public var body: some View { AnyView(content) }
    }
    public let label: Label
    public var isOn: Bool
}

public protocol LabelStyle {
    associatedtype Body: View
    typealias Configuration = LabelStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct LabelStyleConfiguration {
    public struct Title: View {
        let content: any View
        public var body: some View { AnyView(content) }
    }
    public struct Icon: View {
        let content: any View
        public var body: some View { AnyView(content) }
    }
    public let title: Title
    public let icon: Icon
}

public protocol ProgressViewStyle {
    associatedtype Body: View
    typealias Configuration = ProgressViewStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct ProgressViewStyleConfiguration {
    public struct Label: View {
        let content: any View
        public var body: some View { AnyView(content) }
    }
    public struct CurrentValueLabel: View {
        let content: any View
        public var body: some View { AnyView(content) }
    }
    public let fractionCompleted: Double?
    public var label: Label?
    public var currentValueLabel: CurrentValueLabel?
}

public protocol MenuStyle {
    associatedtype Body: View
    typealias Configuration = MenuStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct MenuStyleConfiguration {
    public struct Label: View, WrappedView {
        let wrapped: any View
        public var body: some View { AnyView(wrapped) }
    }
    public struct Content: View, WrappedView {
        let wrapped: any View
        public var body: some View { AnyView(wrapped) }
    }
    let label: Label
    let content: Content
}

public protocol NavigationViewStyle {}
public struct StackNavigationViewStyle: NavigationViewStyle { public init() {} }
public struct DefaultNavigationViewStyle: NavigationViewStyle { public init() {} }
public struct DoubleColumnNavigationViewStyle: NavigationViewStyle { public init() {} }

public protocol DisclosureGroupStyle {
    associatedtype Body: View
    typealias Configuration = DisclosureGroupStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct DisclosureGroupStyleConfiguration {
    public struct Label: View, WrappedView {
        let wrapped: any View
        public var body: some View { AnyView(wrapped) }
    }
    public struct Content: View, WrappedView {
        let wrapped: any View
        public var body: some View { AnyView(wrapped) }
    }
    public let label: Label
    public let content: Content
    @Binding public var isExpanded: Bool
}

public struct AutomaticDisclosureGroupStyle: DisclosureGroupStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        _DisclosureChrome(label: configuration.label, content: configuration.content, isExpanded: configuration.$isExpanded)
    }
}

extension DisclosureGroupStyle where Self == AutomaticDisclosureGroupStyle {
    public static var automatic: AutomaticDisclosureGroupStyle { AutomaticDisclosureGroupStyle() }
}

protocol WrappedView { var wrapped: any View { get } }

public protocol DatePickerStyle {}
public struct WheelDatePickerStyle: DatePickerStyle { public init() {} }
public struct CompactDatePickerStyle: DatePickerStyle { public init() {} }
public struct GraphicalDatePickerStyle: DatePickerStyle { public init() {} }

public struct EmptyModifier: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View { content }
}

extension View {
    public func buttonStyle<S: PrimitiveButtonStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.primitiveButtonStyle = { configuration in style.makeBody(configuration: configuration) }
        }, onUpdate: nil))
    }
}


extension View {
    public func buttonStyle<S: ButtonStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.buttonStyle = { configuration in style.makeBody(configuration: configuration) }
        }, onUpdate: nil))
    }

    public func labelStyle<S: LabelStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.labelStyle = { configuration in style.makeBody(configuration: configuration) }
        }, onUpdate: nil))
    }

    public func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.progressViewStyle = { configuration in style.makeBody(configuration: configuration) }
        }, onUpdate: nil))
    }

    public func menuStyle<S: MenuStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.menuStyle = { configuration in style.makeBody(configuration: configuration) }
        }, onUpdate: nil))
    }

    public func disclosureGroupStyle<S: DisclosureGroupStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.disclosureGroupStyle = { configuration in style.makeBody(configuration: configuration) }
        }, onUpdate: nil))
    }

    public func toggleStyle<S: ToggleStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.toggleStyle = { configuration in style.makeBody(configuration: configuration) }
        }, onUpdate: nil))
    }
}

extension ButtonStyleConfiguration.Label: WrappedView { var wrapped: any View { content } }
extension PrimitiveButtonStyleConfiguration.Label: WrappedView { var wrapped: any View { content } }
extension ToggleStyleConfiguration.Label: WrappedView { var wrapped: any View { content } }
extension LabelStyleConfiguration.Title: WrappedView { var wrapped: any View { content } }
extension LabelStyleConfiguration.Icon: WrappedView { var wrapped: any View { content } }
extension ProgressViewStyleConfiguration.Label: WrappedView { var wrapped: any View { content } }
extension ProgressViewStyleConfiguration.CurrentValueLabel: WrappedView { var wrapped: any View { content } }
