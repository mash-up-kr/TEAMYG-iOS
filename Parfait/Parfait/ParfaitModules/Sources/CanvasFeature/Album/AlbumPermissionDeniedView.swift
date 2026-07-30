//
//  AlbumPermissionDeniedView.swift
//  CanvasFeature
//
//  Created by 김남수 on 7/30/26.
//

import SwiftUI
import UIComponent
import UIKit

/// 앨범 권한 거부/제한 시 안내 화면 (Figma C-102-Error).
/// 상태·비동기가 없어 Store 없이 View 만 둔다 (MVI Store 는 컨테이너 AlbumView 소유).
/// 우상단 닫기 버튼은 컨테이너가 오버레이한다.
public struct AlbumPermissionDeniedView: View {
    @Environment(\.openURL) private var openURL

    private static let warningIconSize: CGFloat = 44

    public init() {}

    public var body: some View {
        VStack(spacing: .gap7) {
            VStack(spacing: .gap3) {
                Image.icWarningRound
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: Self.warningIconSize, height: Self.warningIconSize)
                    .foregroundStyle(Color.cherry600)

                VStack(spacing: .gap1) {
                    Text("갤러리 권한이 없어요")
                        .suit(.title03SemiBold)
                        .foregroundStyle(Color.gray900)
                    Text("설정에서 갤러리 권한을 허용해 주세요")
                        .suit(.body02Regular)
                        .foregroundStyle(Color.gray500)
                }
            }

            YGButton("설정으로 이동", variant: .mediumPrimary) {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(settingsURL)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.whiteFixed.ignoresSafeArea()
        AlbumPermissionDeniedView()
    }
}
