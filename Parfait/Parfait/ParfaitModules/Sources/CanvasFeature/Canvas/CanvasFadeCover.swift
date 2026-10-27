//
//  CanvasFadeCover.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/27/26.
//

import SwiftUI

/// 편집 화면(토핑 편집·배경 변경)을 C-001 위에 띄우고, `isPresented` 가 꺼지면 전환이 끝난 뒤 `onFadedOut` 으로
/// 내리게 한다. 캔버스는 불투명한 채 C-001 캔버스 자리에서 제자리로 옮겨 가고(`canvasBoardEntrance()`),
/// 나머지(배경·바·버튼)만 페이드한다(`canvasEditChrome()`). 화면 전체를 페이드하면 반투명한 캔버스가 줄어드는 동안
/// 뒤의 C-001 캔버스가 원래 크기로 비쳐 두 캔버스가 겹쳐 보였다.
///
/// 편집 캔버스는 크기가 달라 토핑을 다시 디코딩하고 테두리를 다시 그린다 — 그 전에 출발하면 토핑이 비었다가 튀어나왔다.
/// 그래서 토핑이 다 그려질 때까지(`CanvasLoadTracker`) 아무것도 띄우지 않고 C-001 을 그대로 보여 준다.
struct CanvasFadeCover<Content: View>: View {
    let isPresented: Bool
    /// C-001 캔버스의 화면 좌표.
    let canvasFrame: CGRect
    let onFadedOut: () -> Void
    @ViewBuilder let content: Content

    @State private var isShown = false
    @State private var hasStarted = false
    @State private var loadTracker = CanvasLoadTracker()

    var body: some View {
        content
            .environment(
                \.canvasBoardEntrance,
                CanvasBoardEntrance(sourceFrame: canvasFrame, isShown: isShown, hasStarted: hasStarted)
            )
            .environment(\.canvasLoadTracker, loadTracker)
            .task {
                await loadTracker.waitUntilLoaded()
                hasStarted = true
                withAnimation(CanvasBoardEntrance.animation) { isShown = true }
            }
            .onChange(of: isPresented) { _, isPresented in
                guard !isPresented else { return }
                withAnimation(CanvasBoardEntrance.animation) {
                    isShown = false
                } completion: {
                    onFadedOut()
                }
            }
    }
}

struct CanvasBoardEntrance: Equatable {
    static var animation: Animation { .easeInOut(duration: 0.25) }

    var sourceFrame: CGRect
    var isShown: Bool
    /// 전환을 시작했는지. 그 전엔 캔버스도 숨겨 C-001 이 그대로 보이게 한다.
    var hasStarted: Bool
}

/// 편집 캔버스의 토핑이 다 그려졌는지 센다. 토핑마다 처음 그려질 때까지 하나씩 잡고 있는다.
@MainActor @Observable
final class CanvasLoadTracker {
    /// ponytail: 오래 걸리면(느린 망·큰 원본) 기다리지 않고 출발한다. 이 이상 걸리면 토핑이 늦게 나타나는 걸 감수한다.
    private static let timeout: Duration = .milliseconds(500)
    private static let pollInterval: Duration = .milliseconds(16)

    private var pendingCount = 0

    func begin() {
        pendingCount += 1
    }

    func end() {
        pendingCount -= 1
    }

    /// 토핑 뷰가 레이아웃 뒤에 나타나 등록할 수 있도록 한 프레임 기다린 뒤, 남은 것이 없거나 시간이 다 될 때까지 기다린다.
    func waitUntilLoaded() async {
        let deadline = ContinuousClock.now + Self.timeout
        try? await Task.sleep(for: Self.pollInterval)
        while pendingCount > 0, ContinuousClock.now < deadline {
            try? await Task.sleep(for: Self.pollInterval)
        }
    }
}

extension EnvironmentValues {
    @Entry var canvasBoardEntrance: CanvasBoardEntrance?
    @Entry var canvasLoadTracker: CanvasLoadTracker?
}

extension View {
    /// 편집 화면이 뜨고 지는 동안 이 캔버스를 C-001 캔버스 자리에 겹쳐 둔다. 다 뜨면 제자리.
    func canvasBoardEntrance() -> some View {
        modifier(CanvasBoardEntranceModifier())
    }

    /// 편집 화면에서 캔버스가 아닌 부분 — 캔버스가 옮겨 가는 동안 페이드로 나타나고 사라진다.
    func canvasEditChrome() -> some View {
        modifier(CanvasEditChromeModifier())
    }
}

private struct CanvasEditChromeModifier: ViewModifier {
    @Environment(\.canvasBoardEntrance) private var entrance

    func body(content: Content) -> some View {
        content.opacity(entrance?.isShown == false ? 0 : 1)
    }
}

private struct CanvasBoardEntranceModifier: ViewModifier {
    @Environment(\.canvasBoardEntrance) private var entrance
    @State private var frame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .modifier(
                CanvasBoardEntranceTransform(
                    progress: entrance?.isShown == false ? 0 : 1,
                    isVisible: entrance?.hasStarted != false,
                    sourceFrame: entrance?.sourceFrame ?? .zero,
                    frame: frame
                )
            )
            // 변환 바깥에서 잰다 — 안에서 재면 옮긴 자리가 다시 재어져 옮길 거리가 바뀌는 무한 갱신이 됐다.
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                self.frame = frame
            }
    }
}

/// 페이드와 같은 진행도(0 = C-001 자리, 1 = 제자리)로 움직인다. 진행도를 직접 애니메이션해서, 이 캔버스 자리를
/// 페이드가 시작된 뒤에 알게 돼도 페이드와 한 곡선으로 움직인다 — 따로 출발시키면 페이드가 끝난 뒤에야 줄어들었다.
private struct CanvasBoardEntranceTransform: ViewModifier, Animatable {
    var progress: CGFloat
    let isVisible: Bool
    let sourceFrame: CGRect
    let frame: CGRect

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            // 자리를 재기 전 첫 프레임엔 제자리에 불투명하게 그려지면 번쩍인다 — 잴 때까지 숨긴다.
            .opacity(isVisible && (canMove || progress == 1) ? 1 : 0)
    }

    private var canMove: Bool {
        sourceFrame.width > 0 && frame.width > 0
    }

    /// 두 캔버스 모두 9:16 이라 너비 비율 하나로 맞춘다.
    private var scale: CGFloat {
        guard canMove else { return 1 }
        let sourceScale = sourceFrame.width / frame.width
        return sourceScale + (1 - sourceScale) * progress
    }

    private var offset: CGSize {
        guard canMove else { return .zero }
        return CGSize(
            width: (sourceFrame.midX - frame.midX) * (1 - progress),
            height: (sourceFrame.midY - frame.midY) * (1 - progress)
        )
    }
}
