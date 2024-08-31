//
//  StitchSoundFile.swift
//  prototype
//
//  Created by Christian J Clampitt on 9/24/21.
//

import Foundation
import StitchSchemaKit
import AudioKit
import AVFoundation

final class StitchSoundFilePlayer: NSObject, StitchSoundPlayerDelegate {
    static let permissionsCategory = AVAudioSession.Category.playback

    var engine = AudioEngine()
    let player = AudioPlayer()

    // mixers don't need to be long lived, just the taps?
    private var ampTap: AmplitudeTap
    private var peakAmpTap: AmplitudeTap
    private var fftTap: FFTTap?
    private var variSpeed: VariSpeed
    private var FFT_TAP_SIZE: UInt32 = 4096

    var frequencyAmplitudes: [Double] = SoundImportNode.defaultFrequencyAmplitudes

    @MainActor
    init(url: URL,
         willLoop: Bool = true,
         rate: AUValue? = nil,
         jumpTime: Double? = nil) {
        // MARK: we had this in a Task object before but calling this async appeared to cause crashes
        try? AVAudioSession.enableSpeaker()

        do {
            try player.load(url: url)
        } catch {
            log("StitchSoundFilePlayer error: \(error)")
        }
        player.isLooping = willLoop

        // adding mixers for peak and average amplitude taps
        let mixer = Mixer(player)
        let mixer2 = Mixer(mixer)

        self.ampTap = AmplitudeTap(mixer, callbackQueue: .main)

        let peakAmpTap = AmplitudeTap(mixer2, callbackQueue: .main)
        peakAmpTap.analysisMode = .peak
        self.peakAmpTap = peakAmpTap

        self.variSpeed = VariSpeed(mixer2)

        self.engine.output = variSpeed

        super.init()

        setupFFTTap(mixer2)

        if let rate = rate {
            self.rate = rate
        }

        if let jumpTime = jumpTime {
            self.setJumpTime(jumpTime)
        }

        self.setPlayerLoop(time: .zero, enableInfiniteLoop: willLoop)
    }
    
    private func setupFFTTap(_ mixer: Mixer) {
        self.fftTap = FFTTap(mixer, bufferSize: FFT_TAP_SIZE, callbackQueue: .main) { [weak self] fftData in
            guard let strongSelf = self else { return }
            strongSelf.processFFTData(fftData)
        }
    }

    private func processFFTData(_ fftData: [Float]) {
        let binCount = fftData.count
        let numberOfRanges = 16

        var amplitudes: [Double] = []

        for i in 0..<numberOfRanges {
            let startBin = Int(pow(Double(binCount), Double(i) / Double(numberOfRanges)))
            let endBin = Int(pow(Double(binCount), Double(i + 1) / Double(numberOfRanges)))
            let range = startBin..<min(endBin, binCount)

            let amplitude = calculateAmplitude(fftData, in: range)
            amplitudes.append(amplitude)
        }

        // Apply a modified logarithmic scaling
        let logAmplitudes = amplitudes.map { max(-50, 20 * log10(max($0, 1e-5))) }

        // Normalize to 0-1 range
        let minAmplitude = logAmplitudes.min() ?? -50
        let maxAmplitude = logAmplitudes.max() ?? 0
        self.frequencyAmplitudes = logAmplitudes.map {
            max(0, min(1, ($0 - minAmplitude) / (maxAmplitude - minAmplitude)))
        }
    }

    private func calculateAmplitude(_ fftData: [Float], in range: Range<Int>) -> Double {
        let sum = range.reduce(0.0) { $0 + pow(Double(fftData[$1]), 2) }
        return sqrt(sum / Double(range.count))
    }
    
    private func calculateAverageAmplitude(_ fftData: [Float], in range: Range<Int>) -> Double {
        let sum = range.reduce(0.0) { $0 + Double(fftData[$1]) }
        return sum / Double(range.count)
    }
    
    var isRunning: Bool {
        self.player.isStarted
    }

    var isLooping: Bool {
        get {
            self.player.isLooping
        }

        @MainActor
        set(newValue) {
            self.player.isLooping = newValue
            self.setPlayerLoop(time: .zero, enableInfiniteLoop: newValue)
        }
    }

    var rate: AUValue {
        get {
            self.variSpeed.rate
        }
        set(newValue) {
            self.variSpeed.rate = AUValue(newValue)
        }
    }

    func setJumpTime(_ jumpTime: Double) {
        self.player.seek(time: jumpTime)
    }

    var url: URL? { self.player.file?.url }

    @MainActor
    private func setPlayerLoop(time: TimeInterval, enableInfiniteLoop: Bool) {
        player.completionHandler = { [weak self] in
            self?.player.seek(time: time)

            if !enableInfiniteLoop {
                self?.pause()
            }
        }
    }

    /// Gets the player's current playback time.
    func getCurrentPlaybackTime() -> Double {
        // Calling getCurrentTime doesn't reset playback time after audio completes playing, so we compute
        // a modulo on the sound's duration.
        // TODO: getCurrentTime doesn't work perfectly have loop setting is toggled off and on.
        return self.player.currentTime.truncatingRemainder(dividingBy: self.duration)
    }

    var duration: Double {
        self.player.duration
    }

    var volume: Double {
        Double(self.ampTap.amplitude)
    }

    var peakVolume: Double {
        Double(self.peakAmpTap.amplitude)
    }

    func play() {
        self.player.play()
        self.ampTap.start()
        self.peakAmpTap.start()
        self.fftTap?.start()
    }

    func pause() {
        self.player.pause()
        self.ampTap.stop()
        self.peakAmpTap.stop()
        self.fftTap?.stop()
    }

    func stop() {
        self.player.stop()
        self.ampTap.stop()
        self.peakAmpTap.stop()
        self.fftTap?.stop()
    }
}
