import SwiftUI
import AppKit

struct SpriteEngine: View {
    let imagePath: String
    let columns: Int = 8
    let rows: Int = 9
    let frameWidth: CGFloat = 192
    let frameHeight: CGFloat = 208
    let targetRow: Int // 0-indexed row to play
    let fps: Double = 12.0
    
    // 全局静态缓存，避免每次出现都重新切图导致主线程卡顿
    static var cache: [String: [CGImage]] = [:]
    
    @State private var frames: [CGImage] = []
    
    var body: some View {
        GeometryReader { geo in
            if frames.isEmpty {
                Color.clear
                    .onAppear(perform: loadFramesAsync)
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / fps)) { timeline in
                    let frameIndex = Int(timeline.date.timeIntervalSince1970 * fps) % columns
                    let frameToPlay = targetRow * columns + frameIndex
                    
                    if frameToPlay >= 0 && frameToPlay < frames.count {
                        let cgImage = frames[frameToPlay]
                        Image(decorative: cgImage, scale: 1.0, orientation: .up)
                            .resizable()
                            .interpolation(.none) // 保持像素锐利
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
        }
    }
    
    private func loadFramesAsync() {
        if let cached = Self.cache[imagePath] {
            self.frames = cached
            return
        }
        
        Task.detached(priority: .userInitiated) {
            guard let nsImage = NSImage(contentsOfFile: imagePath),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                print("Failed to load image from \(imagePath)")
                return
            }
            
            var loadedFrames: [CGImage] = []
            
            for r in 0..<rows {
                for c in 0..<columns {
                    let rect = CGRect(
                        x: CGFloat(c) * frameWidth,
                        y: CGFloat(r) * frameHeight,
                        width: frameWidth,
                        height: frameHeight
                    )
                    if let cropped = cgImage.cropping(to: rect) {
                        loadedFrames.append(cropped)
                    }
                }
            }
            
            await MainActor.run {
                Self.cache[imagePath] = loadedFrames
                self.frames = loadedFrames
            }
        }
    }
    
}
