import SwiftUI

struct JournalView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: JournalStore

    // Adaptive grid: 3 columns on wide windows, 2 on narrow
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 20)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            themeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar

                if store.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                            ForEach(store.entries) { entry in
                                JournalCardView(entry: entry) {
                                    appState.open(date: entry.date)
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 32)
                    }
                }
            }
        }
    }

    // MARK: - Navigation bar

    private var navigationBar: some View {
        HStack(alignment: .center) {
            // Back / close button
            BackButton { appState.showJournal = false }
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Text("Past Documents")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(mutedColor)
                .tracking(1.5)
                .textCase(.uppercase)

            Spacer()

            // Invisible spacer to balance the back button
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .opacity(0)
        }
        .padding(.horizontal, 40)
        .padding(.top, 28)   // clear traffic lights
        .padding(.bottom, 22)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No past entries yet.")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(mutedColor)
            Text("Start writing today and it will appear here.")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(mutedColor.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var themeBackground: Color {
        appState.theme == .dark
            ? Color(red: 0.153, green: 0.153, blue: 0.153)
            : Color(red: 0.969, green: 0.965, blue: 0.949)
    }

    private var mutedColor: Color {
        appState.theme == .dark ? Color(white: 0.43) : Color(white: 0.55)
    }
}

private struct BackButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                Text("Back")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
            }
            .foregroundColor(isHovered ? Color(hex: "#F56565") : Color(white: 0.43))
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
