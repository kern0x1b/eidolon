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
