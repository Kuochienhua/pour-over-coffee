import Foundation

enum PourPlanner {
    /// 依照食譜的沖煮方法產生注水階段。`targetWater` 一律是累計水量，最後一注等於總水量。
    static func stages(for recipe: BrewRecipe) -> [PourStage] {
        let total = recipe.totalWater
        var stages: [PourStage]

        switch recipe.method {
        case .custom:
            // 自訂：每注是「單注」百分比，累加後換算成克數；最後一注吃掉四捨五入的誤差。
            let pours = recipe.customPours.sorted { $0.startSecond < $1.startSecond }
            let sum = max(pours.reduce(0) { $0 + $1.percent }, 1)
            var running = 0.0
            stages = pours.enumerated().map { i, pour in
                running += pour.percent / sum
                return PourStage(id: i, name: pour.name, startSecond: pour.startSecond,
                                 targetWater: (total * running).rounded())
            }

        case .kasuya46:
            // 前 40% 分兩注（酸甜），後 60% 平均分成 N 注（濃淡），每 45 秒一注。
            let (first, second) = recipe.kasuyaTaste.split
            var fractions = [first, first + second]
            let n = recipe.kasuyaStrength.pours
            for k in 1...n { fractions.append(0.4 + 0.6 * Double(k) / Double(n)) }
            stages = fractions.enumerated().map { i, f in
                let label = i < 2 ? "酸甜" : "濃淡"
                return PourStage(id: i, name: "第 \(i + 1) 注（\(label)）", startSecond: i * 45,
                                 targetWater: (total * f).rounded())
            }
            let finish = (stages.last?.startSecond ?? 0) + 30
            stages.append(PourStage(id: stages.count, name: "滴完・移開濾杯",
                                    startSecond: finish, targetWater: total.rounded()))

        default:
            stages = recipe.method.steps.enumerated().map { i, step in
                let water: Double = switch step.amount {
                case .bloom(let multiple):  min(recipe.coffeeGrams * multiple, total)
                case .fraction(let f):      total * f
                }
                return PourStage(id: i, name: step.name, startSecond: step.second,
                                 targetWater: water.rounded())
            }
            stages.append(PourStage(id: stages.count, name: "滴完・移開濾杯",
                                    startSecond: recipe.method.finishSecond,
                                    targetWater: total.rounded()))
        }

        if let last = stages.indices.last { stages[last].targetWater = total.rounded() }
        assignPourDurations(&stages, flowRate: recipe.method.flowRate)
        return stages
    }

    /// 依流速算出每段建議注水秒數；悶蒸固定 10 秒，且不超過與下一段的間隔。
    private static func assignPourDurations(_ stages: inout [PourStage], flowRate: Double) {
        var previous = 0.0
        for i in stages.indices {
            let amount = stages[i].targetWater - previous
            previous = stages[i].targetWater
            guard amount > 0 else { stages[i].pourSeconds = 0; continue }
            var seconds = i == 0 && stages[i].name.contains("悶蒸") ? 10 : Int((amount / flowRate).rounded(.up))
            if i + 1 < stages.count {
                let gap = stages[i + 1].startSecond - stages[i].startSecond
                seconds = min(seconds, max(gap - 5, 3))
            }
            stages[i].pourSeconds = max(seconds, 3)
        }
    }

    /// 某一秒「秤上應該顯示」的水量：注水窗內線性增加，注完後維持。用來做注水速度引導與重量曲線。
    static func expectedWater(at second: Double, stages: [PourStage]) -> Double {
        var water = 0.0
        for stage in stages where Double(stage.startSecond) <= second {
            let into = second - Double(stage.startSecond)
            if stage.pourSeconds > 0, into < Double(stage.pourSeconds) {
                return water + (stage.targetWater - water) * into / Double(stage.pourSeconds)
            }
            water = stage.targetWater
        }
        return water
    }

    /// 這個計畫預計多久沖完（用來判斷流速太快或太慢）。
    static func targetFinishSecond(for stages: [PourStage]) -> Int {
        guard let last = stages.last else { return 0 }
        return last.pourSeconds == 0 ? last.startSecond : last.startSecond + last.pourSeconds + 60
    }
}
