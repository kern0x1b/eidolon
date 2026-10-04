import UIKit

/// One subview a container holds, with the identity and the container values it carries. It is what a
/// collection of a container's children hands back, and it is a view, so it can be laid out on its own.
public struct Subview: View, PrimitiveView, Identifiable {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }

    /// What tells two subviews apart: the identity of the content behind them, and where it sits.
    public struct ID: Hashable {
        let identity: AnyHashable
        let position: Int
        public static func == (a: Subview.ID, b: Subview.ID) -> Bool {
            a.identity == b.identity && a.position == b.position
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(identity)
            hasher.combine(position)
        }
        public var hashValue: Int { var hasher = Hasher(); hash(into: &hasher); return hasher.finalize() }
    }

    public let id: ID
    public let containerValues: ContainerValues
    let content: AnyView

    public init(_ content: some View) {
        self.content = AnyView(content)
        id = ID(identity: AnyHashable(ObjectIdentifier(content as AnyObject)), position: 0)
        containerValues = ContainerValues()
    }
    init(_ content: AnyView, id: ID, containerValues: ContainerValues) {
        self.content = content
        self.id = id
        self.containerValues = containerValues
    }
    public init(from decoder: any Decoder) throws { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "a subview is made by a container, not decoded")) }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id.hashValue)
    }
    func makeNode(_ env: EnvironmentValues) -> Node { content.makeNode(env) }
}

/// The children a container holds, in order, each one identified and carrying its container values. It
/// is the collection a `Section` hands to a table, a list and a stack; the slice is what a range of it
/// is, so a caller can take part of a container's children and still walk them.
public struct SubviewsCollection: RandomAccessCollection {
    public typealias Element = Subview
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias Iterator = IndexingIterator<SubviewsCollection>
    public typealias SubSequence = SubviewsCollectionSlice
    public let startIndex: Int
    public let endIndex: Int
    let children: [Subview]
    init(_ children: [Subview]) {
        self.children = children
        startIndex = 0
        endIndex = children.count
    }
    public subscript(index: Int) -> Subview { children[index] }
    public subscript(bounds: Range<Int>) -> SubviewsCollectionSlice {
        SubviewsCollectionSlice(Array(children[bounds]))
    }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
}

public struct SubviewsCollectionSlice: RandomAccessCollection {
    public typealias Element = Subview
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias Iterator = IndexingIterator<SubviewsCollectionSlice>
    public typealias SubSequence = SubviewsCollectionSlice
    public let startIndex: Int
    public let endIndex: Int
    let children: [Subview]
    init(_ children: [Subview]) {
        self.children = children
        startIndex = 0
        endIndex = children.count
    }
    public subscript(index: Int) -> Subview { children[index] }
    public subscript(bounds: Range<Int>) -> SubviewsCollectionSlice {
        SubviewsCollectionSlice(Array(children[bounds]))
    }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
}

/// A section a container knows about, as a `Section`'s content sees it: its identity, the container values
/// the container wrote for it, and its header, footer and rows as collections of subviews.
public struct SectionConfiguration: Identifiable {
    /// What tells two sections apart: the identity behind them and where they sit.
    public struct ID: Hashable {
        let identity: AnyHashable
        let position: Int
        public static func == (a: SectionConfiguration.ID, b: SectionConfiguration.ID) -> Bool {
            a.identity == b.identity && a.position == b.position
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(identity)
            hasher.combine(position)
        }
        public var hashValue: Int { var hasher = Hasher(); hash(into: &hasher); return hasher.finalize() }
    }

    /// The row actions a section offers -- a list's and a table's swipe actions, which the release's own
    /// table view carries on a row.
    public struct Actions {
        public var rowActions: [any View] = []
        public init() {}
    }

    public let id: ID
    public let containerValues: ContainerValues
    public let header: SubviewsCollection
    public let footer: SubviewsCollection
    public let content: SubviewsCollection
    public let actions: Actions
    init(id: ID, containerValues: ContainerValues, header: SubviewsCollection, footer: SubviewsCollection,
         content: SubviewsCollection, actions: Actions = Actions()) {
        self.id = id
        self.containerValues = containerValues
        self.header = header
        self.footer = footer
        self.content = content
        self.actions = actions
    }
}

/// The subviews a container holds, read as a collection: what `ForEach(subviews:)` takes, and what a
/// container hands a builder that asked for its children rather than for views.
public struct ForEachSubviewCollection<Content: View>: RandomAccessCollection {
    public typealias Element = Subview
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias Iterator = IndexingIterator<ForEachSubviewCollection>
    public typealias SubSequence = Slice<ForEachSubviewCollection>
    let children: [Subview]
    let content: (Subview) -> Content
    public init(_ children: SubviewsCollection, @ViewBuilder content: @escaping (Subview) -> Content) {
        self.children = Array(children)
        self.content = content
    }
    public var startIndex: Int { 0 }
    public var endIndex: Int { children.count }
    public subscript(index: Int) -> Subview { children[index] }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    /// The views this collection stands for, which is what a container lays out.
    public var views: [Content] { children.map { content($0) } }
}

/// What a `Group` holds when it is given a container's children rather than views: the group, and the
/// result of the transform the app applied to each child.
public struct GroupElementsOfContent<Subviews: View, Content: View>: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let subviews: Subviews
    let transformed: Content
    public var childViews: [any View] { [subviews, transformed] }
}
