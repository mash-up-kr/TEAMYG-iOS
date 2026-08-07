//
//  YGFloatingBar.swift
//  UIComponent
//
//  Created by 김남수 on 8/3/26.
//

import SwiftUI

/// 파르페 플로팅 바.
///
/// Figma `Floating Bar` — Status(Back-Close·Close·Edit·Edit-Tab).
/// 배경 없이 콘텐츠 위에 떠 있는 상단 바로, 원형 버튼은 `YGCircleButton`(`.default`) 재사용.
/// 뒤로가기·닫기 액션을 생략하면 `dismiss` 가 기본 동작.
public struct YGFloatingBar: View {
    public enum Status {
        /// 뒤로가기(좌) + 닫기(우)
        case backClose
        /// 닫기(우)
        case close
        /// 닫기(좌) + 타이틀(중앙) + 확인(우)
        case edit(title: String)
        /// 닫기(좌) + 밑줄 탭(중앙) + 확인(우)
        case editTab(tabs: [String], selection: Binding<Int>)
    }

    private let status: Status
    private let onBack: (() -> Void)?
    private let onClose: (() -> Void)?
    private let onConfirm: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// - Parameters:
    ///   - status: 바 구성 상태.
    ///   - onBack: 뒤로가기 버튼 탭. `backClose` 에서만 노출. 생략하면 `dismiss`.
    ///   - onClose: 닫기 버튼 탭. 모든 상태에서 노출. 생략하면 `dismiss`.
    ///   - onConfirm: 확인(체크) 버튼 탭. `edit`/`editTab` 에서만 노출.
    public init(
        _ status: Status,
        onBack: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        onConfirm: (() -> Void)? = nil
    ) {
        self.status = status
        self.onBack = onBack
        self.onClose = onClose
        self.onConfirm = onConfirm
    }

    public var body: some View {
        HStack(spacing: 0) {
            switch status {
            case .backClose:
                circleButton(.icCaretLeft, action: onBack ?? { dismiss() })
                Spacer(minLength: 0)
                closeButton
            case .close:
                Spacer(minLength: 0)
                closeButton
            case .edit(let title):
                closeButton
                Spacer(minLength: 0)
                Text(title)
                    .suit(.body01Regular)
                    .foregroundStyle(.gray800)
                    .lineLimit(1)
                Spacer(minLength: 0)
                confirmButton
            case .editTab(let tabs, let selection):
                closeButton
                Spacer(minLength: 0)
                editTabButtons(tabs, selection: selection)
                Spacer(minLength: 0)
                confirmButton
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, .padding7) // 좌우 20
        .padding(.top, .padding6)        // 상 16
    }

    private var closeButton: some View {
        circleButton(.icClose, action: onClose ?? { dismiss() })
    }

    private var confirmButton: some View {
        circleButton(.icCheck, action: onConfirm ?? {})
    }

    private func circleButton(_ icon: Image, action: @escaping () -> Void) -> some View {
        YGCircleButton(icon, variant: .default, action: action)
    }

    private func editTabButtons(_ tabs: [String], selection: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { index in
                let isSelected = selection.wrappedValue == index

                Button {
                    selection.wrappedValue = index
                } label: {
                    Text(tabs[index])
                        .suit(isSelected ? .body01SemiBold : .body01Regular)
                        .foregroundStyle(isSelected ? Color.gray900 : Color.gray500)
                        .padding(.bottom, .padding2) // 텍스트-밑줄 간격 4
                        .overlay(alignment: .bottom) {
                            if isSelected {
                                Rectangle()
                                    .fill(.gray900)
                                    .frame(height: 1)
                            }
                        }
                        .padding(.horizontal, .padding4) // 좌우 10
                        .padding(.vertical, .padding3)   // 상하 8
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    @Previewable @State var tabIndex = 0

    VStack(spacing: .gap5) {
        YGFloatingBar(.backClose)
        YGFloatingBar(.close)
        YGFloatingBar(.edit(title: "Text"), onConfirm: {})
        YGFloatingBar(
            .editTab(tabs: ["영역", "테두리"], selection: $tabIndex),
            onConfirm: {}
        )
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.gray200)
}
