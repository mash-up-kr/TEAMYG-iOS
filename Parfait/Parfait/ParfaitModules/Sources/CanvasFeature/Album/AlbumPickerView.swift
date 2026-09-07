//
//  AlbumPickerView.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import CanvasDomain
import Core
import Photos
import SwiftUI
import UIComponent

/// 사진 선택 화면 (Figma C-102-Reselect). 우상단 닫기 버튼은 컨테이너(AlbumView) 소유.
/// 상단 제목은 사진이 있을 때만 닫기 버튼과 같은 라인에 표시한다 — 빈 화면은 제목 숨김.
public struct AlbumPickerView: View {
    @State private var store: AlbumPickerStore
    @Namespace private var zoomNamespace
    @State private var toasts: [YGToastItem] = []
    private let showsSelectionGuide: Bool

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: .gap4), count: 3)

    public init(store: AlbumPickerStore, showsSelectionGuide: Bool = true) {
        _store = State(initialValue: store)
        self.showsSelectionGuide = showsSelectionGuide
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if hasContent {
                    topBar
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: .gap7) {
                        if !store.state.recentUploads.isEmpty {
                            recentUploadsSection
                        }
                        ForEach(store.state.sections) { section in
                            daySection(section)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, .padding7)
                    .padding(.top, .padding6)
                }
                .background(Color.whiteFixed)
                .overlay {
                    if !hasContent {
                        emptyView
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if store.state.isLimited {
                        YGButton("사진 재선택", variant: .mediumPrimary) {
                            store.send(.reselectTapped)
                        }
                        .padding(.vertical, .padding6)
                        .frame(maxWidth: .infinity)
                        .background(Color.whiteFixed)
                    }
                }
                // 상단 바 아래에 붙여 토스트가 바를 가리지 않게 한다 (CanvasView 와 같은 패턴).
                .ygToastOverlay($toasts)
            }

            if let selectedPhoto = store.state.selectedPhoto {
                PhotoConfirmView(
                    photo: selectedPhoto,
                    zoomNamespace: zoomNamespace,
                    onReselect: {
                        withAnimation(.smooth(duration: 0.35)) {
                            store.send(.confirmReselectTapped)
                        }
                    },
                    onNext: { store.send(.confirmNextTapped) }
                )
                .zIndex(1) // 축소(제거) 애니메이션 동안 그리드 위에 유지
            }
        }
        .onAppear {
            store.send(.appeared)
            if showsSelectionGuide {
                toasts.append(
                    YGToastItem(kind: .warning, message: "대상이 배경과 선명하게 구분될수록 깔끔하게 선택돼요")
                )
            }
        }
        .onDisappear { store.send(.disappeared) }
    }

    private var hasContent: Bool {
        !store.state.recentUploads.isEmpty || !store.state.sections.isEmpty
    }

    /// 네비게이션 바 형태의 상단 바 — 닫기 버튼(44, AlbumView 소유)과 같은 라인에 가운데 제목.
    private var topBar: some View {
        Text("오늘 찍은 사진")
            .suit(.body01Regular)
            .foregroundStyle(Color.gray900)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .padding(.top, .padding6)
            .background(Color.whiteFixed)
    }

    /// 빈 상태 (Figma C-102-Empty) — 최근 업로드·앨범 사진이 모두 없을 때 중앙 표시.
    private var emptyView: some View {
        VStack(spacing: .gap1) {
            Image.imageGalleryEmpty
            Text("오늘 찍은 사진이 없어요\n사진을 찍고 토핑을 추가해 보세요")
                .suit(.body02Regular)
                .foregroundStyle(Color.gray300)
                .multilineTextAlignment(.center)
                .fixedSize() // 이미지 폭에 맞춰 줄바꿈되지 않도록 텍스트 고유 폭 유지 (디자인: 2줄 고정)
        }
    }

    private var recentUploadsSection: some View {
        VStack(alignment: .leading, spacing: .gap4) {
            Text("최근 업로드한 사진")
                .suit(.body02Regular)
                .foregroundStyle(Color.gray900)
            LazyVGrid(columns: gridColumns, spacing: .gap4) {
                ForEach(store.state.recentUploads) { upload in
                    RecentUploadCell(
                        upload: upload,
                        zoomNamespace: zoomNamespace,
                        isZoomSource: store.state.selectedPhoto == nil
                    ) { thumbnail in
                        withAnimation(.smooth(duration: 0.35)) {
                            store.send(.recentUploadTapped(upload, thumbnail: thumbnail))
                        }
                    }
                }
            }
        }
    }

    private func daySection(_ section: PhotoDaySection) -> some View {
        VStack(alignment: .leading, spacing: .gap4) {
            HStack(spacing: .gap1) {
                Text(section.dayTitle)
                    .suit(.body02Regular)
                    .foregroundStyle(Color.gray900)
                Text(section.weekdayTitle)
                    .suit(.body02Regular)
                    .foregroundStyle(Color.gray300)
            }
            LazyVGrid(columns: gridColumns, spacing: .gap4) {
                ForEach(section.assets, id: \.localIdentifier) { asset in
                    PhotoAssetCell(
                        asset: asset,
                        zoomNamespace: zoomNamespace,
                        isZoomSource: store.state.selectedPhoto == nil
                    ) { thumbnail in
                        withAnimation(.smooth(duration: 0.35)) {
                            store.send(.photoTapped(asset, thumbnail: thumbnail))
                        }
                    }
                }
            }
        }
    }
}

