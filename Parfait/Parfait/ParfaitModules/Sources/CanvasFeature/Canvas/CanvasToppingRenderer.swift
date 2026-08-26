//
//  CanvasToppingRenderer.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/24/26.
//

import CoreGraphics
import Foundation
import SwiftUI

/// 서버에 저장된 토핑을 캔버스에 그리기 위한 디코딩·테두리 실루엣 캐시.
///
/// 테두리는 이미지에 굽지 않고 색·굵기 값으로만 오므로(확정 규약), 그릴 때마다 알파 실루엣을
/// 다시 떠야 한다. `AsyncImage` 는 `CGImage` 를 내주지 않고 캔버스를 열 때마다 다시 받으므로
/// 여기서 직접 받아 캐시한다. 캔버스를 나갔다 들어와도 캐시가 살아 있도록 앱 루트가 하나를 소유한다.
public actor CanvasToppingRenderer {
    /// 토핑은 캔버스 너비의 40%(확대 상한 3배) 안쪽으로 그려진다 — 이보다 큰 해상도는 버린다.
    private static let displayLongEdge: CGFloat = 1200
    private static let maximumCachedToppings = 24

    private let session: URLSession
    private let borderRenderer = ToppingBorderRenderer()
    private var toppings: [URL: CGImage] = [:]
    private var loads: [URL: Task<CGImage?, Never>] = [:]

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// 같은 URL 을 여러 토핑이 동시에 요청해도 내려받기는 한 번만 한다.
    func topping(at url: URL) async -> CGImage? {
        if let cached = toppings[url] { return cached }
        if let load = loads[url] { return await load.value }

        let load = Task.detached { [session, displayLongEdge = Self.displayLongEdge] () -> CGImage? in
            guard let (imageData, _) = try? await session.data(from: url) else { return nil }
            return ToppingImageEncoder.decode(imageData, longEdge: displayLongEdge)
        }
        loads[url] = load

        let topping = await load.value
        loads[url] = nil
        guard let topping else { return nil }

        if toppings.count >= Self.maximumCachedToppings {
            toppings.removeAll()
        }
        toppings[url] = topping
        return topping
    }

    func silhouette(of topping: CGImage, at url: URL, width: Double) async -> CGImage? {
        await borderRenderer.silhouette(of: topping, source: url.absoluteString, width: width)
    }
}

extension EnvironmentValues {
    /// 캔버스를 그리는 화면(C-001·C-106)이 공유한다. `CanvasView` 가 앱이 소유한 인스턴스를 얹는다.
    ///
    /// 기본값을 두지 않는다. `@Entry` 의 기본값은 계산 프로퍼티로 펼쳐져 **읽을 때마다 새 인스턴스**가
    /// 만들어지고, 그러면 주입이 닿지 않은 화면마다 캐시가 빈 렌더러가 생겨 같은 토핑을 매번 다시 내려받는다.
    /// 대체 인스턴스를 전역에 두는 것도 금지라(`architecture.md` DI) 주입이 없으면 그리지 않는다.
    @Entry var canvasToppingRenderer: CanvasToppingRenderer?
}
