//
//  TextToppingView.swift
//  CanvasFeature
//
//  Created by 김남수 on 10/14/26.
//

import SwiftUI
import UIComponent

/// C-106 / C-106-Arrange.
///
/// 새 화면처럼 보이지 않게 배경에서 C-001 캔버스 자리(`canvasFrame`)만 뚫어 **뒤에 깔린 진짜 캔버스**가 그대로 보이게 하고,
/// 화면 전체를 페이드로 띄우고 내린다 — 캔버스는 제자리에 있고 헤더·딤·키보드만 바뀌는 것처럼 보인다.
/// 캔버스를 여기서 다시 그리면 배경·토핑 이미지를 새로 불러오는 동안 비거나 테두리가 달라 페이드 중에 잔상이 보였다.
/// 캔버스는 키보드에 밀리지 않고(C-001 이 키보드 안전 영역을 무시한다), 툴바만 키보드 위에 붙는다.
struct TextToppingView: View {
    private static var fadeAnimation: Animation { .easeInOut(duration: 0.2) }
    private static var transitionAnimation: Animation { .smooth(duration: 0.3) }

    @State private var store: TextToppingStore
    /// 진행 중인 끌기·핀치·회전 — 커밋 전 미리보기라 뷰 로컬로만 든다 (`docs/mvi.md` 바인딩 절).
    @State private var draft = ToppingTransformDraft()
    /// 입력 중 텍스트 뷰에서 시작한 끌기·핀치가 이어지는 중인지.
    @State private var isTextViewTransforming = false
    /// 키보드가 다 올라왔을 때의 툴바 위 — 키보드가 움직이는 도중 값을 따라가면 박스가 키보드를 따라 미끄러졌다.
    @State private var toolbarMinY: CGFloat?
    /// 입력 ↔ 배치 전환 중 박스를 이전 모습에서 지금 모습으로 옮겨 보이게 하는 변환. 끝나면 `.identity`.
    @State private var transition = TextToppingTransition.identity
    @State private var isTransitioning = false
    @State private var transitionFallbackTask: Task<Void, Never>?
    @State private var isShown = false
    @State private var toasts: [YGToastItem] = []
    @Environment(\.dismiss) private var dismiss
    /// C-001 캔버스 패널의 화면 좌표 — 열릴 때 값으로 고정한다.
    @State private var canvasFrame: CGRect

    init(store: TextToppingStore, canvasFrame: CGRect) {
        _store = State(initialValue: store)
        _canvasFrame = State(initialValue: canvasFrame)
    }

    private var state: TextToppingStore.State { store.state }
    private var isInput: Bool { state.phase == .input }

