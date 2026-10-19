import AppKit

@MainActor
final class MainSplitViewController: NSSplitViewController {
    private let treePane = PlaceholderViewController(message: "ディレクトリツリー")
    private let listPane = PlaceholderViewController(message: "ファイルリスト")
    private let previewPane = PlaceholderViewController(message: "プレビュー")
    private var appliedInitialPositions = false

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = true
        splitView.dividerStyle = .thin

        addSplitViewItem(makeItem(for: treePane, minimumThickness: 160, holdingPriority: 251))
        addSplitViewItem(makeItem(for: listPane, minimumThickness: 240, holdingPriority: 250))
        addSplitViewItem(makeItem(for: previewPane, minimumThickness: 320, holdingPriority: 249))

        splitView.autosaveName = "MainSplit"
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !appliedInitialPositions else { return }
        appliedInitialPositions = true

        let autosaveKey = "NSSplitView Subview Frames MainSplit"
        guard UserDefaults.standard.object(forKey: autosaveKey) == nil else { return }

        splitView.setPosition(220, ofDividerAt: 0)
        let secondDivider = 220 + splitView.dividerThickness + 360
        splitView.setPosition(secondDivider, ofDividerAt: 1)
    }

    private func makeItem(
        for viewController: NSViewController,
        minimumThickness: CGFloat,
        holdingPriority: Float
    ) -> NSSplitViewItem {
        let item = NSSplitViewItem(viewController: viewController)
        item.minimumThickness = minimumThickness
        item.canCollapse = false
        item.holdingPriority = NSLayoutConstraint.Priority(holdingPriority)
        return item
    }
}
