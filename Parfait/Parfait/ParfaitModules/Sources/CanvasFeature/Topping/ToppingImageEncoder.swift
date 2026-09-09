//
//  ToppingImageEncoder.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/24/26.
//

import Common
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 누끼를 알파가 살아 있는 PNG 로 인코딩한다. 서버에 올리는 형식이자 최근 업로드 로컬 저장 형식이다.
enum ToppingImageEncoder {
    /// 업로드 상한. 긴 변이 이보다 크면 비율을 유지한 채 줄인다.
    ///
    /// 가장 크게 보여주는 곳이 테두리 편집 프리뷰다 — `ToppingBorderEditView` 가 미리보기 영역에
    /// `aspectFit` 으로 꽉 채우므로 최대 기종(화면 폭 440pt, 좌우 여백 20pt) 기준 `400 × 3배 = 1200px`.
    /// 캔버스 표시(`440 × 0.4 × 배율 × 3`)와 갤러리 저장본(`360 × 0.4 × 배율 × 3`)은 이보다 작다.
    /// `ToppingDecodeBucket.ladder` 최상단과 `ObjectExtractionPolicy.extractionCanvasLongEdge` 가 이 값을 따른다.
    static let maximumLongEdge: CGFloat = 1200

    /// 최근 업로드로 보관해 둔 알파 PNG 를 다시 읽어들인다.
    static func decode(_ imageData: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// 누끼는 알파가 살아 있어야 한다 — `CGImage.downscaled(longEdge:)` 는 알파를 버리므로 쓰지 않는다.
    static func encodePNG(_ image: CGImage) -> Data? {
        let resized = image.downscaledPreservingAlpha(longEdge: maximumLongEdge)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, resized, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
