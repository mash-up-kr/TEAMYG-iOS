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
        /// `editingTextID` 가 있으면 내 텍스트를 고치러 들어간 경우.
        case text(canvasDate: CalendarDate, editingTextID: Int? = nil)

        public var id: Self { self }
    }

    enum CanvasEditDestination: Hashable, Identifiable, Sendable {
        case background
        /// C-001 에서 내 토핑을 탭해 토핑 편집 화면으로 들어간 경우.
        case toppings(selectedToppingID: Int)

        public var id: Self { self }
    }
}

extension CanvasStore.CanvasEditDestination {
    var selectedToppingID: Int? {
        switch self {
        case .background: nil
        case .toppings(let selectedToppingID): selectedToppingID
        }
    }
}
