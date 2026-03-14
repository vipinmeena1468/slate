import AppKit

// MARK: - CheckboxCell
//
// Custom attachment cell that draws the checkbox using our image.
// Used instead of NSTextAttachment.image to avoid the mutual-exclusion
// issue where setting `image` replaces `fileWrapper` and vice versa.

private final class CheckboxCell: NSTextAttachmentCell {
    let isChecked: Bool

    init(isChecked: Bool) {
        self.isChecked = isChecked
        super.init()
    }

    required init(coder: NSCoder) { fatalError() }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        CheckboxAttachment.makeImage(isChecked: isChecked).draw(in: cellFrame)
    }

    override func cellBaselineOffset() -> NSPoint { .init(x: 0, y: -3) }
    override func cellSize() -> NSSize { .init(width: 18, height: 18) }
}

// MARK: - CheckboxAttachment

/// NSTextAttachment that draws a proper rounded-square checkbox.
///
/// Checked   → coral (#F56565) filled square with a white checkmark
/// Unchecked → outlined square with gray stroke, no fill
///
/// State is stored in a 1-byte fileWrapper so RTFD round-trips preserve it.
/// Rendering goes through a custom NSTextAttachmentCell — never through
/// `NSTextAttachment.image` — to avoid the mutual-exclusion between
/// `image` and `fileWrapper` in AppKit.
final class CheckboxAttachment: NSTextAttachment {

    // MARK: Constants

    static let filenamePrefix       = "slate-checkbox"
    private static let boxSize: CGFloat    = 18
    private static let cornerRadius: CGFloat = 4
    private static let checkedColor = NSColor(red: 0.961, green: 0.396, blue: 0.396, alpha: 1)

    // MARK: State

    var isChecked: Bool {
        didSet { if oldValue != isChecked { refresh() } }
    }

    // MARK: Init

    init(isChecked: Bool) {
        self.isChecked = isChecked
        super.init(data: nil, ofType: nil)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Factory — reconstruct from a plain NSTextAttachment loaded from RTFD

    static func from(_ attachment: NSTextAttachment) -> CheckboxAttachment? {
        guard !(attachment is CheckboxAttachment) else { return attachment as? CheckboxAttachment }
        guard let fw   = attachment.fileWrapper,
              let data = fw.regularFileContents,
              data.count == 1 else { return nil }
        return CheckboxAttachment(isChecked: data[0] != 0)
    }

    // MARK: Private helpers

    private func refresh() {
        // Store state as 1-byte fileWrapper — do NOT set self.image.
        // Setting image replaces fileWrapper with TIFF (and vice versa) in AppKit.
        // Rendering is handled by CheckboxCell instead.
        let data = Data([isChecked ? 1 : 0])
        let fw   = FileWrapper(regularFileWithContents: data)
        fw.preferredFilename = "\(Self.filenamePrefix)-\(isChecked ? 1 : 0)"
        fileWrapper    = fw
        bounds         = CGRect(x: 0, y: -3, width: Self.boxSize, height: Self.boxSize)
        attachmentCell = CheckboxCell(isChecked: isChecked)
    }

    // MARK: Drawing

    static func makeImage(isChecked: Bool) -> NSImage {
        let s  = boxSize
        let cr = cornerRadius

        return NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
            let inset = rect.insetBy(dx: 1, dy: 1)
            let path  = NSBezierPath(roundedRect: inset, xRadius: cr, yRadius: cr)

            if isChecked {
                checkedColor.setFill()
                path.fill()

                let ck = NSBezierPath()
                ck.move(to:  NSPoint(x: s * 0.20, y: s * 0.50))
                ck.line(to:  NSPoint(x: s * 0.42, y: s * 0.27))
                ck.line(to:  NSPoint(x: s * 0.82, y: s * 0.72))
                ck.lineWidth      = 2.0
                ck.lineCapStyle   = .round
                ck.lineJoinStyle  = .round
                NSColor.white.setStroke()
                ck.stroke()

            } else {
                NSColor(white: 0.55, alpha: 1).setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
            return true
        }
    }
}