    var body: some View {
        ZStack {
            // 안전 영역을 모두 무시해 이 층의 좌표가 곧 화면 좌표가 된다 — `canvasFrame` 을 그대로 쓴다.
            ZStack(alignment: .topLeading) {
                CanvasDotGridBackground()
                    .clipShape(ScreenExcludingCanvasShape(canvasFrame: canvasFrame), style: FillStyle(eoFill: true))

                if !isInput {
                    CanvasPanelShape()
                        .fill(Color.black25)
                        .frame(width: canvasFrame.width, height: canvasFrame.height)
                        .position(x: canvasFrame.midX, y: canvasFrame.midY)
                }

                if isInput {
                    // 박스 밖 탭 — 텍스트 박스와 툴바를 뺀 모든 곳. 닫기만 하고 아래로 넘기지 않는다.
                    Color.black50
                        .onTapGesture { sendChangingPhase(.outsideTapped) }
                }

                textLayer
            }
            .ignoresSafeArea()

            if isInput {
                inputChrome
            }
        }
        .overlay(alignment: .top) {
            header
        }
        .overlay {
            if !isInput {
                // 키보드 안전 영역을 무시하는 층에 붙인다 — 배치로 바뀐 뒤 내려가는 키보드 위에 얹혀 같이 내려왔다.
                Color.clear
                    .overlay(alignment: .bottom) {
                        YGButton("캔버스에 쌓기", variant: .large) { store.send(.stackTapped) }
                            .padding(.horizontal, .padding7)
                            .padding(.bottom, .padding1)
                    }
                    .ignoresSafeArea(.keyboard)
            }
        }
        .ygLoading(state.isSaving)
        .disabled(state.isSaving)
        .ygToastOverlay($toasts)
        .opacity(isShown ? 1 : 0)
        // `onAppear` 에서 올리면 첫 프레임이 그려지기 전이라 페이드 없이 한 번에 떴다 — 첫 프레임 뒤에 시작한다.
        .task {
            store.send(.screenAppeared)
            withAnimation(Self.fadeAnimation) { isShown = true }
        }
        .onChange(of: canvasFrame.size, initial: true) { _, size in
            store.send(.canvasResized(size))
        }
        .onChange(of: textAreaHeight, initial: true) { _, height in
            store.send(.textAreaResized(height))
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
            guard let keyboardFrame = $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            // 툴바는 키보드 바로 위에 붙는다 — 키보드가 다 움직인 뒤의 자리를 미리 안다.
            toolbarMinY = keyboardFrame.minY - TextToppingToolbar.height
            // 키보드 애니메이션 블록 밖에서 출발해야 박스 변환이 키보드 곡선에 휩쓸리지 않는다.
            DispatchQueue.main.async { animateTransition() }
        }
        .ygPopup(
            isPresented: store.binding(\.showsExitPopup, TextToppingStore.Intent.exitPopupVisibilityChanged),
            title: "텍스트 작성을 그만둘까요?",
            description: "지금까지 작성한 내용은 저장되지 않아요.\n정말 그만두시겠어요?",
            secondaryTitle: "그만두기",
            primaryTitle: "계속 작성",
            secondaryAction: { store.send(.discardTapped) }
        )
        .task {
            for await event in store.eventStream() {
                switch event {
                case .dismissRequested:
                    fadeOutAndDismiss()
                case .saveFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "텍스트를 저장하지 못했어요, 잠시 후 다시 시도해 주세요")
                    )
                }
            }
        }
    }

    /// 들어올 때와 같이 페이드로 내리고, 시트 내림 애니메이션 없이 닫는다.
    private func fadeOutAndDismiss() {
        withAnimation(Self.fadeAnimation) {
            isShown = false
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { dismiss() }
        }
    }

    /// 입력 ↔ 배치를 바꿀 수 있는 intent. 박스를 새 모습으로 바로 그리고, 이전 모습에서 출발하는 변환만 애니메이션한다.
    /// UIKit 텍스트 뷰의 크기·글자 크기는 애니메이션되지 않아서, 함께 애니메이션하면 프레임만 움직이고 글자는 한 번에 바뀌어 어긋났다.
    /// 출발 변환은 상태를 바꾸는 바로 이 호출에서 넣는다 — `onChange` 로 넣으면 한 프레임 늦어 새 모습이 먼저 보였다.
    private func sendChangingPhase(_ intent: TextToppingStore.Intent) {
        let oldPhase = state.phase
        let oldLook = look(of: oldPhase)
        store.send(intent)
        guard state.phase != oldPhase else { return }

        let delta = TextToppingTransition(from: oldLook, to: look(of: state.phase))
        guard delta != .identity else { return }

        // 키보드가 오르내리는 애니메이션에 휩쓸리지 않게 출발 변환은 애니메이션 없이 넣는다.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            transition = delta
            isTransitioning = true
        }
        // 키보드가 움직이기 시작할 때 출발한다 (`keyboardWillChangeFrame`). 키보드를 띄우고 내리는 준비가 메인 스레드를 잠시 잡아서,
        // 바로 출발하면 그동안 멈춰 있다가 끝자리로 건너뛰었다. 키보드가 안 움직이는 경우(하드웨어 키보드 등)를 위해 늦게라도 출발한다.
        transitionFallbackTask?.cancel()
        transitionFallbackTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            animateTransition()
        }
    }

    private func animateTransition() {
        transitionFallbackTask?.cancel()
        guard transition != .identity else { return }
        withAnimation(Self.transitionAnimation) {
            transition = .identity
        } completion: {
            withAnimation(Self.fadeAnimation) { isTransitioning = false }
        }
    }

    private func look(of phase: TextToppingStore.Phase) -> TextToppingLook {
        let placement = switch phase {
        case .input: state.inputPlacement
        case .arrange: state.placement ?? state.inputPlacement
        }
        return TextToppingLook(
            center: placement.center(in: state.canvasSize),
            rotationDegrees: placement.rotationDegrees,
            fontSize: state.displayFontSize * CGFloat(placement.scale)
        )
    }

    /// 캔버스 상단 ~ 툴바 위. 캔버스보다 길어지지 않는다.
    private var textAreaHeight: CGFloat {
        guard let toolbarMinY else { return canvasFrame.height }
        return min(max(toolbarMinY - canvasFrame.minY, 0), canvasFrame.height)
    }

    @ViewBuilder
    private var header: some View {
        if isInput {
            // 키보드가 올라와 있는 동안엔 나가기 없이 ✓ 만 둔다.
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 44, height: 44)
                Spacer(minLength: 0)
                Text("배치")
                    .suit(.body01Regular)
                    .foregroundStyle(.gray800)
                Spacer(minLength: 0)
                YGCircleButton(.icCheck, variant: .default) { sendChangingPhase(.confirmTapped) }
            }
            .padding(.horizontal, .padding7)
            .padding(.top, .padding6)
        } else {
            YGFloatingBar(.title("배치"), onClose: { store.send(.closeTapped) })
        }
    }

    // MARK: - 텍스트

    private var textLayer: some View {
        let canvasSize = state.canvasSize
        let placement = draft.applied(to: state.displayPlacement, in: canvasSize)
        let fontSize = state.displayFontSize * CGFloat(placement.scale)
        let text = isInput ? state.text : state.arrangedText
        let textSize = TextToppingBox.textSize(
            of: text,
            fontSize: fontSize,
            // 배치에선 줄바꿈이 이미 개행으로 박혀 있어 제한 없이 잰다.
            wrapWidth: isInput ? canvasSize.width : .greatestFiniteMagnitude
        )
        let boxSize = TextToppingBox.boxSize(textSize: textSize, fontSize: fontSize, type: state.displayType)

        return ZStack {
            TextToppingBox(
                text: text,
                fontSize: fontSize,
                textSize: textSize,
                boxSize: boxSize,
                color: state.color,
                type: state.displayType,
                alignment: state.alignment,
                // 키보드는 이 값으로만 올리고 내린다 — 닫으며 따로 내리면 다음 뷰 갱신에서 다시 올라왔다.
                isEditing: isInput && !state.isDismissing,
                inputCanvasSize: isInput ? canvasSize : nil,
                draft: $draft,
                onTextChange: { store.send(.textChanged($0)) },
                onEditingEnd: { sendChangingPhase(.editingEnded) },
                onTransformBegin: {
                    isTextViewTransforming = true
                    sendChangingPhase(.transformBegan)
                },
                onTransformCommit: {
                    isTextViewTransforming = false
                    store.send(.placementCommitted($0))
                }
            )
            .rotationEffect(.degrees(placement.rotationDegrees))
            .position(placement.center(in: canvasSize))
            // 키보드가 오르내리는 동안의 암묵적 애니메이션을 끊는다 — 전환 모습은 아래 변환만 움직인다.
            .transaction { $0.animation = nil }
            .modifier(TextToppingTransitionEffect(center: placement.center(in: canvasSize), transition: transition))

            if !isInput {
                arrangeControls(placement: placement, boxSize: boxSize)
                    // 박스가 제자리에 오기 전엔 포커스 테두리를 숨긴다.
                    .opacity(isTransitioning ? 0 : 1)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipShape(CanvasPanelShape())
        .position(x: canvasFrame.midX, y: canvasFrame.midY)
    }

    /// 배치 상태 — 캔버스 전체 제스처 면 + 포커스 테두리 (토핑 편집 화면과 같은 점선).
    @ViewBuilder
    private func arrangeControls(placement: ToppingPlacement, boxSize: CGSize) -> some View {
        let canvasSize = state.canvasSize
        let committedPlacement = state.displayPlacement

        ToppingTransformGestureOverlay(
            draft: $draft,
            // 입력 중 시작한 끌기가 아직 이어지는 동안엔 변형을 끈다 — 두 인식기가 같은 draft 를 번갈아 쓰면 튄다.
            placementCenter: isTextViewTransforming ? nil : committedPlacement.center(in: canvasSize),
            onTap: { point in
                guard committedPlacement.contains(point, renderedSize: boxSize, canvasSize: canvasSize) else { return }
                sendChangingPhase(.arrangedTextTapped)
            },
            onCommit: { store.send(.placementCommitted($0)) }
        )

        ToppingSelectionFrame(renderedSize: boxSize)
            .rotationEffect(.degrees(placement.rotationDegrees))
            .position(placement.center(in: canvasSize))
            .allowsHitTesting(false)
    }

    // MARK: - 입력 도구

    /// 키보드를 따라 올라가는 층 — 팝오버 + 툴바.
    private var inputChrome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
                .allowsHitTesting(false)

            if state.isColorPopoverPresented {
                TextToppingColorPopover(selectedColor: state.color) { store.send(.colorSelected($0)) }
            }

            TextToppingToolbar(
                color: state.color,
                type: state.type,
                alignment: state.alignment,
                characterCount: state.text.count,
                onColorTap: { store.send(.colorButtonTapped) },
                onTypeTap: { store.send(.typeButtonTapped) },
                onAlignmentTap: { store.send(.alignmentButtonTapped) }
            )
        }
    }
}

