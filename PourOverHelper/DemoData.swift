#if DEBUG
import Foundation
import SwiftData

/// 截圖用的示範資料。只在 Debug 版、且啟動參數帶 `-seedDemo` 時寫入，正式版不會編進去。
@MainActor
enum DemoData {
    static func seedIfRequested(context: ModelContext, app: AppState) {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemo") else { return }
        try? context.delete(model: BrewLog.self)
        try? context.delete(model: Bean.self)

        let day: TimeInterval = 86_400
        let beans = [
            Bean(name: "耶加雪菲 孔加", origin: "衣索比亞", process: "水洗", roast: .light,
                 roastDate: .now.addingTimeInterval(-10 * day), note: "茉莉花、檸檬皮、紅茶感"),
            Bean(name: "粉紅波旁 花園", origin: "哥倫比亞", process: "蜜處理", roast: .lightMedium,
                 roastDate: .now.addingTimeInterval(-5 * day), note: "莓果、焦糖、圓潤酸質"),
            Bean(name: "瑰夏 綠標", origin: "巴拿馬", process: "日曬", roast: .light,
                 roastDate: .now.addingTimeInterval(-16 * day), note: "柑橘、蜂蜜、佛手柑"),
            Bean(name: "喜拉朵", origin: "巴西", process: "日曬", roast: .medium,
                 roastDate: .now.addingTimeInterval(-32 * day), note: "堅果、可可、低酸"),
        ]
        beans.enumerated().forEach { i, bean in
            bean.createdAt = .now.addingTimeInterval(-Double(i) * 60)
            context.insert(bean)
        }

        var recipe = BrewRecipe()
        recipe.method = .kasuya46
        recipe.coffeeGrams = 20
        recipe.ratio = 15
        recipe.waterTemp = 94
        recipe.grind = .coarse
        recipe.kasuyaTaste = .sweeter
        recipe.beanID = beans[0].uid

        var hoffmann = recipe
        hoffmann.method = .hoffmann
        hoffmann.coffeeGrams = 15
        hoffmann.ratio = 16.5
        hoffmann.grind = .mediumFine
        hoffmann.beanID = beans[1].uid

        let logs = [
            BrewLog(date: .now.addingTimeInterval(-0.2 * day), beanName: beans[0].name, recipe: recipe,
                    brewSeconds: 214, rating: 5, note: "甜感很明顯，尾韻像紅茶", grinderClicks: 30,
                    symptoms: [.great]),
            BrewLog(date: .now.addingTimeInterval(-1.1 * day), beanName: beans[1].name, recipe: hoffmann,
                    brewSeconds: 168, rating: 3, note: "有點尖酸，下次磨細一點", grinderClicks: 22,
                    symptoms: [.sour, .thin]),
            BrewLog(date: .now.addingTimeInterval(-2.3 * day), beanName: beans[2].name, recipe: recipe,
                    brewSeconds: 225, rating: 4, note: "花香乾淨，柑橘調明亮", grinderClicks: 30),
            BrewLog(date: .now.addingTimeInterval(-4 * day), beanName: beans[3].name, recipe: hoffmann,
                    brewSeconds: 252, rating: 3, note: "偏苦，水溫降一點試試", grinderClicks: 22,
                    symptoms: [.bitter]),
        ]
        logs.forEach(context.insert)
        app.recipe = recipe
    }
}
#endif
