import SwiftUI
import SwiftData

struct CalculatorView: View {
    @Environment(AppState.self) private var app
    @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
    @State private var showShare = false

    private var selectedBean: Bean? { beans.first { $0.uid == app.recipe.beanID } }

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 4) {
                        Text("\(app.recipe.totalWater, specifier: "%.0f") g")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("總注水量")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                methodSection
                equipmentSection
                beanSection

                Section("咖啡粉") {
                    Stepper(value: $app.recipe.coffeeGrams, in: 5...60, step: 0.5) {
                        LabeledContent("粉量", value: "\(app.recipe.coffeeGrams.formatted()) g")
                    }
                    VStack(alignment: .leading) {
                        LabeledContent("粉水比", value: "1 : \(app.recipe.ratio.formatted())")
                        Slider(value: $app.recipe.ratio, in: 12...18, step: 0.5)
                    }
                    Picker(selection: $app.recipe.grind) {
                        ForEach(GrindSize.allCases) { Text($0.rawValue).tag($0) }
                    } label: {
                        VStack(alignment: .leading) {
                            Text("研磨度")
                            if let clicks = app.grinder.clicks(for: app.recipe.grind) {
                                Text("\(app.grinder.name) 約 \(clicks) \(app.grinder.unit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("水") {
                    Stepper(value: $app.recipe.waterTemp, in: 80...100) {
                        LabeledContent("水溫", value: "\(app.recipe.waterTemp) °C")
                    }
                }

                Section("注水計畫") {
                    ForEach(PourPlanner.stages(for: app.recipe)) { stage in
                        LabeledContent {
                            Text("\(timeString(stage.startSecond))　→ \(stage.targetWater, specifier: "%.0f") g")
                                .monospacedDigit()
                        } label: {
                            Text(stage.name)
                            if stage.pourSeconds > 0 {
                                Text("約 \(stage.pourSeconds) 秒內注完")
                            }
                        }
                    }
                }
            }
            .animation(.default, value: app.recipe)
            .onChange(of: app.recipe.method) { _, method in
                // 換方法時套用該方法的建議比例、水溫與研磨度；粉量保留使用者設定。
                guard let suggested = method.suggested else { return }
                app.recipe.ratio = suggested.ratio
                app.recipe.waterTemp = suggested.temp
                app.recipe.grind = suggested.grind
            }
            .navigationTitle("手沖咖啡小幫手")
            .toolbar {
                Button("分享食譜", systemImage: "qrcode") { showShare = true }
            }
            .sheet(isPresented: $showShare) {
                ShareRecipeView(recipe: app.recipe)
            }
        }
    }

    @ViewBuilder private var methodSection: some View {
        @Bindable var app = app
        Section {
            Picker("沖煮方法", selection: $app.recipe.method) {
                ForEach(BrewMethod.allCases) { Text($0.title).tag($0) }
            }
            if app.recipe.method == .kasuya46 {
                Picker("酸甜", selection: $app.recipe.kasuyaTaste) {
                    ForEach(KasuyaTaste.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("濃淡", selection: $app.recipe.kasuyaStrength) {
                    ForEach(KasuyaStrength.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            if app.recipe.method == .custom {
                NavigationLink("編輯自訂計畫（\(app.recipe.customPours.count) 注）") {
                    CustomPlanView(recipe: $app.recipe)
                }
            }
        } header: {
            Text("沖煮方法")
        } footer: {
            if app.recipe.method == .kasuya46 {
                Text(app.recipe.method.summary + "\n上排：第一注越少越甜。下排：後段注數越多越濃。")
            } else {
                Text(app.recipe.method.summary)
            }
        }
    }

    @ViewBuilder private var equipmentSection: some View {
        @Bindable var app = app
        Section {
            Picker("濾杯", selection: $app.recipe.dripper) {
                ForEach(Dripper.allCases) { Text($0.title).tag($0) }
            }
        } footer: {
            let dripper = app.recipe.dripper
            if dripper.recommendedMethods.contains(app.recipe.method) {
                Text(dripper.note)
            } else {
                Text(dripper.note + "\n建議搭配：" + dripper.recommendedMethods.map(\.title).joined(separator: "、"))
            }
        }
    }

    @ViewBuilder private var beanSection: some View {
        @Bindable var app = app
        Section {
            if beans.isEmpty {
                Button("新增第一支豆子") { app.selectedTab = .beans }
            } else {
                Picker("咖啡豆", selection: $app.recipe.beanID) {
                    Text("未選擇").tag(UUID?.none)
                    ForEach(beans) { Text($0.name).tag(Optional($0.uid)) }
                }
                if let bean = selectedBean {
                    LabeledContent("烘焙", value: "\(bean.roast.rawValue)・第 \(bean.daysSinceRoast) 天")
                    LabeledContent("狀態") {
                        Text(bean.freshness.label)
                            .foregroundStyle(bean.freshness.isGood ? .green : .orange)
                    }
                    if app.recipe.waterTemp != bean.roast.suggestedTemp {
                        Button("套用\(bean.roast.rawValue)建議水溫 \(bean.roast.suggestedTemp)°C") {
                            app.recipe.waterTemp = bean.roast.suggestedTemp
                        }
                    }
                }
            }
        } header: {
            Text("咖啡豆")
        } footer: {
            if let bean = selectedBean { Text(bean.freshness.detail) }
        }
    }
}

func timeString(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}
