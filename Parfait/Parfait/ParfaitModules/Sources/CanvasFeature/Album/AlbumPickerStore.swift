//
//  AlbumPickerStore.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import Photos
import PhotosUI
import SwiftUI
import UIComponent

/// 사진 선택 화면 Store (Figma C-102-Reselect).
@Observable @MainActor
public final class AlbumPickerStore: MVIStore {
    public private(set) var state: State
    private let recentUploadsStorage = RecentUploadsStorage()
    private var recentUploadsTask: Task<Void, Never>?
    private var limitedPickerTask: Task<Void, Never>?

    public init(isLimited: Bool) {
        state = State(isLimited: isLimited)
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .appeared:
            loadRecentUploads()
            fetchDeviceSections()
        case .disappeared:
            recentUploadsTask?.cancel()
            limitedPickerTask?.cancel()
        case .reselectTapped:
            presentLimitedLibraryPicker()
        case .photoTapped:
            break // TODO(#54): 캔버스 연결 시 선택 결과 전달 정의 (스펙: 스코프 외)
        }
    }

    /// 최근 업로드 기록 로드 — 비면 뷰가 섹션을 숨긴다.
    private func loadRecentUploads() {
        recentUploadsTask?.cancel()
        recentUploadsTask = Task { [weak self, recentUploadsStorage] in
            let urls = await recentUploadsStorage.loadRecentURLs(limit: 6)
            guard !Task.isCancelled else { return }
            self?.state.recentUploadURLs = urls
        }
    }

    /// 기기 사진을 최신순으로 가져와 날짜별 섹션으로 묶는다.
    /// limited 면 Photos 가 선택된 사진만 돌려주므로 별도 분기가 없다.
    private func fetchDeviceSections() {
        let fetchOptions = PHFetchOptions()
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
        public var recentUploadURLs: [URL] = []
        public var sections: [PhotoDaySection] = []
    }

    public enum Intent {
        case appeared
        case disappeared
        case reselectTapped
        case photoTapped(PHAsset)
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
