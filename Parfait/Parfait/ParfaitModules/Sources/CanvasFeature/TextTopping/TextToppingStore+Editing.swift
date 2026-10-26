//
//  TextToppingStore+Editing.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/26/26.
//

import CanvasDomain

/// 쌓아 둔 내 텍스트 수정. 내용은 고칠 수 없고(제품 정책) 위치·크기·회전·색·타입·삭제만 서버로 보낸다.
struct TextToppingEditing: Equatable {
    let text: CanvasStore.CanvasText
    /// 팔레트 밖 색이면 White 로 열린다 — 비교는 열린 값 기준이라 색을 안 건드리면 보내지 않는다.
    let color: TextToppingColor
    let type: TextToppingType
    let placement: ToppingPlacement
}

extension TextToppingStore {
    /// 쌓아 둔 텍스트의 바뀐 값만 보낸다. 지운 표시가 있으면 지운다.
    func saveEdit(of editing: TextToppingEditing) {
        guard !state.isSaving else { return }
        guard let parfaitID = dependencies.parfaitID else {
            eventChannel.send(.saveFailed)
            return
        }
        guard !state.isDeleted else {
            save { dependencies in
                try await dependencies.toppingUseCase.deleteText(
                    textID: editing.text.id,
                    groupID: dependencies.groupID,
                    parfaitID: parfaitID
                )
                return .deleted(textID: editing.text.id)
            }
            return
        }

        let update = state.textUpdate
        guard !update.isEmpty else {
            requestDismiss()
            return
        }
        let edited = state.editedText(from: editing.text)
        save { dependencies in
            try await dependencies.toppingUseCase.updateText(
                update,
                textID: editing.text.id,
                groupID: dependencies.groupID,
                parfaitID: parfaitID
            )
            return .saved(edited)
        }
    }
}

extension TextToppingStore.State {
    /// 쌓아 둔 내 텍스트를 배치 상태로 연다. 글자 크기는 기본값, 배율은 저장된 값 그대로 —
    /// 보는 쪽이 그리는 크기(기본 크기 × `scale`)와 같다.
    init(editing text: CanvasStore.CanvasText) {
        let color = TextToppingColor(textHex: text.textHex) ?? .white
        let placement = ToppingPlacement(
            positionX: text.positionX,
            positionY: text.positionY,
            scale: text.scale,
            rotationDegrees: text.rotation
        )
        phase = .arrange
        self.text = text.text
        arrangedText = text.text
        self.color = color
        type = text.type
        self.placement = placement
        editing = TextToppingEditing(text: text, color: color, type: text.type, placement: placement)
    }

    /// 나가기 확인 팝업을 띄울지. 새 텍스트는 늘 있다.
    var hasChanges: Bool {
        guard let editing else { return true }
        return isDeleted || color != editing.color || type != editing.type || placement != editing.placement
    }

    var textUpdate: TextUpdate {
        guard let editing, let placement else { return TextUpdate() }
        let saved = editing.placement
        return TextUpdate(
            placement: ToppingPlacementUpdate(
                positionX: placement.positionX == saved.positionX ? nil : placement.positionX,
                positionY: placement.positionY == saved.positionY ? nil : placement.positionY,
                scale: placement.scale == saved.scale ? nil : placement.scale,
                rotation: placement.rotationDegrees == saved.rotationDegrees ? nil : placement.rotationDegrees
            ),
            colorHex: color == editing.color ? nil : color.textHex,
            isFill: type == editing.type ? nil : type.hasFill,
            isStroke: type == editing.type ? nil : type.hasStroke
        )
    }

    func editedText(from text: CanvasStore.CanvasText) -> CanvasStore.CanvasText {
        let placement = placement ?? editing?.placement ?? ToppingPlacement()
        let colorChanged = color != editing?.color
        return CanvasStore.CanvasText(
            id: text.id,
            text: text.text,
            positionX: placement.positionX,
            positionY: placement.positionY,
            positionZ: text.positionZ,
            scale: placement.scale,
            rotation: placement.rotationDegrees,
            textHex: colorChanged ? color.textHex : text.textHex,
            fillHex: colorChanged ? color.fillHex : text.fillHex,
            type: type,
            isMine: text.isMine
        )
    }
}
