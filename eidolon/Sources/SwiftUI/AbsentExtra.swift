import UIKit
import CoreGraphics

public struct FocusedValues {}
public protocol LayoutValueKey {
    associatedtype Value
    static var defaultValue: Value { get }
}
public enum PresentationBackgroundInteraction { case automatic, enabled, disabled }
public enum PresentationContentInteraction { case automatic, resizes, scrolls }

extension VerticalEdge {
    public struct Set: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let top = Set(rawValue: 1)
        public static let bottom = Set(rawValue: 2)
        public static let all = Set(rawValue: 3)
    }
}

extension View {
    public func accessibilityChartDescriptor<R>(_ representable: R) -> some View {
        ignored(self, "accessibilityChartDescriptor", "iOS 6 has no audio graphs")
    }
    public func accessibilityQuickAction<Content: View>(style: Any, @ViewBuilder content: () -> Content) -> some View {
        ignored(self, "accessibilityQuickAction", "iOS 6 has no assistive access quick actions")
    }
    public func accessibilityRotor<Content>(_ label: Text, @ViewBuilder entries: () -> Content) -> some View {
        ignored(self, "accessibilityRotor", "iOS 6 accessibility has no rotors")
    }
    public func accessibilityRotorEntry<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        ignored(self, "accessibilityRotorEntry", "iOS 6 accessibility has no rotors")
    }
    public func digitalCrownAccessory(_ visibility: Visibility) -> some View {
        ignored(self, "digitalCrownAccessory", "the digital crown belongs to watchOS")
    }
    public func exportableToServices<T>(_ payload: @escaping () -> [T]) -> some View {
        ignored(self, "exportableToServices", "iOS 6 has no share services of that kind")
    }
    @available(iOS 8.0, *)
    public func exportsItemProviders(_ contentTypes: [String], onExport: @escaping () -> [NSItemProvider]) -> some View {
        ignored(self, "exportsItemProviders", "iOS 6 has no item providers")
    }
    public func importableFromServices<T>(for payloadType: T.Type, action: @escaping ([T]) -> Bool) -> some View {
        ignored(self, "importableFromServices", "iOS 6 has no share services of that kind")
    }
    @available(iOS 8.0, *)
    public func importsItemProviders(_ contentTypes: [String], onImport: @escaping ([NSItemProvider]) -> Bool) -> some View {
        ignored(self, "importsItemProviders", "iOS 6 has no item providers")
    }
    public func focusScope(_ namespace: Namespace.ID) -> some View {
        ignored(self, "focusScope", "iOS 6 has no focus engine")
    }
    public func focusedValue<T>(_ keyPath: WritableKeyPath<FocusedValues, T?>, _ value: T) -> some View {
        ignored(self, "focusedValue", "iOS 6 has no focus engine")
    }
    public func focusedObject<T: ObservableObject>(_ object: T?) -> some View {
        ignored(self, "focusedObject", "iOS 6 has no focus engine")
    }
    public func focusedSceneValue<T>(_ keyPath: WritableKeyPath<FocusedValues, T?>, _ value: T) -> some View {
        ignored(self, "focusedSceneValue", "iOS 6 has no scenes")
    }
    public func focusedSceneObject<T: ObservableObject>(_ object: T?) -> some View {
        ignored(self, "focusedSceneObject", "iOS 6 has no scenes")
    }
    public func listRowPlatterColor(_ color: Color?) -> some View {
        ignored(self, "listRowPlatterColor", "platters belong to watchOS")
    }
    public func listRowSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View {
        ignored(self, "listRowSeparatorTint", "the table of iOS 6 has one separator colour")
    }
    public func listSectionSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View {
        ignored(self, "listSectionSeparatorTint", "the table of iOS 6 has one separator colour")
    }
    public func menuButtonStyle<S>(_ style: S) -> some View {
        ignored(self, "menuButtonStyle", "menu buttons belong to macOS")
    }
    public func onCommand(_ selector: Selector, perform action: (() -> Void)?) -> some View {
        ignored(self, "onCommand", "commands belong to macOS")
    }
    public func pageCommand<V: Strideable>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride) -> some View {
        ignored(self, "pageCommand", "page commands belong to tvOS")
    }
    public func pasteDestination<T>(for payloadType: T.Type, action: @escaping ([T]) -> Void) -> some View {
        ignored(self, "pasteDestination", "iOS 6 has no system paste destination")
    }
    public func presentationBackgroundInteraction(_ interaction: PresentationBackgroundInteraction) -> some View {
        ignored(self, "presentationBackgroundInteraction", "modal screens of iOS 6 always block the background")
    }
    public func presentationContentInteraction(_ behavior: PresentationContentInteraction) -> some View {
        ignored(self, "presentationContentInteraction", "modal screens of iOS 6 have one interaction mode")
    }
    public func presentedWindowStyle<S>(_ style: S) -> some View {
        ignored(self, "presentedWindowStyle", "windows belong to macOS")
    }
    public func presentedWindowToolbarStyle<S>(_ style: S) -> some View {
        ignored(self, "presentedWindowToolbarStyle", "windows belong to macOS")
    }
    public func previewContext<C>(_ value: C) -> some View {
        ignored(self, "previewContext", "previews belong to Xcode, not to the device")
    }
    public func toolbarTitleMenu<C: View>(@ViewBuilder content: () -> C) -> some View {
        ignored(self, "toolbarTitleMenu", "iOS 6 navigation bars have no title menu")
    }
    public func touchBarCustomizationLabel(_ label: Text) -> some View {
        ignored(self, "touchBarCustomizationLabel", "the touch bar belongs to macOS")
    }
    public func touchBarItemPresence(_ presence: Any) -> some View {
        ignored(self, "touchBarItemPresence", "the touch bar belongs to macOS")
    }
    public func touchBarItemPrincipal(_ principal: Bool = true) -> some View {
        ignored(self, "touchBarItemPrincipal", "the touch bar belongs to macOS")
    }
}
