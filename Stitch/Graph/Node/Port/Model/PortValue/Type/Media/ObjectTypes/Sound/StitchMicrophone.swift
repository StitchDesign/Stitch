//
//  StitchMicrophone.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/24/21.
//

import AudioKit
import AVKit
import Foundation
import StitchSchemaKit

final class StitchMic: NSObject, Sendable, StitchSoundPlayerDelegate {
    let id = UUID()
    
    @MainActor var engine = AudioEngine()

    // Use AudioKit's AmplitudeTap for volume monitoring
    @MainActor private var ampTap: AmplitudeTap?
    @MainActor private var currentVolume: Float = 0
    @MainActor private var currentPeakVolume: Float = 0
    
    // For tracking peak volume
    @MainActor private var peakHoldTime: Float = 0.5 // Hold peak for half a second
    @MainActor private var lastPeakTime: TimeInterval = 0
    @MainActor private var peakValue: Float = 0

    @MainActor
    init(isEnabled: Bool) {
        super.init()
        
        // Initializer shouldn't call if not enabled
        guard isEnabled else {
            fatalErrorIfDebug()
            return
        }
        
        do {
            // Important for these session calls to happen before async caller
            try AVAudioSession.enableSpeakerAndMic()
            
            log("initializeAVAudioSession called")
            
            Task(priority: .high) { [weak self] in
                if await AVAudioApplication.requestRecordPermission() {
                    await MainActor.run { [weak self] in                        
                        // Engine callers, play etc must be called after permissions logic runs
                        self?.engine.output = self?.engine.input
                        
                        // Setup amplitude tap on the input node
                        if let input = self?.engine.input {
                            self?.ampTap = AmplitudeTap(input, callbackQueue: .main)
                            self?.ampTap?.start()
                        }
                        
                        if isEnabled {
                            self?.play()
                        }
                    }
                } else {                    
                    // Prompt user to consider enabling mic permissions
                    DispatchQueue.main.async {
                        dispatch(ReceivedStitchFileError(error: .recordingPermissionsDisabled))
                    }
                }
            }
        } catch {
            dispatch(ReceivedStitchFileError(error: .recordingPermissionsDisabled))
        }
    }

    @MainActor
    var url: URL? { nil } // No recorder, so no URL

    @MainActor
    var isRunning: Bool {
        // Consider only engine status since we no longer use recorder
        return self.ampTap != nil && self.engine.avEngine.isRunning
    }

    @MainActor
    func play() {
        // Just start the engine for the amplitude tap
        if !engine.avEngine.isRunning {
            try? engine.start()
        }
        // Start the amplitude tap if not already running
        self.ampTap?.start()
    }

    @MainActor
    func pause() {
        stop()
    }

    @MainActor
    func stop() {
        // Stop the amplitude tap
        self.ampTap?.stop()
        // Optionally stop the engine if needed
        self.engine.stop()
    }

    @MainActor
    func retrieveVolumeData() -> (Float, Float) {
        // Only use amplitude tap for volume monitoring
        if let ampTap = ampTap {
            let average = ampTap.amplitude
            
            // Proper peak calculation with decay
            let currentTime = Date().timeIntervalSince1970
            
            // If current amplitude is higher than our stored peak, update peak immediately
            if average > peakValue {
                peakValue = average
                lastPeakTime = currentTime
            }
            // Otherwise, check if we should let the peak decay (if hold time has passed)
            else if currentTime - lastPeakTime > Double(peakHoldTime) {
                // Gradually decay the peak value rather than dropping it immediately
                peakValue = max(average, peakValue * 0.95) // 5% decay per call
            }
            
            // Store the values for access even when the tap hasn't updated
            self.currentVolume = average
            self.currentPeakVolume = peakValue
            
            return (average, peakValue)
        } else {
            // Return stored values or zeros if no tap exists
            return (self.currentVolume, self.currentPeakVolume)
        }
    }

    // Delay doesn't work with mic - tracked in #2362
    @MainActor
    func assignDelay(_ value: Double) {
        // TODO: commented out below line with known current issues with delay + mic
        //        try await initializeAVAudioSession(Self.permissionsCategory)

        let isEnabled = self.isRunning

        // TODO: assess what's necessary here
        self.engine.stop()
        self.ampTap?.stop()  // Stop the tap before recreating engine
        self.ampTap = nil   // Clear the tap reference
        self.engine.input?.removeAllInputs()
        self.engine.output?.reset()
        self.engine = AudioEngine()

        if let input = engine.input {
            self.engine.output = Delay(input,
                                       time: AUValue(value),
                                       feedback: 0,
                                       dryWetMix: 100)
            
            // Re-create amplitude tap on the new input node
            self.ampTap = AmplitudeTap(input, callbackQueue: .main)
            self.ampTap?.start()
            
            if isEnabled {
                try? self.engine.start()
            }
        }
    }
}
