// Encodes numbered PNG frames as an App Store preview: H.264 video plus a
// silent stereo AAC track (Connect expects an audio track).
//
//   swiftc -O encode.swift -o encode
//   ./encode <frames dir> <fps> <width> <height> <output.mp4>
//
// Frames are frame-00000.png, frame-00001.png, ... at exactly width x height.

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

let args = CommandLine.arguments
guard args.count == 6, let fps = Int32(args[2]), let width = Int(args[3]), let height = Int(args[4]) else {
    FileHandle.standardError.write(Data("usage: encode <frames dir> <fps> <width> <height> <output.mp4>\n".utf8))
    exit(1)
}
let dir = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[5])
try? FileManager.default.removeItem(at: out)

let frames = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".png") }.sorted()
guard !frames.isEmpty else { FileHandle.standardError.write(Data("no frames\n".utf8)); exit(1) }

let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)

let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 10_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: Int(fps),
        AVVideoExpectedSourceFrameRateKey: Int(fps),
    ],
])
video.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
])
writer.add(video)

// Silent stereo audio, fed as 16-bit PCM and encoded to AAC by the writer.
let sampleRate = 44_100.0
var pcm = AudioStreamBasicDescription(
    mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
    mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
    mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
var pcmFormat: CMAudioFormatDescription?
CMAudioFormatDescriptionCreate(allocator: nil, asbd: &pcm, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &pcmFormat)
let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: sampleRate,
    AVNumberOfChannelsKey: 2,
    AVEncoderBitRateKey: 256_000,
], sourceFormatHint: pcmFormat)
audio.expectsMediaDataInRealTime = false
writer.add(audio)

guard writer.startWriting() else { FileHandle.standardError.write(Data("cannot start: \(String(describing: writer.error))\n".utf8)); exit(1) }
writer.startSession(atSourceTime: .zero)

func pixelBuffer(for url: URL) -> CVPixelBuffer? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(src, 0, nil),
          let pool = adaptor.pixelBufferPool else { return nil }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    guard let buffer else { return nil }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    else { return nil }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return buffer
}

func silence(frames: Int, at pts: CMTime) -> CMSampleBuffer? {
    let bytes = frames * 4
    var block: CMBlockBuffer?
    CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bytes, blockAllocator: nil, customBlockSource: nil,
                                       offsetToData: 0, dataLength: bytes, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block)
    guard let block, let pcmFormat else { return nil }
    CMBlockBufferFillDataBytes(with: 0, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes)
    var buffer: CMSampleBuffer?
    CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block, formatDescription: pcmFormat, sampleCount: frames,
                                                         presentationTimeStamp: pts, packetDescriptions: nil, sampleBufferOut: &buffer)
    return buffer
}

let group = DispatchGroup()
var index = 0
group.enter()
video.requestMediaDataWhenReady(on: DispatchQueue(label: "video")) {
    while video.isReadyForMoreMediaData {
        if index >= frames.count { video.markAsFinished(); group.leave(); return }
        if let buffer = pixelBuffer(for: dir.appendingPathComponent(frames[index])) {
            adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: fps))
        }
        index += 1
    }
}

let totalAudio = Int(Double(frames.count) / Double(fps) * sampleRate)
var audioDone = 0
group.enter()
audio.requestMediaDataWhenReady(on: DispatchQueue(label: "audio")) {
    while audio.isReadyForMoreMediaData {
        if audioDone >= totalAudio { audio.markAsFinished(); group.leave(); return }
        let chunk = min(4096, totalAudio - audioDone)
        if let buffer = silence(frames: chunk, at: CMTime(value: Int64(audioDone), timescale: Int32(sampleRate))) { audio.append(buffer) }
        audioDone += chunk
    }
}

group.wait()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status == .completed {
    print("encoded \(frames.count) frames, \(String(format: "%.1f", Double(frames.count) / Double(fps))) s, \(width)x\(height) -> \(out.path)")
} else {
    FileHandle.standardError.write(Data("failed: \(String(describing: writer.error))\n".utf8))
    exit(1)
}
