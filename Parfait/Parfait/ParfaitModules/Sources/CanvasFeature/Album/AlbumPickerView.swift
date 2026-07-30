//
//  AlbumPickerView.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import Photos
import SwiftUI
import UIComponent

/// 사진 선택 화면 (Figma C-102-Reselect). 우상단 닫기 버튼은 컨테이너(AlbumView) 소유.
public struct AlbumPickerView: View {
    @State private var store: AlbumPickerStore

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    public init(isLimited: Bool) {
        _store = State(initialValue: AlbumPickerStore(isLimited: isLimited))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !store.state.recentUploadURLs.isEmpty {
                    recentUploadsSection
                }
                ForEach(store.state.sections) { section in
                    daySection(section)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 76) // 플로팅 닫기 버튼 영역(60) + 16
        }
        .background(Color.whiteFixed)
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
        .onAppear { store.send(.appeared) }
        .onDisappear { store.send(.disappeared) }
    }

    private var recentUploadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 업로드한 사진")
                .suit(.body02Regular)
                .foregroundStyle(Color.gray900)
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(store.state.recentUploadURLs, id: \.self) { fileURL in
                    RecentUploadCell(fileURL: fileURL)
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
                    PhotoAssetCell(asset: asset) {
                        store.send(.photoTapped(asset))
                    }
                }
            }
        }
    }
}

/// 최근 업로드 파일 셀 — 로컬 파일을 UIImage 로 로드해 표시 (기기 사진 셀과 같은 렌더 경로).
private struct RecentUploadCell: View {
    let fileURL: URL

    @State private var image: UIImage?

    var body: some View {
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
            .task(id: fileURL) {
                // path() 는 percent-encoding 이 기본이라 "Application Support" 공백에서 깨짐 — URL 로 직접 읽는다.
                image = await Task.detached {
                    guard let imageData = try? Data(contentsOf: fileURL) else { return nil }
                    return UIImage(data: imageData)
                }.value
            }
    }
}

/// 기기 사진 셀 — 셀 크기 썸네일만 요청 (원본 디코딩 방지).
private struct PhotoAssetCell: View {
    let asset: PHAsset
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    // ponytail: 3열 셀 ~110pt 가정 고정 픽셀 — 화면폭 대응이 필요해지면 GeometryReader 로.
    private static let thumbnailTargetSize = CGSize(width: 360, height: 360)

    var body: some View {
        Button(action: onTap) {
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
        }
        .buttonStyle(.plain)
        .task(id: asset.localIdentifier) {
            thumbnail = await Self.requestThumbnail(for: asset)
        }
    }

    /// ponytail: 요청 취소·프리페치·캐싱은 성능 최적화 작업에서 (스펙: 스코프 제외).
    private static func requestThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat // 콜백 1회 보장 (opportunistic 은 다회 → continuation 중복 resume 크래시)
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true // iCloud 최적화 사진도 표시
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: thumbnailTargetSize,
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
