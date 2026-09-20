import UIKit

struct SwipeButton {
    let title: String
    let action: () -> Void
    let destructive: Bool
}

struct RowTraits {
    var badge: String?
    var deleteDisabled: Bool?
    var moveDisabled: Bool?
    var trailingSwipe: [SwipeButton]?
}

struct RowTraitModifier: NodeModifier {
    let apply: (inout RowTraits) -> Void
    var badge: String? = nil
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { RowTraitNode() }
}

final class RowTraitNode: Node {
    var child: Node?
    var apply: (inout RowTraits) -> Void = { _ in }
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        apply = (m.modifierValue as! RowTraitModifier).apply
        child = adopt(reconcile(child, m.modifiedContent, env))
        env.list?.traitsChanged()
    }
    override func mountContents() { child?.mount() }
}

func rowTraits(_ item: Node, upTo list: Node) -> RowTraits {
    var chain: [RowTraitNode] = []
    var current: Node? = item
    while let node = current, node !== list {
        if let trait = node as? RowTraitNode { chain.append(trait) }
        current = node.parent
    }
    var traits = RowTraits()
    for trait in chain.reversed() { trait.apply(&traits) }
    return traits
}

func swipeButtons(_ view: any View, destructive: Bool = false) -> [SwipeButton] {
    if let button = view as? ButtonLike {
        let role = (view as? RoleButtonLike)?.buttonRole
        return [SwipeButton(title: findText(button.buttonLabel)?.content ?? findLabelTitle(button.buttonLabel) ?? "",
                            action: button.buttonAction, destructive: destructive || role == .destructive)]
    }
    if let group = view as? GroupView { return group.childViews.flatMap { swipeButtons($0, destructive: destructive) } }
    if let modified = view as? ModifiedViewLike { return swipeButtons(modified.modifiedContent, destructive: destructive) }
    return []
}

func findLabelTitle(_ view: any View) -> String? {
    if let label = view as? LabelTitled { return findText(label.labelTitle)?.content }
    if let group = view as? GroupView { for child in group.childViews { if let found = findLabelTitle(child) { return found } } }
    return nil
}


protocol RoleButtonLike { var buttonRole: ButtonRole? { get } }

final class SwipeMenu: NSObject, UIActionSheetDelegate {
    nonisolated(unsafe) static var shown: SwipeMenu?
    let buttons: [SwipeButton]
    init(_ buttons: [SwipeButton]) { self.buttons = buttons }
    func actionSheet(_ actionSheet: UIActionSheet, clickedButtonAt buttonIndex: Int) {
        if buttonIndex >= 0 && buttonIndex < buttons.count { buttons[buttonIndex].action() }
        SwipeMenu.shown = nil
    }
    func show(in view: UIView) {
        let sheet = UIActionSheet()
        sheet.delegate = self
        for button in buttons { sheet.addButton(withTitle: button.title) }
        if let index = buttons.firstIndex(where: { $0.destructive }) { sheet.destructiveButtonIndex = index }
        sheet.addButton(withTitle: "Cancel")
        sheet.cancelButtonIndex = buttons.count
        SwipeMenu.shown = self
        sheet.show(in: view)
    }
}

extension View {
    public func deleteDisabled(_ disabled: Bool) -> some View {
        _ModifiedView(content: self, modifier: RowTraitModifier(apply: { $0.deleteDisabled = disabled }))
    }
    public func moveDisabled(_ disabled: Bool) -> some View {
        _ModifiedView(content: self, modifier: RowTraitModifier(apply: { $0.moveDisabled = disabled }))
    }
    public func swipeActions<T: View>(edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> T) -> some View {
        let buttons = swipeButtons(content())
        if edge == .leading {
            _Unsupported.note("swipeActions(edge: .leading)", "a UITableView row on iOS 6 swipes only from the trailing side")
        }
        return _ModifiedView(content: self, modifier: RowTraitModifier(apply: { traits in
            if edge == .trailing { traits.trailingSwipe = buttons }
        }))
    }
}
