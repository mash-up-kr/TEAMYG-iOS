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

        public var id: Self { self }
    }
}
