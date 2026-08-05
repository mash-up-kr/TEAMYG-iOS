//
//  AlbumPickerView.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import CanvasDomain
import Photos
import SwiftUI
import UIComponent

/// 사진 선택 화면 (Figma C-102-Reselect). 우상단 닫기 버튼은 컨테이너(AlbumView) 소유.
public struct AlbumPickerView: View {
    @State private var store: AlbumPickerStore
    @Namespace private var zoomNamespace
    @State private var toasts: [YGToastItem] = []

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    public init(isLimited: Bool) {
        _store = State(initialValue: AlbumPickerStore(isLimited: isLimited))
    }

    public var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !store.state.recentUploads.isEmpty {
                        recentUploadsSection
                    }
                    ForEach(store.state.sections) { section in
                        daySection(section)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 76) // 플로팅 닫기 버튼 영역(60) + 16
            }
            .background(Color.whiteFixed)
            .overlay {
                if store.state.recentUploads.isEmpty && store.state.sections.isEmpty {
                    emptyView
                }
            }
            .safeAreaInset(edge: .bottom) {
                if store.state.isLimited {
                    YGButton("사진 재선택", variant: .mediumPrimary) {
                        store.send(.reselectTapped)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.whiteFixed)
                }
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
            toasts.append(YGToastItem(kind: .warning, message: "대상이 배경과 선명하게 구분될수록 깔끔하게 선택돼요"))
        }
        .onDisappear { store.send(.disappeared) }
        .ygToastOverlay($toasts)
    }

    /// 빈 상태 (Figma C-102-Empty) — 최근 업로드·앨범 사진이 모두 없을 때 중앙 표시.
    private var emptyView: some View {
        VStack(spacing: 2) {
            Image.imageGalleryEmpty
            Text("오늘 찍은 사진이 없어요\n사진을 찍고 토핑을 추가해 보세요")
                .suit(.body02Regular)
                .foregroundStyle(Color.gray300)
                .multilineTextAlignment(.center)
                .fixedSize() // 이미지 폭에 맞춰 줄바꿈되지 않도록 텍스트 고유 폭 유지 (디자인: 2줄 고정)
        }
    }

    private var recentUploadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 업로드한 사진")
                .suit(.body02Regular)
                .foregroundStyle(Color.gray900)
            LazyVGrid(columns: gridColumns, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 2) {
                Text(section.dayTitle)
                    .suit(.body02Regular)
                    .foregroundStyle(Color.gray900)
                Text(section.weekdayTitle)
                    .suit(.body02Regular)
                    .foregroundStyle(Color.gray300)
            }
            LazyVGrid(columns: gridColumns, spacing: 12) {
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

/// 최근 업로드 셀 — 저장소가 넘긴 Data 를 UIImage 로 표시 (파일 IO 없음).
private struct RecentUploadCell: View {
    let upload: StoredImage
    let zoomNamespace: Namespace.ID
    /// 확인 화면이 떠 있는 동안 false — matched geometry 소스는 확인 화면 이미지 하나여야 한다.
    let isZoomSource: Bool
    let onTap: (UIImage?) -> Void

    @State private var image: UIImage?

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
                .matchedGeometryEffect(id: upload.zoomIdentifier, in: zoomNamespace, isSource: isZoomSource)
        }
        .buttonStyle(.plain)
        .task(id: upload.id) {
            image = UIImage(data: upload.imageData)
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
    AlbumPickerView(isLimited: true)
}

#Preview("전체허용") {
    AlbumPickerView(isLimited: false)
}
