import UIKit
import CoreGraphics

public struct Slider<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let value: Binding<Double>
    let bounds: ClosedRange<Double>
    let step: Double?
    let onEditingChanged: (Bool) -> Void
    func makeNode(_ env: EnvironmentValues) -> Node { let n = SliderNode(); n.update(self, env); return n }
}

extension Slider where Label == EmptyView {
    public init(value: Binding<Double>, in bounds: ClosedRange<Double> = 0...1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(value: value, bounds: bounds, step: nil, onEditingChanged: onEditingChanged)
    }
    public init(value: Binding<Double>, in bounds: ClosedRange<Double>, step: Double, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(value: value, bounds: bounds, step: step, onEditingChanged: onEditingChanged)
    }
}

protocol SliderLike {
    var sliderValue: Binding<Double> { get }
    var sliderBounds: ClosedRange<Double> { get }
    var sliderStep: Double? { get }
    var sliderEditing: (Bool) -> Void { get }
}

extension Slider: SliderLike {
    var sliderValue: Binding<Double> { value }
    var sliderBounds: ClosedRange<Double> { bounds }
    var sliderStep: Double? { step }
    var sliderEditing: (Bool) -> Void { onEditingChanged }
}

final class SliderNode: LayoutNode {
    let target = ControlTarget()
    var slider: UISlider { uiView as! UISlider }
    init() {
        super.init(view: UISlider())
        slider.addTarget(target, action: #selector(ControlTarget.changed(_:)), for: .valueChanged)
    }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let s = view as? SliderLike else { return }
        slider.minimumValue = Float(s.sliderBounds.lowerBound)
        slider.maximumValue = Float(s.sliderBounds.upperBound)
        let binding = s.sliderValue
        let step = s.sliderStep
        target.valueChanged = { control in
            var value = Double((control as! UISlider).value)
            if let step, step > 0 { value = (value / step).rounded() * step }
            binding.wrappedValue = value
        }
        if abs(Double(slider.value) - binding.wrappedValue) > 0.0001 { slider.value = Float(binding.wrappedValue) }
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 200, height: 34) }
}

public struct Stepper<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let label: Label
    let onIncrement: (() -> Void)?
    let onDecrement: (() -> Void)?
    public init(onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, @ViewBuilder label: () -> Label) {
        self.label = label(); self.onIncrement = onIncrement; self.onDecrement = onDecrement
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = StepperNode(); n.update(self, env); return n }
}

extension Stepper where Label == Text {
    public init(_ titleKey: LocalizedStringKey, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?) {
        self.init(onIncrement: onIncrement, onDecrement: onDecrement) { Text(titleKey) }
    }
    public init<V: Strideable>(_ titleKey: LocalizedStringKey, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1) {
        self.init(onIncrement: {
            let next = value.wrappedValue.advanced(by: step)
            if next <= bounds.upperBound { value.wrappedValue = next }
        }, onDecrement: {
            let next = value.wrappedValue.advanced(by: -step)
            if next >= bounds.lowerBound { value.wrappedValue = next }
        }) { Text(titleKey) }
    }
}

protocol StepperLike {
    var stepperLabel: any View { get }
    var stepperIncrement: (() -> Void)? { get }
    var stepperDecrement: (() -> Void)? { get }
}

extension Stepper: StepperLike {
    var stepperLabel: any View { label }
    var stepperIncrement: (() -> Void)? { onIncrement }
    var stepperDecrement: (() -> Void)? { onDecrement }
}

final class StepperNode: ContainerNode {
    let stepper = UIStepper()
    let target = ControlTarget()
    var last: Double = 0

    override init() {
        super.init()
        stepper.minimumValue = -1e9
        stepper.maximumValue = 1e9
        stepper.addTarget(target, action: #selector(ControlTarget.changed(_:)), for: .valueChanged)
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let s = view as? StepperLike else { return }
        let up = s.stepperIncrement, down = s.stepperDecrement
        target.valueChanged = { [weak self] control in
            guard let self else { return }
            let value = (control as! UIStepper).value
            if value > self.last { up?() } else if value < self.last { down?() }
            self.last = value
        }
        content = adopt(reconcile(content, s.stepperLabel, env))
    }

    override func mountContents() { super.mountContents(); uiView.addSubview(stepper) }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let control = stepper.sizeThatFits(.zero)
        let label = children.first?.sizeThatFits(ProposedSize(width: (p.width ?? infinity) - control.width - 8, height: nil)) ?? .zero
        return CGSize(width: p.width ?? (label.width + 8 + control.width), height: max(label.height, control.height))
    }

