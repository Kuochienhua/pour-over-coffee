import Foundation
import SwiftData

/// 一次沖煮的參數：粉量 + 粉水比，其餘數值都由這兩個推導。
struct BrewRecipe: Equatable, Codable {
    var coffeeGrams: Double = 15
    var ratio: Double = 15          // 1 : ratio
    var waterTemp: Int = 92         // °C
    var grind: GrindSize = .mediumFine
    var method: BrewMethod = .threePour
    var customPours: [CustomPour] = CustomPour.defaults
    var kasuyaTaste: KasuyaTaste = .balanced
    var kasuyaStrength: KasuyaStrength = .standard
    var dripper: Dripper = .v60
    var beanID: UUID?

    var totalWater: Double { coffeeGrams * ratio }

    // 新欄位都有預設值，舊版存下的 JSON 缺欄位時照樣解得開。
    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BrewRecipe()
        coffeeGrams = try c.decodeIfPresent(Double.self, forKey: .coffeeGrams) ?? d.coffeeGrams
        ratio = try c.decodeIfPresent(Double.self, forKey: .ratio) ?? d.ratio
        waterTemp = try c.decodeIfPresent(Int.self, forKey: .waterTemp) ?? d.waterTemp
        grind = try c.decodeIfPresent(GrindSize.self, forKey: .grind) ?? d.grind
        method = try c.decodeIfPresent(BrewMethod.self, forKey: .method) ?? d.method
        customPours = try c.decodeIfPresent([CustomPour].self, forKey: .customPours) ?? d.customPours
        kasuyaTaste = try c.decodeIfPresent(KasuyaTaste.self, forKey: .kasuyaTaste) ?? d.kasuyaTaste
        kasuyaStrength = try c.decodeIfPresent(KasuyaStrength.self, forKey: .kasuyaStrength) ?? d.kasuyaStrength
        dripper = try c.decodeIfPresent(Dripper.self, forKey: .dripper) ?? d.dripper
        beanID = try c.decodeIfPresent(UUID.self, forKey: .beanID)
    }
}

/// 自訂計畫的一注。`percent` 是「這一注」佔總水量的百分比，換粉量時會自動等比例縮放。
struct CustomPour: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var startSecond: Int
    var percent: Double

    static let defaults: [CustomPour] = [
        CustomPour(name: "悶蒸", startSecond: 0, percent: 15),
        CustomPour(name: "第一注", startSecond: 40, percent: 45),
        CustomPour(name: "第二注", startSecond: 90, percent: 40),
    ]
}

enum GrindSize: String, CaseIterable, Identifiable, Codable {
    case fine = "細"
    case mediumFine = "中細"
    case medium = "中"
    case coarse = "粗"
    var id: String { rawValue }

    var finer: GrindSize? {
        let all = Self.allCases
        let i = all.firstIndex(of: self)!
        return i > 0 ? all[i - 1] : nil
    }

    var coarser: GrindSize? {
        let all = Self.allCases
        let i = all.firstIndex(of: self)!
        return i < all.count - 1 ? all[i + 1] : nil
    }
}

/// 粕谷哲 4:6 法：前 40% 的分配決定酸甜，後 60% 的注數決定濃淡。
enum KasuyaTaste: String, CaseIterable, Identifiable, Codable {
    case sweeter = "偏甜"
    case balanced = "平衡"
    case brighter = "偏酸"
    var id: String { rawValue }

    /// 前兩注各佔總水量的比例（合計 0.4）。第一注越少越甜、越多越亮。
    var split: (Double, Double) {
        switch self {
        case .sweeter:  (0.15, 0.25)
        case .balanced: (0.20, 0.20)
        case .brighter: (0.25, 0.15)
        }
    }
}

enum KasuyaStrength: String, CaseIterable, Identifiable, Codable {
    case lighter = "淡"
    case standard = "標準"
    case stronger = "濃"
    var id: String { rawValue }

    /// 後 60% 分成幾注，注數越多萃取越濃。
    var pours: Int {
        switch self {
        case .lighter:  2
        case .standard: 3
        case .stronger: 4
        }
    }
}

/// 計時器上的一段注水。`targetWater` 是這段結束時秤上應該顯示的累計水量。
struct PourStage: Identifiable, Equatable {
    var id: Int                  // 在計畫中的序號，重新計算時保持穩定
    var name: String
    var startSecond: Int
    var targetWater: Double
    /// 建議在幾秒內注完這一段；0 代表不需注水（例如「移開濾杯」）。
    var pourSeconds: Int = 0
}

