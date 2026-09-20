import SwiftUI

struct Contact: Identifiable, Hashable {
    let id: Int
    var name: String
    var phone: String
    var favorite = false
}

struct ContactDetail: View {
    @Binding var contact: Contact
    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.fill").font(.system(size: 44)).foregroundColor(.white)
                            .frame(width: 84, height: 84).background(Circle().fill(Color.gray))
                        Text(contact.name).font(.title2).bold()
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section(header: Text("Details")) {
                LabeledContent("Phone", value: contact.phone)
                TextField("Name", text: $contact.name)
                Toggle(isOn: $contact.favorite) { Label("Favorite", systemImage: "star") }
            }
            Section {
                NavigationLink(destination: Text("Notes")) { Label("Notes", systemImage: "doc") }
                NavigationLink(destination: Text("History")) { Label("History", systemImage: "clock") }
            }
            Section {
                Button("Call") {}
                Button("Delete Contact", role: .destructive) {}
            }
        }
        .navigationTitle(contact.name)
    }
}

struct ContactsView: View {
    @State private var contacts = (1...12).map { Contact(id: $0, name: ["Alice", "Bob", "Carol", "Dave"][$0 % 4] + " \($0)", phone: "555-01\(String(format: "%02d", $0))", favorite: $0 % 5 == 0) }
    @State private var filter = "All"

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Favorites")) {
                    ForEach($contacts.filter { $0.wrappedValue.favorite }) { $contact in
                        NavigationLink(destination: ContactDetail(contact: $contact)) { Text(contact.name) }
                    }
                }
                Section(header: Text("All contacts")) {
                    ForEach($contacts) { $contact in
                        NavigationLink(destination: ContactDetail(contact: $contact)) {
                            HStack {
                                Text(contact.name)
                                Spacer()
                                if contact.favorite { Image(systemName: "star.fill").foregroundColor(.orange) }
                            }
                        }
                    }
                    .onDelete { contacts.remove(atOffsets: $0) }
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) { Button { } label: { Image(systemName: "plus") } }
            }
        }
    }
}