    override func layoutContents(_ size: CGSize) {
        let control = stepper.sizeThatFits(.zero)
        stepper.frame = CGRect(x: size.width - control.width, y: (size.height - control.height) / 2, width: control.width, height: control.height)
        if let label = children.first {
            let wanted = label.sizeThatFits(ProposedSize(width: size.width - control.width - 8, height: nil))
            label.place(CGRect(x: 0, y: (size.height - wanted.height) / 2, width: wanted.width, height: wanted.height))
        }
    }
}

public struct ProgressView<Label: View, CurrentValueLabel: View>: View, PrimitiveView, EnvironmentGroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let value: Double?
    let total: Double
    var label: (any View)? = nil
    var currentValueLabel: (any View)? = nil
    var timer: (ClosedRange<Date>, Bool)? = nil

    init(value: Double?, total: Double) { self.value = value; self.total = total }

    var indicator: any View {
        if let (interval, countsDown) = timer {
            return TimelineView(.periodic(from: interval.lowerBound, by: 1)) { context in
                _ProgressIndicator(value: timerFraction(interval, context.date, countsDown), total: 1)
            }
        }
        return _ProgressIndicator(value: value, total: total)
    }

    var childViews: [any View] {
        let bar = indicator
        guard label != nil || currentValueLabel != nil else { return [bar] }
        let top = label.map { AnyView($0) }, bottom = currentValueLabel.map { AnyView($0) }
        if value == nil && timer == nil {
            return [VStack(spacing: 6) { AnyView(bar); top; bottom }]
        }
        return [VStack(alignment: .leading, spacing: 4) { top; AnyView(bar); bottom?.foregroundColor(.gray) }]
    }

    func childViews(in env: EnvironmentValues) -> [any View] {
        guard let style = env.progressViewStyle else { return childViews }
        let fraction = timer.map { timerFraction($0.0, Date(), $0.1) } ?? value.map { max(0, min(1, $0 / max(total, 0.0001))) }
        var configuration = ProgressViewStyleConfiguration(fractionCompleted: fraction)
        configuration.label = label.map { .init(content: $0) }
        configuration.currentValueLabel = currentValueLabel.map { .init(content: $0) }
        return [withEnvironment(style(configuration)) { $0.progressViewStyle = nil }]
    }
}

func timerFraction(_ interval: ClosedRange<Date>, _ now: Date, _ countsDown: Bool) -> Double {
    let length = max(interval.upperBound.timeIntervalSince(interval.lowerBound), 0.001)
    let elapsed = max(0, min(length, now.timeIntervalSince(interval.lowerBound)))
    return countsDown ? 1 - elapsed / length : elapsed / length
}

public struct DefaultDateProgressLabel: View {
    let interval: ClosedRange<Date>
    let countsDown: Bool
    public var body: some View {
        TimelineView(.periodic(from: interval.lowerBound, by: 1)) { context in
            let seconds = Int(countsDown ? max(0, interval.upperBound.timeIntervalSince(context.date)) : max(0, context.date.timeIntervalSince(interval.lowerBound)))
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
        }
    }
}

extension ProgressView where CurrentValueLabel == EmptyView {
    public init(@ViewBuilder label: () -> Label) {
        self.init(value: nil, total: 1); self.label = label()
    }
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0, @ViewBuilder label: () -> Label) {
        self.init(value: value.map(Double.init), total: Double(total)); self.label = label()
    }
}

