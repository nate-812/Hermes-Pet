import SwiftUI
import AVKit
import CoreImage

struct VideoPetEngine: NSViewRepresentable {
    var state: AgentActivityState
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        let layerA = AVPlayerLayer()
        layerA.videoGravity = videoGravity
        layerA.isOpaque = false
        layerA.backgroundColor = NSColor.clear.cgColor
        layerA.isHidden = false
        
        let layerB = AVPlayerLayer()
        layerB.videoGravity = videoGravity
        layerB.backgroundColor = NSColor.clear.cgColor
        layerB.isOpaque = false
        layerB.isHidden = true
        
        view.layer?.addSublayer(layerA)
        view.layer?.addSublayer(layerB)
        
        let playerA = AVPlayer()
        playerA.isMuted = true
        layerA.player = playerA
        
        let playerB = AVPlayer()
        playerB.isMuted = true
        layerB.player = playerB
        
        context.coordinator.setup(playerA: playerA, layerA: layerA, playerB: playerB, layerB: layerB)
        context.coordinator.updateState(state)
        
        view.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: .main) { _ in
            layerA.frame = view.bounds
            layerB.frame = view.bounds
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.updateState(state)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    enum PetAnimationPhase {
        case idle
        case working
        case finishing
    }
    
    class PetVideoItem: AVPlayerItem {
        var videoName: String = ""
    }
    
    @MainActor
    class Coordinator: NSObject {
        var playerA: AVPlayer?
        var playerB: AVPlayer?
        var layerA: AVPlayerLayer?
        var layerB: AVPlayerLayer?
        
        var isPlayerAActive = true
        
        var targetActivityState: AgentActivityState = .idle
        var currentPhase: PetAnimationPhase = .idle
        
        var idleCount = 0
        var workCount = 0
        
        var currentlyPlayingVideoName: String = ""
        var currentPreloadedVideoName: String = ""
        var currentLoopCount: Int = 0
        
        nonisolated(unsafe) var observer: (any NSObjectProtocol)?
        
        private var isFirstLoad = true
        
        func setup(playerA: AVPlayer, layerA: AVPlayerLayer, playerB: AVPlayer, layerB: AVPlayerLayer) {
            self.playerA = playerA
            self.layerA = layerA
            self.playerB = playerB
            self.layerB = layerB
        }
        
        deinit {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        @MainActor
        func updateState(_ state: AgentActivityState) {
            targetActivityState = state
            
            if isFirstLoad {
                isFirstLoad = false
                currentPhase = (state == .idle) ? .idle : .working
                idleCount = 0
                workCount = 0
                
                let initialName = (state == .idle) ? "待机" : "戴帽子进入工作状态"
                currentlyPlayingVideoName = initialName
                let nextName = determineNextVideo(after: initialName)
                currentPreloadedVideoName = nextName
                
                preloadVideo(named: initialName, into: playerA)
                playerA?.play()
                layerA?.isHidden = false
                layerB?.isHidden = true
                
                preloadVideo(named: nextName, into: playerB)
                
                observer = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let finishedItem = notification.object as? AVPlayerItem else { return }
                    let itemID = ObjectIdentifier(finishedItem)
                    
                    MainActor.assumeIsolated {
                        guard let self = self else { return }
                        let aID = self.playerA?.currentItem.map { ObjectIdentifier($0) }
                        let bID = self.playerB?.currentItem.map { ObjectIdentifier($0) }
                        
                        if itemID == aID || itemID == bID {
                            self.onVideoFinished()
                        }
                    }
                }
            } else {
                // 打断逻辑：如果在睡觉期间进入工作状态，直接打断
                if state != .idle && (currentlyPlayingVideoName == "纯睡" || currentlyPlayingVideoName == "趴下动作") {
                    let interruptName = determineNextVideo(after: currentlyPlayingVideoName)
                    currentPreloadedVideoName = interruptName
                    
                    let inactivePlayer = isPlayerAActive ? playerB : playerA
                    preloadVideo(named: interruptName, into: inactivePlayer)
                    
                    onVideoFinished()
                    return
                }
                
                let newNextName = determineNextVideo(after: currentlyPlayingVideoName)
                if newNextName != currentPreloadedVideoName {
                    currentPreloadedVideoName = newNextName
                    let inactivePlayer = isPlayerAActive ? playerB : playerA
                    preloadVideo(named: newNextName, into: inactivePlayer)
                }
            }
        }
        
        private func onVideoFinished() {
            swapPlayers()
            currentlyPlayingVideoName = currentPreloadedVideoName
            
            let nextName = determineNextVideo(after: currentPreloadedVideoName)
            currentPreloadedVideoName = nextName
            let inactivePlayer = isPlayerAActive ? playerB : playerA
            preloadVideo(named: nextName, into: inactivePlayer)
        }
        
        private func swapPlayers() {
            guard let playerA = playerA, let playerB = playerB,
                  let layerA = layerA, let layerB = layerB else { return }
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            if isPlayerAActive {
                layerB.isHidden = false
                layerA.isHidden = true
                playerB.play()
                playerA.pause()
                isPlayerAActive = false
            } else {
                layerA.isHidden = false
                layerB.isHidden = true
                playerA.play()
                playerB.pause()
                isPlayerAActive = true
            }
            CATransaction.commit()
        }
        
        private func determineNextVideo(after currentVideoName: String) -> String {
            let isTargetIdle = (targetActivityState == .idle)
            
            if currentVideoName.isEmpty {
                return isTargetIdle ? "待机" : "戴帽子进入工作状态"
            }
            
            switch currentPhase {
            case .idle:
                if !isTargetIdle {
                    currentPhase = .working
                    workCount = 0
                    return "戴帽子进入工作状态"
                } else {
                    if currentVideoName == "待机" {
                        idleCount += 1
                        if idleCount >= 2 {
                            idleCount = 0
                            return "趴下动作"
                        } else {
                            return "待机"
                        }
                    } else if currentVideoName == "趴下动作" || currentVideoName == "纯睡" {
                        return "纯睡"
                    } else {
                        return "待机"
                    }
                }
                
            case .working:
                if isTargetIdle {
                    currentPhase = .finishing
                    return "关电脑"
                } else {
                    if currentVideoName == "戴帽子进入工作状态" || currentVideoName == "疯狂状态" {
                        return "正常工作"
                    } else if currentVideoName == "正常工作" {
                        workCount += 1
                        if workCount >= 2 {
                            workCount = 0
                            return "疯狂状态"
                        } else {
                            return "正常工作"
                        }
                    } else {
                        return "正常工作"
                    }
                }
                
            case .finishing:
                currentPhase = .idle
                idleCount = 0
                if !isTargetIdle {
                    currentPhase = .working
                    workCount = 0
                    return "戴帽子进入工作状态"
                }
                return "待机"
            }
        }
        
        private func preloadVideo(named name: String, into player: AVPlayer?) {
            guard let player = player else { return }
            
            guard let url = Bundle.main.url(forResource: name, withExtension: "mov", subdirectory: "pet_clips") ??
                            Bundle.main.url(forResource: name, withExtension: "mov") else {
                print("❌ Failed to find \\(name).mov in resources")
                return
            }
            
            let asset = AVAsset(url: url)
            let filter = ChromaKeyFilter()
            let composition = AVMutableVideoComposition(asset: asset) { request in
                let source = request.sourceImage
                filter.inputImage = source
                if let output = filter.outputImage {
                    request.finish(with: output, context: nil)
                } else {
                    request.finish(with: source, context: nil)
                }
            }
            
            let item = AVPlayerItem(asset: asset)
            item.videoComposition = composition
            
            player.replaceCurrentItem(with: item)
        }
    }
}

// Custom Chroma Key Filter
class ChromaKeyFilter: CIFilter {
    var inputImage: CIImage?
    
    static let kernel: CIColorKernel = {
        // Robust green screen removal logic
        let kernelString = """
        kernel vec4 chromaKey(__sample s) {
            float greenness = s.g - max(s.r, s.b);
            float alpha = 1.0 - smoothstep(0.05, 0.15, greenness);
            
            vec3 resultColor = s.rgb;
            if (greenness > 0.0) {
                // Spill suppression
                resultColor.g = min(s.g, max(s.r, s.b) + 0.1);
            }
            
            return vec4(resultColor * alpha, s.a * alpha);
        }
        """
        return CIColorKernel(source: kernelString)!
    }()
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        return ChromaKeyFilter.kernel.apply(extent: inputImage.extent, arguments: [inputImage])
    }
}
