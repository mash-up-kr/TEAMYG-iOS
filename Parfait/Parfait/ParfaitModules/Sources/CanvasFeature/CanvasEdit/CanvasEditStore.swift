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
        case .background, .toppings:
            state.showsExitPopup = true
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

        try await saveConcurrently(Array(updates.keys)) { [dependencies] toppingID in
            guard let update = updates[toppingID] else { return }
            _ = try await dependencies.toppingUseCase.updatePlacement(
                update,
                toppingID: toppingID,
                groupID: dependencies.groupID,
                parfaitID: dependencies.parfaitID
            )
        } promote: { toppingID in
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

    private func saveConcurrently(
        _ toppingIDs: [Int],
        request: @escaping @Sendable (Int) async throws -> Void,
        promote: (Int) -> Void
    ) async throws {
        guard !toppingIDs.isEmpty else { return }

        let savedIDs = await withTaskGroup(of: Int?.self) { group in
            for toppingID in toppingIDs {
                group.addTask {
                    do {
                        try await request(toppingID)
                        return toppingID
                    } catch {
                        return nil
                    }
                }
            }

            var succeeded: [Int] = []
            for await toppingID in group {
                if let toppingID { succeeded.append(toppingID) }
            }
            return succeeded
        }

        savedIDs.forEach(promote)
        guard savedIDs.count == toppingIDs.count else { throw SaveFailure.someRequestsFailed }
    }
}

private enum SaveFailure: Error {
    case someRequestsFailed
}
