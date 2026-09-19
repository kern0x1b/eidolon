import UIKit

public struct _AnyTableColumn<Row> {
    let title: String
    let cell: (Row) -> any View
}

public protocol TableColumnContent {
    associatedtype TableRowValue: Identifiable
    associatedtype TableColumnSortComparator
    associatedtype TableColumnBody
    var _columns: [_AnyTableColumn<TableRowValue>] { get }
}

public struct TableColumn<RowValue: Identifiable, Sort, Content: View, Label: View>: TableColumnContent {
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public typealias TableColumnBody = Content
    let title: String
    let cell: (RowValue) -> Content
    public var _columns: [_AnyTableColumn<RowValue>] { [_AnyTableColumn(title: title, cell: { cell($0) })] }
    public func width(_ width: CGFloat? = nil) -> Self { self }
    public func width(min: CGFloat? = nil, ideal: CGFloat? = nil, max: CGFloat? = nil) -> Self { self }
}

extension TableColumn where Sort == Never, Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: @escaping (RowValue) -> Content) {
        title = titleKey.text; cell = content
    }
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: @escaping (RowValue) -> Content) {
        self.title = String(title); cell = content
    }
}

extension TableColumn where Sort == Never, Label == Text, Content == Text {
    public init(_ titleKey: LocalizedStringKey, value: KeyPath<RowValue, String>) {
        title = titleKey.text; cell = { Text($0[keyPath: value]) }
    }
    public init<S: StringProtocol>(_ title: S, value: KeyPath<RowValue, String>) {
        self.title = String(title); cell = { Text($0[keyPath: value]) }
    }
}

public struct TupleTableColumnContent<RowValue: Identifiable, Sort, T>: TableColumnContent {
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public typealias TableColumnBody = Never
    public let value: T
    public let _columns: [_AnyTableColumn<RowValue>]
}

@resultBuilder
public struct TableColumnBuilder<RowValue: Identifiable, Sort> {
    public static func buildExpression<C: TableColumnContent>(_ column: C) -> C where C.TableRowValue == RowValue { column }
    public static func buildBlock<C: TableColumnContent>(_ column: C) -> C where C.TableRowValue == RowValue { column }
    public static func buildBlock<each C: TableColumnContent>(_ columns: repeat each C) -> TupleTableColumnContent<RowValue, Sort, (repeat each C)> {
        var all: [_AnyTableColumn<RowValue>] = []
        for column in repeat each columns {
            for part in column._columns { if let typed = part as? _AnyTableColumn<RowValue> { all.append(typed) } }
        }
        return TupleTableColumnContent(value: (repeat each columns), _columns: all)
    }
}

public protocol TableRowContent {
    associatedtype TableRowValue: Identifiable
    associatedtype TableRowBody
    var _rows: [TableRowValue] { get }
}

public struct TableRow<Value: Identifiable>: TableRowContent {
    public typealias TableRowValue = Value
    public typealias TableRowBody = Never
    let value: Value
    public init(_ value: Value) { self.value = value }
    public var _rows: [Value] { [value] }
}

public struct TableForEachContent<Data: RandomAccessCollection>: TableRowContent where Data.Element: Identifiable {
    public typealias TableRowValue = Data.Element
    public typealias TableRowBody = Never
    let data: Data
    public var _rows: [Data.Element] { Array(data) }
}

public struct EmptyTableRowContent<Value: Identifiable>: TableRowContent {
    public typealias TableRowValue = Value
    public typealias TableRowBody = Never
    public var _rows: [Value] { [] }
}

public struct TupleTableRowContent<Value: Identifiable, T>: TableRowContent {
    public typealias TableRowValue = Value
    public typealias TableRowBody = Never
    public let value: T
    public let _rows: [Value]
}

@resultBuilder
public struct TableRowBuilder<Value: Identifiable> {
    public static func buildExpression<R: TableRowContent>(_ row: R) -> R where R.TableRowValue == Value { row }
    public static func buildBlock() -> EmptyTableRowContent<Value> { EmptyTableRowContent() }
    public static func buildBlock<R: TableRowContent>(_ row: R) -> R where R.TableRowValue == Value { row }
    public static func buildBlock<each R: TableRowContent>(_ rows: repeat each R) -> TupleTableRowContent<Value, (repeat each R)> {
        var all: [Value] = []
        for row in repeat each rows {
            for item in row._rows { if let typed = item as? Value { all.append(typed) } }
        }
        return TupleTableRowContent(value: (repeat each rows), _rows: all)
    }
}

public protocol TableStyle {}
public struct AutomaticTableStyle: TableStyle { public init() {} }
public struct InsetTableStyle: TableStyle { public init() {} }
public struct BorderedTableStyle: TableStyle { public init() {} }
public struct TableStyleConfiguration {}
extension TableStyle where Self == AutomaticTableStyle { public static var automatic: AutomaticTableStyle { AutomaticTableStyle() } }
extension TableStyle where Self == InsetTableStyle { public static var inset: InsetTableStyle { InsetTableStyle() } }

public struct Table<Value: Identifiable, Rows: TableRowContent, Columns: TableColumnContent>: View where Rows.TableRowValue == Value, Columns.TableRowValue == Value {
    let rows: Rows
    let columns: Columns
    let selection: SelectionBox?
    public var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad { _Unsupported.pendingNote("Table columns on iPad") }
        let first = columns._columns.first
        var list = List { ForEach(rows._rows) { row -> AnyView in
            guard let first else { return AnyView(EmptyView()) }
            return AnyView(first.cell(row))
        } }
        list.selection = selection
        return list
    }
}

extension Table {
    public init<Data: RandomAccessCollection>(_ data: Data, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data.Element == Value {
        rows = TableForEachContent(data: data); self.columns = columns(); selection = nil
    }
    public init<Data: RandomAccessCollection>(_ data: Data, selection: Binding<Value.ID?>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data.Element == Value {
        rows = TableForEachContent(data: data); self.columns = columns()
        self.selection = SelectionBox(current: { selection.wrappedValue.map { [AnyHashable($0)] } ?? [] },
                                      choose: { if let value = $0.base as? Value.ID { selection.wrappedValue = value } },
                                      clear: { selection.wrappedValue = nil })
    }
    public init(@TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.rows = rows(); self.columns = columns(); selection = nil
    }
}

extension View {
    public func tableStyle<S: TableStyle>(_ style: S) -> some View { self }
}
