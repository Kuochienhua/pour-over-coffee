import Foundation

/// 濾杯：形狀與出水孔決定流速，影響適合的注水手法。
enum Dripper: String, CaseIterable, Identifiable, Codable {
    case v60, kalita, origami, clever, chemex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .v60:     "Hario V60（錐形）"
        case .kalita:  "Kalita Wave（蛋糕杯）"
        case .origami: "Origami（摺紙）"
        case .clever:  "聰明濾杯（浸泡）"
        case .chemex:  "Chemex"
        }
    }

    var note: String {
        switch self {
        case .v60:     "單一大孔、流速快，注水手法對風味影響大，適合多段注水。"
        case .kalita:  "平底三孔、流速穩定，萃取均勻，一刀流或三段式都好用。"
        case .origami: "錐形／蛋糕濾紙都能用，流速很快，建議研磨稍細。"
        case .clever:  "先浸泡再釋放，幾乎不受注水技巧影響，最適合新手。"
        case .chemex:  "厚濾紙流速慢、口感乾淨，研磨要偏粗，粉量建議 25g 以上。"
        }
    }

    var recommendedMethods: [BrewMethod] {
        switch self {
        case .v60:     [.kasuya46, .hoffmann, .threePour]
        case .kalita:  [.singlePour, .threePour, .kasuya46]
        case .origami: [.hoffmann, .threePour, .kasuya46]
        case .clever:  [.singlePour, .custom]
        case .chemex:  [.threePour, .hoffmann]
        }
    }
}

/// 使用者自己磨豆機的刻度對照。文字的「中細」在每台磨豆機上格數都不同。
struct GrinderProfile: Equatable, Codable {
    var name: String
    var unit: String = "格"
    var clicks: [String: Int]      // key: GrindSize.rawValue

    func clicks(for grind: GrindSize) -> Int? { clicks[grind.rawValue] }

    /// 常見磨豆機的手沖起點刻度（依各家建議與社群經驗整理，實際仍需依豆子微調）。
    static let presets: [GrinderProfile] = [
        GrinderProfile(name: "Comandante C40", clicks: ["細": 18, "中細": 22, "中": 26, "粗": 30]),
        GrinderProfile(name: "Timemore C2 / C3", clicks: ["細": 12, "中細": 15, "中": 18, "粗": 21]),
        GrinderProfile(name: "Baratza Encore", clicks: ["細": 12, "中細": 15, "中": 18, "粗": 22]),
        GrinderProfile(name: "Fellow Ode Gen 2", unit: "段", clicks: ["細": 3, "中細": 4, "中": 5, "粗": 7]),
        GrinderProfile(name: "自訂", clicks: ["細": 10, "中細": 14, "中": 18, "粗": 22]),
    ]
}
