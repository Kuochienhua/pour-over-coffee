import Charts
import PhotosUI
import SwiftData
import SwiftUI

struct BrewTimerView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var modelContext
    @State private var showSaveSheet = false
    @State private var finishedSeconds = 0
    @State private var savedLog: BrewLog?
    @State private var adviceLog: BrewLog?

    var body: some View {
        let session = app.session
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(timeString(session.seconds))
                        .font(.system(size: 80, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                    guidance(session)
                        .frame(minHeight: 120)

                    if app.scale.isConnected {
                        scaleReadout(session)
                    }

                    HStack(spacing: 16) {
                        Button(session.isRunning ? "暫停" : (session.hasStarted ? "繼續" : "開始")) {
                            session.isRunning ? session.pause() : session.start()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("完成") {
                            finishedSeconds = session.seconds
                            session.pause()
                            showSaveSheet = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(!session.hasStarted)

                        Button("重設", role: .destructive) { session.reset() }
                            .buttonStyle(.bordered)
                    }
                    .controlSize(.large)

                    if app.scale.isConnected, !session.weightSamples.isEmpty {
                        WeightChart(session: session)
                            .frame(height: 180)
                            .padding(.horizontal)
                    }

                    stageList(session)
                }
                .padding(.top)
            }
            .navigationTitle("沖煮計時")
            .onAppear { session.configure(with: app.recipe) }
            .onChange(of: app.recipe) { _, recipe in session.configure(with: recipe) }
            .sheet(isPresented: $showSaveSheet, onDismiss: {
                // 第一個表單關閉後才能開下一個；有勾口感就接著顯示診斷。
                if let log = savedLog, !log.symptoms.isEmpty { adviceLog = log }
                savedLog = nil
            }) {
                SaveLogSheet(recipe: session.recipe, brewSeconds: finishedSeconds) { log in
                    modelContext.insert(log)
                    savedLog = log
                    session.reset()
                }
            }
            .sheet(item: $adviceLog) { log in
                NavigationStack {
                    AdviceView(log: log)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { adviceLog = nil }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder private func guidance(_ session: BrewSession) -> some View {
        VStack(spacing: 8) {
            if !session.hasStarted, let first = session.stages.first {
                Text("準備：\(first.name)")
                    .font(.title2.bold())
                Text("第一段注到 \(Int(first.targetWater)) g")
                    .font(.title3)
                Text("按下開始後，每段前 3 秒會語音提醒")
                    .foregroundStyle(.secondary)
            } else {
                Text(session.currentStage?.name ?? "準備")
                    .font(.title2.bold())
            }
            if !session.hasStarted {
                EmptyView()
            } else if let progress = session.pourProgress, let stage = session.currentStage {
                Text("注水中：現在應到 \(Int(session.expectedWater)) g")
                    .font(.title3)
                    .monospacedDigit()
                ProgressView(value: progress)
                    .padding(.horizontal, 48)
                Text("目標 \(Int(stage.targetWater)) g・約 \(session.recipe.method.flowRate.formatted()) g/秒")
                    .foregroundStyle(.secondary)
            } else if let current = session.currentStage {
                if current.pourSeconds > 0 {
                    Text("停止注水，等待滴濾（\(Int(current.targetWater)) g）")
                        .font(.title3)
                } else {
                    Text("總水量 \(Int(current.targetWater)) g")
                        .font(.title3)
                }
                if let next = session.nextStage {
                    Text("下一段「\(next.name)」還有 \(next.startSecond - session.seconds) 秒")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private func scaleReadout(_ session: BrewSession) -> some View {
        let weight = app.scale.weight ?? 0
        let diff = weight - session.expectedWater
        HStack {
            Image(systemName: "scalemass.fill")
            Text("秤上 \(Int(weight)) g").monospacedDigit()
            if session.isRunning {
                Text(diff >= 0 ? "+\(Int(diff))" : "\(Int(diff))")
                    .foregroundStyle(abs(diff) <= 10 ? .green : .orange)
                    .monospacedDigit()
            }
            Spacer()
            Button("歸零") { app.scale.tare() }
                .buttonStyle(.bordered)
        }
        .font(.title3)
        .padding(.horizontal, 24)
    }

    @ViewBuilder private func stageList(_ session: BrewSession) -> some View {
        let current = session.currentStage
        VStack(spacing: 0) {
            ForEach(session.stages) { stage in
                HStack {
                    Text(stage.name)
                    Spacer()
                    Text("\(timeString(stage.startSecond))　\(stage.targetWater, specifier: "%.0f") g")
                        .monospacedDigit()
                }
                .fontWeight(stage.id == current?.id ? .bold : .regular)
                .foregroundStyle(current.map { stage.id < $0.id } == true ? .secondary : .primary)
                .padding(.vertical, 12)
                .padding(.horizontal)
                if stage.id != session.stages.last?.id { Divider().padding(.leading) }
            }
        }
        .background(.background.secondary, in: .rect(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom)
    }
}

/// 目標注水曲線（虛線）與秤上實際重量。
private struct WeightChart: View {
    let session: BrewSession

    var body: some View {
        let finish = PourPlanner.targetFinishSecond(for: session.stages)
        Chart {
            ForEach(Array(stride(from: 0, through: finish, by: 2)), id: \.self) { s in
                LineMark(x: .value("秒", s),
                         y: .value("克", PourPlanner.expectedWater(at: Double(s), stages: session.stages)),
                         series: .value("曲線", "目標"))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
            ForEach(session.weightSamples) { sample in
                LineMark(x: .value("秒", sample.second), y: .value("克", sample.grams),
                         series: .value("曲線", "實際"))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .chartXAxisLabel("秒")
        .chartYAxisLabel("g")
    }
}

struct SaveLogSheet: View {
    let recipe: BrewRecipe
    let brewSeconds: Int
    let onSave: (BrewLog) -> Void

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query private var beans: [Bean]
    @State private var beanName = ""
    @State private var rating = 3
    @State private var note = ""
    @State private var symptoms = Set<Symptom>()
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("豆子名稱（例：衣索比亞 耶加雪菲）", text: $beanName)
                    LabeledContent("沖煮時間", value: timeString(brewSeconds))
                    Stepper("評分：\(String(repeating: "★", count: rating))", value: $rating, in: 1...5)
                }
                Section {
                    SymptomPicker(selection: $symptoms)
                } header: {
                    Text("喝起來如何？")
                } footer: {
                    Text("勾選後會給你下一杯的調整建議。")
                }
                Section {
                    TextField("風味筆記", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                    PhotoField(item: $photoItem, photo: $photo)
                }
            }
            .navigationTitle("記錄這一杯")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let log = BrewLog(beanName: beanName.isEmpty ? "未命名" : beanName,
                                          recipe: recipe, brewSeconds: brewSeconds,
                                          rating: rating, note: note,
                                          grinderClicks: app.grinder.clicks(for: recipe.grind),
                                          symptoms: symptoms)
                        log.photo = photo
                        onSave(log)
                        dismiss()
                    }
                }
            }
            .onAppear {
                beanName = beans.first { $0.uid == recipe.beanID }?.name ?? ""
            }
        }
    }
}

struct SymptomPicker: View {
    @Binding var selection: Set<Symptom>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 8) {
            ForEach(Symptom.allCases) { symptom in
                let isOn = selection.contains(symptom)
                Button(symptom.rawValue) {
                    if isOn { selection.remove(symptom) } else { selection.insert(symptom) }
                }
                .buttonStyle(.bordered)
                .tint(isOn ? .accentColor : .secondary)
                .fontWeight(isOn ? .bold : .regular)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 照片欄位：選圖後縮小成 1200px JPEG 再存，避免資料庫膨脹。
struct PhotoField: View {
    @Binding var item: PhotosPickerItem?
    @Binding var photo: Data?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipShape(.rect(cornerRadius: 12))
            } else {
                Label("加入照片", systemImage: "photo")
            }
        }
        .onChange(of: item) { _, newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                let thumb = image.preparingThumbnail(of: CGSize(width: 1200, height: 1200 * image.size.height / image.size.width))
                photo = (thumb ?? image).jpegData(compressionQuality: 0.8)
            }
        }
    }
}
