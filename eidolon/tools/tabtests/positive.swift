import SwiftUI

// A tab's own value, and a content that yields tabs of it.
// a tab's value: it names the tab, and ForEach over it needs it to identify the element
struct Mailbox: Identifiable, Hashable { var id: String { folder }
    let folder: String
    let unread: Int }

struct MailTab: TabContent {
    let folder: String
    var body: some TabContent {
        TabContentList([folder], view: { name in AnyView(Text(name)) }, named: { AnyHashable($0) })
    }
}

// A ForEach of tab content is tab content of the content's tab value, and a TabView takes it.
func tabValuesReachATabView() {
    let mailboxes = [Mailbox(folder: "Inbox", unread: 2), Mailbox(folder: "Sent", unread: 0)]
    let tabs = ForEach<[Mailbox], Mailbox.ID, MailTab>(mailboxes) { box in MailTab(folder: box.folder) }
    let view = TabView {
        tabs
    }
    let selected = TabView(selection: Binding<Mailbox?>.constant(nil)) {
        ForEach<[Mailbox], Mailbox.ID, MailTab>(mailboxes) { box in MailTab(folder: box.folder) }
    }
    _ = (view, selected)
}

// The tabs a list yields, in order, each with the value that names it.
func tabListNamesItsRows() {
    let list = TabContentList([1, 2, 3], view: { AnyView(Text("\($0)")) }, named: { AnyHashable($0) })
    let values = list.rows.map { $0.value }
}