enum RoastLevel: String, CaseIterable, Identifiable, Codable {
    case light = "淺焙"
    case lightMedium = "淺中焙"
    case medium = "中焙"
    case mediumDark = "中深焙"
    case dark = "深焙"
    var id: String { rawValue }

    /// 烘焙越淺豆子越硬、越難萃取，需要越高的水溫。
    var suggestedTemp: Int {
        switch self {
        case .light:       94
        case .lightMedium: 92
        case .medium:      90
        case .mediumDark:  88
        case .dark:        85
        }
    }
}

@Model
final class Bean {
    var uid: UUID = UUID()
    var name: String = ""
    var origin: String = ""
    var process: String = ""
    var roastRaw: String = RoastLevel.lightMedium.rawValue
    var roastDate: Date = Date.now
    var note: String = ""
    var createdAt: Date = Date.now

    init(name: String, origin: String = "", process: String = "",
         roast: RoastLevel = .lightMedium, roastDate: Date = .now, note: String = "") {
        self.name = name
        self.origin = origin
        self.process = process
        self.roastRaw = roast.rawValue
        self.roastDate = roastDate
        self.note = note
    }

    var roast: RoastLevel {
        get { RoastLevel(rawValue: roastRaw) ?? .lightMedium }
        set { roastRaw = newValue.rawValue }
    }

    var daysSinceRoast: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: roastDate),
                                        to: Calendar.current.startOfDay(for: .now)).day ?? 0
    }

    /// 養豆狀態：剛烘好的豆子還在排二氧化碳，太久則香氣流失。
    var freshness: (label: String, detail: String, isGood: Bool) {
        switch daysSinceRoast {
        case ..<4:   ("排氣中", "剛烘好二氧化碳多，悶蒸延長到 40–45 秒。", false)
        case 4..<7:  ("可以沖", "風味逐漸打開，再養幾天會更好。", true)
        case 7...21: ("最佳賞味", "香氣與甜感最完整的時期。", true)
        case 22...35: ("風味下降", "香氣開始變弱，可稍微提高水溫。", false)
        default:     ("不新鮮", "香氣明顯流失，建議盡快喝完。", false)
        }
    }

    static let processes = ["水洗", "日曬", "蜜處理", "厭氧", "濕剝", "其他"]
}

@Model
final class BrewLog {
    var date: Date = Date.now
    var beanName: String = ""
    var coffeeGrams: Double = 0
    var ratio: Double = 0
    var waterTemp: Int = 0
    var grindRaw: String = ""
    var brewSeconds: Int = 0
    var rating: Int = 3
    var note: String = ""
    var methodRaw: String = ""
    var dripperRaw: String = ""
    var grinderClicks: Int?
    var symptomRaws: [String] = []
    /// 完整食譜（含自訂計畫），「再沖一次」時還原用。
    var recipeData: Data?
    @Attribute(.externalStorage) var photo: Data?

    init(date: Date = .now, beanName: String, recipe: BrewRecipe,
         brewSeconds: Int, rating: Int = 3, note: String = "",
         grinderClicks: Int? = nil, symptoms: Set<Symptom> = []) {
        self.date = date
        self.beanName = beanName
        self.coffeeGrams = recipe.coffeeGrams
        self.ratio = recipe.ratio
        self.waterTemp = recipe.waterTemp
        self.grindRaw = recipe.grind.rawValue
        self.brewSeconds = brewSeconds
        self.rating = rating
        self.note = note
        self.methodRaw = recipe.method.rawValue
        self.dripperRaw = recipe.dripper.rawValue
        self.grinderClicks = grinderClicks
        self.symptomRaws = symptoms.map(\.rawValue)
        self.recipeData = try? JSONEncoder().encode(recipe)
    }

    var recipe: BrewRecipe? {
        recipeData.flatMap { try? JSONDecoder().decode(BrewRecipe.self, from: $0) }
    }

    var method: BrewMethod? { BrewMethod(rawValue: methodRaw) }
    var dripper: Dripper? { Dripper(rawValue: dripperRaw) }
    var symptoms: Set<Symptom> { Set(symptomRaws.compactMap(Symptom.init(rawValue:))) }
}
