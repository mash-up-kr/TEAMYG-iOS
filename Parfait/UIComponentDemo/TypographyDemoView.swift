import SwiftUI
import UIComponent

/// Typography 토큰 전수 카탈로그.
struct TypographyDemoView: View {
    var body: some View {
        List {
            ForEach(Self.tokens, id: \.name) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("파르페 Parfait 0123")
                        .suit(entry.token)
                }
            }
        }
        .navigationTitle("Typography")
    }

    // 토큰이 static let 이라 자동 열거 불가 → 손으로 나열. 토큰 추가 시 여기에도 한 줄.
    static let tokens: [(name: String, token: Typography)] = [
        ("title01Bold", .title01Bold), ("title01SemiBold", .title01SemiBold),
        ("title02Bold", .title02Bold), ("title02SemiBold", .title02SemiBold),
        ("title03Bold", .title03Bold), ("title03SemiBold", .title03SemiBold),
        ("body01Bold", .body01Bold), ("body01SemiBold", .body01SemiBold), ("body01Regular", .body01Regular),
        ("body02Bold", .body02Bold), ("body02SemiBold", .body02SemiBold), ("body02Regular", .body02Regular),
        ("caption01Medium", .caption01Medium), ("caption01Regular", .caption01Regular)
    ]
}

#Preview {
    NavigationStack {
        TypographyDemoView()
    }
}
