import ActivityKit
import Foundation

/// 鎖定畫面／動態島上的沖煮計時。App 與 Widget Extension 共用。
struct BrewActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stageName: String
        var targetWater: Int
        /// 計時中時：「等效開始時間」（現在 − 已經過時間），讓系統自行往上數。
        var timerStart: Date
        var isRunning: Bool
        var pausedSeconds: Int
        var nextStageName: String?
        var nextStageDate: Date?
    }

    var methodTitle: String
    var totalWater: Int
}
