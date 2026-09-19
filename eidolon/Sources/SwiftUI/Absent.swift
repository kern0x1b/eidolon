import UIKit
import CoreGraphics

public enum AccessibilityAdjustmentDirection { case increment, decrement }
public enum AccessibilityLabeledPairRole { case label, content }
public enum AccessibilityTextContentType { case plain, console, fileSystem, messaging, narrative, sourceCode, spreadsheet, wordProcessing }
public enum MoveCommandDirection { case up, down, left, right }
public struct PresentationDetent: Hashable {
    let name: String
    public static let medium = PresentationDetent(name: "medium")
    public static let large = PresentationDetent(name: "large")
    public static func height(_ height: CGFloat) -> PresentationDetent { PresentationDetent(name: "height") }
    public static func fraction(_ fraction: CGFloat) -> PresentationDetent { PresentationDetent(name: "fraction") }
}
public enum PresentationAdaptation { case automatic, none, popover, sheet, fullScreenCover }
public enum ToolbarRole { case automatic, navigationStack, browser, editor }
public enum MenuOrder { case automatic, priority, fixed }
public enum MenuActionDismissBehavior { case automatic, enabled, disabled }
public struct ContentTransition: Equatable {
    enum Kind: Equatable { case identity, fade }
    let kind: Kind
    public static let identity = ContentTransition(kind: .identity)
    public static let opacity = ContentTransition(kind: .fade)
    public static let interpolate = ContentTransition(kind: .fade)
    public static func numericText(countsDown: Bool = false) -> ContentTransition { ContentTransition(kind: .fade) }
}
public enum HoverPhase { case active(CGPoint), ended }
public enum HoverEffect { case automatic, highlight, lift }
public struct SymbolVariants { public static let none = SymbolVariants(); public static let fill = SymbolVariants(); public static let circle = SymbolVariants() }
public struct PreviewDevice: ExpressibleByStringLiteral {
    public init(stringLiteral: String) {}
    public init(rawValue: String) {}
}
public enum PreviewLayout { case device, sizeThatFits, fixed(width: CGFloat, height: CGFloat) }
public enum InterfaceOrientation { case portrait, portraitUpsideDown, landscapeLeft, landscapeRight }

