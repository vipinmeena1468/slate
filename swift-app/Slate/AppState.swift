import SwiftUI

@MainActor
final class AppState: ObservableObject {

    enum Theme: String {
        case system, light, dark
    }

    @Published var theme: Theme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "slateTheme")
        }
    }

    @Published var showJournal: Bool = false

    // The date being viewed/edited. nil means today's session date.
    @Published var activeDate: String? = nil

    var currentDate: String {
        activeDate ?? JournalStore.sessionDate
    }

    var isViewingPast: Bool {
        activeDate != nil && activeDate != JournalStore.sessionDate
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "slateTheme") ?? "system"
        self.theme = Theme(rawValue: saved) ?? .system
    }

    func goToToday() {
        activeDate = nil
        showJournal = false
    }

    func open(date: String) {
        activeDate = date == JournalStore.sessionDate ? nil : date
        showJournal = false
    }
}

// MARK: - Editor defaults (shared across EditorView and JournalStore)

enum EditorDefaults {
    nonisolated(unsafe) static let font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    nonisolated(unsafe) static let caretColor = NSColor(hex: "#F56565") ?? .red

    static var typingAttributes: [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 12
        return [
            .font: font,
            .paragraphStyle: style
        ]
    }
}

// MARK: - NSColor hex convenience

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >>  8) & 0xFF) / 255,
            blue:  CGFloat( value        & 0xFF) / 255,
            alpha: 1
        )
    }
}
