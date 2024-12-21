//
//  StitchMediaObject.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/11/23.
//

import Foundation
import StitchSchemaKit
import RealityKit
import SwiftUI
import Vision

enum StitchMediaObject: Sendable {
    case image(UIImage)
    case video(StitchVideoImportPlayer)
    case soundfile(StitchSoundPlayer<StitchSoundFilePlayer>)
    case mic(StitchSoundPlayer<StitchMic>)
    case model3D(StitchEntity)
    case coreMLImageModel(StitchMLModel)
}

enum StitchSingletonMediaObject: Sendable {
    case cameraFeedManager(CameraFeedManager)
    case locationManager(LocationManager)
}

extension StitchSingletonMediaObject {
    var cameraFeedManager: CameraFeedManager? {
        switch self {
        case .cameraFeedManager(let cameraFeedManager):
            return cameraFeedManager
        default:
            return nil
        }
    }

    var locationManager: LocationManager? {
        switch self {
        case .locationManager(let locationManager):
            return locationManager
        default:
            return nil
        }
    }
}

extension StitchMediaObject: Hashable {
    static func == (lhs: StitchMediaObject, rhs: StitchMediaObject) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .image(let uIImage):
            hasher.combine(uIImage.hashValue)
        case .video(let video):
            hasher.combine(video.url.hashValue)
        case .soundfile(let stitchSoundPlayer):
            hasher.combine(stitchSoundPlayer.delegate.url?.hashValue ?? .zero)
        case .mic(let stitchSoundPlayer):
            hasher.combine(stitchSoundPlayer.delegate.id)
        case .model3D(let stitchEntity):
            hasher.combine(stitchEntity.sourceURL)
        case .coreMLImageModel(let stitchMLModel):
            hasher.combine(stitchMLModel.hashValue)
        }
    }
}

extension StitchMediaObject {
    @MainActor
    mutating func transferData(from otherMediaObject: StitchMediaObject) async {
        switch self {
        case .image(let uIImage):
            guard let clone = uIImage.clone() else {
                return
            }
            self = .image(clone)
        case .video(let videoPlayer):
            guard let otherVideoPlayer = otherMediaObject.video else {
                return
            }
            videoPlayer.metadata = otherVideoPlayer.metadata
            self = .video(videoPlayer)

        case .soundfile(let soundFilePlayer):
            guard let otherSoundFilePlayer = otherMediaObject.soundFilePlayer else {
                return
            }

            await MainActor.run { [weak soundFilePlayer] in
                soundFilePlayer?.isEnabled = otherSoundFilePlayer.isEnabled
                soundFilePlayer?.delegate.isLooping = otherSoundFilePlayer.delegate.isLooping
            }
            self = .soundfile(soundFilePlayer)

        case .mic(let micPlayer):
            guard let otherMic = otherMediaObject.mic else {
                return
            }

            await MainActor.run { [weak micPlayer] in
                micPlayer?.isEnabled = otherMic.isEnabled
            }
            self = .mic(micPlayer)

        case .model3D(let stitchEntity):
            guard let otherStitchEntity = otherMediaObject.model3DEntity else {
                return
            }

            // Apply transform if both instances are loaded
            let entityInstance = stitchEntity
            let otherEntityInstance = otherStitchEntity
            
            entityInstance.applyMatrix(newMatrix: otherEntityInstance.containerEntity.transform.matrix)
            stitchEntity.isAnimating = otherStitchEntity.isAnimating
            
            self = .model3D(stitchEntity)

        case .coreMLImageModel:
            // Nothing to transfer
            return
        }
    }

