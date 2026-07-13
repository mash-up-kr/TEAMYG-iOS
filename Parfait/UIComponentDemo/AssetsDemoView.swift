import SwiftUI
import UIComponent

/// 에셋을 50~400pt 로 확대해 벡터 화질(계단 현상·뭉개짐)을 눈으로 검증하는 뷰.
/// 아이콘(SVG·template)은 cherry 로 틴트해 벡터 품질을, 온보딩 이미지(full-color)는 원본 그대로 보여준다.
struct AssetsDemoView: View {
    static let sizes: [CGFloat] = [50, 100, 200, 400]

    // 토큰이 static let 이라 자동 열거 불가 → 손으로 나열. 에셋 추가 시 여기에도 한 줄.
    // 아이콘: template 렌더링 → 틴트 확인. 이미지: 원본(full-color).
    static let icons: [(name: String, image: Image)] = [
        ("icArrowLeft", .icArrowLeft), ("icArrowRight", .icArrowRight),
        ("icCamera", .icCamera), ("icCaretLeft", .icCaretLeft),
        ("icCaretRight", .icCaretRight), ("icCheck", .icCheck),
        ("icCheckRound", .icCheckRound), ("icClose", .icClose),
        ("icCloseRound", .icCloseRound), ("icCopy", .icCopy),
        ("icEnter", .icEnter), ("icGallery", .icGallery),
        ("icHamburger", .icHamburger), ("icLightning", .icLightning),
        ("icNewgroup", .icNewgroup), ("icPlus", .icPlus),
        ("icReverse", .icReverse), ("icSocialApple", .icSocialApple),
        ("icSocialKakao", .icSocialKakao), ("icWarningRound", .icWarningRound)
    ]

    static let images: [(name: String, image: Image)] = [
        ("imageOnboarding1", .imageOnboarding1),
        ("imageOnboarding2", .imageOnboarding2)
    ]

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 40) {
                Text("Icons (template · cherry tint)")
                    .font(.title3.bold())
                ForEach(Self.icons, id: \.name) { entry in
                    assetRow(entry, tint: .cherry)
                }

                Text("Images (original)")
                    .font(.title3.bold())
                ForEach(Self.images, id: \.name) { entry in
                    assetRow(entry, tint: nil)
                }
            }
            .padding()
        }
        .navigationTitle("Assets")
    }

    @ViewBuilder
    private func assetRow(_ entry: (name: String, image: Image), tint: Color?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry.name)
                .font(.headline)
            ForEach(Self.sizes, id: \.self) { size in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(size))pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    entry.image
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(tint ?? Color.primary)
                        .frame(width: size, height: size)
                        .border(.quaternary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AssetsDemoView()
    }
}
