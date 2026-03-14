import AppKit

// MARK: - Slash item definition

struct SlashItem: @unchecked Sendable {
    let icon: String
    let title: String
    let description: String
    let apply: (_ textView: NSTextView, _ slashRange: NSRange) -> Void
}

nonisolated(unsafe) let allSlashItems: [SlashItem] = [
    SlashItem(icon: "•", title: "Bullet Point", description: "Insert a bullet list item") { tv, range in
        prefixCurrentParagraph("• ", erasing: range, in: tv)
    },
    SlashItem(icon: "☐", title: "To-Do", description: "Insert a task item") { tv, range in
        prefixCurrentParagraphWithCheckbox(erasing: range, in: tv)
    },
]

/// Deletes `slashRange` (the "/" + query) then inserts `prefix` at the
/// start of that paragraph. Groups everything into a single undo action.
private func prefixCurrentParagraph(_ prefix: String, erasing slashRange: NSRange, in tv: NSTextView) {
    let str       = tv.string as NSString
    let paraRange = str.paragraphRange(for: NSRange(location: slashRange.location, length: 0))

    tv.undoManager?.beginUndoGrouping()

    // Erase "/" + query
    tv.insertText("", replacementRange: slashRange)

    let attrs      = tv.typingAttributes
    let attrPrefix = NSAttributedString(string: prefix, attributes: attrs)
    tv.textStorage?.insert(attrPrefix, at: paraRange.location)

    // Reset typing attributes so the text the user types after the prefix is normal
    let slateTV = tv as? SlateTextView
    var normalAttrs = tv.typingAttributes
    normalAttrs[.foregroundColor] = slateTV?.themeTextColor ?? NSColor.labelColor
    normalAttrs.removeValue(forKey: .strikethroughStyle)
    tv.typingAttributes = normalAttrs

    // Park caret right after the prefix
    let newCaret = paraRange.location + (prefix as NSString).length
    tv.setSelectedRange(NSRange(location: newCaret, length: 0))

    tv.undoManager?.endUndoGrouping()
}

/// Deletes `slashRange` then inserts a `CheckboxAttachment` + space at the
/// start of that paragraph. Groups everything into a single undo action.
private func prefixCurrentParagraphWithCheckbox(erasing slashRange: NSRange, in tv: NSTextView) {
    let str       = tv.string as NSString
    let paraRange = str.paragraphRange(for: NSRange(location: slashRange.location, length: 0))

    tv.undoManager?.beginUndoGrouping()

    // Erase "/" + query
    tv.insertText("", replacementRange: slashRange)

    // Build CheckboxAttachment + trailing space
    let attachment = CheckboxAttachment(isChecked: false)
    let attrStr    = NSMutableAttributedString(attachment: attachment)

    let slateTV = tv as? SlateTextView
    var spaceAttrs = tv.typingAttributes
    spaceAttrs[.foregroundColor] = slateTV?.themeTextColor ?? NSColor.labelColor
    spaceAttrs.removeValue(forKey: .strikethroughStyle)

    // Apply full paragraph style (incl. lineSpacing) to the attachment char so
    // line height matches normal text lines
    attrStr.addAttributes(spaceAttrs, range: NSRange(location: 0, length: 1))
    attrStr.append(NSAttributedString(string: " ", attributes: spaceAttrs))

    tv.textStorage?.insert(attrStr, at: paraRange.location)
    tv.typingAttributes = spaceAttrs

    // Park caret after attachment + space (U+FFFC + " " = 2 chars)
    tv.setSelectedRange(NSRange(location: paraRange.location + 2, length: 0))

    tv.undoManager?.endUndoGrouping()
}

// MARK: - Floating panel

final class SlashMenuPanel: NSPanel {

    private(set) var filteredItems: [SlashItem] = []
    private(set) var selectedIndex: Int = 0
    private let isDark: Bool

    private var contentStack: NSStackView!
    private var rowViews: [SlashRowView] = []

    var onConfirm: ((SlashItem) -> Void)?

    // MARK: Init

    init(isDark: Bool) {
        self.isDark = isDark
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 8),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        hasShadow = true
        backgroundColor = .clear
        becomesKeyOnlyIfNeeded = true
        setupUI()
    }

    // MARK: Public API

    func update(items: [SlashItem], query: String) {
        filteredItems = query.isEmpty
            ? items
            : items.filter { $0.title.lowercased().contains(query.lowercased()) }
        selectedIndex = 0
        rebuildRows()
    }

    func selectNext() {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, filteredItems.count - 1)
        updateHighlight()
    }

    func selectPrevious() {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
        updateHighlight()
    }

    func confirmSelection() {
        guard selectedIndex < filteredItems.count else { return }
        onConfirm?(filteredItems[selectedIndex])
    }

    // MARK: Setup

    private func setupUI() {
        let bg = NSView()
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 8
        bg.layer?.backgroundColor = isDark
            ? NSColor(white: 0.2, alpha: 1).cgColor
            : NSColor(white: 0.93, alpha: 1).cgColor
        bg.layer?.borderWidth = 1
        bg.layer?.borderColor = isDark
            ? NSColor(white: 1, alpha: 0.08).cgColor
            : NSColor(white: 0, alpha: 0.08).cgColor

        contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .leading
        contentStack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        bg.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: bg.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
        ])

        contentView = bg
    }

    // MARK: Private

    private func rebuildRows() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rowViews = []

        for (i, item) in filteredItems.enumerated() {
            let row = SlashRowView(item: item, isDark: isDark, selected: i == selectedIndex)
            row.onTap = { [weak self] in self?.onConfirm?(item) }
            row.widthAnchor.constraint(equalToConstant: 240).isActive = true
            contentStack.addArrangedSubview(row)
            rowViews.append(row)
        }

        let rowH: CGFloat = 54
        let total = CGFloat(filteredItems.count) * rowH + 8
        setContentSize(NSSize(width: 240, height: total))
    }

    private func updateHighlight() {
        for (i, row) in rowViews.enumerated() {
            row.setSelected(i == selectedIndex)
        }
    }
}

// MARK: - Row view

final class SlashRowView: NSView {

    var onTap: (() -> Void)?

    private let highlightView = NSView()
    private let iconLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let descLabel = NSTextField(labelWithString: "")

    init(item: SlashItem, isDark: Bool, selected: Bool) {
        super.init(frame: .zero)
        iconLabel.stringValue = item.icon
        titleLabel.stringValue = item.title
        descLabel.stringValue = item.description
        setup(isDark: isDark)
        setSelected(selected)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(isDark: Bool) {
        let textPrimary: NSColor = isDark ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.1, alpha: 1)
        let textMuted:   NSColor = isDark ? NSColor(white: 0.5,  alpha: 1) : NSColor(white: 0.55, alpha: 1)

        highlightView.wantsLayer = true
        highlightView.layer?.cornerRadius = 4

        iconLabel.font  = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        iconLabel.textColor = textMuted
        iconLabel.alignment = .center

        titleLabel.font  = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = textPrimary

        descLabel.font  = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        descLabel.textColor = textMuted

        [highlightView, iconLabel, titleLabel, descLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 54),

            highlightView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            highlightView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            highlightView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            highlightView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            iconLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            descLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])
    }

    func setSelected(_ selected: Bool) {
        // #F56565 at 18% opacity for selection tint
        highlightView.layer?.backgroundColor = selected
            ? NSColor(red: 0.961, green: 0.396, blue: 0.396, alpha: 0.18).cgColor
            : .clear
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) { onTap?() }
    }
}
