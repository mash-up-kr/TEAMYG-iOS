//
//  ToppingHandle.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/27/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

enum ToppingHandle {
    static let length: CGFloat = 44
    static let circleLength: CGFloat = 28
    static let iconLength: CGFloat = 18
    static let cornerOffset: CGFloat = 22
}

struct ToppingHandleIcon: View {
    let icon: Image

    init(_ icon: Image) {
        self.icon = icon
    }

    var body: some View {
        icon
            .renderingMode(.template)
            .resizable()
            .frame(width: ToppingHandle.iconLength, height: ToppingHandle.iconLength)
            .foregroundStyle(.gray900)
            .frame(width: ToppingHandle.circleLength, height: ToppingHandle.circleLength)
            .background(.whiteFixed, in: .circle)
            .overlay {
                Circle()
                    .strokeBorder(.black5, lineWidth: 1)
            }
            .frame(width: ToppingHandle.length, height: ToppingHandle.length)
            .contentShape(.rect)
    }
}

/// 선택된 토핑의 편집 핸들과 그 제스처. C-106(배치)과 C-305(재배치)가 같은 배치 규칙을 쓴다
/// (`canvas-policy.md` §6.4.4). 삭제·테두리 편집 핸들은 액션이 주어진 화면에서만 노출된다.
struct ToppingEditHandles: View {
    let placement: ToppingPlacement
    let canvasSize: CGSize
    let toppingPixelSize: CGSize
    let coordinateSpace: String
    @Binding var draft: ToppingTransformDraft
    let onCommit: (ToppingTransformDraft) -> Void
    var onDeleteTap: (() -> Void)?
    var onBorderEditTap: (() -> Void)?

    var body: some View {
        ZStack {
            if let onDeleteTap {
                actionHandle(.icClose, action: onDeleteTap)
                    .position(handleCenter(horizontal: -1, vertical: -1))
            }

            gestureHandle(.icRotate, gesture: rotateGesture)
                .position(handleCenter(horizontal: 1, vertical: -1))

            if let onBorderEditTap {
                actionHandle(.icEdit, action: onBorderEditTap)
                    .position(handleCenter(horizontal: -1, vertical: 1))
            }

            gestureHandle(.icScale, gesture: scaleGesture)
                .position(handleCenter(horizontal: 1, vertical: 1))
        }
    }

    private func actionHandle(_ icon: Image, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ToppingHandleIcon(icon)
        }
        .buttonStyle(.plain)
    }

    private func gestureHandle(_ icon: Image, gesture: some Gesture) -> some View {
        ToppingHandleIcon(icon)
            .gesture(gesture)
    }
}

private extension ToppingEditHandles {
    var previewPlacement: ToppingPlacement {
        draft.applied(to: placement, in: canvasSize)
    }

    var renderedSize: CGSize {
        previewPlacement.renderedSize(toppingPixelSize: toppingPixelSize, canvasSize: canvasSize)
    }

    /// 핸들은 회전한 토핑의 모서리 바깥에 붙는다 (Figma `C-106`/`C-305`).
    func handleCenter(horizontal: CGFloat, vertical: CGFloat) -> CGPoint {
        previewPlacement.handleCenter(
            horizontal: horizontal,
            vertical: vertical,
            frameSize: ToppingSelectionFrame.size(around: renderedSize),
            cornerOffset: ToppingHandle.cornerOffset,
            in: canvasSize
        )
    }

    var scaleGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace))
            .onChanged { draft.scaleByHandle(magnification: magnification(for: $0)) }
            .onEnded { _ in onCommit(draft.endTransform()) }
    }

    var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace))
            .onChanged { draft.rotateByHandle(rawDegrees: rotation(for: $0)) }
            .onEnded { _ in onCommit(draft.endTransform()) }
    }

    func magnification(for value: DragGesture.Value) -> Double {
        placement.magnification(from: value.startLocation, to: value.location, in: canvasSize)
    }

    func rotation(for value: DragGesture.Value) -> Double {
        placement.rotation(from: value.startLocation, to: value.location, in: canvasSize)
    }
}
