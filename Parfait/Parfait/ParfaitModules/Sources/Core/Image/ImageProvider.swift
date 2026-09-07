//
//  ImageProvider.swift
//  Core
//
//  Created by 김남수 on 9/7/26.
//

import CoreGraphics
import Foundation

/// URL 이미지를 내려받아 요청 픽셀 크기로 다운샘플링해 돌려주는 공용 프로바이더.
///
/// 디코딩한 비트맵은 URL·크기 단위로 메모리 캐시하고, 같은 키를 동시에 요청해도
/// 내려받기는 한 번만 한다. 화면을 나갔다 들어와도 캐시가 살아 있도록
/// 앱 루트가 인스턴스 하나를 소유해 주입한다.
public actor ImageProvider {
    /// 디코딩한 비트맵 총량 상한. 한 장의 비용이 다운샘플링 크기에 따라 달라지므로
    /// 장수가 아니라 바이트로 잡는다.
    private static let cacheByteLimit = 48 * 1024 * 1024

    private let session: URLSession
    /// 앱이 끝까지 들고 있는 캐시라 메모리 경고에 스스로 반응해야 한다 — `NSCache` 가 그 일을 한다.
    private let images = NSCache<NSString, CGImage>()
    private var loads: [NSString: Task<CGImage?, Never>] = [:]

    public init(session: URLSession = .shared) {
        self.session = session
        images.totalCostLimit = Self.cacheByteLimit
    }

    /// `maxPixelSize` 는 결과 비트맵 긴 변의 상한(픽셀). 캐시 키에 포함되므로
    /// 호출부가 크기를 계단(버킷)으로 끊어 주면 URL 당 캐시 항목 수가 그만큼 제한된다.
    public func image(at url: URL, maxPixelSize: Int) async -> CGImage? {
        let key = Self.cacheKey(url: url, maxPixelSize: maxPixelSize)

        if let cached = images.object(forKey: key) { return cached }
        if let load = loads[key] { return await load.value }

        // 디코딩이 CPU 작업이라 actor 위에서 돌리면 다른 요청까지 직렬화된다 — 격리를 끊어 밖에서 처리한다.
        let load = Task.detached { [session] () -> CGImage? in
            // 실패 원인 구분 없이 nil 로 — 호출부는 플레이스홀더로 처리한다.
            guard let (imageData, _) = try? await session.data(from: url) else { return nil }
            return ImageDownsampling.decodedImage(from: imageData, maxPixelSize: maxPixelSize)
        }
        loads[key] = load

        let image = await load.value
        loads[key] = nil
        guard let image else { return nil }

        images.setObject(image, forKey: key, cost: image.byteCount)
        return image
    }

    private static func cacheKey(url: URL, maxPixelSize: Int) -> NSString {
        "\(url.absoluteString)#\(maxPixelSize)" as NSString
    }
}

private extension CGImage {
    /// 비트맵이 실제로 차지하는 바이트. 캐시 비용 단위 —
    /// 장수로 세면 큰 이미지 몇 장에 메모리가 쏠려도 상한에 걸리지 않는다.
    var byteCount: Int {
        height * bytesPerRow
    }
}
