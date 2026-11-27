//
//  EmptyCanvasIntroView.swift
//  CanvasFeature
//
//  Created by 박서연 on 11/23/26.
//

import SwiftUI
import UIComponent

struct EmptyCanvasIntroView: View {
    private static let messageCenterYRatio: CGFloat = 0.478
    private static var dissolveAnimation: Animation {
        .timingCurve(0, 0, 0.58, 1, duration: 0.3)
    }

    let phase: EmptyCanvasIntroPhase
    let message: EmptyCanvasMessage
    let onPlaybackFinished: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let messageCenter = CGPoint(
                x: proxy.size.width / 2,
                y: proxy.size.height * Self.messageCenterYRatio
            )

            ZStack {
                EmptyCanvasMessageText(message: message.plain)
                    .foregroundStyle(.gray500)
                    .position(messageCenter)

                if phase != .hidden {
                    EmptyCanvasIntroPlayback(
                        isPlaying: phase == .playing,
                        canvasSize: proxy.size,
                        messageCenter: messageCenter,
                        message: message,
                        onPlaybackFinished: onPlaybackFinished
                    )
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
                }
            }
            .animation(phase == .hidden ? Self.dissolveAnimation : nil, value: phase)
        }
    }
}

private struct EmptyCanvasIntroPlayback: View {
    private static let revealOffsetY: CGFloat = -60

    let isPlaying: Bool
    let canvasSize: CGSize
    let messageCenter: CGPoint
    let message: EmptyCanvasMessage
    let onPlaybackFinished: () -> Void

    @State private var startDate = Date.now
    private let dummyImages = EmptyCanvasDummyImage.all

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let elapsed = isPlaying
                ? context.date.timeIntervalSince(startDate)
                : EmptyCanvasIntroTimeline.duration

            ZStack {
                ForEach(dummyImages) { dummyImage in
                    dummyImageView(dummyImage, elapsed: elapsed)
                }

                EmptyCanvasMessageText(message: message.highlighted(elapsed: elapsed))
                    .position(messageCenter)
            }
        }
        .task(id: isPlaying) {
            guard isPlaying else { return }
            guard (try? await Task.sleep(for: .seconds(EmptyCanvasIntroTimeline.duration))) != nil else { return }
            onPlaybackFinished()
        }
    }

    private func dummyImageView(_ dummyImage: EmptyCanvasDummyImage, elapsed: TimeInterval) -> some View {
        let progress = EmptyCanvasIntroTimeline.imageProgress(order: dummyImage.id, elapsed: elapsed)

        return dummyImage.image
            .resizable()
            .scaledToFit()
            .frame(width: canvasSize.width * dummyImage.widthRatio)
            .rotationEffect(dummyImage.rotation)
            .opacity(progress)
            .offset(y: Self.revealOffsetY * (1 - CGFloat(progress)))
            .position(
                x: canvasSize.width * dummyImage.center.x,
                y: canvasSize.height * dummyImage.center.y
            )
    }
}

private struct EmptyCanvasMessageText: View {
    let message: AttributedString

    var body: some View {
        Text(message)
            .suit(.caption01Medium)
            .multilineTextAlignment(.center)
    }
}

private struct EmptyCanvasDummyImage: Identifiable {
    let id: Int
    let image: Image
    let widthRatio: CGFloat
    let center: UnitPoint
    let rotation: Angle

    static var all: [EmptyCanvasDummyImage] {
        [
            EmptyCanvasDummyImage(
                id: 0,
                image: .imageGroupList2,
                widthRatio: 0.223,
                center: UnitPoint(x: 0.326, y: 0.371),
                rotation: .degrees(-22)
            ),
            EmptyCanvasDummyImage(
                id: 1,
                image: .imageEmptyCanvas2,
                widthRatio: 0.545,
                center: UnitPoint(x: 0.785, y: 0.602),
                rotation: .zero
            ),
            EmptyCanvasDummyImage(
                id: 2,
                image: .imageEmptyCanvas1,
                widthRatio: 0.747,
                center: UnitPoint(x: 0.315, y: 0.691),
                rotation: .zero
            )
        ]
    }
}

/// 빈 캔버스 안내 문구. 가운데 구절만 글자 단위로 강조 애니메이션이 걸린다.
struct EmptyCanvasMessage {
    static let group = EmptyCanvasMessage(
        leadingText: "아직 캔버스가 비어 있어요\n친구들과 ",
        highlightedText: "함께 남기고 싶은 순간"
    )
    /// 내 공간(혼자 공간) 전용.
    static let solo = EmptyCanvasMessage(
        leadingText: "아직 캔버스가 비어 있어요\n마음속에 ",
        highlightedText: "간직하고 싶은 순간"
    )

    private let leadingText: String
    private let highlightedText: String
    private let trailingText = "을 캔버스에 쌓아 주세요"

    var plain: AttributedString {
        AttributedString(leadingText + highlightedText + trailingText)
    }

    func highlighted(elapsed: TimeInterval) -> AttributedString {
        var message = transparent(leadingText)
        var letterIndex = 0

        for character in highlightedText {
            guard character != " " else {
                message.append(transparent(" "))
                continue
            }
            let opacity = EmptyCanvasIntroTimeline.letterOpacity(index: letterIndex, elapsed: elapsed)
            var letter = AttributedString(String(character))
            letter.swiftUI.foregroundColor = Color.blackFixed.opacity(opacity)
            message.append(letter)
            letterIndex += 1
        }

        message.append(transparent(trailingText))
        return message
    }

    private func transparent(_ text: String) -> AttributedString {
        var run = AttributedString(text)
        run.swiftUI.foregroundColor = Color.clear
        return run
    }
}

private enum EmptyCanvasIntroTimeline {
    static let duration: TimeInterval = 2.5

    private static let imageStartDelay: TimeInterval = 0.5
    private static let imageStagger: TimeInterval = 0.5
    private static let imageDuration: TimeInterval = 1
    private static let letterStartDelay: TimeInterval = 0.5
    private static let letterStagger: TimeInterval = 0.15
    private static let letterFadeInDuration: TimeInterval = 0.15
    private static let letterFadeOutDuration: TimeInterval = 0.3

    private static var imageCurve: UnitCurve {
        .bezier(startControlPoint: UnitPoint(x: 0, y: 0), endControlPoint: UnitPoint(x: 0, y: 1))
    }

    private static var letterFadeInCurve: UnitCurve {
        .bezier(startControlPoint: UnitPoint(x: 0, y: 0), endControlPoint: UnitPoint(x: 0.58, y: 1))
    }

    private static var letterFadeOutCurve: UnitCurve {
        .bezier(startControlPoint: UnitPoint(x: 0.42, y: 0), endControlPoint: UnitPoint(x: 0.58, y: 1))
    }

    static func imageProgress(order: Int, elapsed: TimeInterval) -> Double {
        let startTime = imageStartDelay + Double(order) * imageStagger
        let progress = min(max((elapsed - startTime) / imageDuration, 0), 1)
        return imageCurve.value(at: progress)
    }

    static func letterOpacity(index: Int, elapsed: TimeInterval) -> Double {
        let letterElapsed = elapsed - (letterStartDelay + Double(index) * letterStagger)
        guard letterElapsed > 0 else { return 0 }
        guard letterElapsed >= letterFadeInDuration else {
            return letterFadeInCurve.value(at: letterElapsed / letterFadeInDuration)
        }
        let fadeOutProgress = (letterElapsed - letterFadeInDuration) / letterFadeOutDuration
        guard fadeOutProgress < 1 else { return 0 }
        return 1 - letterFadeOutCurve.value(at: fadeOutProgress)
    }
}
