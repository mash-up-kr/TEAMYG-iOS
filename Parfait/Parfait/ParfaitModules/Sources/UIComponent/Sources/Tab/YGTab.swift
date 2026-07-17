//
//  YGTab.swift
//  UIComponent
//
//  Created by 신상우 on 7/14/26.
//

import SwiftUI

/// 파르페 세그먼트 탭 컴포넌트.
///
/// Figma `Tab` 컴포넌트셋을 옮긴 것으로, `Parfait`(`+` 아이콘) / `Edit` 두 세그먼트 중
/// 하나를 선택하는 캡슐형 컨트롤이다. 선택된 세그먼트만 흰 알약 배경으로 강조된다.
/// 상태는 선택 / 미선택 만 (Figma 에 Disabled·Pressed 없음).
public struct YGTab: View {
    /// 탭 모드 — `.parfait`(아이콘 + "Parfait") / `.edit`("Edit")
    public enum Mode: CaseIterable {
        case parfait
        case edit

        public var title: String {
            switch self {
            case .parfait: return "Parfait"
            case .edit: return "Edit"
            }
        }
    }

    @Binding private var selection: Mode
    @Namespace private var pillNamespace

    public init(selection: Binding<Mode>) {
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.self) { mode in
                segment(mode)
            }
        }
        .padding(.padding2)
        .background(.white50, in: .capsule)
        .overlay {
            Capsule().strokeBorder(.black5, lineWidth: 1)
        }
    }

    private func segment(_ mode: Mode) -> some View {
        let isSelected = selection == mode

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selection = mode
            }
        } label: {
            HStack(spacing: .gap2) {
                if mode == .parfait {
                    Image.icPlus
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                Text(mode.title)
                    .suit(isSelected ? .body01SemiBold : .body01Regular)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .gray900 : .black50)
            // 아이콘 쪽 padding-3(8) · 텍스트 쪽 padding-5(12) · 상하 padding-3(8)
            .padding(.vertical, .padding3)
            .padding(.leading, mode == .parfait ? .padding3 : .padding5)
            .padding(.trailing, .padding5)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.whiteFixed)
                        .matchedGeometryEffect(id: "pill", in: pillNamespace)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var mode: YGTab.Mode = .parfait

    VStack(spacing: .gap6) {
        YGTab(selection: $mode)
        Text("선택: \(mode.title)")
            .suit(.body02Regular)
            .foregroundStyle(.gray500)
    }
    .padding()
}
