import SwiftData
import SwiftUI

/// 依紀錄的口感給出調整建議，可勾選要套用的項目後帶到下一杯。
struct AdviceView: View {
    let log: BrewLog

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query private var beans: [Bean]
    @State private var chosen = Set<UUID>()
    @State private var advice: [Advice] = []

    private var baseRecipe: BrewRecipe { log.recipe ?? app.recipe }

    var body: some View {
        List {
            Section {
                Text(log.symptoms.map(\.rawValue).sorted().joined(separator: "、"))
            } header: {
                Text("這一杯：\(log.beanName)・\(timeString(log.brewSeconds))")
            }

            Section {
                ForEach(advice) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.apply != nil {
                            Toggle("套用", isOn: Binding(
                                get: { chosen.contains(item.id) },
                                set: { if $0 { chosen.insert(item.id) } else { chosen.remove(item.id) } }))
                                .labelsHidden()
                        }
                    }
                }
            } header: {
                Text("咖啡師建議")
            } footer: {
                Text("一次只改一到兩個變因，下一杯才知道是哪個調整有效。")
            }

            Section {
                Button("用調整後的參數沖下一杯", systemImage: "arrow.uturn.forward") {
                    var recipe = baseRecipe
                    for item in advice where chosen.contains(item.id) { item.apply?(&recipe) }
                    recipe.beanID = app.recipe.beanID ?? recipe.beanID
                    app.use(recipe)
                    dismiss()
                }
                .disabled(chosen.isEmpty)
            }
        }
        .navigationTitle("風味診斷")
        .onAppear {
            let beanDays = beans.first { $0.uid == baseRecipe.beanID }?.daysSinceRoast
            advice = BrewAdvisor.advice(symptoms: log.symptoms, recipe: baseRecipe,
                                        brewSeconds: log.brewSeconds, beanDays: beanDays)
            // 預設勾選第一個可套用的建議。
            if let first = advice.first(where: { $0.apply != nil }) { chosen = [first.id] }
        }
    }
}