extension ProgressView {
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {
        self.init(value: value.map(Double.init), total: Double(total)); self.label = label(); self.currentValueLabel = currentValueLabel()
    }
    public init(timerInterval: ClosedRange<Date>, countsDown: Bool = true, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {
        self.init(value: 0, total: 1); self.label = label(); self.currentValueLabel = currentValueLabel(); timer = (timerInterval, countsDown)
    }
}

extension ProgressView where Label == Text, CurrentValueLabel == EmptyView {
    public init(_ titleKey: LocalizedStringKey) { self.init(value: nil, total: 1); label = Text(titleKey) }
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S) { self.init(value: nil, total: 1); label = Text(title) }
    public init<V: BinaryFloatingPoint>(_ titleKey: LocalizedStringKey, value: V?, total: V = 1.0) {
        self.init(value: value.map(Double.init), total: Double(total)); label = Text(titleKey)
    }
    @_disfavoredOverload
    public init<S: StringProtocol, V: BinaryFloatingPoint>(_ title: S, value: V?, total: V = 1.0) {
        self.init(value: value.map(Double.init), total: Double(total)); label = Text(title)
    }
}

extension ProgressView where CurrentValueLabel == DefaultDateProgressLabel {
    public init(timerInterval: ClosedRange<Date>, countsDown: Bool = true, @ViewBuilder label: () -> Label) {
        self.init(value: 0, total: 1); self.label = label()
        currentValueLabel = DefaultDateProgressLabel(interval: timerInterval, countsDown: countsDown)
        timer = (timerInterval, countsDown)
    }
}

extension ProgressView where Label == EmptyView, CurrentValueLabel == DefaultDateProgressLabel {
    public init(timerInterval: ClosedRange<Date>, countsDown: Bool = true) {
        self.init(value: 0, total: 1)
        currentValueLabel = DefaultDateProgressLabel(interval: timerInterval, countsDown: countsDown)
        timer = (timerInterval, countsDown)
    }
}

struct _ProgressIndicator: View, PrimitiveView {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    let value: Double?
    let total: Double
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ProgressNode(); n.update(self, env); return n }
}

extension ProgressView where Label == EmptyView, CurrentValueLabel == EmptyView {
    public init(_ configuration: ProgressViewStyleConfiguration) {
        self.init(value: configuration.fractionCompleted, total: 1)
    }
}

extension ProgressView where Label == EmptyView, CurrentValueLabel == EmptyView {
    public init() { self.init(value: nil, total: 1) }
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0) {
        self.init(value: value.map(Double.init), total: Double(total))
    }
}

protocol ProgressLike {
    var progressValue: Double? { get }
    var progressTotal: Double { get }
}

extension _ProgressIndicator: ProgressLike {
    var progressValue: Double? { value }
    var progressTotal: Double { total }
}

final class ProgressNode: LayoutNode {
    let bar = UIProgressView(progressViewStyle: .default)
    let spinner = UIActivityIndicatorView(style: .gray)
    var indeterminate = true

    init() {
        super.init(view: UIView())
        uiView.backgroundColor = .clear
        uiView.addSubview(bar)
        uiView.addSubview(spinner)
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let p = view as? ProgressLike else { return }
        indeterminate = p.progressValue == nil
        bar.isHidden = indeterminate
        spinner.isHidden = !indeterminate
        if indeterminate {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
            bar.progress = Float(max(0, min(1, (p.progressValue ?? 0) / max(p.progressTotal, 0.0001))))
        }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        indeterminate ? spinner.sizeThatFits(.zero) : CGSize(width: p.width ?? 200, height: 9)
    }

    override func layoutContents(_ size: CGSize) {
        let box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        bar.frame = CGRect(x: 0, y: (size.height - 9) / 2, width: size.width, height: 9)
        spinner.frame = box
    }
}

public struct SecureField<Label: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let placeholder: String
    let text: Binding<String>
    func makeNode(_ env: EnvironmentValues) -> Node { let n = TextFieldNode(secure: true); n.update(self, env); return n }
}

extension SecureField where Label == Text {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>) {
        self.init(placeholder: titleKey.text, text: text)
    }
}

extension SecureField: TextFieldLike {
    var fieldPlaceholder: String { placeholder }
    var fieldText: Binding<String> { text }
}

public struct TextEditor: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let text: Binding<String>
    public init(text: Binding<String>) { self.text = text }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = TextEditorNode(); n.update(self, env); return n }
}

