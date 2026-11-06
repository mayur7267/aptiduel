// Pulls evenly spaced frames out of a screen recording as PNGs.
//
//   swiftc -O frames.swift -o frames
//   ./frames <recording.mov> <start seconds> <end seconds> <fps> <max width> <output dir>
//
// Frames are named frame-00000.png, frame-00001.png, and so on.

import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 7, let start = Double(args[2]), let end = Double(args[3]), let fps = Double(args[4]), let maxWidth = Double(args[5]) else {
    FileHandle.standardError.write(Data("usage: frames <recording.mov> <start> <end> <fps> <max width> <output dir>\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: args[6])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = CMTime(seconds: 1.0 / 90, preferredTimescale: 600)
generator.requestedTimeToleranceAfter = CMTime(seconds: 1.0 / 90, preferredTimescale: 600)
generator.maximumSize = CGSize(width: maxWidth, height: maxWidth * 4)

let count = Int(((end - start) * fps).rounded(.down))
var written = 0
for i in 0..<count {
    let time = CMTime(seconds: start + Double(i) / fps, preferredTimescale: 600)
    guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }
    let url = outDir.appendingPathComponent(String(format: "frame-%05d.png", i))
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(dest, image, nil)
    if CGImageDestinationFinalize(dest) { written += 1 }
}
print("frames: \(written) of \(count)")
