import SwiftUI

@main
struct SlateApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var store = JournalStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(store)
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1100, height: 750)
        .commands {
            SlateCommands(appState: appState, store: store)
        }
    }
}