final class TextEditorDelegate: NSObject, UITextViewDelegate {
    var changed: (String) -> Void = { _ in }
    func textViewDidChange(_ textView: UITextView) { changed(textView.text ?? "") }
}

final class TextEditorNode: LayoutNode {
    let delegate = TextEditorDelegate()
    var textView: UITextView { uiView as! UITextView }
    init() {
        let view = UITextView()
        view.font = UIFont.systemFont(ofSize: 17)
        super.init(view: view)
        view.delegate = delegate
    }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let editor = view as? TextEditor else { return }
        let binding = editor.text
        delegate.changed = { binding.wrappedValue = $0 }
        if textView.text != binding.wrappedValue { textView.text = binding.wrappedValue }
        textView.font = env.fontValue ?? UIFont.systemFont(ofSize: 17)
        textView.textColor = env.foregroundColor ?? .black
    }
    override func computeSize(_ p: ProposedSize) -> CGSize {
        CGSize(width: p.width ?? 200, height: p.height ?? 120)
    }
}

public struct Picker<Label: View, SelectionValue: Hashable, Content: View>: View, PrimitiveView, EnvironmentGroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let selection: Binding<SelectionValue>
    let label: Label
    let content: Content
    public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.selection = selection; self.content = content(); self.label = label()
    }
    var childViews: [any View] { [_PickerControl(source: self)] }
    func childViews(in env: EnvironmentValues) -> [any View] {
        switch env.pickerPresentation {
        case .navigationLink:
            let current = pickerOptions.first { $0.0 == pickerSelected }?.1 ?? ""
            return [NavigationLink(destination: _PickerChoices(source: self, title: findText(label)?.content)) {
                HStack {
                    AnyView(label)
                    Spacer()
                    Text(current).foregroundColor(.gray)
                }
            }]
        case .inline:
            let source: PickerLike = self
            return pickerOptions.map { option in
                Button(action: { source.pickerSelect(option.0) }) {
                    HStack {
                        Text(option.1)
                        Spacer()
                        if option.0 == source.pickerSelected { Text("✓").foregroundColor(.accentColor) }
                    }
                }.buttonStyle(.plain)
            }
        default:
            return childViews
        }
    }
}

struct _PickerControl: View, PrimitiveView, PickerLike {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    let source: PickerLike
    var pickerOptions: [(AnyHashable, String)] { source.pickerOptions }
    var pickerSelected: AnyHashable { source.pickerSelected }
    func pickerSelect(_ value: AnyHashable) { source.pickerSelect(value) }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = PickerNode(); n.update(self, env); return n }
}

struct _PickerChoices: View {
    let source: PickerLike
    let title: String?
    @Environment(\.dismiss) var dismiss
    var body: some View {
        let close = dismiss
        return List {
            ForEach(source.pickerOptions.indices, id: \.self) { index in
                let option = source.pickerOptions[index]
                Button(action: { source.pickerSelect(option.0); close() }) {
                    HStack {
                        Text(option.1)
                        Spacer()
                        if option.0 == source.pickerSelected { Text("✓").foregroundColor(.accentColor) }
                    }
                }.buttonStyle(.plain)
            }
        }
        .navigationTitle(title ?? "")
    }
}

extension Picker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, content: content, label: { Text(titleKey) })
    }
}

protocol PickerLike {
    var pickerOptions: [(AnyHashable, String)] { get }
    var pickerSelected: AnyHashable { get }
    func pickerSelect(_ value: AnyHashable)
}

extension Picker: PickerLike {
    var pickerOptions: [(AnyHashable, String)] {
        taggedViews(content).map { tag, view in (tag, findText(view)?.content ?? "") }
    }
    var pickerSelected: AnyHashable { AnyHashable(selection.wrappedValue) }
    func pickerSelect(_ value: AnyHashable) {
        if let typed = value.base as? SelectionValue { selection.wrappedValue = typed }
    }
}

func taggedViews(_ view: any View) -> [(AnyHashable, any View)] {
    if let tagged = view as? TaggedViewLike { return [(tagged.tagValue, tagged.taggedContent)] }
    if let forEach = view as? ForEachLike { return forEach.identifiedViews.flatMap { taggedViews($0.1) } }
    if let group = view as? GroupView { return group.childViews.flatMap { taggedViews($0) } }
    return []
}

