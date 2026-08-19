//
//  ToppingCameraView.swift
//  CanvasFeature
//
//  Created by 박서연 on 8/9/26.
//

import SwiftUI
import UIComponent

struct ToppingCameraView: View {
    let dateText: String
    let weekdayText: String
    let flashMode: CameraFlashMode
    let isFlashControlEnabled: Bool
    let isShutterEnabled: Bool
    let isSwitchingCamera: Bool
    let showsToast: Bool
    let previewSource: any CameraPreviewSource
    let send: (ToppingAddStore.Intent) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewFinderFrame: CGRect = .zero

    var body: some View {
        ZStack {
            CameraPreviewView(previewSource: previewSource)
                .ignoresSafeArea()

            dimOverlay

            VStack(spacing: 0) {
                topBar
                viewFinder
                CameraControlBar(
                    flashMode: flashMode,
                    isFlashControlEnabled: isFlashControlEnabled,
                    isShutterEnabled: isShutterEnabled,
                    isSwitchingCamera: isSwitchingCamera,
                    onFlashTap: { send(.flashTapped) },
                    onShutterTap: { send(.shutterTapped) },
                    onSwitchCameraTap: { send(.cameraPositionTapped) }
                )
                .padding(.top, .padding3)
            }
            .padding(.horizontal, .padding7)
            .safeAreaPadding(.top, .padding6)
        }
    }

    /// 뷰파인더 안쪽만 밝게 남기는 딤 처리 (even-odd fill 로 구멍을 뚫는다).
    @ViewBuilder
    private var dimOverlay: some View {
        if viewFinderFrame != .zero {
            CameraDimShape(viewFinderFrame: viewFinderFrame)
                .fill(Color.black25, style: FillStyle(eoFill: true))
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            ToppingDateBadge(dateText: dateText, weekdayText: weekdayText)
            Spacer(minLength: .gap4)
            YGCircleButton(.icClose, variant: .secondary) { dismiss() }
        }
        .frame(height: 44)
    }

    private var viewFinder: some View {
        ViewFinderGuide()
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .global)
            } action: { frame in
                viewFinderFrame = frame
            }
            .overlay(alignment: .top) {
                if showsToast {
                    YGToast(.warning, message: "대상이 배경과 선명하게 구분될수록 깔끔하게 선택돼요")
                        .onTapGesture { send(.toastDismissed) }
                }
            }
            .padding(.top, .padding4)
    }
}

private struct CameraDimShape: Shape {
    let viewFinderFrame: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRect(viewFinderFrame)
        return path
    }
}

private struct ViewFinderGuide: View {
    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(Color.gray500, lineWidth: 1)

            ViewFinderCornerShape()
                .stroke(Color.gray500, style: StrokeStyle(lineWidth: 2, lineCap: .square))
                .padding(.padding4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ViewFinderCornerShape: Shape {
    private let cornerLength: CGFloat = 16

    func path(in rect: CGRect) -> Path {
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
        HStack(spacing: .gap2) {
            Text(dateText)
                .foregroundStyle(.gray800)
            Text(weekdayText)
                .foregroundStyle(.gray300)
        }
        .suit(.body01Regular)
        .padding(.horizontal, .padding6)
        .frame(height: 44)
        // `ignoresSafeAreaEdges` 기본값이 `.all` 이라, 생략하면 흰 배경이 상단 세이프 에어리어까지 번져
        // dim 처리된 영역을 덮는다.
        .background(.whiteFixed, ignoresSafeAreaEdges: [])
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
            // 켜짐은 어두운 원(secondary), 꺼짐은 밝은 원(default) 으로 구분한다.
            YGCircleButton(.icLightning, variant: flashMode == .enabled ? .secondary : .default, action: onFlashTap)
                .disabled(!isFlashControlEnabled)
                .opacity(isFlashControlEnabled ? 1 : 0.5)

            Spacer()

            ShutterButton(action: onShutterTap)
                .disabled(!isShutterEnabled)
                .opacity(isShutterEnabled ? 1 : 0.5)

            Spacer()

            YGCircleButton(.icReverse, variant: .default, action: onSwitchCameraTap)
                .disabled(isSwitchingCamera)
                .opacity(isSwitchingCamera ? 0.5 : 1)
        }
        .frame(height: 56)
    }
}

/// 이중 원 셔터 — 디자인 시스템에 대응 컴포넌트가 없어 이 화면 전용으로 둔다.
private struct ShutterButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.whiteFixed)
                .overlay {
                    Circle()
                        .fill(Color.gray900)
                        .padding(.padding2)
                }
                .frame(width: 56, height: 56)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
    }
}
