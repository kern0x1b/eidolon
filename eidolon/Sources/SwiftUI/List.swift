import UIKit
import CoreGraphics

func firstEditable(_ node: Node?) -> EditableContent? {
    guard let node else { return nil }
    if let forEach = node as? ForEachNode, let editable = forEach.source as? EditableContent { return editable }
    if let group = node as? GroupNode {
        for child in group.children { if let found = firstEditable(child) { return found } }
    }
    if let composite = node as? CompositeNode { return firstEditable(composite.child) }
    if let section = node as? SectionNode { return firstEditable(section.content) }
    return nil
}

func topLevel(_ node: Node?) -> [Node] {
    guard let node else { return [] }
    if let group = node as? GroupNode { return group.children.flatMap { topLevel($0) } }
    if let composite = node as? CompositeNode { return topLevel(composite.child) }
    if node is SectionNode { return [node] }
    return [node]
}

public protocol ListStyle {}
public struct PlainListStyle: ListStyle { public init() {} }
public struct GroupedListStyle: ListStyle { public init() {} }

final class SelectionBox {
    let current: () -> Set<AnyHashable>
    let choose: (AnyHashable) -> Void
    let clear: () -> Void
    init(current: @escaping () -> Set<AnyHashable>, choose: @escaping (AnyHashable) -> Void, clear: @escaping () -> Void) {
        self.current = current; self.choose = choose; self.clear = clear
    }
}

public struct List<SelectionValue, Content>: View, PrimitiveView where SelectionValue: Hashable, Content: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: Content
    var selection: SelectionBox? = nil
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ListNode(grouped: env.listStyleGrouped); n.update(self, env); return n }
}

extension List where SelectionValue == Never {
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public init<Data: RandomAccessCollection, ID: Hashable, Row: View>(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder rowContent: @escaping (Data.Element) -> Row) where Content == ForEach<Data, ID, Row> {
        self.init { ForEach(data, id: id, content: rowContent) }
    }

    public init<Data: RandomAccessCollection, Row: View>(_ data: Data, @ViewBuilder rowContent: @escaping (Data.Element) -> Row) where Content == ForEach<Data, Data.Element.ID, Row>, Data.Element: Identifiable {
        self.init { ForEach(data, content: rowContent) }
    }

    public init<Row: View>(_ data: Range<Int>, @ViewBuilder rowContent: @escaping (Int) -> Row) where Content == ForEach<Range<Int>, Int, Row> {
        self.init { ForEach(data, content: rowContent) }
    }
}

extension List {
    public init(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> Content) {
        self.content = content()
        if let selection {
            self.selection = SelectionBox(current: { selection.wrappedValue.map { [AnyHashable($0)] } ?? [] },
                                          choose: { if let value = $0.base as? SelectionValue { selection.wrappedValue = value } },
                                          clear: { selection.wrappedValue = nil })
        }
    }
    public init(selection: Binding<Set<SelectionValue>>?, @ViewBuilder content: () -> Content) {
        self.content = content()
        if let selection {
            self.selection = SelectionBox(current: { Set(selection.wrappedValue.map { AnyHashable($0) }) },
                                          choose: { value in
                                              guard let typed = value.base as? SelectionValue else { return }
                                              if selection.wrappedValue.contains(typed) { selection.wrappedValue.remove(typed) } else { selection.wrappedValue.insert(typed) }
                                          },
                                          clear: { selection.wrappedValue = [] })
        }
    }
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {
        self.init(selection: selection) { ForEach(data, content: rowContent) }
    }
    public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, ID, RowContent> {
        self.init(selection: selection) { ForEach(data, id: id, content: rowContent) }
    }
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, selection: Binding<Set<SelectionValue>>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {
        self.init(selection: selection) { ForEach(data, content: rowContent) }
    }
}

protocol ListLike { var listContent: any View { get }; var listSelection: SelectionBox? { get } }
extension ListLike { var listSelection: SelectionBox? { nil } }
extension List: ListLike { var listContent: any View { content }; var listSelection: SelectionBox? { selection } }

public struct Section<Parent, Content, Footer> {
    let header: Parent
    let content: Content
    let footer: Footer
}

extension Section: View, PrimitiveView, SectionLike where Parent: View, Content: View, Footer: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    var sectionHeader: any View { header }
    var sectionContent: any View { content }
    var sectionFooter: any View { footer }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = SectionNode(); n.update(self, env); return n }
}

extension Section where Parent == EmptyView, Footer == EmptyView, Content: View {
    public init(@ViewBuilder content: () -> Content) {
        self.init(header: EmptyView(), content: content(), footer: EmptyView())
    }
}

extension Section where Parent: View, Footer: View, Content: View {
    public init(header: Parent, footer: Footer, @ViewBuilder content: () -> Content) {
        self.init(header: header, content: content(), footer: footer)
    }
}