/// 화면 + 캔버스 패널 두 겹 — even-odd 로 채우면 캔버스 자리만 뚫리고, 그 구멍으로 뒤의 C-001 캔버스가 보인다.
private struct ScreenExcludingCanvasShape: Shape {
    let canvasFrame: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        // `CanvasPanelShape` 는 원점 (0, 0) 기준으로 그린다 — 제 크기로 그린 뒤 캔버스 자리로 옮긴다.
        let panelPath = CanvasPanelShape()
            .path(in: CGRect(origin: .zero, size: canvasFrame.size))
            .offsetBy(dx: canvasFrame.minX, dy: canvasFrame.minY)
        path.addPath(panelPath)
        return path
    }
}

/// 전환 출발·도착 모습 (캔버스 좌표, 화면 pt).
private struct TextToppingLook {
    let center: CGPoint
    let rotationDegrees: Double
    let fontSize: CGFloat
}

/// 지금 모습 → 이전 모습으로 되돌려 보이게 하는 차이. 애니메이션으로 `.identity` 까지 줄인다.
private struct TextToppingTransition: Equatable {
    static let identity = Self(offset: .zero, rotationDegrees: 0, scale: 1)

    var offset: CGSize
    var rotationDegrees: Double
    var scale: CGFloat

    init(offset: CGSize, rotationDegrees: Double, scale: CGFloat) {
        self.offset = offset
        self.rotationDegrees = rotationDegrees
        self.scale = scale
    }

