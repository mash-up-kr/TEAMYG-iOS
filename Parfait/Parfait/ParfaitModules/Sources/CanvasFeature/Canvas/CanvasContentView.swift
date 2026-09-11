//
//  CanvasContentView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/23/26.
//

import Common
import Core
import CoreGraphics
import SwiftUI
import UIComponent

struct CanvasContentView: View {
    /// Spotlight 우선순위: 강조 토핑 → Dim → 나머지 토핑 → 배경 (`canvas-policy.md` §4.2).
    ///
    /// 토핑은 서버 `positionZ` 값이 아니라 **정렬된 배열 순서**로 쌓는다 — `positionZ` 는
    /// 클라이언트가 매기는 값이라 범위가 정해져 있지 않고, dim/Spotlight 상수와 같은 축을 쓰면
    /// 값이 커졌을 때 순서가 뒤집힌다.
    private static let dimZIndex: Double = 1_000_000
    private static let spotlightZIndex: Double = 2_000_000

    let content: CanvasStore.CanvasContent
    var spotlightedToppingID: Int?
    var onImageTap: ((CanvasStore.CanvasImage) -> Void)?
    var onDimTap: (() -> Void)?
    /// 토핑 이미지 다운로드 결과 — 로딩 딤(C-001-Loading)이 전부 모일 때까지 기다린다.
    var onToppingImageLoaded: ((Int) -> Void)?
    var onToppingImageLoadFailed: ((Int) -> Void)?

    init(
        content: CanvasStore.CanvasContent,
        spotlightedToppingID: Int? = nil,
        onImageTap: ((CanvasStore.CanvasImage) -> Void)? = nil,
        onDimTap: (() -> Void)? = nil,
        onToppingImageLoaded: ((Int) -> Void)? = nil,
        onToppingImageLoadFailed: ((Int) -> Void)? = nil
    ) {
        self.content = content
        self.spotlightedToppingID = spotlightedToppingID
        self.onImageTap = onImageTap
        self.onDimTap = onDimTap
        self.onToppingImageLoaded = onToppingImageLoaded
        self.onToppingImageLoadFailed = onToppingImageLoadFailed
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // 저장본(`CanvasSnapshotView`)과 같은 가운데 크롭이 되도록 배경을 캔버스 크기에 고정한다.
                // `scaledToFill` 결과를 캔버스보다 큰 채로 두면 ZStack 이 그만큼 커져 크롭 기준이 어긋난다.
                background
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                if spotlightedToppingID != nil {
                    Color.black50
                        .contentShape(.rect)
                        .onTapGesture { onDimTap?() }
                        .zIndex(Self.dimZIndex)
                }

                ForEach(Array(content.images.enumerated()), id: \.element.id) { order, canvasImage in
                    CanvasPlacedImage(
                        canvasImage: canvasImage,
                        canvasSize: proxy.size,
                        onTap: imageTapAction(for: canvasImage),
                        onToppingLoaded: { _ in onToppingImageLoaded?(canvasImage.id) },
                        onToppingLoadFailed: { onToppingImageLoadFailed?(canvasImage.id) }
                    )
                    .zIndex(zIndex(for: canvasImage, order: order))
                }
            }
        }
        .clipped()
    }

    /// `content.images` 는 `positionZ` 오름차순으로 정렬돼 있다 — 배열 순서가 곧 쌓임 순서다.
    private func zIndex(for canvasImage: CanvasStore.CanvasImage, order: Int) -> Double {
        canvasImage.id == spotlightedToppingID ? Self.spotlightZIndex : Double(order)
    }

    private func imageTapAction(for canvasImage: CanvasStore.CanvasImage) -> (() -> Void)? {
        guard let onImageTap else { return nil }
        return { onImageTap(canvasImage) }
    }

    @ViewBuilder
    private var background: some View {
        switch content.background {
        case .color(let hex):
            Color(hex: hex)

        case .image(let url):
            YGImageView(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    YGLottieView(.loadingDark)
                        .frame(width: 44, height: 44)
                case .failure:
                    Color.gray100
                }
            }

        case .imageData(let imageData):
            LocalCanvasBackgroundImage(imageData: imageData)
        }
    }
}

private struct LocalCanvasBackgroundImage: View {
    let imageData: Data

    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray100
                }
            }
            // GeometryReader 는 자식을 좌상단에 앉히므로, 프레임으로 감싸 가운데 크롭을 보장한다 — 저장본과 같은 기준.
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .task(id: DecodeRequest(size: proxy.size, displayScale: displayScale)) {
                image = await ImageDownsampling.decodedImage(
                    from: imageData,
                    maxPixelSize: proxy.size.longEdgePixelSize(scale: displayScale)
                )
            }
        }
    }

    private struct DecodeRequest: Equatable {
        let size: CGSize
        let displayScale: CGFloat
    }
}

