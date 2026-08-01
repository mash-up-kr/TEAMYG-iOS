//
//  ToppingView.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import GroupDomain
import SwiftUI
import UIComponent

/// 파르페 위에 얹히는 그룹 하나. Img(회전) + Grouptag-Chip 으로 이뤄진 160×160 프레임.
///
/// 프레임 안에서만 좌표를 계산하고, 파르페 어디에 놓일지는 `ParfaitLayout` 이 정한다.
/// 렌더링 크기는 화면 폭에 맞춘 `scale` 로 확대하되 칩 글자는 확대하지 않는다.
struct ToppingView: View {
    let group: YGGroup
    /// 목록에서의 순번 — 짝수 Left / 홀수 Right.
    let index: Int
    let scale: CGFloat
    let action: () -> Void

    private var isRight: Bool { !index.isMultiple(of: 2) }

    private var variant: ToppingVariant {
        .variant(
            forSide: isRight,
            number: StableAssignment.index(for: group.id, count: ToppingVariant.numberCount)
        )
    }

    var body: some View {
        // 프레임 위쪽을 기준점으로 잡아 칩·이미지를 각자의 y 로 내린다.
        // Z 순서는 항상 Img > Chip — 칩을 먼저 깔고 이미지를 위에 올린다.
        ZStack(alignment: .top) {
            chip
            image
        }
        .frame(
            width: ParfaitLayout.toppingSize * scale,
            height: ParfaitLayout.toppingSize * scale,
            alignment: .top
        )
        .contentShape(.rect)
        .onTapGesture(perform: action)
    }

    private var image: some View {
        ToppingImage(group: group)
            .frame(
                width: ParfaitLayout.toppingImageSize * scale,
                height: ParfaitLayout.toppingImageSize * scale
            )
            .rotationEffect(.degrees(variant.rotation))
            .offset(y: Self.imageTopInFrame * scale)
    }

    /// 회전 전 Img 위 끝의 y — 중심을 프레임 중앙에서 `toppingImageCenterLift` 만큼 올린 자리.
    private static var imageTopInFrame: CGFloat {
        ParfaitLayout.toppingSize / 2
            - ParfaitLayout.toppingImageCenterLift
            - ParfaitLayout.toppingImageSize / 2
    }

    /// 칩은 회전하지 않고 Img 아래 끝에 붙는다. 글자는 확대하지 않으므로 위치만 scale 을 곱한다.
    private var chip: some View {
        YGGrouptagChip(
            name: group.name,
            timestamp: RelativeTimeText.string(from: group.lastActivityAt),
            type: group.lastActorNametagType.chipType
        )
        .fixedSize()
        .offset(y: variant.chipTopInFrame * scale)
    }
}

private extension GroupDomain.NametagType {
    /// Domain 의 타입 번호를 UI 컴포넌트의 타입으로 옮긴다. 같은 1~12 번호 체계다.
    var chipType: YGNametagChip.NametagType {
        YGNametagChip.NametagType(rawValue: rawValue) ?? .type1
    }
}

/// 토핑 이미지 자리. 대표 이미지 → 없으면 템플릿 그래픽 → 불러오기 실패면 물음표 그래픽.
private struct ToppingImage: View {
    let group: YGGroup

    var body: some View {
        if let thumbnailURL = group.thumbnailURL {
            // ponytail: Core 에 이미지 캐싱이 생기면 교체 — 지금은 매번 다시 받는다.
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    // 조회 실패 — 칩은 그대로 두고 이미지 자리만 물음표 그래픽으로.
                    fitted(.templateError)
                case .empty:
                    Color.clear
                @unknown default:
                    Color.clear
                }
            }
            .clipShape(.rect)
        } else {
            // 첫 토핑이 올라오기 전까지 보여줄 템플릿 — 그룹마다 한 번 정해지면 바뀌지 않는다.
            fitted(Self.templates[StableAssignment.index(for: group.id, count: Self.templates.count)])
        }
    }

    private static let templates: [Image] = [
        .template01, .template02, .template03, .template04, .template05, .template06
    ]

    private func fitted(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
    }
}
