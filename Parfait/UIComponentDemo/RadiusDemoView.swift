import SwiftUI
import UIComponent

/// Radius 토큰 전수 카탈로그. 각 토큰을 실제 코너에 적용해 곡률을 눈으로 비교한다.
struct RadiusDemoView: View {
    var body: some View {
        List {
            ForEach(Self.tokens, id: \.name) { entry in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: entry.value)
                        .fill(Color.cherry100)
                        .overlay(RoundedRectangle(cornerRadius: entry.value).strokeBorder(Color.cherry))
                        .frame(width: 88, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                        Text("\(Int(entry.value))pt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Radius")
    }

    // 토큰이 static let 이라 자동 열거 불가 → 손으로 나열. 토큰 추가 시 여기에도 한 줄.
    static let tokens: [(name: String, value: CGFloat)] = [
        ("xsmall", Radius.xsmall), ("small", Radius.small),
        ("medium1", Radius.medium1), ("medium2", Radius.medium2),
        ("large", Radius.large), ("xlarge1", Radius.xlarge1),
        ("xlarge2", Radius.xlarge2), ("round", Radius.round)
    ]
}

#Preview {
    NavigationStack {
        RadiusDemoView()
    }
}
