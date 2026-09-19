import UIKit

public protocol TabViewStyle {}
public struct DefaultTabViewStyle: TabViewStyle { public init() {} }
public typealias DefaultTabViewStyleMarker = DefaultTabViewStyle

public struct PageTabViewStyle: TabViewStyle {
    public enum IndexDisplayMode { case automatic, always, never }
    let indexDisplayMode: IndexDisplayMode
    public init(indexDisplayMode: IndexDisplayMode = .automatic) { self.indexDisplayMode = indexDisplayMode }
}

extension TabViewStyle where Self == DefaultTabViewStyle {
    public static var automatic: DefaultTabViewStyle { DefaultTabViewStyle() }
}
extension TabViewStyle where Self == PageTabViewStyle {
    public static var page: PageTabViewStyle { PageTabViewStyle() }
    public static func page(indexDisplayMode: PageTabViewStyle.IndexDisplayMode) -> PageTabViewStyle { PageTabViewStyle(indexDisplayMode: indexDisplayMode) }
}

public protocol IndexViewStyle {}
public struct PageIndexViewStyle: IndexViewStyle {
    public enum BackgroundDisplayMode { case automatic, always, interactive, never }
    let background: BackgroundDisplayMode
    public init(backgroundDisplayMode: BackgroundDisplayMode = .automatic) { background = backgroundDisplayMode }
}
extension IndexViewStyle where Self == PageIndexViewStyle {
    public static var page: PageIndexViewStyle { PageIndexViewStyle() }
    public static func page(backgroundDisplayMode: PageIndexViewStyle.BackgroundDisplayMode) -> PageIndexViewStyle { PageIndexViewStyle(backgroundDisplayMode: backgroundDisplayMode) }
}

struct PagingSettings {
    var showsIndex: PageTabViewStyle.IndexDisplayMode = .automatic
    var indexBackground: PageIndexViewStyle.BackgroundDisplayMode = .automatic
}

struct _BarTabs: View, PrimitiveView {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    let source: TabViewLike
    func makeNode(_ env: EnvironmentValues) -> Node { let n = TabViewNode(); n.update(self, env); return n }
}

struct _PagedTabs: View, PrimitiveView {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    let source: TabViewLike
    let settings: PagingSettings
    func makeNode(_ env: EnvironmentValues) -> Node { let n = PagedTabsNode(); n.update(self, env); return n }
}

final class PagingDelegate: NSObject, UIScrollViewDelegate {
    weak var node: PagedTabsNode?
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { node?.settle() }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { node?.settle() }
    @objc func dotsChanged() { node?.dotsChanged() }
}

final class PagedTabsNode: LayoutNode {
    let pagingDelegate = PagingDelegate()
    let scroller = UIScrollView()
    let dots = UIPageControl()
    var pages: [Node] = []
    var source: TabViewLike?
    var showsDots = true

    init() {
        super.init(view: UIView())
        scroller.isPagingEnabled = true
        scroller.showsHorizontalScrollIndicator = false
        pagingDelegate.node = self
        scroller.delegate = pagingDelegate
        uiView.addSubview(scroller)
        uiView.addSubview(dots)
        dots.addTarget(pagingDelegate, action: #selector(PagingDelegate.dotsChanged), for: .valueChanged)
    }

    override var disposableChildren: [Node] { pages }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let paged = view as! _PagedTabs
        source = paged.source
        let children = paged.source.tabChildren
        var next: [Node] = []
        for (index, child) in children.enumerated() {
            next.append(adopt(reconcile(index < pages.count ? pages[index] : nil, child, env)))
        }
        for old in pages.dropFirst(children.count) { old.dispose() }
        pages = next
        dots.numberOfPages = pages.count
        switch paged.settings.showsIndex {
        case .never: showsDots = false
        case .always: showsDots = true
        case .automatic: showsDots = pages.count > 1
        }
        dots.isHidden = !showsDots
        dots.backgroundColor = paged.settings.indexBackground == .always ? UIColor(white: 0, alpha: 0.25) : .clear
        mount()
        if let index = paged.source.tabSelectedIndex, index < pages.count, index != dots.currentPage {
            dots.currentPage = index
            scroller.setContentOffset(CGPoint(x: CGFloat(index) * scroller.bounds.size.width, y: 0), animated: Updates.animationForFlush != nil)
        }
    }

    override func mountContents() {
        syncSubviews(scroller, pages.flatMap { $0.flattened })
        pages.forEach { $0.mount() }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }

    override func layoutContents(_ size: CGSize) {
        scroller.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        for (index, page) in pages.enumerated() {
            for item in page.flattened {
                item.place(CGRect(x: CGFloat(index) * size.width, y: 0, width: size.width, height: size.height))
            }
        }
        scroller.contentSize = CGSize(width: size.width * CGFloat(pages.count), height: size.height)
        scroller.contentOffset = CGPoint(x: CGFloat(dots.currentPage) * size.width, y: 0)
        dots.frame = CGRect(x: 0, y: size.height - 36, width: size.width, height: 36)
    }

    var currentPage: Int {
        let width = max(scroller.bounds.size.width, 1)
        return max(0, min(pages.count - 1, Int((scroller.contentOffset.x + width / 2) / width)))
    }

    func settle() {
        let page = currentPage
        dots.currentPage = page
        source?.tabSelect(page)
    }

    func dotsChanged() {
        scroller.setContentOffset(CGPoint(x: CGFloat(dots.currentPage) * scroller.bounds.size.width, y: 0), animated: true)
        source?.tabSelect(dots.currentPage)
    }
}

extension View {
    public func tabViewStyle<S: TabViewStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            if let page = style as? PageTabViewStyle {
                var settings = environment.paging ?? PagingSettings()
                settings.showsIndex = page.indexDisplayMode
                environment.paging = settings
            } else {
                environment.paging = nil
            }
        }, onUpdate: nil))
    }
    public func indexViewStyle<S: IndexViewStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            guard let page = style as? PageIndexViewStyle, var settings = environment.paging else { return }
            settings.indexBackground = page.background
            environment.paging = settings
        }, onUpdate: nil))
    }
}
