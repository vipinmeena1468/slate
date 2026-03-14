import Foundation

struct JournalEntry: Identifiable {
    let date: String        // "yyyy-MM-dd" — never changes after creation
    var previewText: String // plain-text excerpt for thumbnail
    var lastModified: Date

    var id: String { date }

    /// Human-readable date for the card label, e.g. "March 14, 2026"
    var displayDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: date) else { return date }
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: d)
    }
}
