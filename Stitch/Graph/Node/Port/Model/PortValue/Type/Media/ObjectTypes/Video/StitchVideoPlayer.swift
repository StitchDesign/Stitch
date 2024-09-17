import AVKit

@Observable
final class StitchVideoImportPlayer: Sendable {
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
    init(url: URL, videoData: VideoMetadata) {
        let player = AVPlayer(url: url)
        self.stitchVideoDelegate = StitchVideoDelegate(url: url,
                                                       videoData: videoData,
                                                       currentPlayer: player)
        self.video = player
        self.metadata = videoData

        Task { [weak self, weak player] in
            self?.thumbnail = await player?.currentItem?.asset.getThumbnail()
        }

        self.muteSound()
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
    
    @MainActor func setVolume(volume: Double) {
        guard volume >= 0.0 && volume <= 1.0 else {
            print("Volume must be between 0.0 and 1.0")
            return
        }
        self.video.volume = Float(volume) // Set the volume of the AVPlayer
        // Assuming there's a method to update the delegate's volume
        self.stitchVideoDelegate.audio.updateVolume(volume) // Update volume through a method
    }

    var peakVolume: Double {
        self.stitchVideoDelegate.audio.delegate.peakVolume
    }

    @MainActor func play() {
        self.stitchVideoDelegate.play(with: self.video)
    }
}
