//
//  CanvasEditStore+State.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

import CanvasDomain
import Foundation

extension CanvasEditStore {
    struct State: Equatable, Sendable {
        let dateText: String
        let weekdayText: String
        var savedBackground: CanvasStore.CanvasBackground
        var background: CanvasStore.CanvasBackground
        var toppings: [EditableTopping]
        var screen: Screen = .background
        var selectedToppingID: Int?
        var borderEditor = ToppingBorderEditor()
        var backgroundImageSource: BackgroundImagePickerStore.PhotoSource?
        var selectedBackgroundImageSource: BackgroundImagePickerStore.PhotoSource?
        var pendingUploadedBackground: UploadedImage?
        var showsExitPopup = false
        var saveState: SaveState = .idle

        init(
            dateText: String,
            weekdayText: String,
            canvasContent: CanvasStore.CanvasContent
        ) {
            self.dateText = dateText
            self.weekdayText = weekdayText
            savedBackground = canvasContent.background
            background = canvasContent.background
            toppings = canvasContent.images.map(EditableTopping.init)
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

        var borderEditingTopping: EditableTopping? {
            guard case .border(let toppingID) = screen else { return nil }
            return toppings.first { $0.id == toppingID && !$0.isDeleted }
        }

        var hasChanges: Bool {
            background != savedBackground || toppings.contains(where: \.hasChanges)
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

    struct Dependencies: Sendable {
        let groupID: Int
        let parfaitID: Int
        let canvasUseCase: any CanvasUseCase
        let toppingUseCase: any ToppingUseCase
        let imageUploadRepository: any ImageUploadRepository
        let onDismiss: @MainActor @Sendable () -> Void
        let onSaved: @MainActor @Sendable () -> Void
    }

    enum Screen: Equatable, Sendable {
        case background
        case toppings
        case border(toppingID: Int)
    }

    enum SaveState: Equatable, Sendable {
        case idle
        case saving
        case failed
    }

    enum Event: Sendable {
        case otherToppingSelected
    }

    enum Intent {
        case colorSelected(String)
        case backgroundImageSourceTapped(BackgroundImagePickerStore.PhotoSource)
        case backgroundImageFlowDismissed
        case backgroundImageSelected(Data, source: BackgroundImagePickerStore.PhotoSource)
        case backgroundTabTapped
        case toppingTabTapped
        case toppingTapped(Int)
        case toppingPlacementChanged(toppingID: Int, placement: ToppingPlacement)
        case toppingDeleteTapped(Int)
        case toppingBorderEditTapped(Int)
        case borderWidthChanged(Double)
        case borderWidthEditingChanged(Bool)
        case borderColorSelected(ToppingBorderColor)
        case borderUndoTapped
        case borderRedoTapped
        case borderEditClosed
        case borderEditConfirmed
        case closeTapped
        case continueEditingTapped
        case discardTapped
        case confirmTapped
        case saveErrorDismissed
    }
}
