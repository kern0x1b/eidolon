import UIKit
import CoreGraphics

public struct Menu<Label: View, Content: View>: View, PrimitiveView, EnvironmentGroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let label: Label
    let content: Content
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content(); self.label = label()
    }
    var childViews: [any View] { [_MenuButton(label: label, content: content)] }
    func childViews(in env: EnvironmentValues) -> [any View] {
        guard let style = env.menuStyle else { return childViews }
        let configuration = MenuStyleConfiguration(label: .init(wrapped: label), content: .init(wrapped: content))
        return [withEnvironment(style(configuration)) { $0.menuStyle = nil }]
    }
}

extension Menu where Label == MenuStyleConfiguration.Label, Content == MenuStyleConfiguration.Content {
    public init(_ configuration: MenuStyleConfiguration) {
        self.init(content: { configuration.content }, label: { configuration.label })
    }
}

struct _MenuButton: View, PrimitiveView {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    let label: any View
    let content: any View
    func makeNode(_ env: EnvironmentValues) -> Node { let n = MenuNode(borderless: env.menuBorderless); n.update(self, env); return n }
}

extension Menu where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content, label: { Text(titleKey) })
    }
}

protocol MenuLike {
    var menuLabel: any View { get }
    var menuItems: [(String, () -> Void)] { get }
}

extension _MenuButton: MenuLike {
    var menuLabel: any View { label }
    var menuItems: [(String, () -> Void)] { menuEntries(content) }
}

func menuEntries(_ view: any View) -> [(String, () -> Void)] {
    var found: [(String, () -> Void)] = []
    func walk(_ value: any View) {
        if let button = value as? ButtonLike {
            found.append((findText(button.buttonLabel)?.content ?? "", button.buttonAction))
            return
        }
        if let group = value as? GroupView { group.childViews.forEach(walk) }
        if let modified = value as? ModifiedViewLike { walk(modified.modifiedContent) }
        if let wrapper = value as? WrappedView { walk(wrapper.wrapped) }
    }
    walk(view)
    return found
}

final class MenuNode: LayoutNode {
    let target = ControlTarget()
    let delegate = SheetDelegate()
    var items: [(String, () -> Void)] = []
    weak var host: UIViewController?
    var button: UIButton { uiView as! UIButton }

    init(borderless: Bool = false) {
        let control = UIButton(type: borderless ? .custom : .roundedRect)
        if borderless {
            control.setTitleColor(UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1), for: .normal)
            control.setTitleColor(UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 0.4), for: .highlighted)
        }
        super.init(view: control)
        control.addTarget(target, action: #selector(ControlTarget.fire), for: .touchUpInside)
        target.action = { [weak self] in self?.present() }
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let menu = view as? MenuLike else { return }
        host = env.host
        items = menu.menuItems
        let title = findText(menu.menuLabel)?.content ?? ""
        if button.title(for: .normal) != title { button.setTitle(title, for: .normal) }
    }

    func present() {
        guard let host else { return }
        let sheet = UIActionSheet()
        sheet.delegate = delegate
        delegate.actions = items.map { $0.1 }
        delegate.dismissed = {}
        for item in items { sheet.addButton(withTitle: item.0) }
        sheet.addButton(withTitle: "Cancel")
        sheet.cancelButtonIndex = items.count
        sheet.show(in: host.view)
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let wanted = button.sizeThatFits(CGSize(width: infinity, height: infinity))
        return CGSize(width: min(max(wanted.width + 24, 72), p.width ?? infinity), height: max(wanted.height, 37))
    }
}

public struct DisclosureGroup<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    let expanded: Binding<Bool>?

    public init(isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content(); self.label = label(); expanded = isExpanded
    }

    public var body: some View {
        _DisclosureBody(label: label, content: content, external: expanded)
    }
}

extension DisclosureGroup where Label == DisclosureGroupStyleConfiguration.Label, Content == DisclosureGroupStyleConfiguration.Content {
    public init(_ configuration: DisclosureGroupStyleConfiguration) {
        self.init(isExpanded: configuration.$isExpanded, content: { configuration.content }, label: { configuration.label })
    }
}

