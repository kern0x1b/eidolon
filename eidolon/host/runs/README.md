# tabletests

What `eidolon/tools/tabletests/run.sh` said with the port's `WidgetBundleBuilder` as it is, and with the
mutant added — one overload that takes a bare `if`'s `any Widget`, which the SDK of 26.2 does not have:

* `tabletests-clean.log` — exit 0, and the bare `if` in a bundle is rejected
* `tabletests-mutant.log` — exit 1, and it is not

The mutant is `static func buildOptional(_ widget: (any Widget)?) -> some Widget` in
`eidolon/Sources/SwiftUI/Widgets.swift`. Add it, build the module, run the tabletests, and the case
turns red; that is the point of keeping both logs here.
