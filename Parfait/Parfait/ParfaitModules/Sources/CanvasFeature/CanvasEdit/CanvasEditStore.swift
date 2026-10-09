//
//  CanvasEditStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CanvasDomain
import Foundation
import Observation
import UIComponent

@Observable @MainActor
final class CanvasEditStore: MVIStore {
    private(set) var state: State

    /// 토스트처럼 한 번만 소비해야 하는 결과는 화면 상태와 분리한다 (`docs/mvi.md`).
    @ObservationIgnored private let eventChannel = EventChannel<Event>()

    private let dependencies: Dependencies

    @ObservationIgnored private let canvasRefreshTicker = CanvasRefreshTicker()
    @ObservationIgnored private var canvasRefreshTask: Task<Void, Never>?

    init(state: State, dependencies: Dependencies) {
        self.state = state
        self.dependencies = dependencies
    }

    /// 화면이 사라졌다 다시 나타나도 이어 받을 수 있도록 구독마다 새 스트림을 내준다.
    func eventStream() -> AsyncStream<Event> {
        eventChannel.stream()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared, .sceneBecameActive:
            canvasRefreshTicker.start { [weak self] in
                self?.send(.canvasRefreshTicked)
            }
        case .screenDisappeared, .sceneEnteredBackground:
            canvasRefreshTicker.stop()
            canvasRefreshTask?.cancel()
            canvasRefreshTask = nil
        case .canvasRefreshTicked:
            refreshCanvas()
        case .colorSelected(let hex):
            guard state.saveState != .saving else { return }
            state.background = .color(hex: hex)
            state.selectedBackgroundImageSource = nil
            state.pendingUploadedBackground = nil
        case .backgroundImageSourceTapped(let source):
            guard state.saveState != .saving else { return }
            state.backgroundImageSource = source
        case .backgroundImageFlowDismissed:
            state.backgroundImageSource = nil
        case .backgroundImageSelected(let jpegData, let source):
            state.background = .imageData(jpegData)
            state.selectedBackgroundImageSource = source
            state.pendingUploadedBackground = nil
            state.backgroundImageSource = nil
        case .toppingTapped(let toppingID):
            selectTopping(toppingID)
        case .toppingPlacementChanged(let toppingID, let placement):
            updateTopping(toppingID) { $0.placement = placement }
        case .toppingDeleteTapped(let toppingID):
            updateTopping(toppingID) { $0.isDeleted = true }
            if state.selectedToppingID == toppingID {
                state.selectedToppingID = nil
                state.isBorderPanelExpanded = false
            }
        case .borderWidthChanged(let width):
            updateBorderPanelTopping { $0.border.width = width }
        case .borderColorSelected(let color):
            updateBorderPanelTopping { $0.border.color = color }
        case .borderPanelExpandTapped:
            guard state.saveState != .saving, state.selectedTopping != nil else { return }
            state.isBorderPanelExpanded = true
        case .borderPanelClosed:
            state.isBorderPanelExpanded = false
        case .backgroundImagePickerCloseTapped:
            state.backgroundImageSource = nil
            dependencies.onDismiss()
        case .closeTapped:
            closeEditor()
        case .exitPopupVisibilityChanged(let isPresented):
            state.showsExitPopup = isPresented
        case .discardTapped:
            state.showsExitPopup = false
            dependencies.onDismiss()
        case .confirmTapped:
            saveChanges()
        }
    }

    private func selectTopping(_ toppingID: Int) {
        guard state.saveState != .saving,
              let topping = state.toppings.first(where: { $0.id == toppingID }),
              !topping.isDeleted
        else { return }

        guard topping.isMine else {
            eventChannel.send(.otherToppingSelected)
            return
        }
        state.isBorderPanelExpanded = state.selectedToppingID == toppingID
        state.selectedToppingID = toppingID
    }

    private func updateBorderPanelTopping(_ update: (inout EditableTopping) -> Void) {
        guard state.saveState != .saving, let topping = state.borderPanelTopping else { return }
        updateTopping(topping.id, update: update)
    }

    private func closeEditor() {
        guard state.saveState != .saving else { return }
        guard state.hasChanges else {
            dependencies.onDismiss()
            return
        }
        state.showsExitPopup = true
    }

    private func updateTopping(_ toppingID: Int, update: (inout EditableTopping) -> Void) {
        guard let index = state.toppings.firstIndex(where: { $0.id == toppingID }) else { return }
        update(&state.toppings[index])
    }
}

extension CanvasEditStore {
    /// 배경 변경 또는 토핑 편집 화면에서 만든 초안을 한 번에 저장한다. 성공한 항목은 즉시 기준값으로 승격해
    /// 중간 실패 뒤 재시도해도 이미 성공한 DELETE/PATCH를 다시 보내지 않는다.
    fileprivate func saveChanges() {
        guard state.saveState != .saving else { return }
        guard state.hasChanges else {
            dependencies.onDismiss()
            return
        }

        state.saveState = .saving
        Task { [self] in
            do {
                try await saveBackgroundIfNeeded()
                try await savePlacementChanges()
                try await saveBorderChanges()
                try await saveDeletions()
                state.saveState = .idle
                dependencies.onSaved()
            } catch is CancellationError {
                return
            } catch {
                state.saveState = .idle
                eventChannel.send(.saveFailed)
            }
        }
    }

