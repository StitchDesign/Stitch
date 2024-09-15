//
//  StitchVideoPlayer.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/5/22.
//

import AVKit

/// A class for managing `AVPlayer` instances for non-layer scenarios. For video layers,
/// `StitchVideoViewController` is used.
@Observable
final class StitchVideoImportPlayer: Sendable {
    var video: AVPlayer
    var stitchVideoDelegate: StitchVideoDelegate
    var thumbnail: UIImage?
    var metadata: VideoMetadata {
        @MainActor
        didSet(newValue) {
            // Need to compare old vs new else publishers get called unnecessarily
            if metadata != newValue {
                // Dispatch fixes issue where background thread could cause crash on AudioKit engine
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

        // Video muted by default, only unmuted by video layer
        self.muteSound()
    }

    @MainActor
    func resetPlayer() {
        self.stitchVideoDelegate.seek(on: self.video,
                                      to: .zero,
                                      // Can be false here since it's just a reset
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

    var peakVolume: Double {
        self.stitchVideoDelegate.audio.delegate.peakVolume
    }

    @MainActor func play() {
        self.stitchVideoDelegate.play(with: self.video)
    }
}
