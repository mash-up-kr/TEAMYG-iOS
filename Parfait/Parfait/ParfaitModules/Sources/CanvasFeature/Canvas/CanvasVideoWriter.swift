//
//  CanvasVideoWriter.swift
//  CanvasFeature
//
//  Created by 김남수 on 9/23/26.
//

import AVFoundation
import CoreGraphics
import CoreVideo

/// 프레임 이미지를 차례로 받아 임시 폴더에 H.264 mp4 로 쓴다 — C-001-Save-Preview 의 `영상으로 저장`.
@MainActor
final class CanvasVideoWriter {
    private let writer: AVAssetWriter
    private let receiver: AVAssetWriterInput.PixelBufferReceiver
    private let framesPerSecond: Int32
    private let outputURL: URL

    init?(pixelSize: CGSize, framesPerSecond: Int32) {
        let outputURL = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString).mp4")
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else { return nil }

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(pixelSize.width),
                AVVideoHeightKey: Int(pixelSize.height)
            ]
        )
        // 받는 쪽을 만들면 입력도 함께 붙는다 — 따로 `add(_:)` 하지 않는다.
        let receiver = writer.inputPixelBufferReceiver(
            for: input,
            pixelBufferAttributes: CVPixelBufferCreationAttributes(
                pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
                size: CVImageSize(pixelSize)
            )
        )

        do {
            try writer.start()
        } catch {
            return nil
        }
        writer.startSession(atSourceTime: .zero)

        self.writer = writer
        self.receiver = receiver
        self.framesPerSecond = framesPerSecond
        self.outputURL = outputURL
    }

    /// 인코더가 바쁘면 `append` 가 알아서 기다린다.
    func append(_ frame: CGImage, at frameIndex: Int) async -> Bool {
        guard let pixelBufferPool = receiver.pixelBufferPool else { return false }

        do {
            let pixelBuffer = try Self.pixelBuffer(drawing: frame, from: pixelBufferPool)
            try await receiver.append(
                pixelBuffer,
                with: CMTime(value: CMTimeValue(frameIndex), timescale: framesPerSecond)
            )
            return true
        } catch {
            return false
        }
    }

    /// 다 쓴 영상 파일 주소. 실패하면 파일을 지우고 `nil`.
    func finish() async -> URL? {
        receiver.finish()
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: outputURL)
            return nil
        }
        return outputURL
    }

    func cancel() {
        writer.cancelWriting()
        try? FileManager.default.removeItem(at: outputURL)
    }

    private static func pixelBuffer(
        drawing frame: CGImage,
        from pool: CVMutablePixelBuffer.Pool
    ) throws -> CVReadOnlyPixelBuffer {
        var pixelBuffer = try pool.makeMutablePixelBuffer()
        // BGRA 는 평면이 하나다.
        pixelBuffer.accessUnsafeMutableRawPlaneBytes { planes in
            guard let plane = planes.first else { return }
            let context = CGContext(
                data: plane.bytes.baseAddress,
                width: plane.properties.size.width,
                height: plane.properties.size.height,
                bitsPerComponent: 8,
                bytesPerRow: plane.properties.bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            )
            context?.draw(
                frame,
                in: CGRect(x: 0, y: 0, width: plane.properties.size.width, height: plane.properties.size.height)
            )
        }
        return CVReadOnlyPixelBuffer(pixelBuffer)
    }
}
