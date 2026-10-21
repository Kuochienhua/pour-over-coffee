import PhotosUI
import SwiftData
import SwiftUI

struct LogListView: View {
    @Query(sort: \BrewLog.date, order: .reverse) private var logs: [BrewLog]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationStack {
            Group {
                if logs.isEmpty {
                    ContentUnavailableView("還沒有紀錄", systemImage: "cup.and.saucer",
                                           description: Text("在「計時」沖完一杯後按「完成」即可記錄。"))
                } else {
                    List {
                        ForEach(logs) { log in
                            NavigationLink { LogDetailView(log: log) } label: { LogRow(log: log) }
                                .swipeActions(edge: .leading) {
                                    if let recipe = log.recipe {
                                        Button("再沖一次", systemImage: "arrow.clockwise") { app.use(recipe) }
                                            .tint(.accentColor)
                                    }
                                }
                        }
                        .onDelete { offsets in
                            offsets.map { logs[$0] }.forEach(modelContext.delete)
                        }
                    }
                }
            }
            .navigationTitle("沖煮紀錄")
        }
    }
}

private struct LogRow: View {
    let log: BrewLog

    var body: some View {
        HStack(spacing: 12) {
            if let data = log.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(.rect(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.beanName).font(.headline)
                    Spacer()
                    Text(String(repeating: "★", count: log.rating))
                        .foregroundStyle(.orange)
                }
                Text("\(log.method?.title ?? "手沖")・\(log.coffeeGrams.formatted())g・1:\(log.ratio.formatted())・\(log.waterTemp)°C")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(log.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct LogDetailView: View {
    @Bindable var log: BrewLog
    @Environment(AppState.self) private var app
    @State private var photoItem: PhotosPickerItem?
    @State private var symptoms = Set<Symptom>()

    var body: some View {
        Form {
            Section {
                PhotoField(item: $photoItem, photo: $log.photo)
            }
            Section("參數") {
                LabeledContent("方法", value: log.method?.title ?? "—")
                LabeledContent("濾杯", value: log.dripper?.title ?? "—")
                LabeledContent("粉量", value: "\(log.coffeeGrams.formatted()) g")
                LabeledContent("粉水比", value: "1 : \(log.ratio.formatted())")
                LabeledContent("水溫", value: "\(log.waterTemp) °C")
                LabeledContent("研磨", value: log.grinderClicks.map { "\(log.grindRaw)（\($0) 格）" } ?? log.grindRaw)
                LabeledContent("沖煮時間", value: timeString(log.brewSeconds))
            }
            Section("評分與筆記") {
                Stepper("評分：\(String(repeating: "★", count: log.rating))", value: $log.rating, in: 1...5)
                TextField("風味筆記", text: $log.note, axis: .vertical)
            }
            Section("口感") {
                SymptomPicker(selection: $symptoms)
                if !symptoms.isEmpty {
                    NavigationLink("查看調整建議") { AdviceView(log: log) }
                }
            }
            if let recipe = log.recipe {
                Section {
                    Button("用這組參數再沖一次", systemImage: "arrow.clockwise") { app.use(recipe) }
                }
            }
        }
        .navigationTitle(log.beanName)
        .onAppear { symptoms = log.symptoms }
        .onChange(of: symptoms) { _, new in log.symptomRaws = new.map(\.rawValue) }
    }
}
