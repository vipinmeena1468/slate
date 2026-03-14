import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SlateCommands: Commands {
    @ObservedObject var appState: AppState
    let store: JournalStore

    var body: some Commands {
        // Replace default "New" with "New / Go to Today"
        CommandGroup(replacing: .newItem) {
            Button("New / Go to Today") {
                appState.goToToday()
            }
            .keyboardShortcut("n")
        }

        CommandGroup(after: .newItem) {
            Divider()

            Button("Open…") {
                openFile()
            }
            .keyboardShortcut("o")

            Button("Past Documents") {
                appState.showJournal = true
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])

            Divider()

            Button("Save As…") {
                saveAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        // Slate menu — about + appearance picker
        CommandMenu("Slate") {
            Button("About Slate") {
                NSApp.orderFrontStandardAboutPanel(options: [
                    .applicationName:    "Slate",
                    .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
                    .credits:            NSAttributedString(
                        string: "A minimal daily journal for Mac.",
                        attributes: [.font: NSFont.systemFont(ofSize: 12)]
                    )
                ])
            }

            Divider()

            Menu("Appearance") {
                Picker(
                    selection: Binding(
                        get: { appState.theme },
                        set: { appState.theme = $0 }
                    ),
                    label: EmptyView()
                ) {
                    Text("System Default").tag(AppState.Theme.system)
                    Divider()
                    Text("Light Mode").tag(AppState.Theme.light)
                    Text("Dark Mode").tag(AppState.Theme.dark)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }

    // MARK: - Open file

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .plainText, .rtf,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "html") ?? .html
        ]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            importFile(at: url)
        }
    }

    private func importFile(at url: URL) {
        let ext = url.pathExtension.lowercased()
        let text: String

        if ext == "rtf" {
            guard let data = try? Data(contentsOf: url),
                  let attributed = try? NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                  ) else { return }
            text = attributed.string
        } else {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return }
            // Strip basic HTML tags if needed
            if ext == "html" || ext == "htm" {
                text = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            } else {
                text = raw
            }
        }

        let isDark: Bool
        switch appState.theme {
        case .dark:   isDark = true
        case .light:  isDark = false
        case .system: isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        let fg: NSColor = isDark ? NSColor(white: 0.949, alpha: 1) : NSColor(white: 0.11, alpha: 1)
        store.importText(text, into: appState.currentDate, foregroundColor: fg)
    }

    // MARK: - Save As

    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [
            .plainText,
            UTType(filenameExtension: "md") ?? .plainText,
            .rtf,
            .html
        ]
        panel.nameFieldStringValue = "Slate — \(appState.currentDate)"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            exportEntry(to: url)
        }
    }

    private func exportEntry(to url: URL) {
        guard let attributed = store.load(date: appState.currentDate) else { return }
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "rtf":
            let range = NSRange(location: 0, length: attributed.length)
            let data = try? attributed.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            try? data?.write(to: url)

        case "html":
            let range = NSRange(location: 0, length: attributed.length)
            let data = try? attributed.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
            )
            try? data?.write(to: url)

        default: // .txt, .md, anything else
            try? attributed.string.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
