import SwiftUI

// An element that is not Hashable cannot be named as a tab's row, so this must not compile -- and the
// rejection has to come from this module's own constraint, not from the standard library's AnyHashable.
struct Untagged { let folder: String }

struct MailTab: TabContent {
    let folder: String
    var body: some TabContent {
        TabContentList([Untagged(folder: folder)], view: { _ in AnyView(Text(folder)) }, named: { AnyHashable($0) })
    }
}

func aTabValueMustBeHashable() {
    _ = TabView { MailTab(folder: "Inbox") }
}
