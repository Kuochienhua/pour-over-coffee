import SwiftUI
import SwiftData

@main
struct PourOverHelperApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(app)
                .onOpenURL { url in
                    app.pendingImport = RecipeShare.recipe(from: url)
                }
        }
        .modelContainer(for: [BrewLog.self, Bean.self])
    }
}
