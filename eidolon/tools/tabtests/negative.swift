import SwiftUI

// A value that is not Hashable cannot name a tab, so this must not compile.
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
