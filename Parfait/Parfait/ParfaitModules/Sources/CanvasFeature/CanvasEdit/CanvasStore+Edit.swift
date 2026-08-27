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

        public var id: Self { self }
    }

    enum CanvasEditDestination: Hashable, Identifiable, Sendable {
        case background
        /// C-001 에서 내 토핑을 탭해 바로 C-305 로 들어간 경우.
        case toppings(selectedToppingID: Int)

        public var id: Self { self }
    }
}

extension CanvasStore.CanvasEditDestination {
    var editScreen: CanvasEditStore.Screen {
        switch self {
        case .background: .background
        case .toppings: .toppings
        }
    }

    var selectedToppingID: Int? {
        switch self {
        case .background: nil
        case .toppings(let selectedToppingID): selectedToppingID
        }
    }
}
