//
//  PhotoConfirmView.swift
//  CanvasFeature
//
//  Created by 김남수 on 8/1/26.
//

import CanvasDomain
import Photos
import SwiftUI
import UIComponent

/// 선택 사진 확인 화면 (Figma C-102-Confirm). 그리드 셀에서 matched geometry 로 확대되어 나타난다.
/// 우상단 닫기 버튼은 컨테이너(AlbumView) 소유 — 이 화면 위에 그대로 떠 있다.
struct PhotoConfirmView: View {
    let photo: AlbumPickerStore.SelectedPhoto
    let zoomNamespace: Namespace.ID
    let onReselect: () -> Void
    let onNext: () -> Void

    /// 고화질 로드 전까지는 셀 썸네일을 그대로 확대해 애니메이션 공백을 없앤다.
    @State private var fullImage: UIImage?
    @State private var imageAreaSize = CGSize.zero
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(spacing: .gap5) {
            Color.gray100
                .overlay {
                    if let image = fullImage ?? photo.thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()
                .overlay {
                    Rectangle().strokeBorder(Color.gray500, lineWidth: 1)
                }
                .matchedGeometryEffect(id: photo.id, in: zoomNamespace)
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { newSize in
                    imageAreaSize = newSize
                }
                .task(id: imageAreaSize) {
                    guard imageAreaSize != .zero else { return }
                    fullImage = await loadFullImage()
                }

            HStack(spacing: .gap4) {
                YGButton("다시 선택", variant: .mediumSecondary, fillsWidth: true, action: onReselect)
                YGButton("다음", variant: .mediumPrimary, fillsWidth: true, action: onNext)
            }
        }
        .padding(.horizontal, .padding7)
        .padding(.top, 70) // 플로팅 닫기 버튼 영역(60) + 10
        .padding(.bottom, .padding6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.whiteFixed.ignoresSafeArea())
    }

    private func loadFullImage() async -> UIImage? {
        if let asset = photo.asset {
            let targetSize = CGSize(
                width: imageAreaSize.width * displayScale,
                height: imageAreaSize.height * displayScale
            )
            return await asset.requestImage(targetSize: targetSize)
        }
        guard let upload = photo.upload else { return nil }
        return await upload.downsampledImage(
            maxPixelSize: imageAreaSize.longEdgePixelSize(scale: displayScale)
        )
    }
}

#Preview {
    @Previewable @Namespace var zoomNamespace
    PhotoConfirmView(
        photo: .init(id: "preview", asset: nil, upload: nil, thumbnail: nil),
        zoomNamespace: zoomNamespace,
        onReselect: {},
        onNext: {}
    )
}
