//
//  CanvasTutorialView.swift
//  CanvasFeature
//
//  Created by 김남수 on 9/5/26.
//

import SwiftUI
import UIComponent

/// 캔버스 화면 최초 진입 시 전체를 덮는 튜토리얼 3장.
///
/// 배경(시안 스크린샷)과 안내 카드가 모두 통짜 이미지라, 카드 안에 그려진
/// "다음/시작하기" 필 위치에 투명 버튼만 얹는다. 버튼 밖 탭은 전부 삼켜서
/// 아래 화면으로 새지 않게 한다.
struct CanvasTutorialView: View {
    /// 최초 1회 노출 여부를 기억하는 UserDefaults 키. CanvasView 의 `@AppStorage` 와 공유.
    static let hasSeenDefaultsKey = "hasSeenCanvasTutorial"

    /// 마지막 장 "시작하기" 탭 — 호출부가 플래그를 세워 오버레이를 내린다.
    let onFinished: () -> Void

    @State private var stepIndex = 0

    /// 장별 (배경, 카드, 카드가 붙는 변). 1장은 하이라이트가 상단(캘린더)이라 카드가 하단,
    /// 2·3장은 하이라이트가 하단 버튼이라 카드가 상단.
    private static let steps: [(backdrop: Image, card: Image, cardAlignment: Alignment)] = [
        (.imageTutorial1, .tutorial1, .bottom),
        (.imageTutorial2, .tutorial2, .top),
        (.imageTutorial3, .tutorial3, .top),
    ]

    var body: some View {
        let step = Self.steps[stepIndex]
        ZStack(alignment: .center) {
            Color.black50.ignoresSafeArea()
            step.backdrop
                .resizable()
                .frame(width: 375)
                .aspectRatio(375/732, contentMode: .fit)
                .overlay(alignment: step.cardAlignment) {
                    step.card
                        .resizable()
                        .scaledToFit()
                        .frame(width: 335)
                        .overlay(alignment: .topTrailing) { nextButton }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {} // 버튼 밖 탭 삼킴
    }

    /// 카드 이미지 우상단의 "다음 >" / "시작하기 >" 필을 덮는 투명 버튼.
    /// 필 실측(카드 335pt 기준 대략 260~320 × 10~40)보다 넉넉히 잡는다.
    private var nextButton: some View {
        Button {
            if stepIndex < Self.steps.count - 1 {
                stepIndex += 1
            } else {
                onFinished()
            }
        } label: {
            Color.clear
                .frame(width: 110, height: 56)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Preview

#Preview("튜토리얼") {
    CanvasTutorialView {}
}
