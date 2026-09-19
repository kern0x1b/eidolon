import UIKit
import CoreGraphics

public enum ColorScheme: CaseIterable { case light, dark }
public enum LayoutDirection: CaseIterable { case leftToRight, rightToLeft }
public enum ScenePhase: Comparable { case background, inactive, active }
public enum ControlSize: CaseIterable { case mini, small, regular, large }
public enum ContentSizeCategory: CaseIterable {
    case extraSmall, small, medium, large, extraLarge, extraExtraLarge, extraExtraExtraLarge
}
public enum UserInterfaceSizeClass { case compact, regular }

struct ColorSchemeKey: EnvironmentKey { static var defaultValue: ColorScheme { .light } }
struct LayoutDirectionKey: EnvironmentKey { static var defaultValue: LayoutDirection { .leftToRight } }
struct IsEnabledKey: EnvironmentKey { static var defaultValue: Bool { true } }
struct LocaleKey: EnvironmentKey { static var defaultValue: Locale { .current } }
struct CalendarKey: EnvironmentKey { static var defaultValue: Calendar { .current } }
struct TimeZoneKey: EnvironmentKey { static var defaultValue: TimeZone { .current } }
struct ScenePhaseKey: EnvironmentKey { static var defaultValue: ScenePhase { AppRuntime.scenePhase } }
struct SizeCategoryKey: EnvironmentKey { static var defaultValue: ContentSizeCategory { .large } }
struct ControlSizeKey: EnvironmentKey { static var defaultValue: ControlSize { .regular } }
struct HorizontalSizeClassKey: EnvironmentKey { static var defaultValue: UserInterfaceSizeClass? { nil } }
struct VerticalSizeClassKey: EnvironmentKey { static var defaultValue: UserInterfaceSizeClass? { nil } }
struct DisplayScaleKey: EnvironmentKey { static var defaultValue: CGFloat { UIScreen.main.scale } }
struct OpenURLKey: EnvironmentKey { static var defaultValue: OpenURLAction { OpenURLAction() } }

public struct OpenURLAction {
    public struct Result {
        enum Kind { case handled, discarded, system(URL?) }
        let kind: Kind
        public static let handled = Result(kind: .handled)
        public static let discarded = Result(kind: .discarded)
        public static let systemAction = Result(kind: .system(nil))
        public static func systemAction(_ url: URL) -> Result { Result(kind: .system(url)) }
    }
    let handler: ((URL) -> Result)?
    public init(handler: @escaping (URL) -> Result) { self.handler = handler }
    init() { handler = nil }
    public func callAsFunction(_ url: URL) { callAsFunction(url) { _ in } }
    public func callAsFunction(_ url: URL, completion: @escaping (Bool) -> Void) {
        let result = handler?(url) ?? .systemAction
        switch result.kind {
        case .handled: completion(true)
        case .discarded: completion(false)
        case .system(let other): completion(UIApplication.shared.openURL(other ?? url))
        }
    }
}

public struct DismissAction {
    let action: () -> Void
    public func callAsFunction() { action() }
}

struct DismissKey: EnvironmentKey { static var defaultValue: DismissAction { DismissAction(action: {}) } }

extension EnvironmentValues {
    public var colorScheme: ColorScheme {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }
    public var layoutDirection: LayoutDirection {
        get { self[LayoutDirectionKey.self] }
        set { self[LayoutDirectionKey.self] = newValue }
    }
    public var isEnabled: Bool {
        get { self[IsEnabledKey.self] }
        set { self[IsEnabledKey.self] = newValue }
    }
    public var locale: Locale {
        get { self[LocaleKey.self] }
        set { self[LocaleKey.self] = newValue }
    }
    public var calendar: Calendar {
        get { self[CalendarKey.self] }
        set { self[CalendarKey.self] = newValue }
    }
    public var timeZone: TimeZone {
        get { self[TimeZoneKey.self] }
        set { self[TimeZoneKey.self] = newValue }
    }
    public var scenePhase: ScenePhase {
        get { self[ScenePhaseKey.self] }
        set { self[ScenePhaseKey.self] = newValue }
    }
    public var sizeCategory: ContentSizeCategory {
        get { self[SizeCategoryKey.self] }
        set { self[SizeCategoryKey.self] = newValue }
    }
    public var controlSize: ControlSize {
        get { self[ControlSizeKey.self] }
        set { self[ControlSizeKey.self] = newValue }
    }
    public var horizontalSizeClass: UserInterfaceSizeClass? {
        get { self[HorizontalSizeClassKey.self] }
        set { self[HorizontalSizeClassKey.self] = newValue }
    }
    public var verticalSizeClass: UserInterfaceSizeClass? {
        get { self[VerticalSizeClassKey.self] }
        set { self[VerticalSizeClassKey.self] = newValue }
    }
    public var displayScale: CGFloat {
        get { self[DisplayScaleKey.self] }
        set { self[DisplayScaleKey.self] = newValue }
    }
    public var openURL: OpenURLAction {
        get { self[OpenURLKey.self] }
        set { self[OpenURLKey.self] = newValue }
    }
    public var dismiss: DismissAction {
        get { self[DismissKey.self] }
        set { self[DismissKey.self] = newValue }
    }
}

public struct Link<Label: View>: View {
    let destination: URL
    let label: Label
    @Environment(\.openURL) var openURL
    public init(destination: URL, @ViewBuilder label: () -> Label) {
        self.destination = destination; self.label = label()
    }
    public var body: some View {
        let open = openURL, url = destination
        return Button(action: { open(url) }) { label }
    }
}

extension Link where Label == Text {
    public init(_ titleKey: LocalizedStringKey, destination: URL) {
        self.init(destination: destination) { Text(titleKey) }
    }
}

@propertyWrapper
public struct ScaledMetric<Value: BinaryFloatingPoint>: DynamicProperty, DynamicPropertyInstaller {
    let value: Value
    public init(wrappedValue: Value, relativeTo textStyle: Font = .body) { value = wrappedValue }
    public var wrappedValue: Value { value }
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {}
}

final class NamespaceStorage {
    nonisolated(unsafe) static var next = 0
    let id: Int
    init() { NamespaceStorage.next += 1; id = NamespaceStorage.next }
}

@propertyWrapper
public struct Namespace: DynamicProperty, DynamicPropertyInstaller {
    public struct ID: Hashable {
        let value: Int
    }
    var storage: NamespaceStorage?
    public var wrappedValue: ID { ID(value: storage?.id ?? 0) }
    public init() {}
    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: Namespace.self)
        if let s = node.storages[key] as? NamespaceStorage {
            p.pointee.storage = s
        } else {
            let s = NamespaceStorage()
            node.storages[key] = s
            p.pointee.storage = s
        }
    }
}
