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
    /// Used by both sound and mic players.
    /// **NOTE: very important to keep the permissions request consistent by always requesting for mic. Fixes crash where requesting "play and record" after "play" was already establisehd.**
    static func enableSpeakerAndMic() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default,
                                // MARK: necessary on iOS!
                                options: [.allowBluetooth])
        try session.setActive(true)
    }
}
