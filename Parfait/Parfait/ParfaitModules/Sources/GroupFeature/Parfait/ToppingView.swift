//
//  ToppingView.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import Common
import GroupDomain
import SwiftUI
import UIComponent

/// 파르페 위에 얹히는 그룹 하나. 그룹의 이미지·칩·탭을 정하고, 프레임 안 배치는 `ToppingFrameView` 에 맡긴다.
struct ToppingView: View {
    let group: ParfaitGroup
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
        ToppingFrameView(variant: variant, scale: scale, chip: chip) {
            ToppingImage(group: group)
        }
        .contentShape(.rect)
        .onTapGesture(perform: action)
    }

    /// 활동 이력이 없는 그룹은 타임스탬프를 넘기지 않는다 — 칩이 이름만 남긴다.
    /// 색을 정하는 Nametag 타입도 없을 수 있는데, 그때 쓰는 기본 계열은 어차피
    /// 타임스탬프에만 칠해지므로 눈에 띄지 않는다.
    private var chip: YGGrouptagChip {
        YGGrouptagChip(
            name: group.name,
            timestamp: group.lastActivityAt.map { RelativeTimeText.string(from: $0) },
            type: group.lastActorNametagType?.chipType ?? .type1
        )
    }
}

/// Img(회전) + Grouptag-Chip 으로 이뤄진 160×160 프레임. 실제 그룹과 0건 안내의 더미 그룹이 함께 쓴다.
///
/// 프레임 안에서만 좌표를 계산하고, 파르페 어디에 놓일지는 `ParfaitLayout` 이 정한다.
/// 렌더링 크기는 화면 폭에 맞춘 `scale` 로 확대하되 칩 글자는 확대하지 않는다.
struct ToppingFrameView<ImageContent: View>: View {
    let variant: ToppingVariant
    let scale: CGFloat
    let chip: YGGrouptagChip
    @ViewBuilder let imageContent: ImageContent

    var body: some View {
        // 프레임 위쪽을 기준점으로 잡아 칩·이미지를 각자의 y 로 내린다(칩은 가로 중앙).
        // Z 순서는 항상 Img > Chip — 칩을 먼저 깔고 이미지를 위에 올린다.
        ZStack(alignment: .top) {
            positionedChip
            image
        }
        .frame(
            width: ParfaitLayout.toppingSize * scale,
            height: ParfaitLayout.toppingSize * scale,
            alignment: .top
        )
    }

    private var image: some View {
        imageContent
            .frame(
                width: ParfaitLayout.toppingImageSize * scale,
                height: ParfaitLayout.toppingImageSize * scale
            )
            // 96 밖으로는 테두리 외곽선 폭만큼만 새어 나가게 잘라 둔다 — 이미지 자체는 96 을 그대로 쓴다.
            // 클립은 프레임이 확정된 여기서 걸어야 한다 — 그룹 이미지의 AsyncImage 안쪽에 걸면
            // AsyncImage 가 이미지 원본 크기를 자기 크기로 잡아 아무것도 안 잘린다.
            .clipShape(Rectangle().inset(by: -ToppingImage.borderWidth))
            .rotationEffect(.degrees(variant.rotation))
            .offset(x: imageOffset.width * scale, y: imageOffset.height * scale)
    }

    /// 회전 전 96×96 프레임을 밀 거리.
    /// ZStack 이 가로는 중앙 정렬이라 x 는 프레임 중앙 기준, y 는 프레임 위 기준으로 잰다.
    private var imageOffset: CGSize {
        let center = variant.imageCenterInFrame
        return CGSize(
            width: center.x - ParfaitLayout.toppingSize / 2,
            height: center.y - ParfaitLayout.toppingImageSize / 2
        )
    }

    /// 칩은 회전하지 않고 Img 아래 끝에 붙는다. 글자는 확대하지 않으므로 위치만 scale 을 곱한다.
    private var positionedChip: some View {
        chip
            .fixedSize()
            .offset(y: variant.chipTopInFrame * scale)
    }
}

/// 토핑 이미지 자리. 대표 이미지 → 없으면 템플릿 그래픽 → 불러오기 실패면 물음표 그래픽.
private struct ToppingImage: View {
    let group: ParfaitGroup

    var body: some View {
        if let thumbnailURL = group.thumbnailURL {
            YGImageView(url: thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    // 누끼는 오브젝트 자체가 내용이라 잘라내면 뭔지 알 수 없게 된다.
                    // 비율이 제각각이므로(펜 같은 3:1 도 있다) 전체를 담는 fit 으로 그린다.
                    if let borderColorHex = group.thumbnailBorderColorHex {
                        outlined(image, color: Color(hex: borderColorHex))
                    } else {
                        fitted(image)
                    }
                case .failure:
                    // 조회 실패 — 칩은 그대로 두고 이미지 자리만 물음표 그래픽으로.
                    fitted(.templateError)
                case .empty:
                    // 다운로드 중 스피너. 컨테이너를 채워 측정 크기를 유지한다 — 44 로 두면
                    // YGImageView 가 스피너 크기(44pt) 기준으로 디코딩 예산을 잡는다.
                    YGLottieView(.loadingDark)
                        .frame(width: 44, height: 44)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            // 첫 토핑이 올라오기 전까지 보여줄 템플릿 — 그룹마다 한 번 정해지면 바뀌지 않는다.
            fitted(Self.templates[StableAssignment.index(for: group.id, count: Self.templates.count)])
        }
    }

    private static let templates: [Image] = [
        .template01, .template02, .template03, .template04, .template05, .template06
    ]

    static let borderWidth: CGFloat = 2
    private static let outlineDirectionCount = 16

    private func fitted(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
    }

    private func outlined(_ image: Image, color: Color) -> some View {
        ZStack {
            ForEach(0..<Self.outlineDirectionCount, id: \.self) { direction in
                let angle = Double(direction) / Double(Self.outlineDirectionCount) * 2 * .pi
                fitted(image.renderingMode(.template))
                    .foregroundStyle(color)
                    .offset(x: cos(angle) * Self.borderWidth, y: sin(angle) * Self.borderWidth)
            }
            fitted(image)
        }
        // drawingGroup 은 프레임 밖을 잘라 그리므로, 버퍼만 외곽선 폭만큼 키우고 레이아웃 크기는 되돌린다.
        .padding(Self.borderWidth)
        .drawingGroup()
        .padding(-Self.borderWidth)
    }
}
