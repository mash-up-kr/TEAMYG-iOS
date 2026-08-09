//
//  YGToastOverlay.swift
//  UIComponent
//
//  Created by 신상우 on 7/29/26.
//

import SwiftUI

/// 토스트 큐에 쌓이는 아이템. `ygToastOverlay(_:)` 바인딩 배열에 append 하면 노출된다.
public struct YGToastItem: Identifiable, Equatable {
    public let id: UUID
    public let kind: YGToast.Kind
    public let message: String

    public init(kind: YGToast.Kind, message: String) {
        self.id = UUID()
        self.kind = kind
        self.message = message
    }
}

public extension View {
    /// 화면 상단에 토스트 스택을 얹는다. 배열에 아이템을 append 하면 위에서 내려와 노출된다.
    ///
    /// Figma 정책(805-5007):
    /// - 노출: 위에서 아래로 내려옴
    /// - 닫기: 위로 스와이프 or 2초 경과 (닫힘 시 배열에서 자동 제거)
    /// - 다중 토스트: **Z축으로 겹쳐 쌓임** — 나중 아이템이 앞 레이어에 내려와 이전 토스트를 덮는다.
    ///   자동 닫힘 2초는 **각 토스트가 나타난 시점부터** 독립적으로 센다(정책 원문에 한정어 없음).
    ///   따라서 동시에 뜬 토스트는 거의 동시에 닫히고, 뒤 토스트가 앞 토스트를 기다리지 않는다.
    ///
    /// `.ygAlert` 등 다른 상단 프레젠테이션보다 **나중(바깥쪽)에** 선언해야 그보다 위 레이어에 노출된다.
    func ygToastOverlay(_ toasts: Binding<[YGToastItem]>) -> some View {
        overlay(alignment: .top) {
            YGToastStack(toasts: toasts)
        }
    }
}

private struct YGToastStack: View {
    @Binding var toasts: [YGToastItem]

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(toasts.enumerated()), id: \.element.id) { index, item in
                YGToastRow(
                    item: item,
                    isFront: item.id == toasts.last?.id
                ) {
                    toasts.removeAll { $0.id == item.id }
                }
                // 배열 순서 = 쌓임 순서. 퇴장 애니메이션 중인 토스트가 뒤 레이어로
                // 떨어지지 않도록(ZStack 전환 시 z순서 뒤집힘 방지) 명시한다.
                .zIndex(Double(index))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(.spring(duration: 0.35), value: toasts)
    }
}

private struct YGToastRow: View {
    let item: YGToastItem
    /// 맨 앞(가장 나중) 토스트인지 — 접근성 노출 판단에만 쓴다.
    /// 자동 닫힘 타이머는 앞/뒤와 무관하게 나타난 시점부터 돈다.
    let isFront: Bool
    let dismiss: () -> Void

    /// 닫기 정책 ② — 나타난 시점부터 자동 닫힘까지 2초
    private static let autoDismissDelay: Duration = .seconds(2)
    /// 닫기 정책 ① — 이 거리보다 위로 끌면 스와이프 닫기로 판정
    private static let dismissDragDistance: CGFloat = 20

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var autoDismissExpired = false

    var body: some View {
        YGToast(item.kind, message: item.message)
            .offset(y: dragOffset)
            .gesture(dragToDismiss)
            .accessibilityHidden(!isFront) // 뒤에 가려진 토스트는 VoiceOver 제외
            .task {
                try? await Task.sleep(for: Self.autoDismissDelay)
                guard !Task.isCancelled else { return }
                // 드래그 중이면 손을 뗄 때 닫는다 (잡고 있는 토스트가 사라지지 않게)
                if isDragging {
                    autoDismissExpired = true
                } else {
                    dismiss()
                }
            }
    }

    private var dragToDismiss: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                // 위로는 그대로 따라가고, 아래로는 저항을 줘서 살짝만 움직임
                let translation = value.translation.height
                dragOffset = translation < 0 ? translation : translation * 0.15
            }
            .onEnded { value in
                isDragging = false
                if value.predictedEndTranslation.height < -Self.dismissDragDistance
                    || autoDismissExpired {
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
                }
            }
    }
}

#Preview {
    @Previewable @State var toasts: [YGToastItem] = []

    VStack(spacing: .gap5) {
        Button("Success 토스트") {
            toasts.append(YGToastItem(kind: .success, message: "초대 코드를 복사했어요"))
        }
        Button("연속 3개 (Z축 스택)") {
            toasts.append(YGToastItem(
                kind: .alert(username: "WWWWWWWWWW", nametagType: .type11),
                message: "님이 59분 전에 쌓았어요"
            ))
            toasts.append(YGToastItem(kind: .warning, message: "내 토핑만 편집할 수 있어요"))
            toasts.append(YGToastItem(kind: .success, message: "초대 코드를 복사했어요"))
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.gray200)
    .ygToastOverlay($toasts)
}
