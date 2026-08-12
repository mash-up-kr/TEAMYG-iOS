//
//  AlbumStore.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import SwiftUI
import UIComponent

/// 앨범 플로우 컨테이너 Store — 권한 상태만 관리한다.
@Observable @MainActor
public final class AlbumStore: MVIStore {
    public private(set) var state = State()
    private var requestTask: Task<Void, Never>?

    public init() {}

    public func send(_ intent: Intent) {
        switch intent {
        case .appeared, .sceneBecameActive:
            refreshPermission()
        case .disappeared:
            requestTask?.cancel()
        }
    }

    /// 현재 권한을 반영하고, 미결정이면 시스템 팝업을 요청한다 (재진입 시 중복 요청 금지).
    private func refreshPermission() {
        let permission = PhotoLibraryPermission.current()
        state.permission = permission
        guard permission == .notDetermined, requestTask == nil else { return }
        requestTask = Task { [weak self] in
            let result = await PhotoLibraryPermission.request()
            guard !Task.isCancelled else { return }
            self?.state.permission = result
            self?.requestTask = nil
        }
    }

    public struct State: Equatable {
        /// nil = 아직 확인 전 (첫 프레임 빈 배경).
        public var permission: PhotoLibraryPermission?
    }

    public enum Intent {
        case appeared
        case sceneBecameActive
        case disappeared
    }
}
