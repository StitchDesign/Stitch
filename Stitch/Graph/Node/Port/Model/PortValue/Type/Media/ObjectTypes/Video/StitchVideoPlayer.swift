import AVKit

@Observable
final class StitchVideoImportPlayer: Sendable {
    static let DEFAULT_VIDEO_PLAYER_VOLUME: Double = 1

    var video: AVPlayer
    var stitchVideoDelegate: StitchVideoDelegate
    var thumbnail: UIImage?
    var metadata: VideoMetadata {
        @MainActor
        didSet(newValue) {
            if metadata != newValue {
                self.stitchVideoDelegate.updateMetadata(for: video, videoData: metadata)
            }
        }
    }

    var currentTime: Double {
        video.currentTime().seconds
    }

    var duration: Double {
        CMTimeGetSeconds(video.currentItem?.duration ?? .zero)
    }

    var url: URL? { video.url }

    @MainActor
    init(url: URL, videoData: VideoMetadata, initialVolume: Double) {
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

    func enableSound() {
        self.video.isMuted = false
    }

    func muteSound() {
        self.video.isMuted = true
    }

    var volume: Double {
        self.stitchVideoDelegate.audio.delegate.volume
    }
    
    @MainActor
    func setVolume(volume: Double) {
        let volume = min(1, max(0, volume))
        self.video.volume = Float(volume)
    }

    var peakVolume: Double {
        self.stitchVideoDelegate.audio.delegate.peakVolume
    }

    @MainActor func play() {
        self.stitchVideoDelegate.play(with: self.video)
    }
}
