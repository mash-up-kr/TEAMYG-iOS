//
//  CanvasToppingRenderer.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/24/26.
//

import Core
import CoreGraphics
import Foundation
import SwiftUI

/// 서버에 저장된 토핑을 캔버스에 그리기 위한 디코딩 버킷 정책 + 테두리 실루엣 캐시.
///
/// 다운로드·다운샘플링·메모리 캐시는 `ImageProvider` 가 담당하고, 여기는 토핑 전용 정책만 남는다 —
/// 필요 해상도를 버킷으로 끊는 것과, 테두리 실루엣(색·굵기 값으로만 오는 확정 규약) 렌더링.
/// 캔버스를 나갔다 들어와도 캐시가 살아 있도록 앱 루트가 하나를 소유한다.
public actor CanvasToppingRenderer {
    private let imageProvider: ImageProvider
    private let borderRenderer = ToppingBorderRenderer()

    public init(imageProvider: ImageProvider) {
        self.imageProvider = imageProvider
    }

    /// `neededLongEdge` 는 이 토핑이 화면에 그려질 긴 변의 **픽셀** 수.
    /// 실제 디코딩은 그보다 크거나 같은 가장 작은 버킷에서 이뤄지므로, 작게 그려지는 토핑은 작게 푼다.
    /// 같은 URL·같은 버킷을 여러 토핑이 동시에 요청해도 내려받기는 한 번만 한다.
    func topping(at url: URL, neededLongEdge: CGFloat) async -> CGImage? {
        let longEdge = ToppingDecodeBucket.longEdge(covering: neededLongEdge)
        return await imageProvider.image(at: url, maxPixelSize: Int(longEdge))
    }

    /// 실루엣은 넘겨받은 비트맵에서 뜨므로 버킷마다 결과 크기가 다르다 — 캐시 키에 그 크기를 섞는다.
    func silhouette(
        of topping: CGImage,
        at url: URL,
        width: Double,
        renderedLongEdge: CGFloat
    ) async -> CGImage? {
        await borderRenderer.silhouette(
            of: topping,
            source: "\(url.absoluteString)#\(topping.width)x\(topping.height)",
            width: width,
            renderedLongEdge: renderedLongEdge
        )
    }
}

/// 토핑에 필요한 해상도는 배율 따라 달라지는데, 배율이 조금 바뀔 때마다 다시 디코딩하면 안 된다.
/// 그래서 2배씩 올라가는 계단으로 끊는다 — 필요량은 언제나 한 칸 위 버킷 안에 들어오므로
/// 과다 디코딩이 최대 2배로 묶이고, 캐시 항목도 URL 당 몇 개로 제한된다.
enum ToppingDecodeBucket {
    /// 아래 끝은 배치 기본 크기(짧은 변 48pt @3x)를 덮는 값, 위 끝은 업로드 상한이다 —
    /// 서버에 그보다 큰 원본이 없어 더 크게 디코딩해도 얻을 것이 없다.
    static let ladder: [CGFloat] = [256, 512, 1024, ToppingImageEncoder.maximumLongEdge]

    static func longEdge(covering neededLongEdge: CGFloat) -> CGFloat {
        ladder.first { $0 >= neededLongEdge } ?? ToppingImageEncoder.maximumLongEdge
    }
}

extension EnvironmentValues {
    /// 캔버스를 그리는 화면이 공유한다. 앱이 소유한 인스턴스를 화면마다 직접 얹는다.
    ///
    /// 기본값을 두지 않는다. `@Entry` 의 기본값은 계산 프로퍼티로 펼쳐져 **읽을 때마다 새 인스턴스**가
    /// 만들어지고, 그러면 주입이 닿지 않은 화면마다 캐시가 빈 렌더러가 생겨 같은 토핑을 매번 다시 내려받는다.
    /// 대체 인스턴스를 전역에 두는 것도 금지라(`architecture.md` DI) 주입이 없으면 그리지 않는다.
    @Entry var canvasToppingRenderer: CanvasToppingRenderer?
}
