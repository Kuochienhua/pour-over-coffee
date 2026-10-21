import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @AppStorage(SettingsKey.voice) private var voice = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.liveActivity) private var liveActivity = true

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section {
                    Picker("型號", selection: Binding(
                        get: { app.grinder.name },
                        set: { name in
                            if let preset = GrinderProfile.presets.first(where: { $0.name == name }) {
                                app.grinder = preset
                            }
                        })) {
                        ForEach(GrinderProfile.presets, id: \.name) { Text($0.name).tag($0.name) }
                    }
                    ForEach(GrindSize.allCases) { grind in
                        Stepper(value: Binding(
                            get: { app.grinder.clicks[grind.rawValue] ?? 0 },
                            set: { app.grinder.clicks[grind.rawValue] = $0 }), in: 0...60) {
                            LabeledContent(grind.rawValue,
                                           value: "\(app.grinder.clicks[grind.rawValue] ?? 0) \(app.grinder.unit)")
                        }
                    }
                } header: {
                    Text("磨豆機")
                } footer: {
                    Text("內建數值是常見的手沖起點，每台磨豆機的歸零點略有差異，請依實際沖煮結果微調。")
                }

                Section {
                    Toggle("語音提示", isOn: $voice)
                    Toggle("震動提示", isOn: $haptics)
                    Toggle("鎖定畫面／動態島計時", isOn: $liveActivity)
                } header: {
                    Text("沖煮提示")
                } footer: {
                    Text("每段開始前 3 秒語音預告水量，開始時強震動、建議注完時輕震動。計時中螢幕會保持常亮。")
                }

                ScaleSection(scale: app.scale)
            }
            .navigationTitle("設定")
        }
    }
}

private struct ScaleSection: View {
    let scale: ScaleManager

    var body: some View {
        Section {
            LabeledContent("狀態", value: scale.status.text)
            if scale.isConnected {
                LabeledContent("目前重量", value: "\(Int(scale.weight ?? 0)) g")
                Button("歸零") { scale.tare() }
                Button("中斷連線", role: .destructive) { scale.disconnect() }
            } else if scale.status == .scanning {
                ForEach(scale.discovered, id: \.identifier) { peripheral in
                    Button(peripheral.name ?? "未命名的秤") { scale.connect(peripheral) }
                }
                Button("停止搜尋") { scale.stopScan() }
            } else {
                Button("搜尋藍牙秤") { scale.startScan() }
            }
        } header: {
            Text("藍牙咖啡秤")
        } footer: {
            Text("支援藍牙標準「體重秤」協定的秤（解析度 5 g）。Acaia、Timemore 等品牌使用私有協定，目前尚未支援。連線後計時頁會顯示即時重量與注水曲線。")
        }
    }
}
