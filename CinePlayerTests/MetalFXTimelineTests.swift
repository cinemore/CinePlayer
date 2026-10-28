import CinePlayerSDK
import CoreVideo
import Foundation
import Testing
@testable import CinePlayer

#if os(macOS)
@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct MetalFXTimelineTests {
    @Test(.enabled(if: MetalFXFrameInterpolationAdapter.isSupported()))
    func realMidpointsStayAlignedThroughFallbackAndDrain() throws {
        let inputs = try (0...7).map { try pattern(shift: $0 * 2) }
        let adapter = MetalFXFrameInterpolationAdapter()
        defer { adapter.endSession() }
        var segments: [VideoFrameResult] = []
        for pair in 0..<7 {
            let result = adapter.processTemporal(previous: snapshot(inputs[pair], index: pair),
                                                  current: context(inputs[pair + 1], index: pair + 1))
            segments.append(result)
            if pair < 3 {
                guard case .passthrough = result else { Issue.record("预热阶段不能发布中间帧"); return }
            } else {
                guard case let .replaceMany(frames) = result else { Issue.record("真实 GPU 必须生成中间帧"); return }
                #expect(frames.count == 2)
                #expect(frames[0].pixelBuffer === inputs[pair])
                #expect(frames.map(\.timestamp) == [Int64(pair * 100), Int64(pair * 100 + 50)])
                #expect(frames.map(\.duration) == [50, 50])
                let measured = try measure(frames[1].pixelBuffer)
                #expect(measured.shift == pair * 2 + 1)
                #expect(measured.mae < 6)
            }
        }

        // 复用真实 GPU 输出，只控制成功／回退的选择，检查内容时刻与连续时间线。
        for scenario in 0..<4 {
            let buffer = TemporalReorderBuffer(reorderDepth: 0)
            var output: [GeneratedVideoFrame] = []
            for index in 3...7 {
                let useGenerated = index > 3 && (scenario == 0 || (scenario == 2 && index.isMultiple(of: 2))
                    || (scenario == 3 && !index.isMultiple(of: 2)))
                let selected: VideoFrameResult = useGenerated ? segments[index - 1] : .passthrough
                let result = buffer.acceptWithDeadline(context(inputs[index], index: index),
                                                       fallbackBudgetFraction: 6, fallbackMaximumWait: 0.250) { _, _ in selected }
                if case let .replaceMany(frames) = result { output += frames }
            }
            output += buffer.drainPendingFrames()
            var expected: Int64 = 300
            for frame in output {
                #expect(frame.timestamp == expected)
                let measured = try measure(frame.pixelBuffer)
                #expect(measured.mae < 6)
                #expect(Int64(measured.shift * 50) == frame.timestamp)
                expected += frame.duration
            }
            #expect(expected == 800)
            #expect(output.filter { $0.pixelBuffer === inputs[7] }.count == 1)
        }
    }

    @Test(.enabled(if: MetalFXFrameInterpolationAdapter.isSupported()))
    func oddDurationsAndNewGenerationsPreserveOriginalAnchor() throws {
        let adapter = MetalFXFrameInterpolationAdapter()
        defer { adapter.endSession() }
        for generation: Int64 in [1, 2] {
            let inputs = try (0...4).map { try pattern(shift: $0 * 2) }
            for pair in 0..<4 {
                let result = adapter.processTemporal(
                    previous: .init(pixelBuffer: inputs[pair], timestamp: Int64(pair * 101), duration: 101,
                                    timebaseNum: 1, timebaseDen: 2400, fps: 24, generation: generation),
                    current: .init(pixelBuffer: inputs[pair + 1], timestamp: Int64((pair + 1) * 101), duration: 101,
                                   timebaseNum: 1, timebaseDen: 2400, fps: 24, generation: generation))
                if pair < 3 {
                    guard case .passthrough = result else { Issue.record("新代必须重新建立历史"); return }
                } else {
                    guard case let .replaceMany(frames) = result else { Issue.record("缺少真实中点图"); return }
                    #expect(frames[0].pixelBuffer === inputs[3])
                    #expect(frames.map(\.timestamp) == [303, 353])
                    #expect(frames.map(\.duration) == [50, 51])
                    let measured = try measure(frames[1].pixelBuffer)
                    #expect(measured.mae < 6)
                    #expect(measured.shift == 7)
                    #expect(abs(Double(frames[1].timestamp) - Double(measured.shift) * 101 / 2) <= 0.5)
                }
            }
        }
    }

    private func context(_ buffer: CVPixelBuffer, index: Int) -> VideoFrameContext {
        .init(pixelBuffer: buffer, timestamp: Int64(index * 100), duration: 100,
              timebaseNum: 1, timebaseDen: 2400, fps: 24, generation: 1)
    }

    private func snapshot(_ buffer: CVPixelBuffer, index: Int) -> PreviousVideoFrameSnapshot {
        .init(pixelBuffer: buffer, timestamp: Int64(index * 100), duration: 100,
              timebaseNum: 1, timebaseDen: 2400, fps: 24, generation: 1)
    }

    private func pattern(shift: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        #expect(CVPixelBufferCreate(nil, 320, 180, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:], kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary,
            &buffer) == kCVReturnSuccess)
        let image = try #require(buffer)
        CVPixelBufferLockBaseAddress(image, [])
        defer { CVPixelBufferUnlockBaseAddress(image, []) }
        let base = try #require(CVPixelBufferGetBaseAddress(image))
        for y in 0..<180 {
            let pixels = (base + y * CVPixelBufferGetBytesPerRow(image)).assumingMemoryBound(to: UInt8.self)
            for x in 0..<320 {
                let value: UInt8 = ((x - shift + 320) % 320 / 16 + y / 16) % 2 == 0 ? 32 : 224
                for channel in 0..<3 { pixels[x * 4 + channel] = value }
                pixels[x * 4 + 3] = 255
            }
        }
        return image
    }

    private func measure(_ image: CVPixelBuffer) throws -> (shift: Int, mae: Double) {
        CVPixelBufferLockBaseAddress(image, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
        let base = try #require(CVPixelBufferGetBaseAddress(image))
        var best = (shift: -1, mae: Double.infinity)
        for shift in 0...20 {
            var error = 0.0
            for y in 32..<148 {
                let pixels = (base + y * CVPixelBufferGetBytesPerRow(image)).assumingMemoryBound(to: UInt8.self)
                for x in 32..<288 {
                    let expected = ((x - shift + 320) % 320 / 16 + y / 16) % 2 == 0 ? 32 : 224
                    error += abs(Double(pixels[x * 4]) - Double(expected))
                }
            }
            let mae = error / Double(116 * 256)
            if mae < best.mae { best = (shift, mae) }
        }
        return best
    }
}
#endif
