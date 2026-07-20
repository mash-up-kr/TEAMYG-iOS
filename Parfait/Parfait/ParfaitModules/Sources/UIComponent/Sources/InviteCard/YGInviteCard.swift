//
//  YGInviteCard.swift
//  UIComponent
//
//  Created by 김남수 on 7/17/26.
//

import SwiftUI

/// 그룹 초대 코드 카드. 코드 노출 + 초대 메시지 복사.
public struct YGInviteCard: View {
    public enum Status: Equatable {
        /// 초대 가능. `remainingCount` = 남은 인원 수.
        case active(remainingCount: Int)
        /// 최대 인원 도달.
        case invalid
    }

    private let code: String
    private let status: Status

    @State private var showsCopied = false
    @State private var revertTask: Task<Void, Never>?

    public init(code: String, status: Status) {
        self.code = code
        self.status = status
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
                    .frame(width: 218, height: 42)
                    .background(
                        isActive ? Color.cherry100 : .gray200,
                        in: .rect(cornerRadius: Radius.small)
                    )
                copyButton
            }
        }
        .padding(.padding6)
        .frame(width: 335)
        .background(.whiteFixed, in: .rect(cornerRadius: Radius.medium1))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.medium1)
                .strokeBorder(isActive ? Color.cherry100 : .gray100, lineWidth: 1)
        )
        .onDisappear { revertTask?.cancel() }
    }

    private var statusLabel: some View {
        let (text, color): (String, Color) = switch (showsCopied, status) {
        case (true, _): ("복사됨", .gray600)
        case (false, .active(let remainingCount)): ("\(remainingCount)명 남음", .gray600)
        case (false, .invalid): ("최대 인원 도달", .cherry600)
        }
        return Text(text)
            .suit(.body02Regular)
            .foregroundStyle(color)
    }

    private var copyButton: some View {
        Button(action: copy) {
            HStack(spacing: .gap1) {
                Text("복사")
                    .suit(.body02SemiBold)
                Image.icCopy
                    .resizable()
                    .frame(width: 24, height: 24)
            }
        }
        .buttonStyle(CopyButtonStyle())
        .disabled(!isActive)
    }

    private func copy() {
        UIPasteboard.general.string = "친구가 파르페에 초대했어요.\n체리 올리러 가볼까요? \(code)"
        revertTask?.cancel()
        showsCopied = true
        revertTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            showsCopied = false
        }
    }
}

/// 색은 YGButton large 와 동일, 크기만 코드 영역(높이 42)에 맞춘 복사 버튼.
private struct CopyButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? .whiteFixed : .gray500)
            .frame(width: 73, height: 42)
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: .rect(cornerRadius: Radius.small)
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
