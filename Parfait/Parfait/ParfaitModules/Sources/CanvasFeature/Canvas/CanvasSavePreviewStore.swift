//
//  CanvasSavePreviewStore.swift
//  CanvasFeature
//
//  Created by 신상우 on 9/6/26.
//

import Common
import Observation
import UIComponent
import UIKit

/// C-001-Save-Preview 의 Store — 캔버스를 저장본 한 장으로 합성해 보여 주고, 고른 형식(사진·영상)으로
/// 앨범에 넣거나 인스타그램 스토리로 넘긴다.
///
/// 합성은 화면을 열 때 한 번뿐이다. 미리보기에 띄운 이미지를 그대로 저장해야
/// 보여 준 것과 앨범에 남는 것이 같다.
@Observable @MainActor
final class CanvasSavePreviewStore: MVIStore {
    private(set) var state: State

    private let dependencies: Dependencies
    @ObservationIgnored private let eventChannel = EventChannel<Event>()
    private var composeTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var shareTask: Task<Void, Never>?

    init(state: State, dependencies: Dependencies) {
        self.state = state
        self.dependencies = dependencies
    }

    func eventStream() -> AsyncStream<Event> {
        eventChannel.stream()
    }

    func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            dependencies.logAnalyticsEvent(.screenView(.canvasSave))
            composeCanvasImage()
        case .saveTapped:
            switch state.format {
            case .image: saveToGallery()
            case .video: saveVideoToGallery()
            }
        case .instagramShareTapped:
            shareToInstagramStory()
        case .closeTapped:
            // 앨범에 쓰는 중에는 닫지 않는다 — 취소해도 사진은 이미 들어가는데 결과를 못 알린다.
            guard !state.isProcessing else { return }
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

    private func saveToGallery() {
        guard let canvasImage = state.image, !state.isProcessing else { return }

        state.isProcessing = true
        saveTask = Task { [weak self] in
            let isSaved = await CanvasGallerySaver.save(canvasImage)
            guard !Task.isCancelled, let self else { return }
            if isSaved {
                dependencies.logAnalyticsEvent(.canvasSaveGallerySaved(format: .image))
            }
            close(.saveFinished(isSuccess: isSaved))
        }
    }

    /// 영상은 미리보기와 같은 스냅샷으로 새로 그린다 — 토핑은 합성기 캐시에서 다시 받는다.
    private func saveVideoToGallery() {
        guard state.image != nil, !state.isProcessing else { return }

        state.isProcessing = true
        saveTask = Task { [weak self, dependencies] in
            let videoURL = await dependencies.canvasImageExporter.video(of: dependencies.canvasContent)
            let isSaved = if let videoURL {
                await CanvasGallerySaver.saveVideo(at: videoURL)
            } else {
                false
            }
            guard !Task.isCancelled, let self else { return }
            if isSaved {
                dependencies.logAnalyticsEvent(.canvasSaveGallerySaved(format: .video))
            }
            close(.saveFinished(isSuccess: isSaved))
        }
    }

    /// 공유는 미리보기를 닫지 않는다 — 인스타그램에서 돌아와 갤러리 저장까지 이어서 할 수 있다.
    /// 영상은 저장과 같은 방식으로 새로 그린다.
    private func shareToInstagramStory() {
        guard let canvasImage = state.image, !state.isProcessing else { return }
        guard CanvasInstagramStorySharer.isInstagramInstalled else {
            eventChannel.send(.instagramNotInstalled)
            return
        }

        state.isProcessing = true
        shareTask = Task { [weak self, dependencies, format = state.format] in
            let background: CanvasInstagramStorySharer.Background? = switch format {
            case .image:
                .image(canvasImage)
            case .video:
                await dependencies.canvasImageExporter.video(of: dependencies.canvasContent).map { .video($0) }
            }
            let isShared = if let background {
                await CanvasInstagramStorySharer.share(background)
            } else {
                false
            }
            guard !Task.isCancelled, let self else { return }
            state.isProcessing = false
            if !isShared {
                eventChannel.send(.instagramShareFailed)
            }
        }
    }

    private func close(_ reason: CloseReason) {
        composeTask?.cancel()
        saveTask?.cancel()
        shareTask?.cancel()
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
        let logAnalyticsEvent: AnalyticsEventLogger
    }

    struct State: Equatable {
        let format: CanvasStore.SaveFormat
        let dateText: String
        let weekdayText: String
        /// 합성이 끝나기 전에는 `nil` — 이미지 자리를 비워 두고 저장 버튼을 잠근다.
        var image: UIImage?
        /// 앨범에 쓰거나 공유할 영상을 만드는 중 — 재탭을 막는다.
        var isProcessing = false

        init(
            format: CanvasStore.SaveFormat,
            dateText: String,
            weekdayText: String,
            image: UIImage? = nil
        ) {
            self.format = format
            self.dateText = dateText
            self.weekdayText = weekdayText
            self.image = image
        }
    }

    enum Intent {
        case screenAppeared
        case saveTapped
        case instagramShareTapped
        case closeTapped
    }

    enum Event: Equatable, Sendable {
        case instagramNotInstalled
        case instagramShareFailed
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
        case .saveFinished(let isSuccess):
            guard isSuccess, let dateText else { return .gallerySaveFailed }
            return .gallerySaveSucceeded(dateText: dateText)
        }
    }
}