/// 최근 업로드 셀 — 저장소가 넘긴 Data 를 실제 셀 크기(포인트) × 스케일 픽셀로 축소 디코딩해 표시.
private struct RecentUploadCell: View {
    let upload: StoredImage
    let zoomNamespace: Namespace.ID
    /// 확인 화면이 떠 있는 동안 false — matched geometry 소스는 확인 화면 이미지 하나여야 한다.
    let isZoomSource: Bool
    let onTap: (UIImage?) -> Void

    @State private var image: UIImage?
    @State private var cellSize = CGSize.zero
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Button {
            onTap(image)
        } label: {
            Color.gray100
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()
                .contentShape(.rect) // clipped 는 그리기만 자름 — 넘친 이미지가 이웃 셀 탭을 가로채지 않도록 히트 영역 제한
                .matchedGeometryEffect(id: upload.zoomIdentifier, in: zoomNamespace, isSource: isZoomSource)
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            cellSize = newSize
        }
        .task(id: cellSize) {
            guard cellSize != .zero else { return }
            image = await upload.downsampledImage(
                maxPixelSize: cellSize.longEdgePixelSize(scale: displayScale)
            )
        }
    }
}

/// 기기 사진 셀 — 실제 셀 크기(포인트) × 스케일 픽셀의 썸네일만 요청 (원본 디코딩 방지, 기기 폭 대응).
private struct PhotoAssetCell: View {
    let asset: PHAsset
    let zoomNamespace: Namespace.ID
    /// 확인 화면이 떠 있는 동안 false — matched geometry 소스는 확인 화면 이미지 하나여야 한다.
    let isZoomSource: Bool
    let onTap: (UIImage?) -> Void

    @State private var thumbnail: UIImage?
    @State private var cellSize = CGSize.zero
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Button {
            onTap(thumbnail)
        } label: {
            Color.gray100
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()
                .overlay {
                    Rectangle().strokeBorder(Color.black5, lineWidth: 1)
                }
                .contentShape(.rect) // clipped 는 그리기만 자름 — 넘친 이미지가 이웃 셀 탭을 가로채지 않도록 히트 영역 제한
                .matchedGeometryEffect(id: asset.localIdentifier, in: zoomNamespace, isSource: isZoomSource)
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            cellSize = newSize
        }
        // 셀 크기가 정해진 뒤 요청, 회전 등으로 크기가 바뀌면 재요청.
        .task(id: cellSize) {
            guard cellSize != .zero else { return }
            let targetSize = CGSize(
                width: cellSize.width * displayScale,
                height: cellSize.height * displayScale
            )
            thumbnail = await asset.requestImage(targetSize: targetSize)
        }
    }
}

extension StoredImage {
    func downsampledImage(maxPixelSize: Int) async -> UIImage? {
        let imageData = imageData
        let decodedImage = await Task.detached(priority: .userInitiated) {
            ImageDownsampling.decodedImage(from: imageData, maxPixelSize: maxPixelSize)
        }.value
        return decodedImage.map { UIImage(cgImage: $0) }
    }
}

extension PHAsset {
    /// 셀·확인 화면 공용 이미지 요청.
    /// ponytail: 요청 취소·프리페치·캐싱은 성능 최적화 작업에서 (스펙: 스코프 제외).
    func requestImage(targetSize: CGSize) async -> UIImage? {
        // 빈 asset(프리뷰의 PHAsset() 등)은 PHImageManager 내부 assertion 으로 크래시 — 요청 자체를 건너뛴다.
        // 실제 asset 의 localIdentifier 는 "UUID/L0/001" 형식, 빈 asset 은 "(null)/L0/001" (isEmpty 아님 주의).
        guard let uuidPart = localIdentifier.split(separator: "/").first,
              UUID(uuidString: String(uuidPart)) != nil
        else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat // 콜백 1회 보장 (opportunistic 은 다회 → continuation 중복 resume 크래시)
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true // iCloud 최적화 사진도 표시
            PHImageManager.default().requestImage(
                for: self,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

#Preview("일부허용 (재선택 버튼)") {
    AlbumPickerView(
        store: AlbumPickerStore(
            isLimited: true,
            recentUploadsRepository: PreviewRecentUploadsRepository(),
            onPhotoConfirmed: { _ in },
            onRecentUploadConfirmed: { _ in }
        )
    )
}

#Preview("전체허용") {
    AlbumPickerView(
        store: AlbumPickerStore(
            isLimited: false,
            recentUploadsRepository: PreviewRecentUploadsRepository(),
            onPhotoConfirmed: { _ in },
            onRecentUploadConfirmed: { _ in }
        )
    )
}
