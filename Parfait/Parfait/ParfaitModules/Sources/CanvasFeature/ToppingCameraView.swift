//
//  ToppingCameraView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import AVFoundation
import SwiftUI
import UIKit
import UIComponent

struct ToppingCameraView: View {
    let dateText: String
    let weekdayText: String
    let flashMode: CameraFlashMode
    let isFlashControlEnabled: Bool
    let isShutterEnabled: Bool
    let isSwitchingCamera: Bool
    let showsToast: Bool
    let previewSource: (any CameraPreviewSource)?
    let send: (ToppingAddStore.Intent) -> Void

    @State private var viewFinderFrame: CGRect = .zero

    var body: some View {
        ZStack {
            cameraPreview
                .ignoresSafeArea()

            if viewFinderFrame != .zero {
                CameraDimOverlay(viewFinderFrame: viewFinderFrame)
                    .fill(Color.black25, style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ToppingDateBadge(dateText: dateText, weekdayText: weekdayText)
                    Spacer(minLength: 12)
                    ToppingCircleButton(
                        icon: .icClose,
                        foregroundColor: .whiteFixed,
                        backgroundColor: .gray900,
                        action: { send(.flowCloseTapped) }
                    )
                }
                .frame(height: 44)

                ToppingViewFinder()
                    .onGeometryChange(for: CGRect.self) { geometry in
                        geometry.frame(in: .global)
                    } action: { frame in
                        viewFinderFrame = frame
                    }
                    .overlay(alignment: .top) {
                        if showsToast {
                            ToppingToast()
                                .onTapGesture { send(.toastDismissed) }
                        }
                    }
                    .padding(.top, 10)

                CameraControlBar(
                    flashMode: flashMode,
                    isFlashControlEnabled: isFlashControlEnabled,
                    isShutterEnabled: isShutterEnabled,
                    isSwitchingCamera: isSwitchingCamera,
                    onFlashTap: { send(.flashTapped) },
                    onShutterTap: { send(.shutterTapped) },
                    onSwitchCameraTap: { send(.cameraPositionTapped) }
                )
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .safeAreaPadding(.top, 16)
        }
    }

    @ViewBuilder
    private var cameraPreview: some View {
        if let previewSource {
            CameraPreview(previewSource: previewSource)
        } else {
#if DEBUG
            CameraPreviewPlaceholder()
#else
            Color.black
#endif
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let previewSource: any CameraPreviewSource

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let previewView = CameraPreviewUIView()
        previewView.previewLayer.videoGravity = .resizeAspectFill
        previewSource.connect(to: previewView)
        return previewView
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

private final class CameraPreviewUIView: UIView, CameraPreviewTarget {
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

private struct CameraDimOverlay: Shape {
    let viewFinderFrame: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRect(viewFinderFrame)
        return path
    }
}

private struct ToppingViewFinder: View {
    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(Color.gray500, lineWidth: 1)

            ViewFinderCornerShape()
                .stroke(Color.gray500, style: StrokeStyle(lineWidth: 2, lineCap: .square))
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ViewFinderCornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerLength: CGFloat = 16
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))

        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))

        return path
    }
}

private struct ToppingDateBadge: View {
    let dateText: String
    let weekdayText: String

    var body: some View {
        HStack(spacing: 4) {
            Text(dateText)
                .foregroundStyle(.gray800)
            Text(weekdayText)
                .foregroundStyle(.gray300)
        }
        .suit(.body01Regular)
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(.whiteFixed)
        .overlay {
            Rectangle()
                .strokeBorder(Color.gray500, lineWidth: 1)
        }
    }
}

private struct CameraControlBar: View {
    let flashMode: CameraFlashMode
    let isFlashControlEnabled: Bool
    let isShutterEnabled: Bool
    let isSwitchingCamera: Bool
    let onFlashTap: () -> Void
    let onShutterTap: () -> Void
    let onSwitchCameraTap: () -> Void

    var body: some View {
        HStack {
            ToppingCircleButton(
                icon: .icLightning,
                foregroundColor: flashMode == .enabled ? .gray850 : nil,
                backgroundColor: .whiteFixed,
                action: onFlashTap
            )
            .disabled(!isFlashControlEnabled)
            .opacity(isFlashControlEnabled ? 1 : 0.5)

            Spacer()

            Button(action: onShutterTap) {
                Circle()
                    .fill(Color.whiteFixed)
                    .overlay {
                        Circle()
                            .fill(Color.gray900)
                            .padding(4)
                    }
                    .frame(width: 56, height: 56)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(!isShutterEnabled)
            .opacity(isShutterEnabled ? 1 : 0.5)

            Spacer()

            ToppingCircleButton(
                icon: .icReverse,
                foregroundColor: .gray900,
                backgroundColor: .whiteFixed,
                action: onSwitchCameraTap
            )
            .disabled(isSwitchingCamera)
            .opacity(isSwitchingCamera ? 0.5 : 1)
        }
        .frame(height: 56)
    }
}

struct ToppingCameraConfirmationView: View {
    let photoData: Data?
    let onCloseTap: () -> Void
    let onRetakeTap: () -> Void
    let onNextTap: () -> Void

    @State private var capturedImage: UIImage?

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    ToppingCircleButton(
                        icon: .icClose,
                        foregroundColor: .gray900,
                        backgroundColor: .gray50,
                        action: onCloseTap
                    )
                }
                .frame(height: 60)

                capturedImageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 10)

                ToppingDualActionBar(
                    secondaryTitle: "다시 찍기",
                    primaryTitle: "다음",
                    secondaryAction: onRetakeTap,
                    primaryAction: onNextTap
                )
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)
        }
        .task(id: photoData) {
            capturedImage = await Self.decodeImage(from: photoData)
        }
    }

    @ViewBuilder
    private var capturedImageView: some View {
        if let capturedImage {
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFit()
        } else {
            Color.gray100
        }
    }

    private static func decodeImage(from photoData: Data?) async -> UIImage? {
        guard let photoData else { return nil }
        return await Task.detached(priority: .userInitiated) {
            UIImage(data: photoData)?.preparingForDisplay()
        }.value
    }
}
