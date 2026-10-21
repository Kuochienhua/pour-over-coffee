import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedTab) {
            Tab("比例", systemImage: "scalemass", value: .calculator) {
                CalculatorView()
            }
            Tab("計時", systemImage: "timer", value: .timer) {
                BrewTimerView()
            }
            Tab("紀錄", systemImage: "book.closed", value: .logs) {
                LogListView()
            }
            Tab("豆子", systemImage: "leaf", value: .beans) {
                BeanListView()
            }
            Tab("設定", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .alert("匯入朋友分享的食譜？",
               isPresented: Binding(get: { app.pendingImport != nil },
                                    set: { if !$0 { app.pendingImport = nil } }),
               presenting: app.pendingImport) { recipe in
            Button("匯入") {
                var imported = recipe
                imported.beanID = app.recipe.beanID
                app.use(imported)
                app.pendingImport = nil
            }
            Button("取消", role: .cancel) { app.pendingImport = nil }
        } message: { recipe in
            Text(RecipeShare.summary(for: recipe))
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [BrewLog.self, Bean.self], inMemory: true)
}
