//
//  CameraPreviewView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/20/26.
//

import AVFoundation
import SwiftUI
import UIKit

/// `AVCaptureVideoPreviewLayer` 를 얹은 SwiftUI 래퍼.
struct CameraPreviewView: UIViewRepresentable {
    let previewSource: any CameraPreviewSource

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let previewView = CameraPreviewUIView()
        previewView.previewLayer.videoGravity = .resizeAspectFill
        previewSource.connect(to: previewView)
        return previewView
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

final class CameraPreviewUIView: UIView, CameraPreviewTarget {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("CameraPreviewUIView must use AVCaptureVideoPreviewLayer")
        }
        return previewLayer
    }

    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
    }
}
