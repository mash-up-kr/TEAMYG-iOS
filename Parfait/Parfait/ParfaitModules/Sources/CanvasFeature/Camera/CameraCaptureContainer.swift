//
//  CameraCaptureContainer.swift
//  CanvasFeature
//
//  Created by 박서연 on 9/7/26.
//

import SwiftUI

/// C-101 카메라와 C-101-Confirm 을 겹쳐 두는 컨테이너.
struct CameraCaptureContainer<Preview: View, Confirmation: View>: View {
    let isConfirming: Bool
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let confirmation: () -> Confirmation

    var body: some View {
        ZStack {
            preview()
                .opacity(isConfirming ? 0 : 1)
                .allowsHitTesting(!isConfirming)

            if isConfirming {
                confirmation()
            }
        }
    }
}