final class WheelDataSource: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    var titles: [String] = []
    var rowHeight: CGFloat?
    var selected: (Int) -> Void = { _ in }
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { rowHeight ?? 32 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { titles.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        row < titles.count ? titles[row] : nil
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) { selected(row) }
}

final class PickerNode: LayoutNode {
    let target = ControlTarget()
    var options: [(AnyHashable, String)] = []
    var select: (AnyHashable) -> Void = { _ in }
    var segmented: UISegmentedControl { uiView as! UISegmentedControl }
    var style: PickerPresentation = .segmented
    let wheelSource = WheelDataSource()
    let menuDelegate = SheetDelegate()

    init() {
        super.init(view: UISegmentedControl())
        segmented.addTarget(target, action: #selector(ControlTarget.changed(_:)), for: .valueChanged)
    }

    func switchTo(_ presentation: PickerPresentation, _ env: EnvironmentValues) {
        guard presentation != style || !(uiView is UISegmentedControl) || presentation != .segmented else { return }
        style = presentation
        switch presentation {
        case .segmented, .navigationLink, .inline:
            break
        case .wheel:
            let wheel = UIPickerView()
            wheel.dataSource = wheelSource
            wheel.delegate = wheelSource
            wheel.showsSelectionIndicator = true
            replaceView(wheel)
        case .menu:
            let button = UIButton(type: .roundedRect)
            button.addTarget(target, action: #selector(ControlTarget.fire), for: .touchUpInside)
            replaceView(button)
        }
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let picker = view as? PickerLike else { return }
        switchTo(env.pickerPresentation, env)
        let next = picker.pickerOptions
        if style != .segmented {
            options = next
            select = { picker.pickerSelect($0) }
            let selectedIndex = next.firstIndex(where: { $0.0 == picker.pickerSelected }) ?? 0
            if style == .wheel {
                wheelSource.titles = next.map { $0.1 }
                wheelSource.rowHeight = env.wheelRowHeight
                wheelSource.selected = { [weak self] row in
                    guard let self, row < self.options.count else { return }
                    self.select(self.options[row].0)
                }
                let wheel = uiView as! UIPickerView
                wheel.reloadAllComponents()
                if wheel.selectedRow(inComponent: 0) != selectedIndex { wheel.selectRow(selectedIndex, inComponent: 0, animated: false) }
            } else {
                let button = uiView as! UIButton
                let title = next.indices.contains(selectedIndex) ? next[selectedIndex].1 : ""
                if button.title(for: .normal) != title { button.setTitle(title, for: .normal) }
                let host = env.host
                menuDelegate.actions = next.map { option in { picker.pickerSelect(option.0) } }
                target.action = { [weak self] in
                    guard let self, let host else { return }
                    let sheet = UIActionSheet()
                    sheet.delegate = self.menuDelegate
                    for option in self.options { sheet.addButton(withTitle: option.1) }
                    sheet.addButton(withTitle: "Cancel")
                    sheet.cancelButtonIndex = self.options.count
                    sheet.show(in: host.view)
                }
            }
            return
        }
        if next.map({ $0.1 }) != options.map({ $0.1 }) {
            segmented.removeAllSegments()
            for (index, option) in next.enumerated() {
                segmented.insertSegment(withTitle: option.1, at: index, animated: false)
            }
        }
        options = next
        select = { picker.pickerSelect($0) }
        target.valueChanged = { [weak self] control in
            guard let self else { return }
            let index = (control as! UISegmentedControl).selectedSegmentIndex
            if index >= 0 && index < self.options.count { self.select(self.options[index].0) }
        }
        if let index = options.firstIndex(where: { $0.0 == picker.pickerSelected }), segmented.selectedSegmentIndex != index {
            segmented.selectedSegmentIndex = index
        }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        switch style {
        case .wheel: return CGSize(width: p.width ?? 320, height: 216)
        case .menu:
            let wanted = uiView.sizeThatFits(CGSize(width: infinity, height: infinity))
            return CGSize(width: min(max(wanted.width + 24, 72), p.width ?? infinity), height: max(wanted.height, 37))
        case .segmented, .navigationLink, .inline:
            let wanted = segmented.sizeThatFits(CGSize(width: p.width ?? infinity, height: infinity))
            return CGSize(width: min(p.width ?? wanted.width, max(wanted.width, 100)), height: max(wanted.height, 29))
        }
    }
}

public struct _TaggedView<Content: View, Tag: Hashable>: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: Content
    let tag: Tag
    var childViews: [any View] { [content] }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = TagNode(); n.update(self, env); return n }
}

