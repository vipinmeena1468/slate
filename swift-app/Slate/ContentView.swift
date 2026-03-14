import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: JournalStore
    @Environment(\.colorScheme) var colorScheme

    private var effectiveIsDark: Bool {
        switch appState.theme {
        case .dark:   return true
        case .light:  return false
        case .system: return colorScheme == .dark
        }
    }

    var body: some View {
        ZStack {
            // Background fills the entire window including the title bar area
            themeBackground.ignoresSafeArea()

            if appState.showJournal {
                JournalView()
                    .transition(.opacity)
            } else {
                editorScene
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: appState.showJournal)
        .preferredColorScheme(appState.theme == .dark ? .dark : appState.theme == .light ? .light : nil)
        // Make the whole window draggable (minimal app — no interactive toolbar)
        .onAppear { configureWindow() }
    }

    // MARK: - Editor scene (header + editor)

    private var editorScene: some View {
        VStack(spacing: 0) {
            headerBar
            EditorView(date: appState.currentDate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Slate")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(mutedColor)
                .tracking(1.5)
                .textCase(.uppercase)

            Spacer()

            // Past-date breadcrumb
            if appState.isViewingPast, let date = appState.activeDate {
                HStack(spacing: 6) {
                    Text(shortDate(date))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(mutedColor)
                        .tracking(1.5)

                    Button("Today") {
                        appState.goToToday()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(accentColor.opacity(0.5), lineWidth: 1)
                    )
                }
            } else {
                Text(todayFormatted)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(mutedColor)
                    .tracking(1.5)
            }
        }
        .padding(.horizontal, 80)
        .padding(.top, 28)   // clears macOS traffic lights
        .padding(.bottom, 22)
    }

    // MARK: - Helpers

    private var themeBackground: Color {
        effectiveIsDark
            ? Color(red: 0.153, green: 0.153, blue: 0.153)   // #272727
            : Color(red: 0.969, green: 0.965, blue: 0.949)   // #f7f6f2
    }

    private var mutedColor: Color {
        effectiveIsDark ? Color(white: 0.43) : Color(white: 0.63)
    }

    private var accentColor: Color { Color(hex: "#F56565") }

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: Date())
    }

    private func shortDate(_ iso: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: iso) else { return iso }
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: d)
    }

    private func configureWindow() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            let isDark = self.effectiveIsDark
            window.backgroundColor = isDark
                ? NSColor(red: 0.153, green: 0.153, blue: 0.153, alpha: 1)
                : NSColor(red: 0.969, green: 0.965, blue: 0.949, alpha: 1)
        }
    }
}

// MARK: - Color(hex:) for SwiftUI

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        let value = UInt64(s, radix: 16) ?? 0
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >>  8) & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }
}