extension Section where Parent: View, Footer == EmptyView, Content: View {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) {
        self.init(header: header(), content: content(), footer: EmptyView())
    }
    public init(header: Parent, @ViewBuilder content: () -> Content) {
        self.init(header: header, content: content(), footer: EmptyView())
    }
}

extension Section where Parent == Text, Footer == EmptyView, Content: View {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(header: Text(titleKey), content: content(), footer: EmptyView())
    }
}

protocol SectionLike {
    var sectionHeader: any View { get }
    var sectionContent: any View { get }
    var sectionFooter: any View { get }
}

final class SectionNode: Node {
    var content: Node?
    override var disposableChildren: [Node] { content.map { [$0] } ?? [] }
    var title: String?
    var footer: String?
    var prominent = false
    override var flattened: [LayoutNode] { content?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let section = view as? SectionLike else { return }
        prominent = env.headerProminent
        title = findText(section.sectionHeader)?.content
        footer = findText(section.sectionFooter)?.content
        content = adopt(reconcile(content, section.sectionContent, env))
    }
    override func mountContents() { content?.mount() }
}

final class ListRow: ContainerNode {
    var destination: (any View)?
    var tag: AnyHashable?
    var traits = RowTraits()
    var cell: UITableViewCell?
    override func computeSize(_ p: ProposedSize) -> CGSize {
        let s = children.first?.sizeThatFits(ProposedSize(width: p.width, height: nil)) ?? .zero
        return CGSize(width: p.width ?? s.width, height: s.height)
    }
    override func layoutContents(_ size: CGSize) {
        guard let kid = children.first else { return }
        let s = kid.sizeThatFits(ProposedSize(width: size.width, height: nil))
        kid.place(CGRect(x: 0, y: (size.height - s.height) / 2, width: size.width, height: s.height))
    }
}

final class ListController: NSObject, UITableViewDataSource, UITableViewDelegate {
    weak var node: ListNode?

    func numberOfSections(in tableView: UITableView) -> Int { node?.sections.count ?? 0 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let node, section < node.sections.count else { return nil }
        return node.sections[section].title
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let node, node.prominence[section] == true, let title = node.sections[section].title else { return nil }
        let holder = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 40))
        let label = UILabel(frame: CGRect(x: 20, y: 8, width: tableView.bounds.size.width - 40, height: 28))
        label.text = title
        label.font = UIFont.boldSystemFont(ofSize: 22)
        label.backgroundColor = .clear
        label.textColor = UIColor(red: 0.3, green: 0.34, blue: 0.42, alpha: 1)
        label.shadowColor = .white
        label.shadowOffset = CGSize(width: 0, height: 1)
        holder.addSubview(label)
        return holder
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let node, section < node.sections.count, node.prominence[section] == true, node.sections[section].title != nil else {
            return UITableView.automaticDimension
        }
        return 44
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let node, section < node.sections.count else { return nil }
        return node.sections[section].footer
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let node, section < node.sections.count else { return 0 }
        return node.sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let node, let row = node.row(at: indexPath) else { return UITableViewCell(style: .default, reuseIdentifier: nil) }
        let cell = row.cell ?? UITableViewCell(style: .default, reuseIdentifier: nil)
        row.cell = cell
        cell.accessoryType = row.destination != nil ? .disclosureIndicator : .none
        cell.accessoryView = row.traits.badge.map(badgeView)
        cell.selectionStyle = row.destination != nil || node.selection != nil ? .blue : .none
        if let selection = node.selection, let tag = row.tag, node.env.splitStage == nil {
            cell.accessoryType = selection.current().contains(tag) ? .checkmark : cell.accessoryType
        }
        row.mount()
        if row.uiView.superview !== cell.contentView { cell.contentView.addSubview(row.uiView) }
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let node, let row = node.row(at: indexPath) else { return 44 }
        let width = tableView.bounds.size.width - node.insetWidth
        return max(44, row.sizeThatFits(ProposedSize(width: width, height: nil)).height + 22)
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let node, let row = node.row(at: indexPath) else { return }
        let bounds = cell.contentView.bounds
        row.place(CGRect(x: bounds.origin.x + 10, y: bounds.origin.y, width: bounds.size.width - 20, height: bounds.size.height))
    }
    func canDelete(_ indexPath: IndexPath) -> Bool {
        guard let node, let row = node.row(at: indexPath) else { return false }
        if let swipe = row.traits.trailingSwipe { return !swipe.isEmpty }
        return node.editable?.deleteAction != nil && row.traits.deleteDisabled != true
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        canDelete(indexPath) || self.tableView(tableView, canMoveRowAt: indexPath)
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        canDelete(indexPath) ? .delete : .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        canDelete(indexPath)
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        guard let swipe = node?.row(at: indexPath)?.traits.trailingSwipe, let first = swipe.first else { return "Delete" }
        return swipe.count == 1 ? first.title : "More"
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard let node, node.editable?.moveAction != nil else { return false }
        return node.row(at: indexPath)?.traits.moveDisabled != true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, let node else { return }
        if let swipe = node.row(at: indexPath)?.traits.trailingSwipe {
            tableView.setEditing(false, animated: true)
            if swipe.count == 1 { swipe[0].action() } else { SwipeMenu(swipe).show(in: tableView) }
            return
        }
        node.editable?.deleteAction?(IndexSet(integer: indexPath.row))
    }

    func tableView(_ tableView: UITableView, moveRowAt source: IndexPath, to destination: IndexPath) {
        node?.editable?.moveAction?(IndexSet(integer: source.row), destination.row)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let node, let row = node.row(at: indexPath) else { return }
        if let selection = node.selection, let tag = row.tag {
            selection.choose(tag)
            node.env.splitPush?(selection.clear)
            return
        }
        guard let destination = row.destination else { return }
        pushDestination(destination, from: node.env)
    }
}

