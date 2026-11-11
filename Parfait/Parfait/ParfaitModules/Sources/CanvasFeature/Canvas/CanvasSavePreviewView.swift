//
//  CanvasSavePreviewView.swift
//  CanvasFeature
//
//  Created by 신상우 on 9/6/26.
//

import Core
import SwiftUI
import UIComponent

/// C-001-Save-Preview — 앨범에 넣기 전에 저장본을 그대로 보여 주고 확인받는다.
///
/// 여기 뜬 이미지가 곧 저장본이다. 잘린 모서리와 날짜 바가 없는 9:16 직사각형이라
/// 화면 속 캔버스와 모양이 다르다 — 그래서 미리 보여 준다.
struct CanvasSavePreviewView: View {
    /// 디자인 시안의 저장본 높이. 남는 공간을 채우지 않고 이 크기로 고정해 위아래 여백을 남긴다.
    private static let imageHeight: CGFloat = 352

    @State private var store: CanvasSavePreviewStore
    @State private var toasts: [YGToastItem] = []

    init(store: CanvasSavePreviewStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        ZStack {
            Color.whiteFixed
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: .gap7) {
                    canvasImage
                    info
                }

                Spacer(minLength: 0)

                VStack(spacing: .gap3) {
                    YGButton(store.state.format == .image ? "사진으로 저장" : "영상으로 저장", variant: .large) {
                        store.send(.saveTapped)
                    }
                    YGButton("인스타그램 스토리 공유", variant: .mediumSecondary, fillsWidth: true) {
                        store.send(.instagramShareTapped)
                    }
                }
                .disabled(store.state.image == nil || store.state.isProcessing)
                .padding(.top, .padding6)
            }
            .padding(.horizontal, .padding7)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(
                .title(store.state.format == .image ? "사진 미리보기" : "영상 미리보기"),
                onClose: { store.send(.closeTapped) }
            )
        }
        .ygToastOverlay($toasts)
        .task {
            store.send(.screenAppeared)
        }
        .task {
            for await event in store.eventStream() {
                switch event {
                case .instagramNotInstalled:
                    toasts.append(
                        YGToastItem(kind: .error, message: "스토리 공유에 실패했어요, 나중에 다시 시도해 주세요")
                    )
                case .instagramShareFailed:
                    toasts.append(
                        YGToastItem(kind: .error, message: "인스타그램 공유에 실패했어요, 잠시 후 다시 시도해 주세요")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var canvasImage: some View {
        Group {
            if let image = store.state.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                YGLottieView(.loadingDark)
                    .frame(width: 44, height: 44)
            }
        }
        // 저장본이 곧 9:16 Canvas-Area 라 높이만 정하면 너비는 따라온다.
        .frame(
            width: Self.imageHeight * CanvasArea.aspectRatio,
            height: Self.imageHeight
        )
        .overlay {
            Rectangle()
                .strokeBorder(Color.gray500, lineWidth: 1)
        }
    }

    private var info: some View {
        VStack(spacing: .gap3) {
            HStack(spacing: .gap1) {
                Text(store.state.dateText)
                    .foregroundStyle(.gray900)
                Text(store.state.weekdayText)
                    .foregroundStyle(.gray300)
                Text("의 캔버스를 저장할까요?")
                    .foregroundStyle(.gray900)
            }
            .suit(.body02Regular)
            .padding(.vertical, .padding1)

            Text("이 \(store.state.format == .image ? "이미지" : "영상") 그대로 갤러리에 저장돼요\n인스타그램 스토리에 바로 공유할 수 있어요")
                .suit(.caption01Medium)
                .foregroundStyle(.gray500)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview("합성 완료") {
    CanvasSavePreviewView(
        store: CanvasSavePreviewStore(
            state: .init(format: .image, dateText: "May 20", weekdayText: "(Wed)", image: .parfaitCup),
            dependencies: .init(
                canvasContent: .init(background: .color(hex: "#FFDDE5")),
                canvasImageExporter: CanvasImageExporter(
                    toppingRenderer: CanvasToppingRenderer(imageProvider: ImageProvider()),
                    imageProvider: ImageProvider()
                ),
                onClose: { _ in },
                logAnalyticsEvent: { _ in }
            )
        )
    )
}

#Preview("합성 중") {
    CanvasSavePreviewView(
        store: CanvasSavePreviewStore(
            state: .init(format: .video, dateText: "May 20", weekdayText: "(Wed)"),
            dependencies: .init(
                canvasContent: .init(background: .color(hex: "#FFDDE5")),
                canvasImageExporter: CanvasImageExporter(
                    toppingRenderer: CanvasToppingRenderer(imageProvider: ImageProvider()),
                    imageProvider: ImageProvider()
                ),
                onClose: { _ in },
                logAnalyticsEvent: { _ in }
            )
        )
    )
}
