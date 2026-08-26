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
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(state: State, dependencies: Dependencies) {
        self.state = state
        self.dependencies = dependencies
    }

    /// 화면이 사라졌다 다시 나타나도 이어 받을 수 있도록 구독마다 새 스트림을 내준다.
    func eventStream() -> AsyncStream<Event> {
        eventChannel.stream()
    }

    func send(_ intent: Intent) {
        switch intent {
        case .colorSelected, .backgroundTabTapped, .toppingTabTapped, .closeTapped,
             .continueEditingTapped, .discardTapped:
            handleEditorIntent(intent)
        case .backgroundImageSourceTapped, .backgroundImageFlowDismissed, .backgroundImageSelected:
            handleBackgroundImageIntent(intent)
        case .toppingTapped, .toppingPlacementChanged, .toppingDeleteTapped,
             .toppingBorderEditTapped:
            handleToppingIntent(intent)
        case .borderWidthChanged, .borderWidthEditingChanged, .borderColorSelected,
             .borderUndoTapped, .borderRedoTapped, .borderEditClosed, .borderEditConfirmed:
            handleBorderIntent(intent)
        case .confirmTapped:
            saveChanges()
        case .saveErrorDismissed:
            state.saveState = .idle
        case .screenDisappeared:
            saveTask?.cancel()
            saveTask = nil
        }
    }

    private func handleEditorIntent(_ intent: Intent) {
        switch intent {
        case .colorSelected(let hex):
            guard state.saveState != .saving else { return }
            state.background = .color(hex: hex)
            state.selectedBackgroundImageSource = nil
            state.pendingUploadedBackground = nil
        case .backgroundTabTapped:
            guard state.saveState != .saving else { return }
            state.screen = .background
            state.selectedToppingID = nil
        case .toppingTabTapped:
            guard state.saveState != .saving else { return }
            state.screen = .toppings
        case .closeTapped:
            closeEditor()
        case .continueEditingTapped:
            state.showsExitPopup = false
        case .discardTapped:
            state.showsExitPopup = false
            dependencies.onDismiss()
        default:
            break
        }
    }

    private func handleBackgroundImageIntent(_ intent: Intent) {
        switch intent {
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
        default:
            break
        }
    }

    private func handleToppingIntent(_ intent: Intent) {
        switch intent {
        case .toppingTapped(let toppingID):
            selectTopping(toppingID)
        case .toppingPlacementChanged(let toppingID, let placement):
            updateTopping(toppingID) { $0.placement = placement }
        case .toppingDeleteTapped(let toppingID):
            updateTopping(toppingID) { $0.isDeleted = true }
            if state.selectedToppingID == toppingID {
                state.selectedToppingID = nil
            }
        case .toppingBorderEditTapped(let toppingID):
            openBorderEditor(toppingID)
        default:
            break
        }
    }

    private func handleBorderIntent(_ intent: Intent) {
        switch intent {
        case .borderWidthChanged(let width):
            state.borderEditor.changeWidth(width)
        case .borderWidthEditingChanged(let isEditing):
            state.borderEditor.updateWidthEditing(isEditing)
        case .borderColorSelected(let color):
            state.borderEditor.select(color)
        case .borderUndoTapped:
            state.borderEditor.undo()
        case .borderRedoTapped:
            state.borderEditor.redo()
        case .borderEditClosed:
            state.screen = .toppings
        case .borderEditConfirmed:
            applyBorderDraft()
        default:
            break
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
        state.selectedToppingID = toppingID
    }

    private func openBorderEditor(_ toppingID: Int) {
        guard let topping = state.toppings.first(where: { $0.id == toppingID }),
              topping.isMine,
              !topping.isDeleted
        else { return }

        state.selectedToppingID = toppingID
        state.borderEditor = ToppingBorderEditor(border: topping.border)
        state.screen = .border(toppingID: toppingID)
    }

    private func applyBorderDraft() {
        guard case .border(let toppingID) = state.screen else { return }
        let border = state.borderEditor.border
        updateTopping(toppingID) { $0.border = border }
        state.screen = .toppings
    }

    private func closeEditor() {
        guard state.saveState != .saving else { return }
        switch state.screen {
        case .background:
            state.showsExitPopup = true
        case .toppings:
            dependencies.onDismiss()
        case .border:
            state.screen = .toppings
        }
    }

    private func updateTopping(_ toppingID: Int, update: (inout EditableTopping) -> Void) {
        guard let index = state.toppings.firstIndex(where: { $0.id == toppingID }) else { return }
        update(&state.toppings[index])
    }
}

