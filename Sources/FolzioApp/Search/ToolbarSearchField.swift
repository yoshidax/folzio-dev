import AppKit

/// The toolbar search field that filters the file list by name (FR-380).
///
/// The standard search field shows the magnifying glass on the left and the clear button on the right while it has
/// text; the clear button and Esc remove the text (FR-381, FR-383). The owner sets the magnifying glass to open the
/// search sheet (FR-390). This subclass adds what the standard field does not provide:
/// - separate tooltips for the magnifying glass and for the rest of the field (FR-392), and
/// - ⌘F while the field has the keyboard focus, which reaches `findCommandTarget` (FR-390).
@MainActor
final class ToolbarSearchField: NSSearchField {
    /// Receives ⌘F (the "Find…" menu item) while this field has the keyboard focus. The toolbar is outside the
    /// window's content view, so the responder chain from the field does not reach the view controller that opens the
    /// search sheet. Other commands, such as the file operations, are not forwarded, so they never act on the
    /// selection in the file list or the tree while the user edits this field (EC-257).
    weak var findCommandTarget: AnyObject?

    /// Tooltip shown over the text area of the field.
    var fieldToolTip = "" {
        didSet { updateToolTips() }
    }

    /// Tooltip shown over the magnifying glass.
    var searchButtonToolTip = "" {
        didSet { updateToolTips() }
    }

    /// Tooltip rectangles do not retain their owners, so the strings are kept here.
    private var fieldToolTipOwner: NSString = ""
    private var searchButtonToolTipOwner: NSString = ""
    private var toolTipBounds: NSRect = .zero

    init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        // The field filters as the user types through its delegate. It has no recent searches menu.
        maximumRecents = 0
        recentsAutosaveName = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func supplementalTarget(forAction action: Selector, sender: Any?) -> Any? {
        if action == #selector(MainSplitViewController.showSearch(_:)), let findCommandTarget {
            return findCommandTarget
        }
        return super.supplementalTarget(forAction: action, sender: sender)
    }

    override func layout() {
        super.layout()
        if bounds != toolTipBounds {
            updateToolTips()
        }
    }

    /// Places one tooltip over the magnifying glass and another over the rest of the field.
    private func updateToolTips() {
        removeAllToolTips()
        toolTipBounds = bounds
        guard !bounds.isEmpty else { return }
        fieldToolTipOwner = fieldToolTip as NSString
        searchButtonToolTipOwner = searchButtonToolTip as NSString
        let buttonRect = (cell as? NSSearchFieldCell)?.searchButtonRect(forBounds: bounds) ?? .zero
        if !buttonRect.isEmpty, !searchButtonToolTip.isEmpty {
            _ = addToolTip(buttonRect, owner: searchButtonToolTipOwner, userData: nil)
        }
        var textRect = bounds
        if !buttonRect.isEmpty {
            textRect.size.width = max(0, bounds.maxX - buttonRect.maxX)
            textRect.origin.x = buttonRect.maxX
        }
        if !textRect.isEmpty, !fieldToolTip.isEmpty {
            _ = addToolTip(textRect, owner: fieldToolTipOwner, userData: nil)
        }
    }
}
