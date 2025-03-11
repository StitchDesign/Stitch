//
//  SoundHelpers.swift
//  Stitch
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
}

extension AVAudioSession {
    static func enableSpeaker() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }
}
