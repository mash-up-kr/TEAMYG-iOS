//
//  CanvasInstagramStorySharer.swift
//  CanvasFeature
//
//  Created by 김남수 on 11/9/26.
//

import Foundation
import UIKit

/// 합성한 캔버스를 인스타그램 스토리 배경으로 넘긴다 — C-001-Save-Preview 의 `인스타그램 스토리 공유`.
///
/// 인스타그램의 Sharing to Stories 규격: 배경을 대지(pasteboard)에 올리고 `instagram-stories://share` 를 연다.
/// `source_application` 에는 Meta 개발자 콘솔의 Facebook App ID 가 필요하다 — Info.plist 의 `FACEBOOK_APP_ID`.
@MainActor
enum CanvasInstagramStorySharer {
    enum Background {
        case image(UIImage)
        /// 다 쓴 임시 영상 파일 — 공유 결과와 상관없이 지운다.
        case video(URL)
    }

    /// `LSApplicationQueriesSchemes` 에 `instagram-stories` 가 있어야 설치 여부를 알 수 있다.
    static var isInstagramInstalled: Bool {
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func share(_ background: Background) async -> Bool {
        // 어느 guard 에서 빠져도 지운다 — 영상은 대지에 올릴 때 이미 메모리로 읽어 둔다.
        defer {
            if case .video(let fileURL) = background {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        guard let appID = Bundle.main.object(forInfoDictionaryKey: "FACEBOOK_APP_ID") as? String,
              !appID.isEmpty,
              let url = URL(string: "instagram-stories://share?source_application=\(appID)"),
              let pasteboardItem = pasteboardItem(for: background)
        else { return false }

        // 인스타그램이 열리며 바로 읽어 가므로 대지에 오래 남겨 두지 않는다.
        UIPasteboard.general.setItems(
            [pasteboardItem],
            options: [.expirationDate: Date.now.addingTimeInterval(5 * 60)]
        )
        return await UIApplication.shared.open(url)
    }

    private static func pasteboardItem(for background: Background) -> [String: Any]? {
        switch background {
        case .image(let image):
            return image.pngData().map { ["com.instagram.sharedSticker.backgroundImage": $0] }
        case .video(let fileURL):
            return (try? Data(contentsOf: fileURL)).map { ["com.instagram.sharedSticker.backgroundVideo": $0] }
        }
    }
}