    /// Creates a unique refrence copy of some media object.
    func createComputedCopy(nodeId: NodeId?) async throws -> StitchMediaObject? {
        var copiedMediaObject: StitchMediaObject?

        switch self {
        case .image(let uIImage):
            // MARK: must copy on main thread or will crash
            copiedMediaObject = await MainActor.run { [weak uIImage] in
                guard let copy = uIImage?.copy() as? UIImage else {
                    return nil
                }
                return .image(copy)
            }

        case .video(let videoPlayer):
            let url = videoPlayer.url
            let newPlayer = await StitchVideoImportPlayer(url: url,
                                                          videoData: videoPlayer.stitchVideoDelegate.videoData,
                                                          initialVolume: 0.5)
            copiedMediaObject = .video(newPlayer)

        case .soundfile(let soundFilePlayer):
            guard let url = soundFilePlayer.delegate.url else {
                log("createComputedCopy: could not get sound delegate URL")
                return nil
            }
            
            let newSoundPlayer: StitchSoundPlayer<StitchSoundFilePlayer>? = await MainActor.run { [weak soundFilePlayer] in
                guard let soundFilePlayer = soundFilePlayer else {
                    return nil
                }
                let newFilePlayer = StitchSoundFilePlayer(url: url,
                                                          willLoop: soundFilePlayer.delegate.isLooping,
                                                          rate: soundFilePlayer.delegate.rate,
                                                          jumpTime: soundFilePlayer.delegate.getCurrentPlaybackTime())
                let newSoundPlayer = StitchSoundPlayer(delegate: newFilePlayer,
                                         willPlay: soundFilePlayer.delegate.isRunning)
                return newSoundPlayer
            }
            
            if let newSoundPlayer = newSoundPlayer {
                copiedMediaObject = .soundfile(newSoundPlayer)
            }

        case .mic(let mic):
            let newSoundPlayer: StitchSoundPlayer<StitchMic>? = await MainActor.run { [weak mic] in
                guard let mic = mic else {
                    return nil
                }
                
                let isEnabled = mic.delegate.isRunning
                let newMic = StitchMic(isEnabled: isEnabled)
                let newSoundPlayer = StitchSoundPlayer(delegate: newMic, willPlay: isEnabled)
                return newSoundPlayer
            }

            if let newSoundPlayer = newSoundPlayer {                
                copiedMediaObject = .mic(newSoundPlayer)
            }

        case .model3D(let entity):
            guard let nodeId = nodeId else {
                fatalErrorIfDebug()
                return copiedMediaObject
            }
            
            let newStitchEntity = try await StitchEntity(id: .init(),
                                                         nodeId: nodeId,
                                                         sourceURL: entity.sourceURL,
                                                         isAnimating: entity.isAnimating)
            
            copiedMediaObject = .model3D(newStitchEntity)

        case .coreMLImageModel(let model):            //
            let modelCopy = model.copy()
            if let copiedMLModel = (modelCopy as? StitchMLModel) {
                copiedMediaObject = .coreMLImageModel(copiedMLModel)
            }
        }

        // Copy other metadata from source media object
        await copiedMediaObject?.transferData(from: self)
        return copiedMediaObject
    }
}

/// StitchMediaObject util methods.
extension StitchMediaObject {
    @MainActor
    var name: String {
        switch self {
        case .image(let uIImage):
            return uIImage.accessibilityIdentifier ?? "Image"
        case .video(let videoPlayer):
            return videoPlayer.url.filename
        case .soundfile(let soundPlayer):
            return soundPlayer.delegate.url?.filename ?? "Audio"
        case .model3D(let entity):
            return entity.sourceURL.filename
        case .coreMLImageModel(let model):
            return model.originalURL.filename ?? "Model"
        case .mic:
            return "Mic"
        }
    }

    // Gets URL asset of some media
    var url: URL? {
        switch self {
        case .video(let stitchVideoImportPlayer):
            return stitchVideoImportPlayer.url
        case .soundfile(let soundPlayer):
            return soundPlayer.delegate.url
        case .model3D(let entity):
            return entity.sourceURL

        // Not needed for these scenarios
        case .image, .mic, .coreMLImageModel:
            return nil
        }
    }

    // Checks if some media object has a matching layer to use.
    var layer: Layer? {
        switch self {
        case .image:
            return .image
        case .video:
            return .video
        case .model3D:
            return .model3D
        case .soundfile, .mic, .coreMLImageModel:
            return nil
        }
    }

    /// Applies to sound and video players
    @MainActor
    var currentPlaybackTime: Double? {
        switch self {
        case .video(let videoPlayer):
            return videoPlayer.currentTime
        case .soundfile(let soundPlayer):
            return soundPlayer.delegate.getCurrentPlaybackTime()
        default:
            return nil
        }
    }
}

/// StitchMediaObject helpers for certain media types.
extension StitchMediaObject {
    var image: UIImage? {
        switch self {
        case .image(let uIImage):
            return uIImage
        default:
            return nil
        }
    }

    var video: StitchVideoImportPlayer? {
        switch self {
        case .video(let video):
            return video
        default:
            return nil
        }
    }

    var soundFilePlayer: StitchSoundPlayer<StitchSoundFilePlayer>? {
        switch self {
        case .soundfile(let soundPlayer):
            return soundPlayer
        default:
            return nil
        }
    }

    var mic: StitchSoundPlayer<StitchMic>? {
        switch self {
        case .mic(let mic):
            return mic
        default:
            return nil
        }
    }

    var model3DEntity: StitchEntity? {
        switch self {
        case .model3D(let entity):
            return entity
        default:
            return nil
        }
    }

    var coreMLImageModel: VNCoreMLModel? {
        switch self {
        case .coreMLImageModel(let model):
            return model.model
        default:
            return nil
        }
    }
    
    /// Used to determine if some media object is a supported import type.
    var supportedImportType: SupportedMediaFormat? {
        switch self {
        case .image:
            return .image
        case .video:
            return .video
        case .soundfile:
            return .audio
        case .model3D:
            return .model3D
        case .coreMLImageModel:
            return .coreML
        case .mic:
            return nil
        }
    }
    
    // Update player in media manager with speaker's volume
    @MainActor
    func updateVolume(to volume: Double) {
        switch self {
        case .soundfile(let soundFilePlayer):
            soundFilePlayer.updateVolume(volume)
        case .mic(let mic):
            mic.updateVolume(volume)
        default:
            break
        }
    }
}

extension UIImage: Sendable { }