final class TagNode: Node {
    var child: Node?
    var tag: AnyHashable?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let tagged = view as! TaggedViewLike
        tag = tagged.tagValue
        child = adopt(reconcile(child, tagged.taggedContent, env))
    }
    override func mountContents() { child?.mount() }
}

protocol TaggedViewLike {
    var tagValue: AnyHashable { get }
    var taggedContent: any View { get }
}

extension _TaggedView: TaggedViewLike {
    var tagValue: AnyHashable { AnyHashable(tag) }
    var taggedContent: any View { content }
}

public protocol TextFieldStyle {
    var _borderStyle: UITextField.BorderStyle { get }
}

public struct RoundedBorderTextFieldStyle: TextFieldStyle {
    public init() {}
    public var _borderStyle: UITextField.BorderStyle { .roundedRect }
}

public struct PlainTextFieldStyle: TextFieldStyle {
    public init() {}
    public var _borderStyle: UITextField.BorderStyle { .none }
}

public struct DefaultTextFieldStyle: TextFieldStyle {
    public init() {}
    public var _borderStyle: UITextField.BorderStyle { .roundedRect }
}

extension TextFieldStyle where Self == RoundedBorderTextFieldStyle {
    public static var roundedBorder: RoundedBorderTextFieldStyle { RoundedBorderTextFieldStyle() }
}

extension TextFieldStyle where Self == PlainTextFieldStyle {
    public static var plain: PlainTextFieldStyle { PlainTextFieldStyle() }
}

public protocol PickerStyle {}
public struct SegmentedPickerStyle: PickerStyle { public init() {} }
public struct DefaultPickerStyle: PickerStyle { public init() {} }
public struct InlinePickerStyle: PickerStyle { public init() {} }
public struct WheelPickerStyle: PickerStyle { public init() {} }
public struct MenuPickerStyle: PickerStyle { public init() {} }

enum PickerPresentation { case segmented, wheel, menu, navigationLink, inline }

public struct NavigationLinkPickerStyle: PickerStyle { public init() {} }
extension PickerStyle where Self == NavigationLinkPickerStyle {
    public static var navigationLink: NavigationLinkPickerStyle { NavigationLinkPickerStyle() }
}

extension PickerStyle where Self == WheelPickerStyle {
    public static var wheel: WheelPickerStyle { WheelPickerStyle() }
}

extension PickerStyle where Self == MenuPickerStyle {
    public static var menu: MenuPickerStyle { MenuPickerStyle() }
}

extension PickerStyle where Self == InlinePickerStyle {
    public static var inline: InlinePickerStyle { InlinePickerStyle() }
}

extension PickerStyle where Self == SegmentedPickerStyle {
    public static var segmented: SegmentedPickerStyle { SegmentedPickerStyle() }
}

extension View {
    public func tag<V: Hashable>(_ tag: V) -> some View { _TaggedView(content: self, tag: tag) }

    public func textFieldStyle<S: TextFieldStyle>(_ style: S) -> some View {
        let border = style._borderStyle
        return applyingToViews { view in
            if let field = view as? UITextField { field.borderStyle = border }
        }
    }

    public func pickerStyle<S: PickerStyle>(_ style: S) -> some View {
        let presentation: PickerPresentation
        if style is WheelPickerStyle { presentation = .wheel }
        else if style is MenuPickerStyle { presentation = .menu }
        else if style is InlinePickerStyle { presentation = .inline }
        else if style is NavigationLinkPickerStyle { presentation = .navigationLink }
        else { presentation = .segmented }
        return _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.pickerPresentation = presentation }, onUpdate: nil))
    }

    public func labelsHidden() -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.labelsHidden = true }, onUpdate: nil))
    }
}