extension View {
    public func accessibilityActions<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ignored(self, "accessibilityActions", "iOS 6 accessibility has no custom actions")
    }
    public func accessibilityCustomContent(_ label: Text, _ value: Text) -> some View {
        ignored(self, "accessibilityCustomContent", "iOS 6 accessibility has no custom content")
    }
    public func accessibilityLabeledPair<ID: Hashable>(role: AccessibilityLabeledPairRole, id: ID, in namespace: Namespace.ID) -> some View {
        ignored(self, "accessibilityLabeledPair", "iOS 6 accessibility has no labeled pairs")
    }
    public func accessibilityLinkedGroup<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        ignored(self, "accessibilityLinkedGroup", "iOS 6 accessibility has no linked groups")
    }
    public func accessibilityTextContentType(_ value: AccessibilityTextContentType) -> some View {
        ignored(self, "accessibilityTextContentType", "iOS 6 accessibility has no text content types")
    }
    public func speechAdjustedPitch(_ value: Double) -> some View {
        ignored(self, "speechAdjustedPitch", "iOS 6 has no speech attributes")
    }
    public func speechAlwaysIncludesPunctuation(_ value: Bool = true) -> some View {
        ignored(self, "speechAlwaysIncludesPunctuation", "iOS 6 has no speech attributes")
    }
    public func speechAnnouncementsQueued(_ value: Bool = true) -> some View {
        ignored(self, "speechAnnouncementsQueued", "iOS 6 has no speech attributes")
    }
    public func speechSpellsOutCharacters(_ value: Bool = true) -> some View {
        ignored(self, "speechSpellsOutCharacters", "iOS 6 has no speech attributes")
    }
    public func focusable(_ isFocusable: Bool = true) -> some View {
        ignored(self, "focusable", "iOS 6 has no focus engine")
    }
    public func focusSection() -> some View {
        ignored(self, "focusSection", "iOS 6 has no focus engine")
    }
    public func defaultFocus<V: Hashable>(_ binding: FocusState<V>.Binding, _ value: V) -> some View {
        ignored(self, "defaultFocus", "iOS 6 has no focus engine")
    }
    public func prefersDefaultFocus(_ prefersDefaultFocus: Bool = true, in namespace: Namespace.ID) -> some View {
        ignored(self, "prefersDefaultFocus", "iOS 6 has no focus engine")
    }
    public func draggable<T>(_ payload: @autoclosure @escaping () -> T) -> some View {
        ignored(self, "draggable", "iOS 6 has no drag and drop")
    }
    public func dropDestination<T>(for payloadType: T.Type, action: @escaping ([T], CGPoint) -> Bool) -> some View {
        ignored(self, "dropDestination", "iOS 6 has no drag and drop")
    }
    public func copyable<T>(_ payload: @autoclosure @escaping () -> [T]) -> some View {
        ignored(self, "copyable", "iOS 6 has no system copy command")
    }
    public func cuttable<T>(for payloadType: T.Type, action: @escaping () -> [T]) -> some View {
        ignored(self, "cuttable", "iOS 6 has no system cut command")
    }
    @available(iOS 8.0, *)
    public func itemProvider(_ action: (() -> NSItemProvider?)?) -> some View {
        ignored(self, "itemProvider", "iOS 6 has no item providers")
    }
    @available(iOS 8.0, *)
    public func onCopyCommand(perform payloadAction: (() -> [NSItemProvider])?) -> some View {
        ignored(self, "onCopyCommand", "the copy command is a desktop feature")
    }
    @available(iOS 8.0, *)
    public func onCutCommand(perform action: (() -> [NSItemProvider])?) -> some View {
        ignored(self, "onCutCommand", "the cut command is a desktop feature")
    }
    @available(iOS 8.0, *)
    public func onPasteCommand(of supportedTypes: [String], perform action: @escaping ([NSItemProvider]) -> Void) -> some View {
        ignored(self, "onPasteCommand", "the paste command is a desktop feature")
    }
    public func onDeleteCommand(perform action: (() -> Void)?) -> some View {
        ignored(self, "onDeleteCommand", "the delete command is a desktop feature")
    }
    public func onMoveCommand(perform action: ((MoveCommandDirection) -> Void)?) -> some View {
        ignored(self, "onMoveCommand", "the move command is a desktop feature")
    }
    public func onExitCommand(perform action: (() -> Void)?) -> some View {
        ignored(self, "onExitCommand", "the exit command is a desktop feature")
    }
    public func onPlayPauseCommand(perform action: (() -> Void)?) -> some View {
        ignored(self, "onPlayPauseCommand", "the play/pause command belongs to tvOS")
    }
    public func fileExporter<D>(isPresented: Binding<Bool>, document: D?, contentType: String, onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View {
        ignored(self, "fileExporter", "iOS 6 has no document browser")
    }
    public func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [String], onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View {
        ignored(self, "fileImporter", "iOS 6 has no document browser")
    }
    public func fileMover(isPresented: Binding<Bool>, file: URL?, onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View {
        ignored(self, "fileMover", "iOS 6 has no document browser")
    }
    public func renameAction(_ action: @escaping () -> Void) -> some View {
        ignored(self, "renameAction", "iOS 6 has no rename affordance")
    }
    public func findNavigator(isPresented: Binding<Bool>) -> some View {
        ignored(self, "findNavigator", "iOS 6 text views have no find navigator")
    }
    public func findDisabled(_ isDisabled: Bool = true) -> some View {
        ignored(self, "findDisabled", "iOS 6 text views have no find navigator")
    }
    public func replaceDisabled(_ isDisabled: Bool = true) -> some View {
        ignored(self, "replaceDisabled", "iOS 6 text views have no find navigator")
    }
    public func presentationDetents(_ detents: Set<PresentationDetent>) -> some View {
        ignored(self, "presentationDetents", "modal screens of iOS 6 are always full height")
    }
    public func presentationDragIndicator(_ visibility: Visibility) -> some View {
        ignored(self, "presentationDragIndicator", "modal screens of iOS 6 have no drag indicator")
    }
    public func presentationCornerRadius(_ cornerRadius: CGFloat?) -> some View {
        ignored(self, "presentationCornerRadius", "modal screens of iOS 6 have a fixed shape")
    }
    public func presentationBackground<S: ShapeStyle>(_ style: S) -> some View {
        ignored(self, "presentationBackground", "modal screens of iOS 6 have a fixed background")
    }
    public func presentationCompactAdaptation(_ adaptation: PresentationAdaptation) -> some View {
        ignored(self, "presentationCompactAdaptation", "iOS 6 has one presentation form")
    }
    public func toolbarColorScheme(_ colorScheme: ColorScheme?, for bars: ToolbarPlacement = .automatic) -> some View {
        if bars == .tabBar { _Unsupported.note("toolbarColorScheme(for: .tabBar)", "UITabBar of iOS 6 has no bar style") }
        return _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { _ in }, onUpdate: { environment in
            guard bars != .tabBar, let bar = environment.host?.navigationController?.navigationBar else { return }
            bar.barStyle = colorScheme == .dark ? .black : .default
        }))
    }
    public func toolbarRole(_ role: ToolbarRole) -> some View {
        ignored(self, "toolbarRole", "iOS 6 bars have one role")
    }
    public func menuIndicator(_ visibility: Visibility) -> some View {
        ignored(self, "menuIndicator", "the menu here is an action sheet of iOS 6")
    }
    public func menuOrder(_ order: MenuOrder) -> some View {
        ignored(self, "menuOrder", "the menu here is an action sheet of iOS 6")
    }
    public func menuActionDismissBehavior(_ behavior: MenuActionDismissBehavior) -> some View {
        ignored(self, "menuActionDismissBehavior", "the menu here is an action sheet of iOS 6")
    }
    public func hueRotation(_ angle: Angle) -> some View {
        ignored(self, "hueRotation", "iOS 6 has no layer filters")
    }
    public func luminanceToAlpha() -> some View {
        ignored(self, "luminanceToAlpha", "iOS 6 has no layer filters")
    }
    public func onHover(perform action: @escaping (Bool) -> Void) -> some View {
        ignored(self, "onHover", "iOS 6 has no pointer")
    }
    public func onContinuousHover(coordinateSpace: CoordinateSpace = .local, perform action: @escaping (HoverPhase) -> Void) -> some View {
        ignored(self, "onContinuousHover", "iOS 6 has no pointer")
    }
    public func hoverEffect(_ effect: HoverEffect = .automatic) -> some View {
        ignored(self, "hoverEffect", "iOS 6 has no pointer")
    }
    public func privacySensitive(_ sensitive: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            if sensitive && environment.redactionReasons.contains(.privacy) { environment.redactedDrawing = true }
        }, onUpdate: nil))
    }
    public func symbolVariant(_ variant: SymbolVariants) -> some View {
        ignored(self, "symbolVariant", "iOS 6 has no SF Symbols")
    }
    public func flipsForRightToLeftLayoutDirection(_ enabled: Bool) -> some View {
        ignored(self, "flipsForRightToLeftLayoutDirection", "UIView of iOS 6 has no semantic content attribute")
    }
    public func interactionActivityTrackingTag(_ tag: String) -> some View {
        ignored(self, "interactionActivityTrackingTag", "iOS 6 has no activity tracking")
    }
    public func handlesExternalEvents(preferring: Set<String>, allowing: Set<String>) -> some View {
        ignored(self, "handlesExternalEvents", "iOS 6 has no scenes")
    }
    @available(iOS 8.0, *)
    public func userActivity(_ activityType: String, isActive: Bool = true, _ update: @escaping (NSUserActivity) -> Void) -> some View {
        ignored(self, "userActivity", "iOS 6 has no user activities")
    }
    @available(iOS 8.0, *)
    public func onContinueUserActivity(_ activityType: String, perform action: @escaping (NSUserActivity) -> Void) -> some View {
        ignored(self, "onContinueUserActivity", "iOS 6 has no user activities")
    }
    public func navigationDocument<D>(_ document: D) -> some View {
        ignored(self, "navigationDocument", "iOS 6 navigation bars carry no document proxy")
    }
    public func previewDevice(_ value: PreviewDevice?) -> some View {
        ignored(self, "previewDevice", "previews belong to Xcode, not to the device")
    }
    public func previewLayout(_ value: PreviewLayout) -> some View {
        ignored(self, "previewLayout", "previews belong to Xcode, not to the device")
    }
    public func previewDisplayName(_ value: String?) -> some View {
        ignored(self, "previewDisplayName", "previews belong to Xcode, not to the device")
    }
    public func previewInterfaceOrientation(_ value: InterfaceOrientation) -> some View {
        ignored(self, "previewInterfaceOrientation", "previews belong to Xcode, not to the device")
    }
    public func statusBar(hidden: Bool) -> some View {
        statusBarHidden(hidden)
    }
    public func margins(_ edges: Edge.Set = .all, _ insets: CGFloat) -> some View {
        ignored(self, "margins", "iOS 6 containers have no margin system")
    }
    public func submitScope(_ isBlocking: Bool = true) -> some View {
        ignored(self, "submitScope", "iOS 6 has no submit scopes")
    }
    public func digitalCrownRotation<V: BinaryFloatingPoint>(_ binding: Binding<V>) -> some View {
        ignored(self, "digitalCrownRotation", "the digital crown belongs to watchOS")
    }
    public func horizontalRadioGroupLayout() -> some View {
        ignored(self, "horizontalRadioGroupLayout", "radio groups belong to macOS")
    }
    public func touchBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ignored(self, "touchBar", "the touch bar belongs to macOS")
    }
    public func onLongTouchGesture(minimumDuration: Double = 0.5, perform action: @escaping () -> Void, onTouchingChanged: ((Bool) -> Void)? = nil) -> some View {
        ignored(self, "onLongTouchGesture", "this gesture belongs to tvOS")
    }
}
