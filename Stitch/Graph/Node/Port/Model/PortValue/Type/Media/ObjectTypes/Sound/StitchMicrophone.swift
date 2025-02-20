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
    internal static let permissionsCategory = AVAudioSession.Category.playAndRecord
    private let session: AVAudioSession
    let id = UUID()
    
    var engine = AudioEngine()

    // Recorder and session are used for the mic patch node
    @MainActor private var recorder: AVAudioRecorder?

    @MainActor
    init(isEnabled: Bool) async {
        self.session = AVAudioSession.sharedInstance()
    
        super.init()
        
        // Initializer shouldn't call if not enabled
        guard isEnabled else {
            fatalErrorIfDebug()
            return
        }
        
        do {
            // Important for these session calls to happen before async caller
            try session.setCategory(Self.permissionsCategory,
                                    mode: .default,
                                    // MARK: necessary on iOS!
                                    options: [.allowBluetooth])
            try session.setActive(true)
            
            log("initializeAVAudioSession called")
            
            if await AVAudioApplication.requestRecordPermission() {
                await MainActor.run { [weak self] in
                    // Engine callers, play etc must be called after permissions logic runs
                    self?.engine.output = self?.engine.input
                    
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
        } catch {
            DispatchQueue.main.async {
                dispatch(ReceivedStitchFileError(error: .recordingPermissionsDisabled))
            }
        }
    }

    @MainActor
    var url: URL? { self.recorder?.url }

    @MainActor
    var isRunning: Bool {
        self.recorder.isDefined
    }

    @MainActor
    func play() {
        guard let recorder = recorder else {
            if let newRecorder = Self.createAVAudioRecorder() {
                self.recorder = newRecorder
                newRecorder.startRecording()
            }
            return
        }
        if !recorder.isRecording {
            recorder.startRecording()
        }
    }

    @MainActor
    func pause() {
        stop()
    }

    @MainActor
    func stop() {
        self.recorder?.stop()
        self.recorder = nil
    }

    @MainActor
    func retrieveVolumeData() -> (Float, Float) {
        self.recorder?.retrieveVolumes() ?? (.zero, .zero)
    }

    // Delay doesn't work with mic - tracked in #2362
    @MainActor
    func assignDelay(_ value: Double) {
        // TODO: commented out below line with known current issues with delay + mic
        //        try await initializeAVAudioSession(Self.permissionsCategory)

        let isEnabled = self.isRunning

        // TODO: assess what's necessary here
        self.engine.stop()
        self.engine.input?.removeAllInputs()
        self.engine.output?.reset()
        self.engine = AudioEngine()

        if let input = engine.input {
            self.engine.output = Delay(input,
                                       time: AUValue(value),
                                       feedback: 0,
                                       dryWetMix: 100)
            if isEnabled {
                try? self.engine.start()
            }
        }
    }

    // this url needs to be eg documents/project.stitchproject/tmp
    @MainActor
    private static func createAVAudioRecorder() -> AVAudioRecorder? {
        let recordSettings =
            [AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue,
             AVEncoderBitRateKey: 16,
             AVNumberOfChannelsKey: 2,
             AVSampleRateKey: 44100]

        let tempUrl = StitchFileManager.createTempURL(fileExt: MIC_RECORDING_FILE_EXT)
        
        return try? AVAudioRecorder(
            url: tempUrl,
            settings: recordSettings)
    }
}
