import AppKit

/// Custom NSTextView subclass.
/// Adds two behaviours on top of stock NSTextView:
///
/// 1. **Checkbox toggle** — clicking a `CheckboxAttachment` at the start of a
///    paragraph toggles its checked state (coral fill ↔ outline).
///    No strikethrough — the text stays visually unchanged.
///
/// 2. **List continuation** — pressing Return at the end of a checkbox (attachment)
///    or bullet (• ) line starts a new line with the same prefix.
///    Pressing Return on an *empty* prefix line removes the prefix (exit list).
final class SlateTextView: NSTextView {

    // Set by EditorView when theme changes
    var themeTextColor: NSColor = NSColor(white: 0.949, alpha: 1)
    var mutedTextColor: NSColor = NSColor(white: 0.43,  alpha: 1)
    let accentColor:    NSColor = NSColor(red: 0.961, green: 0.396, blue: 0.396, alpha: 1)

    // MARK: - Caret height fix
    // lineSpacing=12 inflates the line fragment rect, making the caret too tall.
    // font.ascender - font.descender gives the natural line height (no spacing),
    // which is where the text actually lives. lineSpacing is appended at the bottom
    // of each fragment, so we start at rect.minY without any vertical offset.
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        let font           = EditorDefaults.font
        let naturalHeight  = ceil(font.ascender - font.descender)
        let shortRect      = NSRect(x: rect.minX, y: rect.minY,
                                    width: rect.width, height: min(naturalHeight, rect.height))
        super.drawInsertionPoint(in: shortRect, color: color, turnedOn: flag)
    }

    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        // Expand invalidation rect to fully erase the caret on each blink cycle
        super.setNeedsDisplay(NSRect(x: rect.minX, y: rect.minY - 4,
                                    width: rect.width, height: rect.height + 8),
                              avoidAdditionalLayout: flag)
    }

    // MARK: - Checkbox toggle on click

    override func mouseDown(with event: NSEvent) {
        if handleCheckboxClick(event) { return }
        super.mouseDown(with: event)
    }

    // Suppress macOS attachment context menu (Markup / More…) on checkboxes
    override func menu(for event: NSEvent) -> NSMenu? {
        if isOverCheckbox(at: event) { return nil }
        return super.menu(for: event)
    }

    // Show pointing-hand cursor when hovering over any checkbox attachment
    override func resetCursorRects() {
        super.resetCursorRects()
        guard let storage = textStorage,
              let lm = layoutManager,
              let tc = textContainer else { return }
        let full = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.attachment, in: full, options: []) { val, range, _ in
            guard val is CheckboxAttachment ||
                  (val as? NSTextAttachment).flatMap({ CheckboxAttachment.from($0) }) != nil
            else { return }
            let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
                         .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            addCursorRect(rect, cursor: .pointingHand)
        }
    }

    private func isOverCheckbox(at event: NSEvent) -> Bool {
        guard let layoutManager, let textContainer else { return false }
        let raw = convert(event.locationInWindow, from: nil)
        let pt  = NSPoint(x: raw.x - textContainerOrigin.x,
                          y: raw.y - textContainerOrigin.y)
        let glyphIdx = layoutManager.glyphIndex(for: pt, in: textContainer,
                                                fractionOfDistanceThroughGlyph: nil)
        let charIdx  = layoutManager.characterIndexForGlyph(at: glyphIdx)
        guard charIdx < string.count else { return false }
        guard (string as NSString).character(at: charIdx) == 0xFFFC,
              let storage = textStorage else { return false }
        let att = storage.attribute(.attachment, at: charIdx, effectiveRange: nil) as? NSTextAttachment
        return att is CheckboxAttachment || att.flatMap({ CheckboxAttachment.from($0) }) != nil
    }

    private func handleCheckboxClick(_ event: NSEvent) -> Bool {
        guard let layoutManager, let textContainer else { return false }

        let raw = convert(event.locationInWindow, from: nil)
        let pt  = NSPoint(x: raw.x - textContainerOrigin.x,
                          y: raw.y - textContainerOrigin.y)

        let glyphIdx = layoutManager.glyphIndex(for: pt, in: textContainer,
                                                fractionOfDistanceThroughGlyph: nil)
        let charIdx  = layoutManager.characterIndexForGlyph(at: glyphIdx)
        guard charIdx < string.count else { return false }

        // U+FFFC is the replacement character NSTextView uses for attachments
        let ch = (string as NSString).character(at: charIdx)
        guard ch == 0xFFFC else { return false }

        // Only act if it's our CheckboxAttachment
        guard let storage = textStorage else { return false }
        let attachment = storage.attribute(.attachment,
                                           at: charIdx,
                                           effectiveRange: nil) as? NSTextAttachment
        guard attachment is CheckboxAttachment ||
              CheckboxAttachment.from(attachment ?? NSTextAttachment()) != nil else { return false }

        toggleCheckbox(at: charIdx)
        // Trigger autosave via delegate
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
        return true
    }

    // MARK: - Reconstruct CheckboxAttachment after RTFD load
    //
    // NSAttributedString loaded from RTFD restores attachments as plain NSTextAttachment
    // (just a fileWrapper, no image). Call this after setAttributedString to restore
    // our custom rendered checkboxes.

    func reapplyCheckboxes() {
        guard let storage = textStorage, storage.length > 0 else { return }
        let full = NSRange(location: 0, length: storage.length)

        var replacements:      [(NSRange, CheckboxAttachment)] = []
        var checkboxParaRanges: [NSRange] = []

        storage.enumerateAttribute(.attachment, in: full, options: []) { val, range, _ in
            let str       = storage.string as NSString
            let paraRange = str.paragraphRange(for: range)

            if val is CheckboxAttachment {
                // Already reconstructed by JournalStore — just fix lineSpacing
                checkboxParaRanges.append(paraRange)
            } else if let att = val as? NSTextAttachment,
                      let checkbox = CheckboxAttachment.from(att) {
                replacements.append((range, checkbox))
                checkboxParaRanges.append(paraRange)
            }
        }

        guard !replacements.isEmpty || !checkboxParaRanges.isEmpty else { return }

        storage.beginEditing()

        for (range, checkbox) in replacements.reversed() {
            var carry = storage.attributes(at: range.location, effectiveRange: nil)
            carry.removeValue(forKey: .attachment)
            let replacement = NSMutableAttributedString(attachment: checkbox)
            replacement.addAttributes(carry, range: NSRange(location: 0, length: 1))
            storage.replaceCharacters(in: range, with: replacement)
        }

        // RTF doesn't preserve lineSpacing — fix it for every checkbox paragraph.
        // Targets only checkbox lines; all other text is untouched.
        for paraRange in checkboxParaRanges {
            storage.addAttribute(.paragraphStyle,
                                 value: EditorDefaults.paragraphStyle,
                                 range: paraRange)
        }

        storage.endEditing()
    }

    // MARK: - Toggle logic

    func toggleCheckbox(at charIdx: Int) {
        guard let storage = textStorage else { return }

        var effectiveRange = NSRange(location: charIdx, length: 0)
        guard let current = storage.attribute(.attachment,
                                              at: charIdx,
                                              effectiveRange: &effectiveRange) as? NSTextAttachment
        else { return }

        // Reconstruct as CheckboxAttachment if needed (e.g. freshly loaded from RTFD)
        let checkbox: CheckboxAttachment
        if let cb = current as? CheckboxAttachment {
            checkbox = cb
        } else if let cb = CheckboxAttachment.from(current) {
            checkbox = cb
        } else {
            return
        }

        let nowChecked = !checkbox.isChecked

        // Find the paragraph text range after the attachment + space
        let str       = storage.string as NSString
        let paraRange = str.paragraphRange(for: NSRange(location: charIdx, length: 0))
        let nlLen     = paraRange.length > 0 &&
                        str.character(at: paraRange.location + paraRange.length - 1) == 10 ? 1 : 0
        let textStart  = charIdx + 2   // skip attachment char + space
        let textLength = max(0, paraRange.location + paraRange.length - nlLen - textStart)

        // Replace attachment with toggled version — preserve existing attributes
        // (especially .paragraphStyle / lineSpacing) so line height doesn't collapse
        let existingAttrs = storage.attributes(at: charIdx, effectiveRange: nil)
        let toggled = CheckboxAttachment(isChecked: nowChecked)
        let newAttr = NSMutableAttributedString(attachment: toggled)
        var carry = existingAttrs
        carry.removeValue(forKey: .attachment)
        newAttr.addAttributes(carry, range: NSRange(location: 0, length: 1))

        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: charIdx, length: 1), with: newAttr)

        // Apply/remove strikethrough + dim on the line text
        if textLength > 0 {
            let textRange = NSRange(location: textStart, length: textLength)
            if nowChecked {
                storage.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: mutedTextColor,
                ], range: textRange)
            } else {
                storage.removeAttribute(.strikethroughStyle, range: textRange)
                storage.addAttribute(.foregroundColor, value: themeTextColor, range: textRange)
            }
        }

        storage.endEditing()

        // Keep typing attributes clean so text after this line isn't strikethrough
        if !nowChecked {
            var attrs = typingAttributes
            attrs[.foregroundColor] = themeTextColor
            attrs.removeValue(forKey: .strikethroughStyle)
            typingAttributes = attrs
        }
    }

    // MARK: - List continuation (Return key)
    //
    // Called by the coordinator's doCommandBy: — not overriding insertNewline
    // directly so slash-menu Return handling has priority.

    func handleListReturn() -> Bool {
        let location  = selectedRange().location
        let str       = string as NSString
        let paraRange = str.paragraphRange(for: NSRange(location: location, length: 0))
        guard paraRange.length > 0 else { return false }

        // ── Checkbox line? (attachment char at paragraph start) ──────────
        let firstChar = str.character(at: paraRange.location)
        if firstChar == 0xFFFC,
           let storage = textStorage,
           storage.attribute(.attachment,
                             at: paraRange.location,
                             effectiveRange: nil) is CheckboxAttachment
                         || (storage.attribute(.attachment,
                                               at: paraRange.location,
                                               effectiveRange: nil) as? NSTextAttachment)
                                .flatMap({ CheckboxAttachment.from($0) }) != nil {

            let paraText = str.substring(with: paraRange)
            let trimmed  = paraText.trimmingCharacters(in: .whitespacesAndNewlines)

            // Only the attachment character (+ optional space) → empty line → exit list
            let hasContent = trimmed.unicodeScalars.contains { $0.value != 0xFFFC && $0.value != 32 }
            if !hasContent {
                let removeLen = min(2, paraRange.length)
                insertText("", replacementRange: NSRange(location: paraRange.location, length: removeLen))
                return true
            }

            insertText("\n", replacementRange: selectedRange())
            insertCheckboxPrefix()
            return true
        }

        // ── Bullet line? ────────────────────────────────────────────────
        let paraText = str.substring(with: paraRange)
        let isBullet = paraText.hasPrefix("• ")
        guard isBullet else { return false }

        let body = paraText.trimmingCharacters(in: .whitespacesAndNewlines)
        if body == "•" || body.isEmpty {
            let removeRange = NSRange(location: paraRange.location, length: min(2, paraRange.length))
            insertText("", replacementRange: removeRange)
            return true
        }

        insertText("\n", replacementRange: selectedRange())
        insertStyledPrefix("• ")
        return true
    }

    // MARK: - Private helpers

    private func insertCheckboxPrefix() {
        let loc = selectedRange().location

        let attachment = CheckboxAttachment(isChecked: false)
        let attrStr    = NSMutableAttributedString(attachment: attachment)

        var spaceAttrs = typingAttributes
        spaceAttrs[.foregroundColor] = themeTextColor
        spaceAttrs.removeValue(forKey: .strikethroughStyle)

        // Apply full paragraph style (incl. lineSpacing) to the attachment char
        attrStr.addAttributes(spaceAttrs, range: NSRange(location: 0, length: 1))
        attrStr.append(NSAttributedString(string: " ", attributes: spaceAttrs))

        textStorage?.insert(attrStr, at: loc)

        // Park caret after attachment + space
        let newLoc = loc + 2
        setSelectedRange(NSRange(location: newLoc, length: 0))
        typingAttributes = spaceAttrs
    }

    private func insertStyledPrefix(_ prefix: String) {
        let loc   = selectedRange().location
        var attrs = typingAttributes
        if prefix.hasPrefix("☐") {
            attrs[.foregroundColor] = mutedTextColor
        }
        let attributed = NSAttributedString(string: prefix, attributes: attrs)
        textStorage?.insert(attributed, at: loc)
        setSelectedRange(NSRange(location: loc + (prefix as NSString).length, length: 0))
        var normalAttrs = typingAttributes
        normalAttrs[.foregroundColor] = themeTextColor
        normalAttrs.removeValue(forKey: .strikethroughStyle)
        typingAttributes = normalAttrs
    }
}
