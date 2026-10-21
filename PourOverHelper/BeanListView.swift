import SwiftData
import SwiftUI

struct BeanListView: View {
    @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var app
    @State private var editing: Bean?
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            Group {
                if beans.isEmpty {
                    ContentUnavailableView {
                        Label("還沒有豆子", systemImage: "leaf")
                    } description: {
                        Text("記錄產區、處理法與烘焙日期，App 會提醒最佳賞味期並建議水溫。")
                    } actions: {
                        Button("新增豆子") { showNew = true }.buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(beans) { bean in
                            Button { editing = bean } label: { BeanRow(bean: bean) }
                                .tint(.primary)
                                .swipeActions(edge: .leading) {
                                    Button("用這支沖", systemImage: "cup.and.saucer") { brew(with: bean) }
                                        .tint(.accentColor)
                                }
                        }
                        .onDelete { offsets in offsets.map { beans[$0] }.forEach(modelContext.delete) }
                    }
                }
            }
            .navigationTitle("我的豆子")
            .toolbar { Button("新增", systemImage: "plus") { showNew = true } }
            .sheet(isPresented: $showNew) { BeanEditView(bean: nil) }
            .sheet(item: $editing) { BeanEditView(bean: $0) }
        }
    }

    private func brew(with bean: Bean) {
        var recipe = app.recipe
        recipe.beanID = bean.uid
        recipe.waterTemp = bean.roast.suggestedTemp
        app.use(recipe)
    }
}

private struct BeanRow: View {
    let bean: Bean

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(bean.name).font(.headline)
                Spacer()
                Text(bean.freshness.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((bean.freshness.isGood ? Color.green : Color.orange).opacity(0.15), in: .capsule)
                    .foregroundStyle(bean.freshness.isGood ? .green : .orange)
            }
            Text([bean.origin, bean.process, bean.roast.rawValue].filter { !$0.isEmpty }.joined(separator: "・"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("烘焙後第 \(bean.daysSinceRoast) 天・建議水溫 \(bean.roast.suggestedTemp)°C")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

struct BeanEditView: View {
    let bean: Bean?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var origin = ""
    @State private var process = "水洗"
    @State private var roast = RoastLevel.lightMedium
    @State private var roastDate = Date.now
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名稱（例：耶加雪菲 孔加）", text: $name)
                    TextField("產區（例：衣索比亞）", text: $origin)
                    Picker("處理法", selection: $process) {
                        ForEach(Bean.processes, id: \.self) { Text($0) }
                    }
                }
                Section {
                    Picker("烘焙度", selection: $roast) {
                        ForEach(RoastLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    DatePicker("烘焙日期", selection: $roastDate, in: ...Date.now, displayedComponents: .date)
                } footer: {
                    Text("\(roast.rawValue)建議水溫 \(roast.suggestedTemp)°C。烘焙後 7–21 天通常最好喝。")
                }
                Section("筆記") {
                    TextField("風味描述、購買店家…", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(bean == nil ? "新增豆子" : "編輯豆子")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save(); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let bean else { return }
                name = bean.name
                origin = bean.origin
                process = bean.process.isEmpty ? "水洗" : bean.process
                roast = bean.roast
                roastDate = bean.roastDate
                note = bean.note
            }
        }
    }

    private func save() {
        let target = bean ?? Bean(name: name)
        target.name = name
        target.origin = origin
        target.process = process
        target.roast = roast
        target.roastDate = roastDate
        target.note = note
        if bean == nil { modelContext.insert(target) }
    }
}
