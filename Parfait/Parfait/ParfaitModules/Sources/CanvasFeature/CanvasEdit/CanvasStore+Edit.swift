//
//  CanvasStore+Edit.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/26/26.
//

public extension CanvasStore {
    enum ToppingAddSource: Hashable, Identifiable, Sendable {
        case camera(canvasDate: CalendarDate)
        case gallery(canvasDate: CalendarDate)
        case text

        public var id: Self { self }
    }

    enum CanvasEditDestination: Hashable, Identifiable, Sendable {
        case background
        /// C-001 에서 내 사진이나 텍스트를 탭해 토핑 편집 화면으로 들어간 경우. 탭한 쪽이 선택된 채로 열린다.
        case toppings(selectedToppingID: Int? = nil, selectedTextID: Int? = nil)

        public var id: Self { self }
    }
}

extension CanvasStore.CanvasEditDestination {
    var selectedToppingID: Int? {
        guard case .toppings(let selectedToppingID, _) = self else { return nil }
        return selectedToppingID
    }

    var selectedTextID: Int? {
        guard case .toppings(_, let selectedTextID) = self else { return nil }
        return selectedTextID
    }
}
