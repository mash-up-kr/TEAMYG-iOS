//
//  CanvasEditStore+State.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CanvasDomain
import Common
import Foundation

extension CanvasEditStore {
    struct State: Equatable, Sendable {
        let dateText: String
        let weekdayText: String
        var savedBackground: CanvasStore.CanvasBackground
        var background: CanvasStore.CanvasBackground
        var toppings: [EditableTopping]
        var texts: [EditableText]
        /// 이미지·텍스트 id 는 서버에서 따로 매겨져 겹칠 수 있어 선택도 따로 둔다. 둘 중 하나만 값이 있다.
        var selectedToppingID: Int?
        var selectedTextID: Int?
        var isBorderPanelExpanded = false
        var backgroundImageSource: BackgroundImagePickerStore.PhotoSource?
        var selectedBackgroundImageSource: BackgroundImagePickerStore.PhotoSource?
        var pendingUploadedBackground: UploadedImage?
        var showsExitPopup = false
        var saveState: SaveState = .idle

        init(
            dateText: String,
            weekdayText: String,
            canvasContent: CanvasStore.CanvasContent,
            selectedToppingID: Int? = nil,
            selectedTextID: Int? = nil
        ) {
            self.dateText = dateText
            self.weekdayText = weekdayText
            savedBackground = canvasContent.background
            background = canvasContent.background
            toppings = canvasContent.images.map(EditableTopping.init)
            texts = canvasContent.texts.map(EditableText.init)
            self.selectedToppingID = toppings.first { $0.id == selectedToppingID && $0.isMine }?.id
            self.selectedTextID = texts.first { $0.id == selectedTextID && $0.isMine }?.id
        }

        var selectedColorHex: String? {
            guard case .color(let hex) = background else { return nil }
            return hex
        }

        var isImageSelected: Bool {
            switch background {
            case .image, .imageData: true
            case .color: false
            }
        }

        var activeToppings: [EditableTopping] {
            toppings.filter { !$0.isDeleted }
        }

        var activeTexts: [EditableText] {
            texts.filter { !$0.isDeleted }
        }

        var selectedTopping: EditableTopping? {
            guard let selectedToppingID else { return nil }
            return toppings.first { $0.id == selectedToppingID && $0.isMine && !$0.isDeleted }
        }

        var borderPanelTopping: EditableTopping? {
            isBorderPanelExpanded ? selectedTopping : nil
        }

        var hasChanges: Bool {
            background != savedBackground
                || toppings.contains(where: \.hasChanges)
                || texts.contains(where: \.hasChanges)
        }
    }

    struct EditableTopping: Equatable, Identifiable, Sendable {
        let id: Int
        let imageURL: URL
        let positionZ: Double
        let isMine: Bool
        var savedPlacement: ToppingPlacement
        var placement: ToppingPlacement
        var savedBorder: ToppingBorder
        var border: ToppingBorder
        var isDeleted = false

        init(_ canvasImage: CanvasStore.CanvasImage) {
            id = canvasImage.id
            imageURL = canvasImage.imageURL
            positionZ = canvasImage.positionZ
            isMine = canvasImage.isMine
            savedPlacement = ToppingPlacement(canvasImage)
            placement = ToppingPlacement(canvasImage)
            savedBorder = ToppingBorder(canvasImage.border)
            border = ToppingBorder(canvasImage.border)
        }

        var canvasImage: CanvasStore.CanvasImage {
            canvasImage(placement: placement)
        }

        func canvasImage(placement: ToppingPlacement) -> CanvasStore.CanvasImage {
            CanvasStore.CanvasImage(
                id: id,
                imageURL: imageURL,
                positionX: placement.positionX,
                positionY: placement.positionY,
                positionZ: positionZ,
                scale: placement.scale,
                rotation: placement.rotationDegrees,
                border: border.canvasImageBorder,
                isMine: isMine
            )
        }

        var hasPlacementChanges: Bool { placement != savedPlacement }
        var hasBorderChanges: Bool { border != savedBorder }
        var hasChanges: Bool { isDeleted || hasPlacementChanges || hasBorderChanges }

        var placementUpdate: ToppingPlacementUpdate {
            ToppingPlacementUpdate(
                positionX: placement.positionX == savedPlacement.positionX ? nil : placement.positionX,
                positionY: placement.positionY == savedPlacement.positionY ? nil : placement.positionY,
                scale: placement.scale == savedPlacement.scale ? nil : placement.scale,
                rotation: placement.rotationDegrees == savedPlacement.rotationDegrees
                    ? nil
                    : placement.rotationDegrees
            )
        }
    }

