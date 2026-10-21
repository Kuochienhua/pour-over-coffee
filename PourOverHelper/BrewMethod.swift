import Foundation

/// 常見的手沖計畫。每個方法帶有建議參數，以及一組以「累計水量」描述的注水步驟。
enum BrewMethod: String, CaseIterable, Identifiable, Codable {
    case kasuya46
    case hoffmann
    case threePour
    case singlePour
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kasuya46:   "粕谷哲 4:6 法"
        case .hoffmann:   "James Hoffmann V60"
        case .threePour:  "經典三段式"
        case .singlePour: "一刀流（單次注水）"
        case .custom:     "自訂計畫"
        }
    }

    var summary: String {
        switch self {
        case .kasuya46:
            "2016 世界手沖冠軍。粗研磨、每 45 秒注一次。前 40% 調酸甜、後 60% 調濃淡，容錯率高，適合新手。"
        case .hoffmann:
            "前世界咖啡師冠軍的 V60 沖法。2 倍粉重悶蒸並搖晃，分兩次注到 60% 與 100%，最後輕旋讓粉床平整，萃取均勻。"
        case .threePour:
            "日式手沖最常見的基本手法：悶蒸 → 注到 60% → 注滿。風味平衡，適合大多數淺中焙豆。"
        case .singlePour:
            "悶蒸後以細水柱一次緩慢注完。流程簡單、口感乾淨，適合聰明濾杯或 Kalita 蛋糕杯等平底濾杯。"
        case .custom:
            "自己設定每一注的時間與水量比例。"
        }
    }

    /// 選擇方法時套用的建議參數；自訂計畫不更動使用者的設定。
    var suggested: (ratio: Double, temp: Int, grind: GrindSize)? {
        switch self {
        case .kasuya46:   (15, 92, .coarse)
        case .hoffmann:   (16.5, 96, .mediumFine)
        case .threePour:  (15, 92, .mediumFine)
        case .singlePour: (15, 90, .medium)
        case .custom:     nil
        }
    }

    /// 建議注水流速（克／秒）。手沖壺細口穩定注水約 3–6 g/s。
    var flowRate: Double {
        switch self {
        case .kasuya46:   6
        case .hoffmann:   8
        case .threePour:  5
        case .singlePour: 2.5
        case .custom:     5
        }
    }

    /// 預設方法在幾秒時移開濾杯（4:6 法依注數另外計算）。
    var finishSecond: Int {
        switch self {
        case .kasuya46:   210
        case .hoffmann:   210
        case .threePour:  150
        case .singlePour: 150
        case .custom:     0
        }
    }

    enum Amount {
        case bloom(Double)        // 粉重的幾倍
        case fraction(Double)     // 總水量的累計比例
    }

    /// 固定步驟的方法。4:6 法與自訂計畫的步驟取決於食譜，由 `PourPlanner` 產生。
    var steps: [(name: String, second: Int, amount: Amount)] {
        switch self {
        case .hoffmann:
            [("悶蒸＋搖晃", 0,  .bloom(2)),
             ("注到 60%",  45, .fraction(0.6)),
             ("注滿後輕旋", 75, .fraction(1.0))]
        case .threePour:
            [("悶蒸",  0,  .bloom(2)),
             ("第一注", 40, .fraction(0.6)),
             ("第二注", 80, .fraction(1.0))]
        case .singlePour:
            [("悶蒸",       0,  .bloom(2)),
             ("細水柱注滿", 30, .fraction(1.0))]
        case .kasuya46, .custom:
            []
        }
    }
}
