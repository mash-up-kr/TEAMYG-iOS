//
//  AlbumView.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import SwiftUI
import UIComponent

/// 앨범 플로우 진입점 — 권한 3분기로 화면을 전환하고 우상단 닫기 버튼을 소유한다.
public struct AlbumView: View {
    @State private var store = AlbumStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        ZStack {
            Color.whiteFixed.ignoresSafeArea()

            Group {
                switch store.state.permission {
                case .fullAccess:
                    AlbumPickerView(isLimited: false)
                case .limited:
                    AlbumPickerView(isLimited: true)
                case .denied:
                    AlbumPermissionDeniedView()
                case .notDetermined, nil:
                    Color.clear // 시스템 권한 팝업 대기
                }
            }
            // 설정 복귀로 limited↔fullAccess 가 바뀌면 AlbumPickerView 의 @State store 를 재생성.
            .id(store.state.permission)
        }
        .overlay(alignment: .topTrailing) {
            YGCircleButton(.icClose, variant: .default) { dismiss() }
                .padding(.top, 16)
                .padding(.trailing, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { store.send(.appeared) }
        .onDisappear { store.send(.disappeared) }
        .onChange(of: scenePhase) { _, newPhase in
            // 설정 앱에서 권한 바꾸고 복귀하는 경로.
            if newPhase == .active { store.send(.sceneBecameActive) }
        }
    }
}

#Preview {
    AlbumView()
}
