//
//  OpenURLAction+Settings.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/28/26.
//

import SwiftUI
import UIKit

extension OpenURLAction {
    /// 이 앱의 시스템 설정 화면(카메라·사진 권한)을 연다.
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        self(settingsURL)
    }
}