extension DisclosureGroup where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content, label: { Text(titleKey) })
    }
    public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.init(isExpanded: isExpanded, content: content, label: { Text(titleKey) })
    }
}

struct _DisclosureBody<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    let external: Binding<Bool>?
    @State private var internalExpanded = false
    @Environment(\.disclosureGroupStyle) var style

    var body: some View {
        let isExpanded = external ?? $internalExpanded
        if let style {
            let nested = withEnvironment(content) { $0.disclosureGroupStyle = style }
            let configuration = DisclosureGroupStyleConfiguration(label: .init(wrapped: label), content: .init(wrapped: nested), isExpanded: isExpanded)
            return AnyView(withEnvironment(style(configuration)) { $0.disclosureGroupStyle = nil })
        }
        return AnyView(_DisclosureChrome(label: label, content: content, isExpanded: isExpanded))
    }
}

struct _DisclosureChrome<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    let isExpanded: Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                label
                Spacer()
                Text(isExpanded.wrappedValue ? "▾" : "▸").foregroundColor(.gray)
            }
            .onTapGesture { isExpanded.wrappedValue.toggle() }
            if isExpanded.wrappedValue {
                content
            }
        }
    }
}

extension View {
    public func contextMenu<Content: View>(@ViewBuilder menuItems: @escaping () -> Content) -> some View {
        let items = menuEntries(menuItems())
        return onLongPressGesture {
            guard let window = UIApplication.shared.keyWindow, let root = window.rootViewController else { return }
            let sheet = UIActionSheet()
            let keeper = ContextMenuKeeper.shared
            keeper.delegate.actions = items.map { $0.1 }
            sheet.delegate = keeper.delegate
            for item in items { sheet.addButton(withTitle: item.0) }
            sheet.addButton(withTitle: "Cancel")
            sheet.cancelButtonIndex = items.count
            sheet.show(in: root.view)
        }
    }
}

final class ContextMenuKeeper {
    static let shared = ContextMenuKeeper()
    let delegate = SheetDelegate()
}

public struct DatePicker<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let selection: Binding<Date>
    let label: Label
    let components: DatePickerComponents
    func makeNode(_ env: EnvironmentValues) -> Node { let n = DatePickerNode(); n.update(self, env); return n }
}

public struct DatePickerComponents: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let hourAndMinute = DatePickerComponents(rawValue: 1)
    public static let date = DatePickerComponents(rawValue: 2)
}

extension DatePicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, displayedComponents: DatePickerComponents = [.date]) {
        self.init(selection: selection, label: Text(titleKey), components: displayedComponents)
    }
}

protocol DatePickerLike {
    var pickedDate: Binding<Date> { get }
    var pickedComponents: DatePickerComponents { get }
}

extension DatePicker: DatePickerLike {
    var pickedDate: Binding<Date> { selection }
    var pickedComponents: DatePickerComponents { components }
}

final class DatePickerNode: LayoutNode {
    let target = ControlTarget()
    var picker: UIDatePicker { uiView as! UIDatePicker }

    init() {
        super.init(view: UIDatePicker())
        picker.addTarget(target, action: #selector(ControlTarget.changed(_:)), for: .valueChanged)
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let source = view as? DatePickerLike else { return }
        let binding = source.pickedDate
        target.valueChanged = { binding.wrappedValue = ($0 as! UIDatePicker).date }
        if source.pickedComponents == .hourAndMinute {
            picker.datePickerMode = .time
        } else if source.pickedComponents.contains(.hourAndMinute) {
            picker.datePickerMode = .dateAndTime
        } else {
            picker.datePickerMode = .date
        }
        if abs(picker.date.timeIntervalSince(binding.wrappedValue)) > 1 { picker.date = binding.wrappedValue }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        CGSize(width: p.width ?? 320, height: 216)
    }
}