    private func saveBackgroundIfNeeded() async throws {
        guard state.background != state.savedBackground else { return }

        let change: ParfaitBackgroundChange
        switch state.background {
        case .color(let hex):
            change = .color(hex: hex)
        case .image:
            // 이미지 URL 배경은 업로드 성공 경로에서만 만들어지고 그 자리에서 savedBackground 로
            // 승격된다. 여기 도달했다면 "변경이 있는데 아무것도 안 보내고 성공" 이 되므로 알린다.
            assertionFailure("이미지 URL 배경은 업로드 경로에서만 만들어진다")
            return
        case .imageData(let jpegData):
            let uploadedImage: UploadedImage
            if let pendingUploadedBackground = state.pendingUploadedBackground {
                uploadedImage = pendingUploadedBackground
            } else {
                uploadedImage = try await dependencies.imageUploadRepository.upload(
                    .background(jpegData: jpegData)
                )
                try Task.checkCancellation()
                state.pendingUploadedBackground = uploadedImage
            }
            try Task.checkCancellation()
            _ = try await dependencies.canvasUseCase.changeBackground(
                groupID: dependencies.groupID,
                parfaitID: dependencies.parfaitID,
                to: .image(imageID: uploadedImage.id)
            )
            try Task.checkCancellation()
            state.background = .image(url: uploadedImage.url)
            state.savedBackground = state.background
            state.pendingUploadedBackground = nil
            return
        }

        _ = try await dependencies.canvasUseCase.changeBackground(
            groupID: dependencies.groupID,
            parfaitID: dependencies.parfaitID,
            to: change
        )
        try Task.checkCancellation()
        state.savedBackground = state.background
    }

    private func savePlacementChanges() async throws {
        let updates = Dictionary(
            uniqueKeysWithValues: state.toppings
                .filter { !$0.isDeleted && $0.hasPlacementChanges }
                .map { ($0.id, $0.placementUpdate) }
        )

        guard !updates.isEmpty else { return }

        try await dependencies.toppingUseCase.updatePlacements(
            updates,
            groupID: dependencies.groupID,
            parfaitID: dependencies.parfaitID
        )
        for toppingID in updates.keys {
            updateTopping(toppingID) { $0.savedPlacement = $0.placement }
        }
    }

    private func saveBorderChanges() async throws {
        let styles = Dictionary(
            uniqueKeysWithValues: state.toppings
                .filter { !$0.isDeleted && $0.hasBorderChanges }
                .map { ($0.id, $0.border.style) }
        )

        try await saveConcurrently(Array(styles.keys)) { [dependencies] toppingID in
            guard let style = styles[toppingID] else { return }
            _ = try await dependencies.toppingUseCase.updateBorder(
                style,
                toppingID: toppingID,
                groupID: dependencies.groupID,
                parfaitID: dependencies.parfaitID
            )
        } promote: { toppingID in
            updateTopping(toppingID) { $0.savedBorder = $0.border }
        }
    }

    private func saveDeletions() async throws {
        try await saveConcurrently(state.toppings.filter(\.isDeleted).map(\.id)) { [dependencies] toppingID in
            try await dependencies.toppingUseCase.delete(
                toppingID: toppingID,
                groupID: dependencies.groupID,
                parfaitID: dependencies.parfaitID
            )
        } promote: { toppingID in
            state.toppings.removeAll { $0.id == toppingID }
        }
    }

}

/// 편집 중에도 10초마다 오늘 캔버스를 다시 받아 **읽기 전용 부분만** 맞춘다.
/// 내 토핑 초안과 내가 손댄 배경은 어떤 경우에도 덮지 않는다.
extension CanvasEditStore {
    fileprivate func refreshCanvas() {
        guard state.saveState != .saving, canvasRefreshTask == nil else { return }

        canvasRefreshTask = Task { [self] in
            let parfait = try? await dependencies.canvasUseCase.fetchToday(groupID: dependencies.groupID)
            guard !Task.isCancelled else { return }
            canvasRefreshTask = nil
            guard let parfait else { return }
            // 새벽 3시 경계를 넘겼다면 편집 중인 캔버스와 다른 캔버스다 — 섞지 않고 갱신을 멈춘다.
            guard parfait.id == dependencies.parfaitID else {
                canvasRefreshTicker.stop()
                return
            }
            merge(CanvasStore.CanvasContent(parfait))
        }
    }

    private func merge(_ content: CanvasStore.CanvasContent) {
        // 저장 diff 기준은 늘 서버 값으로 맞추되, 내가 고른 배경 초안은 그대로 둔다.
        let isBackgroundUntouched = state.background == state.savedBackground
        state.savedBackground = content.background
        if isBackgroundUntouched {
            state.background = content.background
        }

        let editingToppings = state.toppings
        state.toppings = content.images.map { image in
            // 내 토핑은 이 기기에서만 바뀐다 — 위치·테두리·삭제 예정 초안을 그대로 지킨다.
            if let mine = editingToppings.first(where: { $0.id == image.id && $0.isMine }) {
                return mine
            }
            return EditableTopping(image)
        }

        if let selectedToppingID = state.selectedToppingID,
           !state.toppings.contains(where: { $0.id == selectedToppingID && !$0.isDeleted }) {
            state.selectedToppingID = nil
            state.isBorderPanelExpanded = false
        }
    }
}
