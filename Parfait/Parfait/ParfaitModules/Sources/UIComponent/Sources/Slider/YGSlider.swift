//
//  YGSlider.swift
//  UIComponent
//
//  Created by 박서연 on 8/23/26.
//

import SwiftUI

public struct YGSlider: View {
    private static let trackHeight: CGFloat = 6
    private static let handleLength: CGFloat = 20
    private static let touchHeight: CGFloat = 44

    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let onEditingChanged: (Bool) -> Void

    @State private var isEditing = false

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _value = value
        self.range = range
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        GeometryReader { proxy in
            let travel = max(proxy.size.width - Self.handleLength, 1)
            let ratio = normalizedValue

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.gray100)
                    .frame(height: Self.trackHeight)

                Capsule()
                    .fill(.gray850)
                    .frame(width: Self.handleLength / 2 + travel * ratio, height: Self.trackHeight)

                Circle()
                    .fill(.gray850)
                    .frame(width: Self.handleLength, height: Self.handleLength)
                    .offset(x: travel * ratio)
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isEditing {
                            isEditing = true
                            onEditingChanged(true)
                        }
                        updateValue(atPositionX: gesture.location.x, travel: travel)
                    }
                    .onEnded { _ in
                        isEditing = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: Self.touchHeight)
        .accessibilityRepresentation {
            Slider(value: $value, in: range)
        }
    }

    private var normalizedValue: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return clampedRatio((value - range.lowerBound) / span)
    }

    private func updateValue(atPositionX positionX: CGFloat, travel: CGFloat) {
        let ratio = clampedRatio((positionX - Self.handleLength / 2) / travel)
        value = range.lowerBound + Double(ratio) * (range.upperBound - range.lowerBound)
    }

    private func clampedRatio(_ ratio: CGFloat) -> CGFloat {
        min(max(ratio, 0), 1)
    }
}

#Preview {
    @Previewable @State var width: Double = 12

    VStack(spacing: .gap5) {
        YGSlider(value: $width, in: 2...50)
        Text("\(Int(width))px")
    }
    .padding()
}
