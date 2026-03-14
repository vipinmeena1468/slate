import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: JournalStore
    @Environment(\.colorScheme) var colorScheme

    let date: String

    private var effectiveIsDark: Bool {
        switch appState.theme {
        case .dark:   return true
        case .light:  return false
        case .system: return colorScheme == .dark
        }
    }

    // MARK: - Make

    func makeNSView(context: Context) -> NSScrollView {
        // Build our own pair so we can use SlateTextView (not NSTextView)
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = SlateTextView()
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable   = true
        textView.isHorizontallyResizable = false
        scrollView.documentView = textView

        configure(textView, coordinator: context.coordinator)
        loadContent(into: textView, for: date)
        return scrollView
    }

    // MARK: - Update (lean — only reacts to real changes)

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SlateTextView else { return }

        if context.coordinator.loadedDate != date {
            context.coordinator.loadedDate = date
            context.coordinator.lastSeenImportCount = store.importCount
            loadContent(into: textView, for: date)
        } else if context.coordinator.lastSeenImportCount != store.importCount {
            context.coordinator.lastSeenImportCount = store.importCount
            loadContent(into: textView, for: date)
        }

        if context.coordinator.currentIsDark != effectiveIsDark {
            context.coordinator.currentIsDark = effectiveIsDark
            applyTheme(to: textView)
        }
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        var loadedDate: String = ""
        var currentIsDark: Bool = true
        var lastSeenImportCount: Int = 0

        private var saveTimer: Timer?

        // Slash state
        private var slashPanel: SlashMenuPanel?
        private var slashStart: Int?
        private var slashQuery: String = ""

        init(_ parent: EditorView) { self.parent = parent }

        // MARK: Text change

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }

            handleSlashDetection(in: textView)

            saveTimer?.invalidate()
            saveTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                guard let self else { return }
                let snapshot = NSAttributedString(attributedString: storage)
                Task { @MainActor in
                    self.parent.store.save(date: self.parent.date, attributed: snapshot)
                }
            }
        }

        // MARK: Selection change

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  slashPanel != nil,
                  let start = slashStart else { return }
            let range = textView.selectedRange()
            if range.location < start || range.length > 0 { dismissSlashMenu() }
        }

        // MARK: Command interception

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {

            // ── Slash menu active ──────────────────────────────────────────
            if slashPanel != nil {
                switch commandSelector {
                case #selector(NSResponder.moveUp(_:)):
                    slashPanel?.selectPrevious(); return true
                case #selector(NSResponder.moveDown(_:)):
                    slashPanel?.selectNext(); return true
                case #selector(NSResponder.insertNewline(_:)):
                    applySelectedSlashItem(in: textView); return true
                case #selector(NSResponder.cancelOperation(_:)):
                    dismissSlashMenu(); return true
                default: break
                }
            }

            // ── Return key: list continuation ─────────────────────────────
            if commandSelector == #selector(NSResponder.insertNewline(_:)),
               let slateTV = textView as? SlateTextView {
                return slateTV.handleListReturn()
            }

            return false
        }

        // MARK: Slash detection

        private func handleSlashDetection(in textView: NSTextView) {
            let location = textView.selectedRange().location
            let text     = textView.string

            if let start = slashStart {
                guard location > start else { dismissSlashMenu(); return }

                let s0    = text.index(text.startIndex, offsetBy: start + 1)
                let s1    = text.index(text.startIndex, offsetBy: location)
                let query = String(text[s0..<s1])

                if query.contains(" ") || query.contains("\n") {
                    dismissSlashMenu(); return
                }
                slashQuery = query
                slashPanel?.update(items: allSlashItems, query: query)
                if slashPanel?.filteredItems.isEmpty == true { dismissSlashMenu() }
                return
            }

            guard location > 0 else { return }
            let prevIdx = text.index(text.startIndex, offsetBy: location - 1)
            guard text[prevIdx] == "/" else { return }

            // Only trigger at the start of a line (position 0 or immediately after a newline)
            if location >= 2 {
                let beforeSlash = text.index(text.startIndex, offsetBy: location - 2)
                guard text[beforeSlash] == "\n" else { return }
            }

            slashStart = location - 1
            slashQuery = ""
            showSlashMenu(for: textView, at: location - 1)
        }

        private func showSlashMenu(for textView: NSTextView, at charIndex: Int) {
            let isDark = parent.effectiveIsDark
            let panel  = SlashMenuPanel(isDark: isDark)
            panel.update(items: allSlashItems, query: "")
            panel.onConfirm = { [weak self, weak textView] item in
                guard let self, let textView else { return }
                self.applySlashItem(item, in: textView)
            }
            positionPanel(panel, for: textView, at: charIndex)
            panel.orderFront(nil)
            slashPanel = panel
        }

        private func applySelectedSlashItem(in textView: NSTextView) {
            slashPanel?.confirmSelection()
        }

        private func applySlashItem(_ item: SlashItem, in textView: NSTextView) {
            guard let start = slashStart else { return }
            let currentCaret = textView.selectedRange().location
            let eraseRange   = NSRange(location: start, length: currentCaret - start)
            item.apply(textView, eraseRange)
            dismissSlashMenu()
        }

        private func dismissSlashMenu() {
            slashPanel?.orderOut(nil); slashPanel = nil
            slashStart = nil; slashQuery = ""
        }

        private func positionPanel(_ panel: SlashMenuPanel,
                                   for textView: NSTextView,
                                   at charIndex: Int) {
            guard let lm   = textView.layoutManager,
                  let tc   = textView.textContainer,
                  let win  = textView.window else { return }

            let safe     = min(charIndex, max(0, textView.string.count - 1))
            let glyph    = lm.glyphIndexForCharacter(at: safe)
            var lineRect = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let origin   = textView.textContainerOrigin
            lineRect     = lineRect.offsetBy(dx: origin.x, dy: origin.y)

            let wr = textView.convert(lineRect, to: nil)
            let sr = win.convertToScreen(wr)
            panel.setFrameOrigin(NSPoint(x: sr.minX, y: sr.minY - panel.frame.height - 4))
        }
    }

    // MARK: - Private helpers

    private func configure(_ textView: SlateTextView, coordinator: Coordinator) {
        textView.delegate = coordinator
        coordinator.loadedDate  = date
        coordinator.currentIsDark = effectiveIsDark

        textView.isEditable   = true
        textView.isSelectable = true
        textView.isRichText   = true
        textView.allowsUndo   = true

        textView.isAutomaticQuoteSubstitutionEnabled  = false
        textView.isAutomaticDashSubstitutionEnabled   = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled     = false
        textView.isGrammarCheckingEnabled             = false

        textView.layoutManager?.allowsNonContiguousLayout = true

        textView.drawsBackground     = false
        textView.insertionPointColor = EditorDefaults.caretColor
        textView.font                = EditorDefaults.font
        textView.defaultParagraphStyle = EditorDefaults.paragraphStyle
        textView.typingAttributes    = EditorDefaults.typingAttributes

        applyTheme(to: textView)

        // Coral text-selection highlight matching the caret and accent colour
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(red: 0.961, green: 0.396, blue: 0.396, alpha: 0.30),
        ]

        textView.textContainerInset                  = NSSize(width: 80, height: 40)
        textView.textContainer?.lineFragmentPadding  = 0
        textView.textContainer?.widthTracksTextView  = true
        textView.textContainer?.heightTracksTextView = false
    }

    private func loadContent(into textView: SlateTextView, for date: String) {
        if let saved = store.load(date: date) {
            textView.textStorage?.setAttributedString(saved)
        } else {
            textView.string = ""
            textView.typingAttributes = EditorDefaults.typingAttributes
        }
        let end = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: end, length: 0))
        textView.scrollToEndOfDocument(nil)
    }

    private func applyTheme(to textView: SlateTextView) {
        let isDark = effectiveIsDark
        let fg: NSColor    = isDark ? NSColor(white: 0.949, alpha: 1) : NSColor(white: 0.11, alpha: 1)
        let muted: NSColor = isDark ? NSColor(white: 0.43,  alpha: 1) : NSColor(white: 0.55, alpha: 1)
        textView.textColor           = fg
        textView.insertionPointColor = EditorDefaults.caretColor
        textView.themeTextColor      = fg
        textView.mutedTextColor      = muted
    }
}

// MARK: - EditorDefaults paragraph style

extension EditorDefaults {
    static var paragraphStyle: NSParagraphStyle {
        let s = NSMutableParagraphStyle()
        s.lineSpacing = 12
        return s
    }
}