    /// 쌓아 둔 텍스트. 위치·크기·회전만 바꾸거나 지울 수 있다 — 내용·색·타입·정렬은 고칠 수 없다 (제품 정책).
    struct EditableText: Equatable, Identifiable, Sendable {
        let saved: CanvasStore.CanvasText
        var savedPlacement: ToppingPlacement
        var placement: ToppingPlacement
        var isDeleted = false

        init(_ canvasText: CanvasStore.CanvasText) {
            saved = canvasText
            savedPlacement = ToppingPlacement(
                positionX: canvasText.positionX,
                positionY: canvasText.positionY,
                scale: canvasText.scale,
                rotationDegrees: canvasText.rotation
            )
            placement = savedPlacement
        }

        var id: Int { saved.id }
        var isMine: Bool { saved.isMine }
        var positionZ: Double { saved.positionZ }

        func canvasText(placement: ToppingPlacement) -> CanvasStore.CanvasText {
            CanvasStore.CanvasText(
                id: saved.id,
                text: saved.text,
                positionX: placement.positionX,
                positionY: placement.positionY,
                positionZ: saved.positionZ,
                scale: placement.scale,
                rotation: placement.rotationDegrees,
                textHex: saved.textHex,
                fillHex: saved.fillHex,
                type: saved.type,
                alignment: saved.alignment,
                isMine: saved.isMine
            )
        }

        var hasPlacementChanges: Bool { placement != savedPlacement }
        var hasChanges: Bool { isDeleted || hasPlacementChanges }

        var placementUpdate: ToppingPlacementUpdate {
            ToppingPlacementUpdate(
                positionX: placement.positionX == savedPlacement.positionX ? nil : placement.positionX,
                positionY: placement.positionY == savedPlacement.positionY ? nil : placement.positionY,
                scale: placement.scale == savedPlacement.scale ? nil : placement.scale,
                rotation: placement.rotationDegrees == savedPlacement.rotationDegrees
                    ? nil
                    : placement.rotationDegrees
            )
        }
    }

    struct Dependencies: Sendable {
        let groupID: Int
        let parfaitID: Int
        let canvasUseCase: any CanvasUseCase
        let toppingUseCase: any ToppingUseCase
        let imageUploadRepository: any ImageUploadRepository
        let onDismiss: @MainActor @Sendable () -> Void
        let onSaved: @MainActor @Sendable () -> Void
        /// 토핑 편집 화면으로 열렸는지 — 배경 편집과 Store 를 같이 써서 토핑 편집 전용 이벤트를 가른다.
        let isToppingEdit: Bool
        let logAnalyticsEvent: AnalyticsEventLogger
    }

    /// 저장 진행 상태. **실패는 여기 담지 않는다** — 일회성 알림이라 이벤트 채널로 보낸다
    /// (`docs/mvi.md` 부수효과·이벤트 절).
    enum SaveState: Equatable, Sendable {
        case idle
        case saving
    }

    enum Event: Sendable {
        case otherToppingSelected
        case otherTextSelected
        case saveFailed
    }

    enum Intent {
        case screenAppeared
        /// 토핑 편집 화면 진입 — screen_view 전용. `screenAppeared` 는 캔버스 주기 갱신까지 켜므로 따로 둔다.
        case toppingEditScreenAppeared
        /// 배경 편집 화면 진입 — screen_view 전용
        case backgroundEditScreenAppeared
        case screenDisappeared
        case sceneBecameActive
        case sceneEnteredBackground
        case canvasRefreshTicked
        case colorSelected(String)
        case backgroundImageSourceTapped(BackgroundImagePickerStore.PhotoSource)
        case backgroundImageFlowDismissed
        case backgroundImageSelected(Data, source: BackgroundImagePickerStore.PhotoSource)
        case toppingTapped(Int)
        case toppingPlacementChanged(toppingID: Int, placement: ToppingPlacement)
        case toppingDeleteTapped(Int)
        case textTapped(Int)
        case textPlacementChanged(textID: Int, placement: ToppingPlacement)
        case textDeleteTapped(Int)
        /// 보드에서 사진·텍스트가 없는 곳을 탭했다.
        case emptyAreaTapped
        case borderWidthChanged(Double)
        case borderColorSelected(ToppingBorderColor)
        case borderPanelExpandTapped
        case borderPanelClosed
        case backgroundImagePickerCloseTapped
        case closeTapped
        case exitPopupVisibilityChanged(Bool)
        case discardTapped
        case confirmTapped
    }
}
