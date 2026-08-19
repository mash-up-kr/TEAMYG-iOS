//
//  CanvasDotGridBackground.swift
//  CanvasFeature
//
//  Created by 박서연 on 7/30/26.
//

import SwiftUI
import UIComponent

struct CanvasDotGridBackground: View {
    private let spacing: CGFloat = 22
    private let dotLength: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            var verticalPosition: CGFloat = 0

            while verticalPosition <= size.height {
                var horizontalPosition: CGFloat = 0

                while horizontalPosition <= size.width {
                    let dotRect = CGRect(
                        x: horizontalPosition,
                        y: verticalPosition,
                        width: dotLength,
                        height: dotLength
                    )
                    context.fill(Path(ellipseIn: dotRect), with: .color(.gray100))
                    horizontalPosition += spacing
                }

                verticalPosition += spacing
            }
        }
        .background(.whiteFixed)
        .accessibilityHidden(true)
    }
}
