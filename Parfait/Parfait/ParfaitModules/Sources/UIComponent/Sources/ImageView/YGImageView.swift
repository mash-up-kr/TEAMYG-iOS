//
//  YGImageView.swift
//  UIComponent
//
//  Created by 김남수 on 9/7/26.
//

import CoreGraphics
import SwiftUI

/// 원격 이미지를 표시 크기에 맞춰 다운샘플링해 보여주는 공용 이미지 뷰.
///
/// 다운로드·캐싱은 환경의 `ygImageLoader` 가 담당한다 — UIComponent 는 Core 를 모르므로
/// (architecture.md import 경계) App 루트가 `ImageProvider` 를 클로저로 감싸 얹는다.
/// `AsyncImage` 와 달리 디코딩 결과가 메모리 캐시에 남아 재방문 시 다시 받지 않는다.
public struct YGImageView<Content: View>: View {
    private let url: URL
    private let content: (YGImagePhase) -> Content

    @Environment(\.ygImageLoader) private var ygImageLoader
    @Environment(\.displayScale) private var displayScale
    @State private var phase: YGImagePhase = .empty
    @State private var frameSize: CGSize = .zero

    public init(url: URL, @ViewBuilder content: @escaping (YGImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    public var body: some View {
        content(phase)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                frameSize = size
            }
            .task(id: LoadRequest(url: url, size: frameSize, displayScale: displayScale)) {
                await load()
            }
    }

    private func load() async {
        // 크기가 잡히기 전엔 픽셀 예산을 모른다 — onGeometryChange 가 크기를 넣으면 task(id:) 가 다시 부른다.
        guard frameSize != .zero else { return }
        guard let ygImageLoader else {
            // 로더 주입 누락 — 빈 화면으로 숨지 않고 실패 상태로 드러낸다.
            phase = .failure
            return
        }

        let maxPixelSize = Int((max(frameSize.width, frameSize.height) * displayScale).rounded(.up))
        if let image = await ygImageLoader(url, maxPixelSize) {
            phase = .success(Image(decorative: image, scale: displayScale))
        } else {
            phase = .failure
        }
    }

    private struct LoadRequest: Equatable {
        let url: URL
        let size: CGSize
        let displayScale: CGFloat
    }
}

/// `YGImageView` 렌더링 단계. `AsyncImage.Phase` 와 같은 구조.
public enum YGImagePhase {
    /// 아직 크기를 못 쟀거나 로드 중. 로드가 끝나면 `success`/`failure` 로 바뀐다.
    case empty
    case success(Image)
    case failure
}

/// `YGImageView` 가 쓰는 이미지 로더 — URL 과 긴 변 최대 픽셀 수를 받아 디코딩된 비트맵을 돌려준다.
public typealias YGImageLoader = @Sendable (_ url: URL, _ maxPixelSize: Int) async -> CGImage?

extension EnvironmentValues {
    /// 기본값 없음 — App 루트가 Core `ImageProvider` 를 감싸 한 번 얹는다. 없으면 `failure` 로 렌더링된다.
    @Entry public var ygImageLoader: YGImageLoader?
}

#Preview {
    YGImageView(url: URL(filePath: "/preview")) { phase in
        switch phase {
        case .success(let image):
            image.resizable().scaledToFill()
        case .failure:
            Color.red
        case .empty:
            Color.gray
        }
    }
    .frame(width: 120, height: 120)
}
