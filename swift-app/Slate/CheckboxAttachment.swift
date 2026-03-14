import AppKit

/// NSTextAttachment that draws a proper rounded-square checkbox.
///
/// Checked   → coral (#F56565) filled square with a white checkmark
/// Unchecked → outlined square with gray stroke, no fill
///
/// The checked state is persisted inside the fileWrapper (1 byte: 0x00 / 0x01)
/// so round-trips through RTFD preserve it.
final class CheckboxAttachment: NSTextAttachment {

    // MARK: Constants

    private static let filenamePrefix  = "slate-checkbox"
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

    /// Returns a `CheckboxAttachment` if `attachment` was originally created by us,
    /// otherwise `nil`.
    static func from(_ attachment: NSTextAttachment) -> CheckboxAttachment? {
        guard !(attachment is CheckboxAttachment) else { return attachment as? CheckboxAttachment }
        guard let fw   = attachment.fileWrapper,
              let name = fw.preferredFilename ?? fw.filename,
              name.hasPrefix(filenamePrefix),
              let data = fw.regularFileContents,
              !data.isEmpty else { return nil }
        return CheckboxAttachment(isChecked: data[0] != 0)
    }

    // MARK: Private helpers

    private func refresh() {
        // Persist state in fileWrapper so RTFD round-trips work
        let data = Data([isChecked ? 1 : 0])
        fileWrapper = FileWrapper(regularFileWithContents: data)
        fileWrapper?.preferredFilename = "\(Self.filenamePrefix)-\(isChecked ? 1 : 0)"

        image  = Self.makeImage(isChecked: isChecked)
        bounds = CGRect(x: 0, y: -3, width: Self.boxSize, height: Self.boxSize)
    }

    // MARK: Drawing

    static func makeImage(isChecked: Bool) -> NSImage {
        let s  = boxSize
        let cr = cornerRadius

        return NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
            // Inset by 1pt so the stroke doesn't clip
            let inset = rect.insetBy(dx: 1, dy: 1)
            let path  = NSBezierPath(roundedRect: inset, xRadius: cr, yRadius: cr)

            if isChecked {
                // Filled coral square
                checkedColor.setFill()
                path.fill()

                // White checkmark — coordinates in y-up space (origin = bottom-left)
                // Left tip → valley → right end
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
                // Outlined square — gray, no fill
                NSColor(white: 0.55, alpha: 1).setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
            return true
        }
    }
}
