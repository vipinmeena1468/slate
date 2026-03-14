import Foundation
import AppKit

@MainActor
final class JournalStore: ObservableObject {

    // Captured once at app launch — never changes during the session
    // even if the clock crosses midnight.
    static let sessionDate: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }()

    @Published var entries: [JournalEntry] = []
    /// Incremented every time `importText` succeeds so EditorView knows to reload.
    @Published private(set) var importCount: Int = 0

    private let baseURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        baseURL = appSupport.appendingPathComponent("Slate", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        refreshEntries()
    }

    // MARK: - Public API

    func load(date: String) -> NSAttributedString? {
        // Try RTFD first (new format with attachment support)
        let rtfdUrl = rtfdURL(for: date)
        if FileManager.default.fileExists(atPath: rtfdUrl.path),
           let attributed = try? NSAttributedString(
               url: rtfdUrl,
               options: [.documentType: NSAttributedString.DocumentType.rtfd],
               documentAttributes: nil
           ) {
            return reconstructCheckboxes(in: attributed)
        }

        // Fall back to legacy RTF (no attachments)
        let rtfUrl = rtfURL(for: date)
        if let data = try? Data(contentsOf: rtfUrl),
           let attributed = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            return attributed
        }

        return nil
    }

    func save(date: String, attributed: NSAttributedString) {
        let url   = rtfdURL(for: date)
        let range = NSRange(location: 0, length: attributed.length)
        guard let fileWrapper = try? attributed.fileWrapper(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        ) else { return }
        try? fileWrapper.write(to: url, options: .atomic, originalContentsURL: nil)
        refreshEntries()
    }

    func importText(_ string: String, into date: String, foregroundColor: NSColor? = nil) {
        let existing = load(date: date) ?? NSAttributedString()
        let mutable  = NSMutableAttributedString(attributedString: existing)
        if mutable.length > 0 {
            mutable.append(NSAttributedString(string: "\n\n"))
        }
        var attrs = EditorDefaults.typingAttributes
        if let fg = foregroundColor { attrs[.foregroundColor] = fg }
        let imported = NSAttributedString(
            string: string,
            attributes: attrs
        )
        mutable.append(imported)
        save(date: date, attributed: mutable)
        importCount += 1
    }

    // MARK: - Private

    private func rtfdURL(for date: String) -> URL {
        baseURL.appendingPathComponent("\(date).rtfd")
    }

    private func rtfURL(for date: String) -> URL {
        baseURL.appendingPathComponent("\(date).rtf")
    }

    private func refreshEntries() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        // Collect entries; prefer .rtfd over .rtf for the same date
        var seen: Set<String> = []
        let candidates = files
            .filter { $0.pathExtension == "rtfd" || $0.pathExtension == "rtf" }
            .compactMap { url -> JournalEntry? in
                let date = url.deletingPathExtension().lastPathComponent
                guard date.count == 10 else { return nil }
                let attrs    = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                let modified = attrs?.contentModificationDate ?? Date.distantPast
                let preview  = previewText(at: url)
                return JournalEntry(date: date, previewText: preview, lastModified: modified)
            }
            .sorted { lhs, rhs in
                // rtfd before rtf so we keep rtfd when deduplicating
                lhs.date > rhs.date
            }

        entries = candidates.filter { seen.insert($0.date).inserted }
            .sorted { $0.date > $1.date }
    }

    private func previewText(at url: URL) -> String {
        let attributed: NSAttributedString?
        if url.pathExtension == "rtfd" {
            attributed = try? NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.rtfd],
                documentAttributes: nil
            )
        } else {
            guard let data = try? Data(contentsOf: url) else { return "" }
            attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        }
        guard let attributed else { return "" }
        // Strip U+FFFC attachment placeholder characters from preview text
        let filtered = attributed.string.unicodeScalars
            .filter { $0.value != 0xFFFC }
            .map { Character($0) }
        return String(String(filtered).prefix(300))
    }

    /// After loading from RTFD, replace any plain NSTextAttachment whose fileWrapper
    /// matches our slate-checkbox naming with a proper CheckboxAttachment so the
    /// image and interaction hooks are live.
    private func reconstructCheckboxes(in attributed: NSAttributedString) -> NSAttributedString {
        let mutable   = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)

        // Collect replacements first so we can apply in reverse order (preserves ranges)
        var replacements: [(NSRange, CheckboxAttachment)] = []
        mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? NSTextAttachment,
                  !(attachment is CheckboxAttachment),
                  let checkbox = CheckboxAttachment.from(attachment) else { return }
            replacements.append((range, checkbox))
        }

        for (range, checkbox) in replacements.reversed() {
            mutable.replaceCharacters(in: range, with: NSAttributedString(attachment: checkbox))
        }

        return mutable
    }
}
