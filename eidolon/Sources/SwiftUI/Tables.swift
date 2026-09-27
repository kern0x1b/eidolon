import UIKit

/// The two arms of an `if` in a builder, kept apart until the builder asks which one it got. The
/// shape and the storage enum are the ones OpenSwiftUI uses (MIT, commit b13f093dcc71).
public struct _ConditionalTableContent<TrueContent, FalseContent> {
    @frozen public enum Storage { case trueContent(TrueContent), falseContent(FalseContent) }
    public let storage: Storage
}

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
    // The three conditional forms below are the ones Apple's TableColumnBuilder declares, with Apple's
    // constraints: a builder that is one column wide cannot take two, and a builder that sorts cannot
    // be given a column that does not.
    public static func buildEither<T, F>(first: T) -> _ConditionalContent<T, F>
        where RowValue == T.TableRowValue, T: TableColumnContent, F: TableColumnContent,
              T.TableColumnSortComparator == Never, T.TableRowValue == F.TableRowValue,
              F.TableColumnSortComparator == Never { _ConditionalContent(storage: .trueContent(first)) }
    public static func buildEither<T, F>(second: F) -> _ConditionalContent<T, F>
        where RowValue == T.TableRowValue, Sort == T.TableColumnSortComparator, T: TableColumnContent, F: TableColumnContent,
              T.TableColumnSortComparator == F.TableColumnSortComparator, T.TableRowValue == F.TableRowValue {
        _ConditionalContent(storage: .falseContent(second))
    }
    @_disfavoredOverload
    public static func buildEither<T, F>(second: F) -> _ConditionalContent<T, F>
        where RowValue == T.TableRowValue, T: TableColumnContent, F: TableColumnContent,
              T.TableColumnSortComparator == Never, T.TableRowValue == F.TableRowValue,
              F.TableColumnSortComparator == Never { _ConditionalContent(storage: .falseContent(second)) }
    public static func buildLimitedAvailability<C: TableColumnContent>(_ content: C) -> C where C.TableRowValue == RowValue, C.TableColumnSortComparator == Sort { content }
    @_disfavoredOverload
    public static func buildLimitedAvailability<C: TableColumnContent>(_ content: C) -> C where C.TableRowValue == RowValue, C.TableColumnSortComparator == Never { content }
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
    // As above: Apple's TableRowBuilder conditional forms, with its constraints.
    public static func buildIf<C>(_ content: C?) -> C? where Value == C.TableRowValue, C: TableRowContent { content }
    public static func buildEither<T, F>(first: T) -> _ConditionalContent<T, F>
        where Value == T.TableRowValue, T: TableRowContent, F: TableRowContent, T.TableRowValue == F.TableRowValue {
        _ConditionalContent(storage: .trueContent(first))
    }
    public static func buildEither<T, F>(second: F) -> _ConditionalContent<T, F>
        where Value == T.TableRowValue, T: TableRowContent, F: TableRowContent, T.TableRowValue == F.TableRowValue {
        _ConditionalContent(storage: .falseContent(second))
    }
    public static func buildLimitedAvailability<C: TableRowContent>(_ content: C) -> C where C.TableRowValue == Value { content }
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

// What a view contributes to a Table's rows and columns. A view that is not part of that plumbing
// says so with Never, which is what the builders are then left with.
extension Group: TableRowContent, TableColumnContent {
    public typealias TableRowValue = Never
    public typealias TableRowBody = Never
    public typealias TableColumnSortComparator = Never
    public typealias TableColumnBody = Never
    public typealias TabValue = Never
    public var _rows: [Never] { [] }
    public var _columns: [_AnyTableColumn<Never>] { [] }
}

extension Section: TableRowContent, TableColumnContent {
    public typealias TableRowValue = Never
    public typealias TableRowBody = Never
    public typealias TableColumnSortComparator = Never
    public typealias TableColumnBody = Never
    public var _rows: [Never] { [] }
    public var _columns: [_AnyTableColumn<Never>] { [] }
}

extension OutlineGroup: TableRowContent, TableColumnContent {
    public typealias TableRowValue = Never
    public typealias TableRowBody = Never
    public typealias TableColumnSortComparator = Never
    public typealias TableColumnBody = Never
    public var _rows: [Never] { [] }
    public var _columns: [_AnyTableColumn<Never>] { [] }
}

extension ForEach: TableRowContent, TableColumnContent {
    public typealias TableRowValue = Never
    public typealias TableRowBody = Never
    public typealias TableColumnSortComparator = Never
    public typealias TableColumnBody = Never
    public typealias TabValue = Never
    public var _rows: [Never] { [] }
    public var _columns: [_AnyTableColumn<Never>] { [] }
}
