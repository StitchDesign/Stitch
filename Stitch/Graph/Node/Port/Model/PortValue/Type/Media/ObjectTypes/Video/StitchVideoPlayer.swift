import AVKit

@Observable
final class StitchVideoImportPlayer: Sendable {
    static let DEFAULT_VIDEO_PLAYER_VOLUME: Double = 1

    @MainActor var video: AVPlayer
    @MainActor var stitchVideoDelegate: StitchVideoDelegate
    @MainActor var thumbnail: UIImage?
    
    @MainActor var metadata: VideoMetadata {
        didSet(newValue) {
            if metadata != newValue {
                self.stitchVideoDelegate.updateMetadata(for: video, videoData: metadata)
            }
        }
    }

    @MainActor var currentTime: Double {
        video.currentTime().seconds
    }

    @MainActor var duration: Double {
        CMTimeGetSeconds(video.currentItem?.duration ?? .zero)
    }

    let url: URL

    @MainActor
    init(url: URL, videoData: VideoMetadata, initialVolume: Double) {
        self.url = url
        
        let player = AVPlayer(url: url)
        self.stitchVideoDelegate = StitchVideoDelegate(url: url,
                                                       videoData: videoData,
                                                       currentPlayer: player)
        self.video = player
        self.metadata = videoData

        Task { [weak self, weak player] in
            self?.thumbnail = await player?.currentItem?.asset.getThumbnail()
        }

        self.setVolume(volume: initialVolume) // Set initial volume here
    }

    @MainActor
    func resetPlayer() {
        self.stitchVideoDelegate.seek(on: self.video,
                                      to: .zero,
                                      isScrubbing: false)
    }

    @MainActor func enableSound() {
        self.video.isMuted = false
    }

    @MainActor func muteSound() {
        self.video.isMuted = true
    }

    @MainActor
    var volume: Double {
        self.stitchVideoDelegate.audio.delegate.volume
    }
    
    @MainActor
    func setVolume(volume: Double) {
        let volume = min(1, max(0, volume))
        self.video.volume = Float(volume)
    }

    @MainActor
    var peakVolume: Double {
        self.stitchVideoDelegate.audio.delegate.peakVolume
    }

    @MainActor func play() {
        self.stitchVideoDelegate.play(with: self.video)
    }
    
    @MainActor func pause() {
        self.stitchVideoDelegate.pause(with: self.video)
    }
}
