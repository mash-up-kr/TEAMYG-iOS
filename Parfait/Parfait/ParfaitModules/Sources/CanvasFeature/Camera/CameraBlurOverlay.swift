//
//  CameraBlurOverlay.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/28/26.
//

import SwiftUI
import UIKit

/// 뷰파인더 **바깥만** 흐리게 덮는 레이어 (`canvas-policy.md` §5.2).
///
/// 카메라 프리뷰는 SwiftUI 가 그린 내용이 아니라 `AVCaptureVideoPreviewLayer` 라
/// SwiftUI `.blur()` 가 닿지 않는다. 프레임을 직접 블러 처리하면 매 프레임 GPU 작업이 되므로,
/// Core Animation 이 합성 단계에서 처리하는 `UIVisualEffectView` 를 얹고 뷰파인더 구멍만 마스크로 뚫는다.
/// 앱 코드가 픽셀을 만지지 않아 비용이 사실상 없다.
///
/// `viewFinderFrame` 은 `CameraDimShape` 와 같은 전역 좌표를 그대로 받는다.
struct CameraBlurOverlay: UIViewRepresentable {
    /// Figma 의 gaussian `4` 에 가장 가까운 재료. `UIBlurEffect` 는 반경을 직접 받지 않아 근사치다.
    private static let blurStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark

    let viewFinderFrame: CGRect

    func makeUIView(context: Context) -> CameraBlurUIView {
        CameraBlurUIView(blurStyle: Self.blurStyle)
    }

    func updateUIView(_ uiView: CameraBlurUIView, context: Context) {
        uiView.viewFinderFrame = viewFinderFrame
    }
}

final class CameraBlurUIView: UIView {
    private let effectView: UIVisualEffectView
    private let holeMask = CAShapeLayer()

    /// 뚫어 둘 뷰파인더 영역. 바뀌면 다음 레이아웃에서 마스크를 다시 만든다.
    var viewFinderFrame: CGRect = .zero {
        didSet {
            guard viewFinderFrame != oldValue else { return }
            setNeedsLayout()
        }
    }

    init(blurStyle: UIBlurEffect.Style) {
        effectView = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        super.init(frame: .zero)

        isUserInteractionEnabled = false
        holeMask.fillRule = .evenOdd
        effectView.layer.mask = holeMask
        addSubview(effectView)
    }

    /// 코드로만 만든다 — 스토리보드 경로가 없다.
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView.frame = bounds

        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(rect: viewFinderFrame))

        // 레이아웃 중 path 가 바뀌면 CALayer 가 암시적으로 애니메이션한다 — 흐림이 밀려 보인다.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        holeMask.frame = bounds
        holeMask.path = path.cgPath
        CATransaction.commit()
    }
}
