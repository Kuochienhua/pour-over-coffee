import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

/// 把食譜編成 `pourover://recipe?d=…` 連結與 QR Code。朋友用相機掃描即可開啟 App 匯入。
enum RecipeShare {
    static func url(for recipe: BrewRecipe) -> URL? {
        var shared = recipe
        shared.beanID = nil                         // 豆子是個人資料，不分享
        guard let data = try? JSONEncoder().encode(shared) else { return nil }
        let encoded = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(string: "pourover://recipe?d=\(encoded)")
    }

    static func recipe(from url: URL) -> BrewRecipe? {
        guard url.scheme == "pourover", url.host == "recipe",
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "d" })?.value
        else { return nil }
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(BrewRecipe.self, from: data)
    }

    static func qrImage(for url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cg)
    }

    static func summary(for recipe: BrewRecipe) -> String {
        "\(recipe.method.title)｜\(recipe.coffeeGrams.formatted())g 粉、1:\(recipe.ratio.formatted())、\(recipe.waterTemp)°C、研磨\(recipe.grind.rawValue)"
    }
}
