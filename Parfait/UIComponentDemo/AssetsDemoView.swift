import SwiftUI
import UIComponent

/// 에셋 이미지를 50~400pt 로 확대해 벡터 화질(계단 현상·뭉개짐)을 눈으로 검증하는 뷰.
struct AssetsDemoView: View {
    static let sizes: [CGFloat] = [50, 100, 200, 400]

    // 토큰이 static let 이라 자동 열거 불가 → 손으로 나열. 에셋 추가 시 여기에도 한 줄.
    static let assets: [(name: String, image: Image)] = [
        
    ]

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 40) {
                ForEach(Self.assets, id: \.name) { entry in
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
                                    .foregroundStyle(Color.cherry)
                                    .frame(width: size, height: size)
                                    .border(.quaternary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Assets")
    }
}

#Preview {
    NavigationStack {
        AssetsDemoView()
    }
}