extension CanvasEditStore {
    /// 배경·토핑 탭을 오가며 만든 초안을 한 번에 저장한다. 성공한 항목은 즉시 기준값으로 승격해
    /// 중간 실패 뒤 재시도해도 이미 성공한 DELETE/PATCH를 다시 보내지 않는다.
    fileprivate func saveChanges() {
        guard state.saveState != .saving else { return }
        guard state.hasChanges else {
            dependencies.onDismiss()
            return
        }

        state.saveState = .saving
        saveTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await saveBackgroundIfNeeded()
                try await savePlacementChanges()
                try await saveBorderChanges()
                try await saveDeletions()
                guard !Task.isCancelled else { return }
                state.saveState = .idle
                dependencies.onSaved()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                state.saveState = .failed
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
            return
        case .imageData(let jpegData):
            let uploadedImage: UploadedImage
            if let pendingUploadedBackground = state.pendingUploadedBackground {
                uploadedImage = pendingUploadedBackground
            } else {
                uploadedImage = try await dependencies.imageUploadRepository.upload(
                    .background(jpegData: jpegData)
                )
                guard !Task.isCancelled else { return }
                state.pendingUploadedBackground = uploadedImage
            }
            guard !Task.isCancelled else { return }
            _ = try await dependencies.canvasUseCase.changeBackground(
                groupID: dependencies.groupID,
                parfaitID: dependencies.parfaitID,
                to: .image(imageID: uploadedImage.id)
            )
            guard !Task.isCancelled else { return }
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
        guard !Task.isCancelled else { return }
        state.savedBackground = state.background
    }

    private func savePlacementChanges() async throws {
        let toppingIDs = state.toppings
            .filter { !$0.isDeleted && $0.hasPlacementChanges }
            .map(\.id)

        for toppingID in toppingIDs {
            guard let topping = state.toppings.first(where: { $0.id == toppingID }) else { continue }
            _ = try await dependencies.toppingUseCase.updatePlacement(
                topping.placementUpdate,
                toppingID: toppingID,
                groupID: dependencies.groupID,
                parfaitID: dependencies.parfaitID
            )
            guard !Task.isCancelled else { return }
            updateTopping(toppingID) { $0.savedPlacement = $0.placement }
        }
    }

    private func saveBorderChanges() async throws {
        let toppingIDs = state.toppings
            .filter { !$0.isDeleted && $0.hasBorderChanges }
            .map(\.id)

        for toppingID in toppingIDs {
            guard let topping = state.toppings.first(where: { $0.id == toppingID }) else { continue }
            _ = try await dependencies.toppingUseCase.updateBorder(
                topping.border.style,
                toppingID: toppingID,
                groupID: dependencies.groupID,
                parfaitID: dependencies.parfaitID
            )
            guard !Task.isCancelled else { return }
            updateTopping(toppingID) { $0.savedBorder = $0.border }
        }
    }

    private func saveDeletions() async throws {
        let toppingIDs = state.toppings.filter(\.isDeleted).map(\.id)
        for toppingID in toppingIDs {
            try await dependencies.toppingUseCase.delete(
                toppingID: toppingID,
                groupID: dependencies.groupID,
                parfaitID: dependencies.parfaitID
            )
            guard !Task.isCancelled else { return }
            state.toppings.removeAll { $0.id == toppingID }
        }
    }
}
