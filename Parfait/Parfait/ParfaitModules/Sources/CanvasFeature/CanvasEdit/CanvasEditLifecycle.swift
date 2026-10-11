//
//  CanvasEditLifecycle.swift
//  CanvasFeature
//
//  Created by 박서연 on 10/9/26.
//

import SwiftUI
import UIComponent

extension View {
    func canvasEditLifecycle(
        isSaving: Bool,
        send: @escaping (CanvasEditStore.Intent) -> Void
    ) -> some View {
        modifier(CanvasEditLifecycleModifier(isSaving: isSaving, send: send))
    }
}

private struct CanvasEditLifecycleModifier: ViewModifier {
    let isSaving: Bool
    let send: (CanvasEditStore.Intent) -> Void
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .ygLoading(isSaving)
            .onAppear {
                send(.screenAppeared)
            }
            .onDisappear {
                send(.screenDisappeared)
            }
            .onChange(of: scenePhase) { _, newScenePhase in
                switch newScenePhase {
                case .active:
                    send(.sceneBecameActive)
                case .background:
                    send(.sceneEnteredBackground)
                default:
                    break
                }
            }
    }
}
