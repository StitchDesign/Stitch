//
//  SoundHelpers.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/1/21.
//

import Foundation
import StitchSchemaKit
import AudioKit
import SwiftUI
import AVFAudio
import AVFoundation

// https://blog.demofox.org/2015/04/14/decibels-db-and-amplitude/

func convertDecibelToAmplitude(_ db: Float) -> Float {
    pow(10.0, (db/20.0))
}

extension AVAudioRecorder {
    func startRecording(meteringEnabled: Bool = true) {
        self.prepareToRecord()
        self.isMeteringEnabled = true
        self.record()
    }

    func stopRecording() -> URL {
        self.stop()
        return self.url
    }

    // In decibels.
    // For use when the recorder is ACTIVE and isMetering = enabled
    func retrieveVolumes() -> (Float, Float) {
        self.updateMeters()
        // channel (0 vs 1) seems irrelevant?
        let peak = self.peakPower(forChannel: 0)
        let average = self.averagePower(forChannel: 0)

        return (convertDecibelToAmplitude(average),
                convertDecibelToAmplitude(peak))
    }
}

extension AVAudioSession {
    static func enableSpeaker() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }
}
