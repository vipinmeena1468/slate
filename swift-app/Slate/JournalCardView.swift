import SwiftUI

struct JournalCardView: View {
    let entry: JournalEntry
    let onTap: () -> Void

    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Preview area
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(hex: "#F56565").opacity(isHovered ? 0.5 : 0), lineWidth: 1)
                        )

                    Text(entry.previewText.isEmpty ? " " : entry.previewText)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(previewTextColor)
                        .lineLimit(8)
                        .multilineTextAlignment(.leading)
                        .padding(12)
                }
                .frame(height: 140)
                .clipped()

                // Date label
                Text(entry.displayDate)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(isHovered ? Color(hex: "#F56565") : mutedColor)
                    .tracking(0.5)
                    .padding(.top, 8)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private var cardBackground: Color {
        appState.theme == .dark
            ? Color(white: 0.18)
            : Color(white: 0.92)
    }

    private var previewTextColor: Color {
        appState.theme == .dark
            ? Color(white: 0.6)
            : Color(white: 0.3)
    }

    private var mutedColor: Color {
        appState.theme == .dark ? Color(white: 0.43) : Color(white: 0.55)
    }
}
