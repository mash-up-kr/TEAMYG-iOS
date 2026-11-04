//
//  YGInviteCard.swift
//  UIComponent
//
//  Created by 김남수 on 7/17/26.
//

import SwiftUI

/// 그룹 초대 코드 카드. 코드 노출 + 초대 메시지 시스템 공유.
public struct YGInviteCard: View {
    public enum Status: Equatable {
        /// 초대 가능. `remainingCount` = 남은 인원 수.
        case active(remainingCount: Int)
        /// 최대 인원 도달.
        case invalid
    }

    private let code: String
    private let status: Status
    /// 공유 버튼 탭 시 호출 — 호출부가 이벤트 수집 등에 쓴다.
    private let onShare: (() -> Void)?

    public init(code: String, status: Status, onShare: (() -> Void)? = nil) {
        self.code = code
        self.status = status
        self.onShare = onShare
    }

    private var isActive: Bool { status != .invalid }

    public var body: some View {
        VStack(spacing: .gap3) {
            HStack {
                Text("그룹 초대 코드")
                    .suit(.body02Regular)
                    .foregroundStyle(.gray400)
                Spacer()
                statusLabel
            }
            HStack(spacing: .gap4) {
                Text(code)
                    .suit(.body01SemiBold)
                    .foregroundStyle(isActive ? .gray900 : .gray500)
                    .frame(height: 42)
                    .frame(maxWidth: .infinity)
                    .background(isActive ? Color.cherry100 : .gray200)
                shareButton
            }
        }
        .padding(.padding6)
        .background(.whiteFixed)
        .overlay(
            Rectangle()
                .strokeBorder(isActive ? Color.cherry100 : .gray100, lineWidth: 1)
        )
    }

    private var statusLabel: some View {
        let (text, color): (String, Color) = switch status {
        case .active(let remainingCount): ("\(remainingCount)명 남음", .gray600)
        case .invalid: ("최대 인원 도달", .cherry600)
        }
        return Text(text)
            .suit(.body02Regular)
            .foregroundStyle(color)
    }

    private var shareButton: some View {
        ShareLink(item: Self.inviteMessage(code: code)) {
            Text("공유하기")
                .suit(.body02SemiBold)
        }
        .buttonStyle(ShareButtonStyle())
        .disabled(!isActive)
        // 공유 시트 완료 여부는 ShareLink 가 알려 주지 않는다 — 탭 시점에 알린다.
        .simultaneousGesture(TapGesture().onEnded { onShare?() })
    }

    /// 초대 메시지 — 링크를 탭하면 앱이 열려 코드가 채워진 초대코드 화면으로 간다(유니버설 링크).
    /// 붙여넣기 쪽은 맨 뒤 6자를 코드로 읽으므로 링크는 반드시 코드로 끝나야 한다.
    public static func inviteMessage(code: String) -> String {
        "친구가 파르페에 초대했어요.\n체리 올리러 가볼까요?\nhttps://parfait-app.store/link?inviteCode=\(code)"
    }
}

/// 색은 YGButton large 와 동일, 크기만 코드 영역(높이 42)에 맞춘 공유 버튼.
private struct ShareButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? .whiteFixed : .gray500)
            .padding(.init(top: 10, leading: 12, bottom: 10, trailing: 10))
            .background(
                backgroundColor(isPressed: configuration.isPressed)
            )
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else { return .gray200 }
        return isPressed ? .gray950 : .gray900
    }
}

#Preview {
    VStack(spacing: .gap5) {
        YGInviteCard(code: "AB12CD", status: .active(remainingCount: 3))
        YGInviteCard(code: "AB12CD", status: .invalid)
    }
    .padding()
    .background(.gray50)
}