final class ListNode: LayoutNode {
    let controller = ListController()
    var content: Node?
    var rows: [ListRow] = []
    var sections: [(title: String?, footer: String?, rows: [ListRow])] = []
    var editable: EditableContent?
    var selection: SelectionBox?
    var prominence: [Int: Bool] = [:]
    let grouped: Bool
    var insetWidth: CGFloat { grouped ? 60 : 40 }
    init(grouped: Bool) {
        self.grouped = grouped
        super.init(view: UITableView(frame: .zero, style: grouped ? .grouped : .plain))
        controller.node = self
        let table = uiView as! UITableView
        table.dataSource = controller
        table.delegate = controller
    }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        var inner = env
        inner.list = self
        let table = uiView as! UITableView
        if env.scrollBackgroundHidden {
            table.backgroundView = nil
            table.backgroundColor = .clear
        }
        selection = (view as! ListLike).listSelection
        content = adopt(reconcile(content, (view as! ListLike).listContent, inner))
        syncRows()
    }

    func row(at indexPath: IndexPath) -> ListRow? {
        guard indexPath.section < sections.count else { return nil }
        let rows = sections[indexPath.section].rows
        return indexPath.row < rows.count ? rows[indexPath.row] : nil
    }

    func syncRows() {
        editable = firstEditable(content)
        var reusable = rows
        func take(_ item: LayoutNode) -> ListRow {
            let row = reusable.isEmpty ? ListRow() : reusable.removeFirst()
            if row.content !== item { row.cell = nil }
            row.content = item
            row.destination = (item as? NavigationLinkNode)?.destination
            row.traits = rowTraits(item, upTo: self)
            row.tag = rowTag(item, upTo: self)
            return row
        }
        var groups: [(title: String?, footer: String?, rows: [ListRow])] = []
        prominence = [:]
        var loose: [ListRow] = []
        for node in topLevel(content) {
            if let section = node as? SectionNode {
                if !loose.isEmpty { groups.append((nil, nil, loose)); loose = [] }
                groups.append((section.title, section.footer, section.flattened.map(take)))
                prominence[groups.count - 1] = section.prominent
            } else {
                loose.append(contentsOf: node.flattened.map(take))
            }
        }
        if !loose.isEmpty || groups.isEmpty { groups.append((nil, nil, loose)) }
        sections = groups
        rows = groups.flatMap { $0.rows }
        (uiView as! UITableView).reloadData()
    }
    func traitsChanged() {
        for row in rows { if let item = row.content { row.traits = rowTraits(item, upTo: self) } }
    }
    override func mountContents() { content?.mount() }
    override var disposableChildren: [Node] { content.map { [$0] } ?? [] }

    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }
}

func badgeView(_ text: String) -> UIView {
    let label = UILabel()
    label.text = text
    label.font = UIFont.boldSystemFont(ofSize: 14)
    label.textColor = .white
    label.textAlignment = .center
    label.backgroundColor = UIColor(red: 0.55, green: 0.6, blue: 0.7, alpha: 1)
    label.layer.cornerRadius = 10
    label.clipsToBounds = true
    let size = label.sizeThatFits(CGSize(width: 200, height: 20))
    label.frame = CGRect(x: 0, y: 0, width: max(24, size.width + 14), height: 20)
    return label
}

func rowTag(_ item: Node, upTo list: Node) -> AnyHashable? {
    var current: Node? = item
    while let node = current, node !== list {
        if let tagged = node as? TagNode { return tagged.tag }
        if let each = node.parent as? ForEachNode, let match = each.children.first(where: { $0.1 === node }) { return match.0 }
        current = node.parent
    }
    return nil
}
