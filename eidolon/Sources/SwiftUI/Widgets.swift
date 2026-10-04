import SwiftUI
import CoreGraphics

// MARK: - the three protocols a widget is written with

/// A widget: a configuration, and nothing that draws on this device. Apple declares it for iOS 14 and up
/// and not for tvOS (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:19484-19489`).
///
/// iOS 6.1.3 has no widget host — a widget is a view the system puts on a home screen, and the system of
/// iOS 6 has no such place — so a widget written here is never shown, exactly as a widget is in an app
/// whose extension is not installed. The protocol and its body are what the port carries; the host is
/// what the platform does not have.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol Widget {
    associatedtype Body: WidgetConfiguration
    @WidgetConfigurationBuilder var body: Body { get }
}

/// What a widget is told: a family it is laid out for, a schedule it updates on. Apple's shape from the
/// SDK of 16.4 (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:12988-12992`).
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol WidgetConfiguration {
    associatedtype Body: WidgetConfiguration
    @WidgetConfigurationBuilder var body: Body { get }
}

/// A bundle of widgets, which is what an extension's entry point is. Apple's shape from the same file
/// (`:11775-11779`), with the bundle's body built by `WidgetBundleBuilder`.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol WidgetBundle {
    associatedtype Body: Widget
    @WidgetBundleBuilder var body: Body { get }
}

/// A widget with nothing in it, which is what a configuration that says no more than that is.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
@frozen public struct EmptyWidgetConfiguration: WidgetConfiguration {
    // the configuration that says nothing, and says it by itself: a `Never` body would not be a
    // `WidgetConfiguration` and the builder could not hand one out for an empty block
    public typealias Body = EmptyWidgetConfiguration
    public var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    public init() {}
}

// MARK: - the builders, as the interface spells them

@_functionBuilder
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public struct WidgetConfigurationBuilder {
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: WidgetConfiguration { content }
    public static func buildBlock() -> some WidgetConfiguration { EmptyWidgetConfiguration() }
    public static func buildBlock<Content>(_ content: Content) -> some WidgetConfiguration where Content: WidgetConfiguration { content }
    public static func buildBlock<First, Second>(_ first: First, _ second: Second) -> some WidgetConfiguration
        where First: WidgetConfiguration, Second: WidgetConfiguration { first }
    public static func buildBlock<First, Second, Third>(_ first: First, _ second: Second, _ third: Third) -> some WidgetConfiguration
        where First: WidgetConfiguration, Second: WidgetConfiguration, Third: WidgetConfiguration { first }
    public static func buildOptional(_ configuration: (WidgetConfiguration)?) -> some WidgetConfiguration {
        _configuration(configuration ?? EmptyWidgetConfiguration())
    }
    public static func buildEither<First, Second>(first: First) -> some WidgetConfiguration where First: WidgetConfiguration { first }
    public static func buildEither<First, Second>(second: Second) -> some WidgetConfiguration where Second: WidgetConfiguration { second }
    public static func buildLimitedAvailability(_ content: AnyWidgetConfiguration) -> some WidgetConfiguration { content }
}

/// One configuration whatever it is: an existential does not conform to `WidgetConfiguration` on its own,
/// and a builder that hands one out has to put it in something that does.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct _Configuration: WidgetConfiguration {
    typealias Body = EmptyWidgetConfiguration
    var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
private func _configuration(_ configuration: any WidgetConfiguration) -> some WidgetConfiguration {
    let boxed = _Configuration(); return boxed
}

@_functionBuilder
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public struct WidgetBundleBuilder {
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: Widget { content }
    public static func buildBlock() -> some Widget { EmptyWidget() }
    public static func buildBlock<Content>(_ content: Content) -> some Widget where Content: Widget { content }
    public static func buildBlock<First, Second>(_ first: First, _ second: Second) -> some Widget
        where First: Widget, Second: Widget { EmptyWidget() }
    public static func buildBlock<First, Second, Third>(_ first: First, _ second: Second, _ third: Third) -> some Widget
        where First: Widget, Second: Widget, Third: Widget { EmptyWidget() }
    public static func buildOptional(_ widget: Widget?) -> some Widget { _widget(_erased(widget)) }
    public static func buildEither<First, Second>(first: First) -> some Widget where First: Widget { first }
    public static func buildEither<First, Second>(second: Second) -> some Widget where Second: Widget { second }
}

/// A widget's configuration that is behind an availability, which the interface builds through
/// `buildLimitedAvailability(_:)`.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public struct AnyWidgetConfiguration: WidgetConfiguration {
    public typealias Body = EmptyWidgetConfiguration
    /// What the availability hid, when the configuration it was given is still around.
    var erased: (any WidgetConfiguration)?
    public var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    public init(_ configuration: any WidgetConfiguration) { erased = configuration }
    public init() {}
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
private func _widget(_ widget: some Widget) -> some Widget { EmptyWidget() }

/// A widget that was behind an availability, as a value: an existential does not conform to `Widget`,
/// so the optional branch of the builder goes through a box that does.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct AnyWidget: Widget {
    typealias Body = EmptyWidgetConfiguration
    var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
private func _erased(_ widget: Widget?) -> some Widget { AnyWidget() }

/// The widget an empty bundle holds. The port's own: Apple's `buildBlock()` answers `some Widget`, and a
/// bundle with nothing in it still has to be a widget.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct EmptyWidget: Widget {
    typealias Body = EmptyWidgetConfiguration
    var body: EmptyWidgetConfiguration { let empty = EmptyWidgetConfiguration(); return empty }
}