/// 테두리는 이미지에 굽지 않고 색·굵기로만 저장되므로(확정 규약), 알파 실루엣을 떠서 토핑 뒤에 깐다.
/// C-105·C-106 미리보기와 같은 `ToppingBorderRenderer` 를 타야 저장 전후 모습이 같다.
struct CanvasPlacedImage: View {
    let canvasImage: CanvasStore.CanvasImage
    let canvasSize: CGSize
    var isSelected = false
    var onTap: (() -> Void)?
    var onToppingLoaded: ((CGSize) -> Void)?
    var onToppingLoadFailed: (() -> Void)?

    @Environment(\.canvasToppingRenderer) private var renderer
    @Environment(\.displayScale) private var displayScale
    @State private var topping: CGImage?
    @State private var silhouette: CGImage?

    var body: some View {
        // 토핑이 오기 전엔 `content` 가 빈 옵셔널 뷰라 `.task` 가 돌지 않는다(`EmptyView` 와 같다).
        // 항상 존재하는 컨테이너에 걸어야 첫 다운로드가 시작된다.
        ZStack {
            content
        }
        .task(id: loadKey) {
            await load()
        }
    }

    private var loadKey: LoadKey {
        LoadKey(
            canvasImage,
            hasRenderSize: neededLongEdgePixels > 0,
            decodeLongEdge: decodeLongEdge,
            borderRedrawKey: borderRedrawKey
        )
    }

    @ViewBuilder
    private var content: some View {
        if let topping {
            CanvasToppingLayer(
                topping: topping,
                silhouette: silhouette,
                borderColor: canvasImage.border.map { Color(hex: $0.colorHex) },
                borderWidth: canvasImage.border.map { CGFloat($0.width) } ?? 0,
                placement: placement,
                canvasSize: canvasSize,
                isSelected: isSelected,
                onTap: onTap
            )
        }
    }

    private func load() async {
        // 렌더러는 캔버스 화면이 주입한다. 주입이 없으면 그릴 수단이 없다.
        // 레이아웃 전(캔버스 크기 0)에는 필요 해상도를 모른다 — 크기가 정해지면 `task` 가 다시 돈다.
        guard let renderer, neededLongEdgePixels > 0 else { return }

        // 이미 그려 둔 이미지는 새 해상도가 도착할 때까지 그대로 둔다 — 확대 중 깜빡이지 않게.
        let loaded = await renderer.topping(
            at: canvasImage.imageURL,
            neededLongEdge: neededLongEdgePixels
        )
        guard !Task.isCancelled else { return }
        topping = loaded
        if let loaded {
            onToppingLoaded?(CGSize(width: loaded.width, height: loaded.height))
        } else {
            onToppingLoadFailed?()
        }

        guard let loaded, let border = canvasImage.border, border.width > 0 else {
            silhouette = nil
            return
        }
        let rendered = await renderer.silhouette(
            of: loaded,
            at: canvasImage.imageURL,
            width: border.width,
            renderedLongEdge: longSide
        )
        guard !Task.isCancelled else { return }
        silhouette = rendered
    }

    private var placement: ToppingPlacement {
        ToppingPlacement(canvasImage)
    }

    private var longSide: CGFloat {
        placement.longSide(in: canvasSize)
    }

    /// 화면에 그려질 긴 변의 픽셀 수. 짧은 변은 원본 비율을 따라가므로 이 값만으로 필요 해상도가 정해진다 —
    /// 이미지를 받기 전에도 계산할 수 있어 "받아 보고 크기를 정하는" 순환을 피한다.
    private var neededLongEdgePixels: CGFloat {
        longSide * displayScale
    }

    private var decodeLongEdge: CGFloat {
        ToppingDecodeBucket.longEdge(covering: neededLongEdgePixels)
    }

    private var borderRedrawKey: Int {
        guard let border = canvasImage.border, longSide > 0 else { return 0 }
        return Int((CGFloat(border.width) / longSide * decodeLongEdge).rounded())
    }

    /// 확대해서 버킷이 올라가면 다시 받아야 하므로 해상도도 키에 넣는다.
    /// 버킷 안에서 배율만 오르내리는 동안에는 값이 그대로라 재디코딩이 일어나지 않는다.
    private struct LoadKey: Equatable {
        let imageURL: URL
        let border: CanvasStore.CanvasImageBorder?
        let hasRenderSize: Bool
        let decodeLongEdge: CGFloat
        let borderRedrawKey: Int

        init(
            _ canvasImage: CanvasStore.CanvasImage,
            hasRenderSize: Bool,
            decodeLongEdge: CGFloat,
            borderRedrawKey: Int
        ) {
            imageURL = canvasImage.imageURL
            border = canvasImage.border
            self.hasRenderSize = hasRenderSize
            self.decodeLongEdge = decodeLongEdge
            self.borderRedrawKey = borderRedrawKey
        }
    }
}
