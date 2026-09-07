//
//  CanvasSavePreviewView.swift
//  CanvasFeature
//
//  Created by 신상우 on 9/6/26.
//

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

                YGButton("갤러리에 저장", variant: .mediumPrimary) {
                    store.send(.saveTapped)
                }
                .disabled(store.state.image == nil || store.state.isSaving)
                .padding(.top, .padding6)
            }
            .padding(.horizontal, .padding7)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            YGFloatingBar(
                .title("이미지 미리보기"),
                onClose: { store.send(.closeTapped) }
            )
        }
        .task {
            store.send(.screenAppeared)
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
                ProgressView()
                    .tint(.gray500)
            }
        }
        // 저장본이 곧 16:9 Canvas-Area 라 높이만 정하면 너비는 따라온다.
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
                Text("의 캔버스를 갤러리에 저장할까요?")
                    .foregroundStyle(.gray900)
            }
            .suit(.body02Regular)
            .padding(.vertical, .padding1)

            Text("이 이미지 그대로 갤러리에 저장돼요\n파르페는 인스타그램 스토리 규격에 최적화되어 있어요")
                .suit(.caption01Medium)
                .foregroundStyle(.gray500)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview("합성 완료") {
    CanvasSavePreviewView(
        store: CanvasSavePreviewStore(
            state: .init(dateText: "May 20", weekdayText: "(Wed)", image: .parfaitCup),
            dependencies: .init(
                canvasContent: .init(background: .color(hex: "#FFDDE5")),
                canvasImageExporter: CanvasImageExporter(toppingRenderer: CanvasToppingRenderer()),
                onClose: { _ in }
            )
        )
    )
}

#Preview("합성 중") {
    CanvasSavePreviewView(
        store: CanvasSavePreviewStore(
            state: .init(dateText: "May 20", weekdayText: "(Wed)"),
            dependencies: .init(
                canvasContent: .init(background: .color(hex: "#FFDDE5")),
                canvasImageExporter: CanvasImageExporter(toppingRenderer: CanvasToppingRenderer()),
                onClose: { _ in }
            )
        )
    )
}
