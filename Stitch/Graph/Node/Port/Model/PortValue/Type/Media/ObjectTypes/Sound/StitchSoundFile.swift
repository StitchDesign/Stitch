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

    var lowFrequencyAmplitude: Double = 0
    var midFrequencyAmplitude: Double = 0
    var highFrequencyAmplitude: Double = 0

    var lowFrequencyRange: (min: Double, max: Double) = (0, 0)
    var midFrequencyRange: (min: Double, max: Double) = (0, 0)
    var highFrequencyRange: (min: Double, max: Double) = (0, 0)

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

        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }

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
        self.fftTap = FFTTap(mixer, bufferSize: 4096, callbackQueue: .main) { [weak self] fftData in
            guard let strongSelf = self else { return }
            strongSelf.processFFTData(fftData)
        }
    }

    private func processFFTData(_ fftData: [Float]) {
        let binCount = fftData.count
        
        let sampleRate = Settings.sampleRate
        
        let nyquistFrequency = sampleRate / 2.0
        let frequencyPerBin = nyquistFrequency / Double(binCount)

        let lowRange = 0..<Int(Double(binCount) * 0.1)  // 0-10% of bins for low frequency
        let midRange = Int(Double(binCount) * 0.1)..<Int(Double(binCount) * 0.5)  // 10-50% of bins for mid frequency
        let highRange = Int(Double(binCount) * 0.5)..<binCount  // 50-100% of bins for high frequency

        self.lowFrequencyAmplitude = calculateAverageAmplitude(fftData, in: lowRange)
        self.midFrequencyAmplitude = calculateAverageAmplitude(fftData, in: midRange)
        self.highFrequencyAmplitude = calculateAverageAmplitude(fftData, in: highRange)

        self.lowFrequencyRange = (Double(lowRange.lowerBound) * frequencyPerBin, Double(lowRange.upperBound) * frequencyPerBin)
        self.midFrequencyRange = (Double(midRange.lowerBound) * frequencyPerBin, Double(midRange.upperBound) * frequencyPerBin)
        self.highFrequencyRange = (Double(highRange.lowerBound) * frequencyPerBin, Double(highRange.upperBound) * frequencyPerBin)

        print("Low Frequency Range: \(self.lowFrequencyRange.min.rounded()) - \(self.lowFrequencyRange.max.rounded()) Hz, Amplitude: \(self.lowFrequencyAmplitude)")
        print("Mid Frequency Range: \(self.midFrequencyRange.min.rounded()) - \(self.midFrequencyRange.max.rounded()) Hz, Amplitude: \(self.midFrequencyAmplitude)")
        print("High Frequency Range: \(self.highFrequencyRange.min.rounded()) - \(self.highFrequencyRange.max.rounded()) Hz, Amplitude: \(self.highFrequencyAmplitude)")
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

    var lowFrequencyInfo: (range: (min: Double, max: Double), amplitude: Double) {
        return (self.lowFrequencyRange, self.lowFrequencyAmplitude)
    }

    var midFrequencyInfo: (range: (min: Double, max: Double), amplitude: Double) {
        return (self.midFrequencyRange, self.midFrequencyAmplitude)
    }

    var highFrequencyInfo: (range: (min: Double, max: Double), amplitude: Double) {
        return (self.highFrequencyRange, self.highFrequencyAmplitude)
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
