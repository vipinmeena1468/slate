import SwiftUI

struct JournalCardView: View {
    let entry: JournalEntry
    let onTap: () -> Void

    @EnvironmentObject var appState: AppState

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Preview area
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cardBackground)

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
                    .foregroundColor(mutedColor)
                    .tracking(0.5)
                    .padding(.top, 8)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
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
