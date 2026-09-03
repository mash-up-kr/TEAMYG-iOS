//
//  AlbumPickerStore.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import CanvasDomain
import Photos
import PhotosUI
import SwiftUI
import UIComponent

public typealias AlbumPickerStoreFactory = (
    _ isLimited: Bool,
    _ onPhotoConfirmed: @escaping (_ assetIdentifier: String) -> Void
) -> AlbumPickerStore

@Observable @MainActor
public final class AlbumPickerStore: MVIStore {
    public private(set) var state: State
    private let recentUploadsRepository: any RecentUploadsRepository
    private let onPhotoConfirmed: (_ assetIdentifier: String) -> Void
    private var recentUploadsTask: Task<Void, Never>?
    private var limitedPickerTask: Task<Void, Never>?
    private var changeRelay: PhotoLibraryChangeRelay?

    public init(
        isLimited: Bool,
        recentUploadsRepository: any RecentUploadsRepository,
        onPhotoConfirmed: @escaping (_ assetIdentifier: String) -> Void
    ) {
        self.recentUploadsRepository = recentUploadsRepository
        self.onPhotoConfirmed = onPhotoConfirmed
        state = State(isLimited: isLimited)
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .appeared:
            registerChangeObserverIfNeeded()
            loadRecentUploads()
            fetchDeviceSections()
        case .disappeared:
            recentUploadsTask?.cancel()
            limitedPickerTask?.cancel()
            unregisterChangeObserver()
        case .reselectTapped:
            presentLimitedLibraryPicker()
        case let .photoTapped(asset, thumbnail):
            state.selectedPhoto = SelectedPhoto(
                id: asset.localIdentifier,
                asset: asset,
                upload: nil,
                thumbnail: thumbnail
            )
        case let .recentUploadTapped(upload, thumbnail):
            state.selectedPhoto = SelectedPhoto(
                id: upload.zoomIdentifier,
                asset: nil,
                upload: upload,
                thumbnail: thumbnail
            )
        case .confirmReselectTapped:
            state.selectedPhoto = nil
        case .confirmNextTapped:
            guard let asset = state.selectedPhoto?.asset else { return }
            onPhotoConfirmed(asset.localIdentifier)
        }
    }

    /// 최근 업로드 기록 로드 — 정책 창(03:00~다음날 02:59) 안의 기록만, 비면 뷰가 섹션을 숨긴다.
    private func loadRecentUploads() {
        recentUploadsTask?.cancel()
        recentUploadsTask = Task { [weak self, recentUploadsRepository] in
            let uploads = await recentUploadsRepository.loadRecent(
                limit: AlbumPolicy.recentUploadsLimit,
                within: AlbumPolicy.todayWindow()
            )
            guard !Task.isCancelled else { return }
            self?.state.recentUploads = uploads
        }
    }

    /// 기기 사진을 정책 창(03:00~다음날 02:59) 안에서 최신순으로 가져와 날짜별 섹션으로 묶는다.
    /// limited 면 Photos 가 선택된 사진만 돌려주므로 별도 분기가 없다.
    private func fetchDeviceSections() {
        let window = AlbumPolicy.todayWindow()
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@",
            window.start as NSDate,
            window.end as NSDate
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        // ponytail: 전량 열거 — 수만 장 라이브러리에서 느려지면 fetchLimit+페이징 도입.
        fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }

        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: assets) { asset in
            calendar.startOfDay(for: asset.creationDate ?? .distantPast)
        }
        state.sections = groupedByDay
            .sorted { $0.key > $1.key }
            .map { day, dayAssets in PhotoDaySection(day: day, assets: dayAssets) }
    }

    /// 라이브러리 변경(일부허용 선택 변경·사진 추가 등) 시 재조회.
    /// 첫 권한 요청에서 "접근 제한" 을 고르면 시스템이 선택 시트를 자동으로 띄우는데,
    /// 그 시트는 우리가 띄운 게 아니라 종료 훅이 없다 — observer 가 유일한 갱신 경로.
    private func registerChangeObserverIfNeeded() {
        guard changeRelay == nil else { return }
        let relay = PhotoLibraryChangeRelay { [weak self] in
            Task { @MainActor [weak self] in
                self?.fetchDeviceSections()
            }
        }
        PHPhotoLibrary.shared().register(relay)
        changeRelay = relay
    }

    private func unregisterChangeObserver() {
        guard let changeRelay else { return }
        PHPhotoLibrary.shared().unregisterChangeObserver(changeRelay)
        self.changeRelay = nil
    }

    /// 일부허용에서 더 많은 사진을 고르는 진입점. 픽커 종료 후 재조회한다.
    private func presentLimitedLibraryPicker() {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController
        else { return }

        limitedPickerTask?.cancel()
        limitedPickerTask = Task { [weak self] in
            await PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: rootViewController)
            guard !Task.isCancelled else { return }
            self?.send(.appeared)
        }
    }

    public struct State: Equatable {
        public var isLimited: Bool
        public var recentUploads: [StoredImage] = []
        public var sections: [PhotoDaySection] = []
        var selectedPhoto: SelectedPhoto?
    }

    public enum Intent {
        case appeared
        case disappeared
        case reselectTapped
        case photoTapped(PHAsset, thumbnail: UIImage?)
        case recentUploadTapped(StoredImage, thumbnail: UIImage?)
        case confirmReselectTapped
        case confirmNextTapped
    }

    /// 확인 화면(C-102-Confirm)에 표시할 선택 사진 — 기기 사진·최근 업로드 공용.
    /// 썸네일은 셀 크기로만 디코딩된 플레이스홀더라, 확인 화면은 아래 원본 출처에서 화면 크기로 다시 로드한다.
    struct SelectedPhoto: Equatable {
        /// matched geometry 전환 식별자 (기기 사진: localIdentifier, 최근 업로드: zoomIdentifier)
        let id: String
        /// 고화질 후속 로드용 원본 출처 — 둘 중 하나만 채워진다.
        let asset: PHAsset?
        let upload: StoredImage?
        let thumbnail: UIImage?

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id && lhs.thumbnail === rhs.thumbnail
        }
    }
}

extension StoredImage {
    /// 기기 사진 localIdentifier 와 겹치지 않는 matched geometry 식별자.
    var zoomIdentifier: String { "recent-upload-\(id)" }
}

/// `PHPhotoLibraryChangeObserver` 는 NSObjectProtocol 이라 Store 가 직접 채택하지 않고
/// 작은 릴레이로 감싼다. 콜백은 임의 스레드에서 오므로 클로저는 @Sendable.
private final class PhotoLibraryChangeRelay: NSObject, PHPhotoLibraryChangeObserver {
    private let onChange: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange()
    }
}

/// 하루 단위 사진 섹션. 헤더는 "May 20 (Wed)" 형식 (en 고정 — 디자인 확정 포맷).
public struct PhotoDaySection: Equatable, Identifiable {
    public let day: Date
    public let assets: [PHAsset]
    public var id: Date { day }

    public var dayTitle: String { Self.dayFormatter.string(from: day) }
    public var weekdayTitle: String { "(\(Self.weekdayFormatter.string(from: day)))" }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter
    }()
}
