import Foundation

/// 喝完後勾選的口感。
enum Symptom: String, CaseIterable, Identifiable, Codable {
    case sour = "尖酸"
    case thin = "水感單薄"
    case flat = "平淡沒層次"
    case bitter = "苦"
    case astringent = "澀、口乾"
    case tooStrong = "太濃"
    case tooWeak = "太淡"
    case great = "很好喝"

    var id: String { rawValue }
}

struct Advice: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    /// 可以一鍵套用到下一杯的調整；nil 表示只是技巧建議。
    var apply: ((inout BrewRecipe) -> Void)?
}

/// 咖啡師式的萃取診斷：從口感推回萃取不足／過度，再給出一次只改一個變因的建議。
enum BrewAdvisor {
    static func advice(symptoms: Set<Symptom>, recipe: BrewRecipe,
                       brewSeconds: Int?, beanDays: Int? = nil) -> [Advice] {
        var list: [Advice] = []
        let under = !symptoms.isDisjoint(with: [.sour, .thin])
        let over = !symptoms.isDisjoint(with: [.bitter, .astringent])

        if symptoms.contains(.great) && symptoms.count == 1 {
            return [Advice(title: "這杯很成功！",
                           detail: "在紀錄裡按「再沖一次」就能用完全相同的參數重現。換新豆時從這組參數開始調整。")]
        }

        // 沖煮時間是最客觀的線索，先看它。
        // 只有在所有注水都完成後才判斷流速；中途就按「完成」的紀錄沒有參考價值。
        let stages = PourPlanner.stages(for: recipe)
        let lastPour = stages.last(where: { $0.pourSeconds > 0 })?.startSecond ?? 0
        if let brewSeconds, brewSeconds > lastPour {
            let target = PourPlanner.targetFinishSecond(for: stages)
            if target > 0, brewSeconds > target + 30 {
                list.append(coarser(reason: "比預計多了 \(brewSeconds - target) 秒才滴完，流速太慢容易苦澀。", recipe: recipe))
            } else if target > 0, brewSeconds < target - 30, !over {
                list.append(finer(reason: "比預計早了 \(target - brewSeconds) 秒滴完，水流過粉層太快，萃取不夠。", recipe: recipe))
            }
        }

        if under && over {
            list.append(Advice(
                title: "同時酸又苦：萃取不均",
                detail: "部分粉萃取過度、部分不足，常見原因是通道效應。悶蒸時確認粉全部濕透，注水繞圈均勻、避免沖到濾紙邊，並檢查磨豆機細粉是否太多。"))
        } else if under {
            if !list.contains(where: { $0.title.contains("磨細") }) {
                list.append(finer(reason: "尖酸、單薄是萃取不足的典型表現。", recipe: recipe))
            }
            if recipe.waterTemp < 96 {
                list.append(Advice(title: "水溫提高到 \(recipe.waterTemp + 2)°C",
                                   detail: "溫度越高萃取越快，對淺焙豆特別有效。",
                                   apply: { $0.waterTemp = min($0.waterTemp + 2, 100) }))
            }
            if recipe.method == .kasuya46, symptoms.contains(.sour), recipe.kasuyaTaste != .sweeter {
                list.append(Advice(title: "4:6 法改為「偏甜」",
                                   detail: "第一注少一點、第二注多一點，可以壓低酸感、拉出甜味。",
                                   apply: { $0.kasuyaTaste = .sweeter }))
            }
        } else if over {
            if !list.contains(where: { $0.title.contains("磨粗") }) {
                list.append(coarser(reason: "苦、澀是萃取過度的訊號。", recipe: recipe))
            }
            if recipe.waterTemp > 85 {
                list.append(Advice(title: "水溫降到 \(recipe.waterTemp - 2)°C",
                                   detail: "降低溫度可減少苦味物質溶出，深焙豆建議 85–88°C。",
                                   apply: { $0.waterTemp = max($0.waterTemp - 2, 80) }))
            }
            if symptoms.contains(.astringent) {
                list.append(Advice(title: "注水輕柔一點",
                                   detail: "澀感常來自過度攪動粉層或細粉堵塞。降低水柱高度、減少搖晃或攪拌。"))
            }
        }

        if symptoms.contains(.flat) {
            if let beanDays, beanDays > 35 {
                list.append(Advice(title: "豆子可能不新鮮了",
                                   detail: "已烘焙 \(beanDays) 天，香氣自然會變弱。可提高水溫 1–2°C 補一些萃取。"))
            }
            if recipe.method == .kasuya46, recipe.kasuyaTaste != .brighter {
                list.append(Advice(title: "4:6 法改為「偏酸」",
                                   detail: "第一注多一點，讓酸質更明亮、層次更多。",
                                   apply: { $0.kasuyaTaste = .brighter }))
            } else if !under && !over {
                list.append(Advice(title: "水溫提高到 \(recipe.waterTemp + 2)°C",
                                   detail: "多一點萃取通常能帶出更多香氣與甜感。",
                                   apply: { $0.waterTemp = min($0.waterTemp + 2, 100) }))
            }
        }

        // 濃淡只跟粉水比（或 4:6 的後段注數）有關，跟酸苦是兩回事。
        if symptoms.contains(.tooStrong) {
            if recipe.method == .kasuya46, recipe.kasuyaStrength != .lighter {
                list.append(Advice(title: "4:6 法改為「淡」",
                                   detail: "後 60% 改成 2 注，萃取濃度會下降。",
                                   apply: { $0.kasuyaStrength = .lighter }))
            } else {
                list.append(Advice(title: "粉水比調到 1:\((recipe.ratio + 1).formatted())",
                                   detail: "加水稀釋濃度，酸苦平衡不會改變。",
                                   apply: { $0.ratio = min($0.ratio + 1, 18) }))
            }
        }
        if symptoms.contains(.tooWeak) {
            if recipe.method == .kasuya46, recipe.kasuyaStrength != .stronger {
                list.append(Advice(title: "4:6 法改為「濃」",
                                   detail: "後 60% 改成 4 注，萃取更完整、口感更厚。",
                                   apply: { $0.kasuyaStrength = .stronger }))
            } else {
                list.append(Advice(title: "粉水比調到 1:\((recipe.ratio - 1).formatted())",
                                   detail: "用更多粉或更少水提高濃度。",
                                   apply: { $0.ratio = max($0.ratio - 1, 12) }))
            }
        }

        if list.isEmpty {
            list.append(Advice(title: "先維持這組參數",
                               detail: "勾選喝到的口感，就能得到調整建議。每次只改一個變因，才知道是哪個調整有效。"))
        }
        return list
    }

    private static func finer(reason: String, recipe: BrewRecipe) -> Advice {
        guard let finer = recipe.grind.finer else {
            return Advice(title: "延長萃取時間", detail: reason + "研磨已是最細，改為增加一次注水或延長悶蒸。")
        }
        return Advice(title: "研磨磨細一格（\(finer.rawValue)）", detail: reason + "磨細會增加萃取率與時間。",
                      apply: { $0.grind = finer })
    }

    private static func coarser(reason: String, recipe: BrewRecipe) -> Advice {
        guard let coarser = recipe.grind.coarser else {
            return Advice(title: "降低水溫或縮短時間", detail: reason + "研磨已是最粗，改為降低水溫 2°C。")
        }
        return Advice(title: "研磨磨粗一格（\(coarser.rawValue)）", detail: reason + "磨粗可以加快流速、減少萃取。",
                      apply: { $0.grind = coarser })
    }
}
