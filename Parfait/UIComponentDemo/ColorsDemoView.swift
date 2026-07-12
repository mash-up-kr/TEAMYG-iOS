import SwiftUI
import UIComponent

/// Color 토큰 전수 카탈로그. 다크모드 전환은 시뮬레이터 설정으로 확인.
struct ColorsDemoView: View {
    var body: some View {
        List {
            ForEach(Self.tokens, id: \.name) { entry in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(entry.color)
                        .frame(width: 44, height: 28)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                    Text(entry.name)
                }
            }
        }
        .navigationTitle("Colors")
    }

    // 토큰이 static let 이라 자동 열거 불가 → 손으로 나열. 토큰 추가 시 여기에도 한 줄.
    static let tokens: [(name: String, color: Color)] = [
        ("cherry", .cherry), ("cherry50", .cherry50), ("cherry100", .cherry100),
        ("cherry200", .cherry200), ("cherry300", .cherry300), ("cherry400", .cherry400),
        ("cherry500", .cherry500), ("cherry700", .cherry700),
        ("gray50", .gray50), ("gray100", .gray100), ("gray200", .gray200),
        ("gray300", .gray300), ("gray400", .gray400), ("gray500", .gray500),
        ("gray600", .gray600), ("gray700", .gray700), ("gray800", .gray800),
        ("gray850", .gray850), ("gray900", .gray900), ("gray950", .gray950),
        ("melon", .melon), ("pudding", .pudding),
        ("success", .success), ("warning", .warning), ("danger", .cherry600), ("info", .info),
        // accentColor 는 SwiftUI 내장 Color.accentColor 와 모호해 제외.
        ("blackFixed", .blackFixed), ("whiteFixed", .whiteFixed)
    ]
}

#Preview {
    NavigationStack {
        ColorsDemoView()
    }
}
