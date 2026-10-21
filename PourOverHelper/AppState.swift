import Foundation
import Observation

enum AppTab: Hashable {
    case calculator, timer, logs, beans, settings
}

/// 全 App 共用的狀態：目前食譜、分頁、磨豆機設定，以及跨分頁存活的沖煮計時與藍牙秤。
@Observable
@MainActor
final class AppState {
    var recipe: BrewRecipe { didSet { save(recipe, key: Keys.recipe) } }
    var grinder: GrinderProfile { didSet { save(grinder, key: Keys.grinder) } }
    var selectedTab: AppTab = .calculator
    /// 從分享連結開啟時，等待使用者確認匯入的食譜。
    var pendingImport: BrewRecipe?

    let scale = ScaleManager()
    let session: BrewSession

    private enum Keys {
        static let recipe = "lastRecipe"
        static let grinder = "grinderProfile"
    }

    init() {
        recipe = Self.load(BrewRecipe.self, key: Keys.recipe) ?? BrewRecipe()
        grinder = Self.load(GrinderProfile.self, key: Keys.grinder) ?? GrinderProfile.presets[0]
        session = BrewSession(scale: scale)
    }

    /// 「再沖一次」或套用建議後回到比例頁。
    func use(_ recipe: BrewRecipe) {
        self.recipe = recipe
        selectedTab = .calculator
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}

enum SettingsKey {
    static let voice = "voiceCues"
    static let haptics = "hapticCues"
    static let liveActivity = "liveActivity"
}
