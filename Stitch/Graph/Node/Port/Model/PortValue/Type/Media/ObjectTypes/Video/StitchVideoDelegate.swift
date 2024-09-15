//
//  StitchVideoDelegate.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/16/22.
//

import AVKit
import Foundation
import StitchSchemaKit

/// A delegate for modifying video objects, used by patch and layer nodes.
/// Delegate pattern used because it allows us to re-use common video functionality without the
/// class itself owning the video. This is especially useful for StitchVideoViewController which owns
/// its own video object.
class StitchVideoDelegate: NSObject {
    var loopObserver: NSObjectProtocol?
    var videoData: VideoMetadata

    // used to measure volume but this stays muted
    let audio: StitchSoundPlayer<StitchSoundFilePlayer>

    private var isSeekInProgress = false
    private var chaseTime = CMTime.zero

    @MainActor
    init(url: URL, videoData: VideoMetadata, currentPlayer: AVPlayer) {
        self.videoData = videoData

        let audioDelegate = StitchSoundFilePlayer(url: url,
                                                  willLoop: videoData.isLooped)
        self.audio = StitchSoundPlayer(delegate: audioDelegate, willPlay: videoData.playing)

        super.init()
        self.updateMetadata(for: currentPlayer, videoData: videoData)
    }

    @MainActor
    func updateMetadata(for currentPlayer: AVPlayer, videoData: VideoMetadata) {
        self.videoData = videoData

        // Update audio
        self.audio.isEnabled = videoData.playing
        self.audio.delegate.isLooping = videoData.isLooped

        self.updateLoopSetting(on: currentPlayer,
                               to: videoData.isLooped,
                               isScrubbing: videoData.isScrubbing)

        // Only update playback time with scrubbing enabled, otherwise we would break playback
        // functionality by calling player.seek too many times
        //
        // Note: cannot scrub and play at same time; causes crash in AVFoundation AudioPlayer's .play method
        if videoData.isScrubbing && !videoData.playing {
            self.pause(with: currentPlayer)
            self.seek(on: currentPlayer,
                      to: videoData.scrubTime,
                      isScrubbing: true)
        } else {
            self.updateIsPlay(on: currentPlayer, videoData.playing)
        }
    }

    @MainActor func play(with currentPlayer: AVPlayer) {
        currentPlayer.play()
        self.audio.isEnabled = true
    }

    @MainActor func pause(with currentPlayer: AVPlayer) {
        currentPlayer.pause()
        self.audio.isEnabled = false
    }

    @MainActor
    func seek(on currentPlayer: AVPlayer,
              to time: Double,
              isScrubbing: Bool) {
        seek(on: currentPlayer,
             to: time.cmTime,
             isScrubbing: isScrubbing)
    }

    @MainActor
    func seek(on currentPlayer: AVPlayer,
              to time: CMTime,
              isScrubbing: Bool) {
        // Catches crash by AudioKit where seek causes crash if engine not started
        guard self.audio.delegate.engine.avEngine.isRunning else {
            try? self.audio.engine.start()
            return
        }

        if isScrubbing {
            // Only for manual scrubbing, doesn't work for looping
            self.seekSmoothlyToTime(player: currentPlayer, newChaseTime: time)
        } else {
            // Better for looping
            currentPlayer.seek(to: time)
        }
        self.audio.delegate.player.seek(time: time.seconds)
    }

    /// Adds support for video looping:
    /// * If true, create an observer that listens to AVPlayer playback ending.
    /// * If false, tear down the observer.
    @MainActor private func updateLoopSetting(on currentPlayer: AVPlayer, to isLooped: Bool, isScrubbing: Bool) {
        // Enabled scrubbing should prevent video looping
        guard isValidVideoLoop(isLoopedSetting: isLooped, isScrubbing: isScrubbing) else {
            removeLoopObserver()
            return
        }

        // Only create loop observer if none yet created or if any parameters changed
        if shouldCreateLoopObserver(isLoopedSetting: isLooped) {
            // tear down current observer before creating new one
            removeLoopObserver()

            self.loopObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                                       object: currentPlayer.currentItem, queue: .main) { [weak self, weak currentPlayer] _ in
                guard let currentPlayer = currentPlayer else {
                    return
                }
                
                if isLooped {
                    let videoStart = Double.zero.cmTime
                    self?.seek(on: currentPlayer,
                               to: videoStart,
                               // Needs to be false, and assumes looping doesn't happen
                               // with scrubbing true
                               isScrubbing: false)
                    self?.play(with: currentPlayer)
                } else {
                    self?.pause(with: currentPlayer)
                }
            }

        }
    }

    @MainActor
    func updateIsPlay(on currentPlayer: AVPlayer, _ isPlay: Bool) {
        if didToggleToPause(on: currentPlayer, isPlaySettingOn: isPlay) {
            self.pause(with: currentPlayer)
        } else if didToggleToPlay(on: currentPlayer, isPlaySettingOn: isPlay) {
            self.play(with: currentPlayer)
        }
    }

    func removeLoopObserver() {
        if let loopObserver = loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
            self.loopObserver = nil
        }
    }

    func removeAllObservers() {
        removeLoopObserver()
    }

    deinit {
        removeAllObservers()
    }

    // Fixes issue where AVPlayer has poor scrubbing performance
    // Source: https://gist.github.com/shaps80/ac16b906938ad256e1f47b52b4809512?permalink_comment_id=3066594#gistcomment-3066594
    private func seekSmoothlyToTime(player: AVPlayer,
                                    newChaseTime: CMTime) {
        if CMTimeCompare(newChaseTime, chaseTime) != 0 {
            chaseTime = newChaseTime

            if !isSeekInProgress {
                trySeekToChaseTime(player: player)
            }
        }
    }

    private func trySeekToChaseTime(player: AVPlayer) {
        guard player.status == .readyToPlay else { return }
        actuallySeekToTime(player: player)
    }

    private func actuallySeekToTime(player: AVPlayer) {
        isSeekInProgress = true
        let seekTimeInProgress = chaseTime

        player.seek(to: seekTimeInProgress, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let `self` = self else { return }

            if CMTimeCompare(seekTimeInProgress, self.chaseTime) == 0 {
                self.isSeekInProgress = false
            } else {
                self.trySeekToChaseTime(player: player)
            }
        }
    }
}

/// Private helpers for `StitchVideoAVPlayer`.
extension StitchVideoDelegate {
    private func didToggleToPlay(on currentPlayer: AVPlayer, isPlaySettingOn: Bool) -> Bool {
        return isPlaySettingOn && !currentPlayer.isPlaying
    }

    private func didToggleToPause(on currentPlayer: AVPlayer, isPlaySettingOn: Bool) -> Bool {
        return !isPlaySettingOn && currentPlayer.isPlaying
    }

    private func shouldCreateLoopObserver(isLoopedSetting: Bool) -> Bool {
        self.loopObserver == nil && isLoopedSetting
    }

    /// A video should only loop if (a) looping is enabled and (b) scurbbing is disabled.
    private func isValidVideoLoop(isLoopedSetting: Bool,
                                  isScrubbing: Bool) -> Bool {
        isLoopedSetting && !isScrubbing
    }
}