    init(from start: TextToppingLook, to end: TextToppingLook) {
        // 가까운 쪽으로 돈다 — 350° 에서 0° 로 갈 때 한 바퀴 돌지 않게.
        let rotation = (start.rotationDegrees - end.rotationDegrees).truncatingRemainder(dividingBy: 360)
        self.init(
            offset: CGSize(width: start.center.x - end.center.x, height: start.center.y - end.center.y),
            rotationDegrees: rotation > 180 ? rotation - 360 : (rotation < -180 ? rotation + 360 : rotation),
            scale: end.fontSize > 0 ? start.fontSize / end.fontSize : 1
        )
    }
}

/// 박스 중심을 축으로 차이만큼 옮기고·돌리고·키운다. 위치·크기는 그대로라 UIKit 텍스트 뷰를 다시 배치하지 않는다.
private struct TextToppingTransitionEffect: GeometryEffect {
    /// 지금 모습의 박스 중심 — 이 레이어 좌표가 곧 캔버스 좌표다 (`.position` 뒤라 캔버스 크기를 채운다).
    let center: CGPoint
    var transition: TextToppingTransition

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<Double, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(transition.offset.width, transition.offset.height),
                AnimatablePair(transition.rotationDegrees, transition.scale)
            )
        }
        set {
            transition = TextToppingTransition(
                offset: CGSize(width: newValue.first.first, height: newValue.first.second),
                rotationDegrees: newValue.second.first,
                scale: newValue.second.second
            )
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let transform = CGAffineTransform(
            translationX: center.x + transition.offset.width,
            y: center.y + transition.offset.height
        )
        .rotated(by: transition.rotationDegrees * .pi / 180)
        .scaledBy(x: transition.scale, y: transition.scale)
        .translatedBy(x: -center.x, y: -center.y)
        return ProjectionTransform(transform)
    }
}
