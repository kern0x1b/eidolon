import UIKit

public struct _IndexedIdentifier<Index, ID: Hashable> {
    let index: Index
    let id: ID
}

protocol _EditHooks {
    var deleteHook: ((IndexSet) -> Void)? { get }
    var moveHook: ((IndexSet, Int) -> Void)? { get }
}

public struct IndexedIdentifierCollection<Base: RandomAccessCollection, ID: Hashable>: RandomAccessCollection, _EditHooks where Base.Index: Hashable {
    let items: [_IndexedIdentifier<Base.Index, ID>]
    var deleteHook: ((IndexSet) -> Void)?
    var moveHook: ((IndexSet, Int) -> Void)?
    public var startIndex: Int { items.startIndex }
    public var endIndex: Int { items.endIndex }
    public subscript(position: Int) -> _IndexedIdentifier<Base.Index, ID> { items[position] }
}

public struct EditableCollectionContent<Content: View, Data>: View {
    let content: Content
    public var body: some View { content }
}

extension ForEach: EditableContent where Data: _EditHooks, Content: View {
    var deleteAction: ((IndexSet) -> Void)? { data.deleteHook }
    var moveAction: ((IndexSet, Int) -> Void)? { data.moveHook }
}

func indexed<C: RandomAccessCollection, ID: Hashable>(_ collection: C, id: KeyPath<C.Element, ID>) -> [_IndexedIdentifier<C.Index, ID>] where C.Index: Hashable {
    collection.indices.map { _IndexedIdentifier(index: $0, id: collection[$0][keyPath: id]) }
}

func elementBinding<C: MutableCollection>(_ data: Binding<C>, _ index: C.Index) -> Binding<C.Element> {
    Binding(get: { data.wrappedValue[index] }, set: { data.wrappedValue[index] = $0 })
}

extension ForEach where Content: View {
    public init<C: MutableCollection & RandomAccessCollection, R: View>(_ data: Binding<C>, @ViewBuilder content: @escaping (Binding<C.Element>) -> R) where Data == IndexedIdentifierCollection<C, ID>, ID == C.Element.ID, Content == EditableCollectionContent<R, C>, C.Element: Identifiable, C.Index: Hashable {
        self.init(data: IndexedIdentifierCollection(items: indexed(data.wrappedValue, id: \.id)), id: \.id) { item in
            EditableCollectionContent(content: content(elementBinding(data, item.index)))
        }
    }
    public init<C: MutableCollection & RandomAccessCollection, R: View>(_ data: Binding<C>, id: KeyPath<C.Element, ID>, @ViewBuilder content: @escaping (Binding<C.Element>) -> R) where Data == IndexedIdentifierCollection<C, ID>, Content == EditableCollectionContent<R, C>, C.Index: Hashable {
        self.init(data: IndexedIdentifierCollection(items: indexed(data.wrappedValue, id: id)), id: \.id) { item in
            EditableCollectionContent(content: content(elementBinding(data, item.index)))
        }
    }
    public init<C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, R: View>(_ data: Binding<C>, editActions: EditActions<C>, @ViewBuilder content: @escaping (Binding<C.Element>) -> R) where Data == IndexedIdentifierCollection<C, ID>, ID == C.Element.ID, Content == EditableCollectionContent<R, C>, C.Element: Identifiable, C.Index: Hashable {
        var collection = IndexedIdentifierCollection<C, ID>(items: indexed(data.wrappedValue, id: \.id))
        if editActions.contains(.delete) { collection.deleteHook = { data.wrappedValue.remove(atOffsets: $0) } }
        if editActions.contains(.move) { collection.moveHook = { data.wrappedValue.move(fromOffsets: $0, toOffset: $1) } }
        self.init(data: collection, id: \.id) { item in
            EditableCollectionContent(content: content(elementBinding(data, item.index)))
        }
    }
}

extension List where SelectionValue == Never {
    public init<C: MutableCollection & RandomAccessCollection, R: View>(_ data: Binding<C>, @ViewBuilder rowContent: @escaping (Binding<C.Element>) -> R) where Content == ForEach<IndexedIdentifierCollection<C, C.Element.ID>, C.Element.ID, EditableCollectionContent<R, C>>, C.Element: Identifiable, C.Index: Hashable {
        self.init { ForEach(data, content: rowContent) }
    }
    public init<C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, R: View>(_ data: Binding<C>, editActions: EditActions<C>, @ViewBuilder rowContent: @escaping (Binding<C.Element>) -> R) where Content == ForEach<IndexedIdentifierCollection<C, C.Element.ID>, C.Element.ID, EditableCollectionContent<R, C>>, C.Element: Identifiable, C.Index: Hashable {
        self.init { ForEach(data, editActions: editActions, content: rowContent) }
    }
}
