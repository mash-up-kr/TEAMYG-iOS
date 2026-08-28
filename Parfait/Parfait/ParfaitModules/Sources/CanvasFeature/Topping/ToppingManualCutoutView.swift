//
//  ToppingManualCutoutView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import CoreGraphics
import SwiftUI
import UIComponent

struct ToppingManualCutoutView: View {
    static let historyBarInset: CGFloat = 18
    static let modeButtonHeight: CGFloat = 40
    static let modeIconLength: CGFloat = 24
    static let backgroundGuideOpacity: Double = 0.5
    static let selectionTintOpacity: Double = 0.5

    let topping: ExtractedTopping
    let brush: ToppingBrush
    let canUndo: Bool
    let canRedo: Bool
    let onUndoTap: () -> Void
    let onRedoTap: () -> Void
    let onBrushModeSelect: (ToppingBrushMode) -> Void
    let onBrushDiameterChange: (Double) -> Void
    let onStrokeEnd: (ToppingBrushStroke) -> Void
    let onCloseTap: () -> Void
    let onConfirmTap: () -> Void

    @State private var viewportSize: CGSize = .zero
    @State private var scale: CGFloat = ToppingMaskEditor.minimumScale
    @State private var translation: CGSize = .zero
    @State private var strokePoints: [CGPoint] = []
    @State private var brushLocation: CGPoint?
    @State private var isAdjustingBrush = false

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: 0) {
                historyBar
                viewport
                editArea
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            YGFloatingBar(
                .editTab(tabs: ["영역", "테두리"], selection: tabSelection),
                onClose: onCloseTap,
                onConfirm: onConfirmTap
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { 0 },
            set: { newTab in
                guard newTab == 1 else { return }
                onConfirmTap()
            }
        )
    }

    private var historyBar: some View {
        ToppingHistoryBar(
            canUndo: canUndo,
            canRedo: canRedo,
            onUndoTap: onUndoTap,
            onRedoTap: onRedoTap
        )
        .padding(.horizontal, Self.historyBarInset)
        .padding(.top, .padding7)
    }

    private var viewport: some View {
        ZStack {
            Image(decorative: topping.photo, scale: 1, orientation: .up)
                .resizable()
                .opacity(Self.backgroundGuideOpacity)

            Image(decorative: topping.image, scale: 1, orientation: .up)
                .resizable()

            // 지금 누끼에 포함된 영역을 붉게 덮어 선택 상태를 보여 준다.
            Image(decorative: topping.image, scale: 1, orientation: .up)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Color.cherry500.opacity(Self.selectionTintOpacity))
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .position(imageCenter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            strokeGuide
        }
        .clipped()
        .contentShape(.rect)
        .overlay {
            ToppingCanvasGestureOverlay(
                onBrushBegan: beginStroke,
                onBrushMoved: extendStroke,
                onBrushEnded: endStroke,
                onBrushCancelled: cancelStroke,
                onMagnify: magnify,
                onPan: pan,
                onTransformEnded: {}
            )
        }
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: resizeViewport)
        .onChange(of: ObjectIdentifier(topping.image)) { _, _ in
            strokePoints = []
        }
    }

    @ViewBuilder
    private var strokeGuide: some View {
        if let strokePath {
            strokePath
                .stroke(
                    Color.cherry500.opacity(Self.selectionTintOpacity),
                    style: StrokeStyle(lineWidth: brushScreenDiameter, lineCap: .round, lineJoin: .round)
                )
                .allowsHitTesting(false)
        }

        if let brushPreviewLocation {
            Circle()
                .fill(Color.cherry500.opacity(Self.selectionTintOpacity))
                .overlay {
                    Circle()
                        .strokeBorder(Color.cherry500, lineWidth: 1)
                }
                .frame(width: brushScreenDiameter, height: brushScreenDiameter)
                .position(brushPreviewLocation)
                .allowsHitTesting(false)
        }
    }

    private var editArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("브러시 크기")
                .suit(.caption01Medium)
                .foregroundStyle(.gray800)
                .padding(.top, .padding6)

            YGSlider(
                value: Binding(get: { brush.diameter }, set: { onBrushDiameterChange($0) }),
                in: ToppingBrush.diameterRange,
                onEditingChanged: { isAdjustingBrush = $0 }
            )
            .frame(height: 32)
            .padding(.top, .padding2)

            HStack(spacing: 11) {
                modeButton("영역 지우기", icon: .icMinusRound, mode: .erase)
                modeButton("영역 채우기", icon: .icAddRound, mode: .fill)
            }
            .padding(.top, .padding3)
        }
        .padding(.horizontal, .padding7)
        .padding(.vertical, .padding6)
    }

    private func modeButton(_ title: String, icon: Image, mode: ToppingBrushMode) -> some View {
        let isSelected = brush.mode == mode

        return Button {
            onBrushModeSelect(mode)
        } label: {
            HStack(spacing: 0) {
                Text(title)
                    .suit(.body02SemiBold)

                icon
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: Self.modeIconLength, height: Self.modeIconLength)
            }
            .foregroundStyle(isSelected ? Color.whiteFixed : .gray900)
            .frame(maxWidth: .infinity)
            .frame(height: Self.modeButtonHeight)
            .background(isSelected ? Color.gray900 : .whiteFixed)
            .overlay {
                Rectangle()
                    .strokeBorder(isSelected ? Color.gray900 : .gray100, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension ToppingManualCutoutView {
    /// 뷰포트 안에 상·하·좌·우 `10pt` 여백을 두고 Aspect Fit 한 크기가 `scale 1.0` 이다.
    var baseSize: CGSize {
        let available = CGSize(
            width: max(viewportSize.width - ToppingMaskEditor.viewportMargin * 2, 0),
            height: max(viewportSize.height - ToppingMaskEditor.viewportMargin * 2, 0)
        )
        let pixelSize = topping.pixelSize
        guard available.width > 0, available.height > 0, pixelSize.width > 0, pixelSize.height > 0 else {
            return .zero
        }

        let fitScale = min(available.width / pixelSize.width, available.height / pixelSize.height)
        return CGSize(width: pixelSize.width * fitScale, height: pixelSize.height * fitScale)
    }

    var displaySize: CGSize {
        CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
    }

    var imageCenter: CGPoint {
        CGPoint(
            x: viewportSize.width / 2 + translation.width,
            y: viewportSize.height / 2 + translation.height
        )
    }

    var imageOrigin: CGPoint {
        CGPoint(x: imageCenter.x - displaySize.width / 2, y: imageCenter.y - displaySize.height / 2)
    }

    var pixelsPerPoint: CGFloat {
        guard displaySize.width > 0 else { return 1 }
        return topping.pixelSize.width / displaySize.width
    }

    /// 브러시 굵기는 `scale 1.0` 화면 기준이라, 마스크에 닿는 크기는 확대해도 변하지 않는다.
    var brushMaskDiameter: Double {
        guard baseSize.width > 0 else { return brush.diameter }
        return brush.diameter * Double(topping.pixelSize.width / baseSize.width)
    }

    var brushScreenDiameter: CGFloat {
        CGFloat(brush.diameter) * scale
    }

    /// 브러시 크기를 조절하는 동안에는 손가락이 없어도 이미지 영역 한가운데에 크기를 보여 준다.
    var brushPreviewLocation: CGPoint? {
        if let brushLocation { return brushLocation }
        guard isAdjustingBrush, viewportSize.width > 0 else { return nil }
        return CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
    }

    var strokePath: Path? {
        guard let first = strokePoints.first else { return nil }

        return Path { path in
            // 길이 0 짜리 선분 + 둥근 캡 = 브러시 굵기짜리 점.
            path.addLines(strokePoints.count > 1 ? strokePoints : [first, first])
        }
    }

    func maskPoint(from viewPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (viewPoint.x - imageOrigin.x) * pixelsPerPoint,
            y: (viewPoint.y - imageOrigin.y) * pixelsPerPoint
        )
    }

    func clamped(_ translation: CGSize) -> CGSize {
        let limitX = max(0, (displaySize.width - viewportSize.width) / 2)
        let limitY = max(0, (displaySize.height - viewportSize.height) / 2)

        return CGSize(
            width: min(max(translation.width, -limitX), limitX),
            height: min(max(translation.height, -limitY), limitY)
        )
    }

    func resizeViewport(_ size: CGSize) {
        viewportSize = size
        translation = clamped(translation)
    }

    func beginStroke(at point: CGPoint) {
        strokePoints = [point]
        brushLocation = point
    }

    func extendStroke(to point: CGPoint) {
        strokePoints.append(point)
        brushLocation = point
    }

    func cancelStroke() {
        strokePoints = []
        brushLocation = nil
    }

    /// 스트로크 경로는 새 마스크가 올라올 때까지 남겨 둔다. 바로 지우면 재합성되는 사이에 한 번 깜빡인다.
    func endStroke() {
        brushLocation = nil
        guard !strokePoints.isEmpty else { return }

        onStrokeEnd(
            ToppingBrushStroke(
                mode: brush.mode,
                diameter: brushMaskDiameter,
                points: strokePoints.map(maskPoint(from:))
            )
        )
    }

    func magnify(by factor: CGFloat) {
        let magnified = scale * factor
        scale = min(max(magnified, ToppingMaskEditor.minimumScale), ToppingMaskEditor.maximumScale)
        translation = clamped(translation)
    }

    func pan(by delta: CGSize) {
        translation = clamped(
            CGSize(width: translation.width + delta.width, height: translation.height + delta.height)
        )
    }
}
