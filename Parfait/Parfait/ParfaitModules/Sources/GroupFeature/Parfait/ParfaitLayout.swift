//
//  ParfaitLayout.swift
//  GroupFeature
//
//  Created by 신상우 on 8/1/26.
//

import CoreGraphics

/// 그룹 목록(G-001) 파르페 씬의 좌표 계산.
///
/// 디자인 프레임(375pt 폭) 좌표를 그대로 쓰되, y 원점만 상단 바 바로 아래(프레임 y=108)로 옮긴
/// "콘텐츠 좌표계"에서 계산한다. 실제 렌더링은 화면 폭에 맞춘 `scale` 을 곱해 확대한다.
///
/// 규칙 원본은 디자인 스펙(G-001 배치 정책)이고, 여기서는 그 수치를 그대로 옮긴다.
struct ParfaitLayout {
    /// 정렬이 끝난 그룹 수. 토핑 개수이자 크림 장수의 기준.
    let groupCount: Int

    // MARK: 디자인 상수 (375pt 프레임 기준, y 는 상단 바 아래부터)

    /// 좌표가 정의된 디자인 프레임 폭.
    static let designWidth: CGFloat = 375

    static let toppingSize: CGFloat = 160
    static let toppingImageSize: CGFloat = 96

    /// 토핑 x — 템플릿 좌/우 끝에서 각각 4 들어온 자리.
    static let leftColumnX: CGFloat = 29
    static let rightColumnX: CGFloat = 185
    /// 같은 side 세로 갭 -12 → 프레임 160 기준 한 칸 148.
    static let columnStep: CGFloat = 148
    static let leftColumnFirstY: CGFloat = 160
    /// Right 열은 인접한 두 Left 사이 높이.
    static let rightColumnFirstY: CGFloat = 246
    /// N ≤ 2 는 여백을 고려해 모든 토핑을 아래로 내린다.
    static let lowCountDrop: CGFloat = 12
    static let lowCountThreshold = 2

    static let cherrySize = CGSize(width: 82.8, height: 160.5)
    static let cherryOrigin = CGPoint(x: 146.9, y: 64)

    static let creamTopSize = CGSize(width: 209.9, height: 114.5)
    static let creamTopOrigin = CGPoint(x: 79, y: 185)

    static let creamBodySize = CGSize(width: 240.8, height: 131.4)
    static let creamBodyX: CGFloat = 71
    static let creamBodyFirstY: CGFloat = 255
    /// 크림 한 장이 아래로 자라는 양(장끼리 겹침).
    static let creamBodyStep: CGFloat = 66
    /// 여기까지는 파르페가 자라지 않는다 — 크림은 최소 장수 고정.
    static let parfaitGrowthThreshold = 3
    static let minimumCreamBodyCount = 2

    static let cupSize = CGSize(width: 324.3, height: 239.2)
    static let cupX: CGFloat = 25
    /// 접시는 맨 아래 크림에서 이만큼 내려온 자리에 놓인다.
    static let cupGapFromLastCreamBody: CGFloat = 99
    /// 마지막 토핑이 접시에 겹쳐도 되는 최대치.
    static let lastToppingCupOverlap: CGFloat = 48

    /// 접시 아래 스크롤 여유.
    static let bottomPadding: CGFloat = 16

    // MARK: 계산

    /// 토핑 프레임(160×160)들. index 짝수 Left / 홀수 Right 로 지그재그.
    var toppingFrames: [CGRect] {
        (0..<groupCount).map(toppingFrame(at:))
    }

    func toppingFrame(at index: Int) -> CGRect {
        let isRight = !index.isMultiple(of: 2)
        let row = index / 2
        let columnFirstY = isRight ? Self.rightColumnFirstY : Self.leftColumnFirstY
        let drop = groupCount <= Self.lowCountThreshold ? Self.lowCountDrop : 0
        return CGRect(
            x: isRight ? Self.rightColumnX : Self.leftColumnX,
            y: columnFirstY + Self.columnStep * CGFloat(row) + drop,
            width: Self.toppingSize,
            height: Self.toppingSize
        )
    }

    /// 크림(몸통) 장수.
    ///
    /// 기본은 "N ≤ 3 이면 최소 2장, 4부터 그룹당 한 장" — 디자인 프레임(N=3·4·5) 실측과 같다.
    ///
    /// 다만 크림 한 장(66)이 토핑 한 칸(74)보다 짧아서, 그룹이 많아지면 접시가 마지막 토핑
    /// 위로 올라온다. 그때는 마지막 토핑이 접시에 `lastToppingCupOverlap` 을 넘겨 걸치지 않도록
    /// 크림을 더 쌓아 접시를 밀어낸다.
    var creamBodyCount: Int {
        let byGroupCount = groupCount <= Self.parfaitGrowthThreshold
            ? Self.minimumCreamBodyCount
            : groupCount
        guard let lastToppingBottom = toppingFrames.last?.maxY else { return byGroupCount }
        let requiredCupY = lastToppingBottom - Self.lastToppingCupOverlap
        let stepsToReachCup = (requiredCupY - Self.cupGapFromLastCreamBody - Self.creamBodyFirstY)
            / Self.creamBodyStep
        return max(byGroupCount, Int(stepsToReachCup.rounded(.up)) + 1)
    }

    var creamBodyFrames: [CGRect] {
        (0..<creamBodyCount).map { index in
            CGRect(
                x: Self.creamBodyX,
                y: Self.creamBodyFirstY + Self.creamBodyStep * CGFloat(index),
                width: Self.creamBodySize.width,
                height: Self.creamBodySize.height
            )
        }
    }

    var cherryFrame: CGRect {
        CGRect(origin: Self.cherryOrigin, size: Self.cherrySize)
    }

    var creamTopFrame: CGRect {
        CGRect(origin: Self.creamTopOrigin, size: Self.creamTopSize)
    }

    var cupFrame: CGRect {
        let lastCreamBodyY = Self.creamBodyFirstY + Self.creamBodyStep * CGFloat(creamBodyCount - 1)
        return CGRect(
            x: Self.cupX,
            y: lastCreamBodyY + Self.cupGapFromLastCreamBody,
            width: Self.cupSize.width,
            height: Self.cupSize.height
        )
    }

    /// 스크롤 콘텐츠 높이 — 접시와 마지막 토핑 중 더 아래를 기준으로 잡는다.
    var contentHeight: CGFloat {
        let lowestEdge = max(cupFrame.maxY, toppingFrames.last?.maxY ?? 0)
        return lowestEdge + Self.bottomPadding
    }
}
