import SwiftUI

struct Row: Identifiable { let id: Int }

// A ForEach of rows feeds a table's row builder, and the row value is the element's own type.
func forEachRowsFeedATable() {
    let rows = [Row(id: 0)]
    let table = Table(of: Row.self) {
        TableColumn("id") { (row: Row) in Text("\(row.id)") }
    } rows: {
        TableForEachContent(rows) { TableRow($0) }
    }
    _ = table
}

// the row value a ForEach of TableRow carries is the element's own type, not Never
func elementIsTheRow<Each: TableRowContent>(_ each: Each.Type) where Each.TableRowValue == Row {
    let _: Each.TableRowValue = Row(id: 3)
}

func groupPassesTheRowValueThrough() {
    let group = Group { TableRow(Row(id: 1)) }
    func rowValue<G: TableRowContent>(_: G.Type) where G.TableRowValue == Row {}
    rowValue(Group<TableRow<Row>>.self)
    rowValue(ForEach<[Row], Int, TableRow<Row>>.self)
    _ = group
}

func aGroupOfColumnsIsColumnContent() {
    let column = Group { TableColumn("id") { (row: Row) in Text("\(row.id)") } }
    func sortValue<C: TableColumnContent>(_: C.Type) where C.TableColumnSortComparator == Never {}
    sortValue(Group<TableColumn<Row, Never, Text, Text>>.self)
    _ = column
}
