import SwiftUI

struct ShareRecipeView: View {
    let recipe: BrewRecipe
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let url = RecipeShare.url(for: recipe) {
                    if let image = RecipeShare.qrImage(for: url) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 260)
                    }
                    Text(RecipeShare.summary(for: recipe))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text("朋友用 iPhone 相機掃描即可匯入（需已安裝本 App）。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ShareLink("傳送連結", item: url,
                              message: Text("我的手沖食譜：\(RecipeShare.summary(for: recipe))"))
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("分享食譜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("完成") { dismiss() } }
        }
        .presentationDetents([.large])
    }
}
