import UIKit

public struct DatePickerComponents: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let hourAndMinute = DatePickerComponents(rawValue: 1)
    public static let date = DatePickerComponents(rawValue: 2)
}

public struct DatePicker<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public typealias Components = DatePickerComponents
    public var body: Never { neverBody(Self.self) }
    let selection: Binding<Date>
    let label: Label
    let components: DatePickerComponents
    let minimum: Date?
    let maximum: Date?
    func makeNode(_ env: EnvironmentValues) -> Node { let n = DatePickerNode(); n.update(self, env); return n }

    public init(selection: Binding<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.selection = selection; self.components = displayedComponents; self.label = label(); minimum = nil; maximum = nil
    }
    public init(selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.selection = selection; self.components = displayedComponents; self.label = label(); minimum = range.lowerBound; maximum = range.upperBound
    }
    public init(selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.selection = selection; self.components = displayedComponents; self.label = label(); minimum = range.lowerBound; maximum = nil
    }
    public init(selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.selection = selection; self.components = displayedComponents; self.label = label(); minimum = nil; maximum = range.upperBound
    }
}

extension DatePicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, displayedComponents: displayedComponents) { Text(titleKey) }
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(titleKey) }
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(titleKey) }
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(titleKey) }
    }
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, displayedComponents: displayedComponents) { Text(title) }
    }
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(title) }
    }
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(title) }
    }
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: DatePickerComponents = [.hourAndMinute, .date]) {
        self.init(selection: selection, in: range, displayedComponents: displayedComponents) { Text(title) }
    }
}

protocol DatePickerLike {
    var pickedDate: Binding<Date> { get }
    var pickedComponents: DatePickerComponents { get }
    var pickedLabel: any View { get }
    var pickedMinimum: Date? { get }
    var pickedMaximum: Date? { get }
}

extension DatePicker: DatePickerLike {
    var pickedDate: Binding<Date> { selection }
    var pickedComponents: DatePickerComponents { components }
    var pickedLabel: any View { label }
    var pickedMinimum: Date? { minimum }
    var pickedMaximum: Date? { maximum }
}

// iOS 6 has the wheel only, so the label sits above it, as SwiftUI puts it for the wheel style.
final class DatePickerNode: ContainerNode {
    let target = ControlTarget()
    let picker = UIDatePicker()
    var showsLabel = true

    override init() {
        super.init()
        picker.addTarget(target, action: #selector(ControlTarget.changed(_:)), for: .valueChanged)
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let source = view as? DatePickerLike else { return }
        let binding = source.pickedDate
        target.valueChanged = { binding.wrappedValue = ($0 as! UIDatePicker).date }
        if source.pickedComponents == .hourAndMinute {
            picker.datePickerMode = .time
        } else if source.pickedComponents.contains(.hourAndMinute) {
            picker.datePickerMode = .dateAndTime
        } else {
            picker.datePickerMode = .date
        }
        picker.minimumDate = source.pickedMinimum
        picker.maximumDate = source.pickedMaximum
        if abs(picker.date.timeIntervalSince(binding.wrappedValue)) > 1 { picker.date = binding.wrappedValue }
        showsLabel = !env.labelsHidden
        content = adopt(reconcile(content, showsLabel ? source.pickedLabel : EmptyView(), env))
    }

    override func mountContents() { super.mountContents(); uiView.addSubview(picker) }

    var labelNode: LayoutNode? { showsLabel ? children.first : nil }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let width = p.width ?? 320
        let label = labelNode?.sizeThatFits(ProposedSize(width: width, height: nil)) ?? .zero
        return CGSize(width: width, height: (label.height > 0 ? label.height + 4 : 0) + 216)
    }

    override func layoutContents(_ size: CGSize) {
        var y: CGFloat = 0
        if let label = labelNode {
            let wanted = label.sizeThatFits(ProposedSize(width: size.width, height: nil))
            label.place(CGRect(x: 0, y: 0, width: wanted.width, height: wanted.height))
            y = wanted.height + 4
        }
        picker.frame = CGRect(x: 0, y: y, width: size.width, height: 216)
    }
}
