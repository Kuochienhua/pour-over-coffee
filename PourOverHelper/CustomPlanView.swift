import SwiftUI

/// 編輯自訂計畫：每一注的名稱、開始時間與水量。水量以百分比儲存，畫面同時顯示克數。
struct CustomPlanView: View {
    @Binding var recipe: BrewRecipe

    private var percentSum: Double { recipe.customPours.reduce(0) { $0 + $1.percent } }

    var body: some View {
        Form {
            Section {
                LabeledContent("總水量", value: "\(Int(recipe.totalWater)) g")
                LabeledContent("比例合計") {
                    Text("\(Int(percentSum))%")
                        .foregroundStyle(percentSum == 100 ? Color.secondary : Color.orange)
                }
            } footer: {
                if percentSum != 100 {
                    Text("合計不是 100%，計時時會自動依比例換算成總水量。")
                }
            }

            ForEach($recipe.customPours) { $pour in
                Section {
                    TextField("名稱", text: $pour.name)
                    Stepper(value: $pour.startSecond, in: 0...600, step: 5) {
                        LabeledContent("開始時間", value: timeString(pour.startSecond))
                    }
                    Stepper(value: $pour.percent, in: 5...100, step: 5) {
                        LabeledContent("這一注") {
                            Text("\(Int(pour.percent))%　≈ \(Int(recipe.totalWater * pour.percent / 100)) g")
                                .monospacedDigit()
                        }
                    }
                }
            }
            .onDelete { recipe.customPours.remove(atOffsets: $0) }

            Section {
                Button("新增一注", systemImage: "plus") {
                    let lastStart = recipe.customPours.map(\.startSecond).max() ?? 0
                    recipe.customPours.append(
                        CustomPour(name: "第 \(recipe.customPours.count) 注",
                                   startSecond: lastStart + 30, percent: 20))
                }
                Button("恢復預設", systemImage: "arrow.counterclockwise", role: .destructive) {
                    recipe.customPours = CustomPour.defaults
                }
            }
        }
        .navigationTitle("自訂計畫")
        .toolbar { EditButton() }
    }
}
