//
//  CanvasSavePreviewStore.swift
//  CanvasFeature
//
//  Created by 신상우 on 9/6/26.
//

import Observation
import UIComponent
import UIKit

/// C-001-Save-Preview 의 Store — 캔버스를 저장본 한 장으로 합성해 보여 주고, 그 이미지를 앨범에 넣는다.
///
/// 합성은 화면을 열 때 한 번뿐이다. 미리보기에 띄운 이미지를 그대로 저장해야
/// 보여 준 것과 앨범에 남는 것이 같다.
@Observable @MainActor
final class CanvasSavePreviewStore: MVIStore {
    private(set) var state: State

    private let dependencies: Dependencies
    private var composeTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    init(state: State, dependencies: Dependencies) {
        self.state = state
        self.dependencies = dependencies
    }

    func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            composeCanvasImage()
        case .saveTapped:
            saveToGallery()
        case .closeTapped:
            // 앨범에 쓰는 중에는 닫지 않는다 — 취소해도 사진은 이미 들어가는데 결과를 못 알린다.
            guard !state.isSaving else { return }
            close(.dismissed)
        }
    }

    /// 배경·토핑을 모두 받아 합성한다. 하나라도 못 받으면 빈 미리보기를 띄워 두지 않고 접는다.
    private func composeCanvasImage() {
        guard state.image == nil, composeTask == nil else { return }

        composeTask = Task { [weak self, dependencies] in
            let canvasImage = await dependencies.canvasImageExporter.image(of: dependencies.canvasContent)
            guard !Task.isCancelled, let self else { return }

            guard let canvasImage else {
                close(.composeFailed)
                return
            }
            state.image = canvasImage
        }
    }

    /// 권한 거부 전용 화면은 정책 범위 밖이라(`canvas-policy.md` §8) 거부도 실패로 수렴한다.
    private func saveToGallery() {
        guard let canvasImage = state.image, !state.isSaving else { return }

        state.isSaving = true
        saveTask = Task { [weak self] in
            let isSaved = await CanvasGallerySaver.save(canvasImage)
            guard !Task.isCancelled, let self else { return }
            close(.saved(isSaved))
        }
    }

    private func close(_ reason: CloseReason) {
        composeTask?.cancel()
        saveTask?.cancel()
        dependencies.onClose(reason)
    }
}

extension CanvasSavePreviewStore {
    /// 닫히는 이유는 캔버스 화면의 Intent 가 그대로 받는다.
    typealias CloseReason = CanvasStore.SavePreviewCloseReason

    struct Dependencies {
        /// 미리보기를 연 순간의 캔버스. 뒤에서 새로고침이 돌아도 이 스냅샷만 그린다.
        let canvasContent: CanvasStore.CanvasContent
        /// 캔버스 화면과 토핑 캐시를 공유하는 합성기.
        let canvasImageExporter: CanvasImageExporter
        let onClose: @MainActor (CloseReason) -> Void
    }

    struct State: Equatable {
        let dateText: String
        let weekdayText: String
        /// 합성이 끝나기 전에는 `nil` — 이미지 자리를 비워 두고 저장 버튼을 잠근다.
        var image: UIImage?
        /// 앨범에 쓰는 중 — 재탭을 막는다.
        var isSaving = false

        init(dateText: String, weekdayText: String, image: UIImage? = nil) {
            self.dateText = dateText
            self.weekdayText = weekdayText
            self.image = image
        }
    }

    enum Intent {
        case screenAppeared
        case saveTapped
        case closeTapped
    }
}

extension CanvasStore.SavePreviewCloseReason {
    /// 미리보기가 닫힌 뒤 캔버스 화면이 띄울 Toast. 알릴 것이 없으면 `nil`.
    func event(dateText: String?) -> CanvasStore.Event? {
        switch self {
        case .dismissed:
            return nil
        case .composeFailed:
            return .savePreviewRenderFailed
        case .saved(let isSaved):
            guard isSaved, let dateText else { return .gallerySaveFailed }
            return .gallerySaveSucceeded(dateText: dateText)
        }
    }
}
