import SwiftUI

func check(_ condition: Bool, _ what: String) { if !condition { print("FAIL \(what)") } }

struct Row: Identifiable, Comparable { let id: Int; let name: String
    static func < (a: Row, b: Row) -> Bool { a.name < b.name } }

// A ForEach of rows feeds a table's row builder, and the row value is the element's own type.
func forEachRowsFeedATable() {
    let rows = [Row(id: 0, name: "a")]
    let table = Table(of: Row.self) {
        TableColumn("id") { (row: Row) in Text("\(row.id)") }
    } rows: {
        ForEach(rows) { TableRow($0) }
    }
    _ = table
}

// the row value a ForEach of TableRow carries is the element's own type, not Never
func elementIsTheRow<Each: TableRowContent>(_ each: Each.Type) where Each.TableRowValue == Row {}

func groupPassesTheRowValueThrough() {
    let group = Group { TableRow(Row(id: 1, name: "b")) }
    elementIsTheRow(Group<TableRow<Row>>.self)
    elementIsTheRow(ForEach<[Row], Int, TableRow<Row>>.self)
    _ = group
}

func aGroupOfColumnsIsColumnContent() {
    let column = Group { TableColumn("id") { (row: Row) in Text("\(row.id)") } }
    func sortValue<C: TableColumnContent>(_: C.Type) where C.TableColumnSortComparator == Never {}
    sortValue(Group<TableColumn<Row, Never, Text, Text>>.self)
    _ = column
}

// the sorted forms: the binding is the app's own and the table reads it
func sortedForms() {
    let nameKey = \Row.name
    var order: [KeyPathComparator<Row>] = []
    let byName = Binding(get: { order }, set: { order = $0 })
    let rows = [Row(id: 0, name: "a")]

    let overRows = Table(of: Row.self, sortOrder: byName) {
        TableColumn("name", value: nameKey)
    } rows: {
        ForEach(rows) { TableRow($0) }
    }
    let overData = Table(rows, sortOrder: byName) {
        TableColumn("name", value: nameKey)
    }
    let selected = Table(rows, selection: Binding<Row.ID?>.constant(nil), sortOrder: byName) {
        TableColumn("name", value: nameKey)
    }
    _ = (overRows, overData, selected)
}

// the order a tap on a sortable column's header writes: the same column again with the order turned,
// and a new column first and forward
func headerTapOrdering() {
    let ascending = KeyPathComparator(\Row.name)
    let descending = KeyPathComparator(\Row.name, ascending: false)
    let byID = KeyPathComparator(\Row.id)
    let forward = ascending.ordering([], after: \Row.name)
    let turned = ascending.ordering(forward, after: \Row.name)
    let moved = ascending.ordering(turned, after: \Row.id)
    check(forward == [ascending], "a new column goes first and forward")
    check(turned == [descending], "the same column again turns the order")
    check(moved == [byID, descending], "another column goes in front of the rest")
    _ = (ascending, descending, byID)
}

// an editable list: the rows are written against the element's own binding
func editableList(_ items: Binding<[Row]>) {
    let withId = List(items, editActions: .delete, id: \.id) { $row in
        Text($row.wrappedValue.name)
    }
    let plain = List(items, id: \Row.id) { $row in Text($row.wrappedValue.name) }
    let selected = List(items, selection: Binding<Row.ID?>.constant(nil)) { $row in
        Text($row.wrappedValue.name)
    }
    _ = (withId, plain, selected)
}
