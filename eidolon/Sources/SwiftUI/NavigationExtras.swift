import UIKit
import CoreGraphics

public struct ToolbarItemPlacement: Equatable {
    let leading: Bool
    public static let navigationBarLeading = ToolbarItemPlacement(leading: true)
    public static let navigationBarTrailing = ToolbarItemPlacement(leading: false)
    public static let primaryAction = ToolbarItemPlacement(leading: false)
    public static let cancellationAction = ToolbarItemPlacement(leading: true)
    public static let confirmationAction = ToolbarItemPlacement(leading: false)
    public static let automatic = ToolbarItemPlacement(leading: false)
}

public struct ToolbarItem<ID, Content: View>: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let placement: ToolbarItemPlacement
    let content: Content
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {
        self.placement = placement; self.content = content()
    }
    var childViews: [any View] { [content] }
}

protocol ToolbarItemLike {
    var itemPlacement: ToolbarItemPlacement { get }
    var itemContent: any View { get }
}

extension ToolbarItem: ToolbarItemLike {
    var itemPlacement: ToolbarItemPlacement { placement }
    var itemContent: any View { content }
}

final class BarButtonTarget: NSObject {
    var action: () -> Void = {}
    @objc func fire() { action() }
}

struct BarItemsModifier: NodeModifier {
    let leading: () -> any View
    let trailing: () -> any View
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { BarItemsNode() }
}

final class BarItemsNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    let leadingTarget = BarButtonTarget()
    let trailingTarget = BarButtonTarget()
    override var flattened: [LayoutNode] { child?.flattened ?? [] }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! BarItemsModifier
        child = adopt(reconcile(child, m.modifiedContent, env))
        guard let host = env.host else { return }
        host.navigationItem.leftBarButtonItem = barButton(modifier.leading(), leadingTarget)
        host.navigationItem.rightBarButtonItem = barButton(modifier.trailing(), trailingTarget)
    }

    func barButton(_ view: any View, _ target: BarButtonTarget) -> UIBarButtonItem? {
        guard let title = findText(view)?.content, !title.isEmpty else { return nil }
        target.action = findAction(view) ?? {}
        return UIBarButtonItem(title: title, style: .plain, target: target, action: #selector(BarButtonTarget.fire))
    }

    override func mountContents() { child?.mount() }
}

func findAction(_ view: any View) -> (() -> Void)? {
    if let button = view as? ButtonLike { return button.buttonAction }
    if let group = view as? GroupView {
        for child in group.childViews { if let action = findAction(child) { return action } }
    }
    if let modified = view as? ModifiedViewLike { return findAction(modified.modifiedContent) }
    if let wrapper = view as? WrappedView { return findAction(wrapper.wrapped) }
    return nil
}

public struct ActionSheet {
    let title: String
    let message: String?
    let buttons: [Alert.Button]
    public init(title: Text, message: Text? = nil, buttons: [Alert.Button] = [.cancel()]) {
        self.title = title.content
        self.message = message?.content
        self.buttons = buttons
    }
}

final class SheetDelegate: NSObject, UIActionSheetDelegate {
    var actions: [() -> Void] = []
    var dismissed: () -> Void = {}
    func actionSheet(_ actionSheet: UIActionSheet, clickedButtonAt buttonIndex: Int) {
        if buttonIndex >= 0 && buttonIndex < actions.count { actions[buttonIndex]() }
        dismissed()
    }
}

extension View {
    public func navigationBarItems<L: View, T: View>(leading: L, trailing: T) -> some View {
        _ModifiedView(content: self, modifier: BarItemsModifier(leading: { leading }, trailing: { trailing }))
    }
    public func navigationBarItems<L: View>(leading: L) -> some View {
        _ModifiedView(content: self, modifier: BarItemsModifier(leading: { leading }, trailing: { EmptyView() }))
    }
    public func navigationBarItems<T: View>(trailing: T) -> some View {
        _ModifiedView(content: self, modifier: BarItemsModifier(leading: { EmptyView() }, trailing: { trailing }))
    }
    @_disfavoredOverload
    public func toolbar<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        _ModifiedView(content: self, modifier: BarItemsModifier(
            leading: { toolbarSide(content(), leading: true) },
            trailing: { toolbarSide(content(), leading: false) }))
    }
    public func navigationBarHidden(_ hidden: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { _ in }, onUpdate: { env in
            env.host?.navigationController?.setNavigationBarHidden(hidden, animated: false)
        }))
    }
    public func navigationBarBackButtonHidden(_ hidden: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { _ in }, onUpdate: { env in
            env.host?.navigationItem.hidesBackButton = hidden
        }))
    }
    public func fullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }
    public func sheet<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        let isPresented = Binding<Bool>(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
        return sheet(isPresented: isPresented, onDismiss: onDismiss) {
            AnyView(item.wrappedValue.map { AnyView(content($0)) } ?? AnyView(EmptyView()))
        }
    }
}

func toolbarSide(_ view: any View, leading: Bool) -> any View {
    var found: [any View] = []
    func walk(_ value: any View) {
        if let item = value as? ToolbarItemLike {
            if item.itemPlacement.leading == leading { found.append(item.itemContent) }
            return
        }
        if let group = value as? GroupView { group.childViews.forEach(walk) }
    }
    walk(view)
    if found.isEmpty && !leading, findText(view) != nil, !(view is ToolbarItemLike) {
        return view
    }
    return found.first ?? EmptyView()
}

extension NavigationLink where Label == Text {
    public init(_ titleKey: LocalizedStringKey, destination: Destination, isActive: Binding<Bool>) {
        self.init(destination: destination, isActive: isActive) { Text(titleKey) }
    }
    public init<V: Hashable>(_ titleKey: LocalizedStringKey, destination: Destination, tag: V, selection: Binding<V?>) {
        self.init(destination: destination, tag: tag, selection: selection) { Text(titleKey) }
    }
}
