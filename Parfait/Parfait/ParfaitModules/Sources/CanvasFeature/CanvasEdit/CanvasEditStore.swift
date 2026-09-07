//
//  CanvasEditStore.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CanvasDomain
import CoreGraphics
import Foundation
import Observation
import UIComponent

@Observable @MainActor
final class CanvasEditStore: MVIStore {
    private(set) var state: State

    /// 토스트처럼 한 번만 소비해야 하는 결과는 화면 상태와 분리한다 (`docs/mvi.md`).
    @ObservationIgnored private let eventChannel = EventChannel<Event>()

    private let dependencies: Dependencies

    @ObservationIgnored private var borderToppingLoadTask: Task<Void, Never>?
    @ObservationIgnored private var borderSilhouetteRenderTask: Task<Void, Never>?

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
        case .borderPreviewLongEdgeChanged, .borderWidthChanged, .borderWidthEditingChanged,
             .borderColorSelected, .borderUndoTapped, .borderRedoTapped, .borderEditClosed,
             .borderEditConfirmed:
            handleBorderIntent(intent)
        case .confirmTapped:
            saveChanges()
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
        case .borderPreviewLongEdgeChanged(let longEdge):
            guard state.borderPreviewLongEdge != longEdge else { break }
            state.borderPreviewLongEdge = longEdge
            renderBorderSilhouette()
        case .borderWidthChanged(let width):
            state.borderEditor.changeWidth(width)
            renderBorderSilhouette()
        case .borderWidthEditingChanged(let isEditing):
            state.borderEditor.updateWidthEditing(isEditing)
        case .borderColorSelected(let color):
            state.borderEditor.select(color)
            renderBorderSilhouette()
        case .borderUndoTapped:
            state.borderEditor.undo()
            renderBorderSilhouette()
        case .borderRedoTapped:
            state.borderEditor.redo()
            renderBorderSilhouette()
        case .borderEditClosed:
            state.screen = .toppings
            stopBorderRendering()
        case .borderEditConfirmed:
            applyBorderDraft()
            stopBorderRendering()
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
        loadBorderTopping(of: topping)
        renderBorderSilhouette()
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
    /// 토핑 이미지와 테두리 실루엣은 **따로** 로드한다. 한 흐름으로 묶으면 굵기 슬라이더를
    /// 움직일 때마다 토핑까지 다시 로드하며 미리보기가 스피너로 깜빡인다.
    fileprivate func loadBorderTopping(of topping: EditableTopping) {
        borderToppingLoadTask?.cancel()
        // 이미 그려 둔 토핑은 새 이미지가 도착할 때까지 그대로 둔다 — 화면이 비지 않게.
        borderToppingLoadTask = Task { [self] in
            let image = await dependencies.toppingRenderer.topping(
                at: topping.imageURL,
                neededLongEdge: ToppingImageEncoder.maximumLongEdge
            )
            guard !Task.isCancelled, let image else { return }
            state.borderTopping = image
        }
    }

    /// 굵기·색이 바뀔 때마다 여기만 다시 돈다. 토핑 이미지는 건드리지 않는다.
    fileprivate func renderBorderSilhouette() {
        borderSilhouetteRenderTask?.cancel()
        guard let topping = state.borderEditingTopping,
              state.borderEditor.border.isVisible,
              state.borderPreviewLongEdge > 0
        else {
            state.borderSilhouette = nil
            return
        }

        let imageURL = topping.imageURL
        let width = state.borderEditor.border.width
        let renderedLongEdge = state.borderPreviewLongEdge
        let loadedTopping = state.borderTopping
        borderSilhouetteRenderTask = Task { [self] in
            // 토핑 로드가 아직 안 끝났을 수 있다 — 캐시에서 다시 받아 온다(대개 즉시 반환).
            var toppingImage = loadedTopping
            if toppingImage == nil {
                toppingImage = await dependencies.toppingRenderer.topping(
                    at: imageURL,
                    neededLongEdge: ToppingImageEncoder.maximumLongEdge
                )
            }
            guard !Task.isCancelled, let toppingImage else { return }

            let silhouette = await dependencies.toppingRenderer.silhouette(
                of: toppingImage,
                at: imageURL,
                width: width,
                renderedLongEdge: renderedLongEdge
            )
            guard !Task.isCancelled, let silhouette else { return }
            state.borderSilhouette = BorderSilhouette(image: silhouette)
        }
    }

    /// 테두리 화면을 떠날 때 로드를 끊고 비운다 — 다른 토핑으로 재진입할 때 이전 이미지가 비치지 않게.
    fileprivate func stopBorderRendering() {
        borderToppingLoadTask?.cancel()
        borderSilhouetteRenderTask?.cancel()
        state.borderTopping = nil
        state.borderSilhouette = nil
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

}
