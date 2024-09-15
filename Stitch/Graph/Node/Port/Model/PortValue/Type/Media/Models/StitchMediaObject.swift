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
    case arAnchor(AnchorEntity)
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
            hasher.combine(video.url?.hashValue)
        case .soundfile(let stitchSoundPlayer):
            hasher.combine(stitchSoundPlayer.delegate.url?.hashValue ?? .zero)
        case .mic(let stitchSoundPlayer):
            hasher.combine(stitchSoundPlayer.delegate.url?.hashValue ?? .zero)
        case .model3D(let stitchEntity):
            hasher.combine(stitchEntity.sourceURL)
        case .arAnchor(let anchorEntity):
            hasher.combine(anchorEntity.hashValue)
        case .coreMLImageModel(let stitchMLModel):
            hasher.combine(stitchMLModel.hashValue)
        }
    }
}

extension StitchMediaObject {
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
            if let entityInstance = stitchEntity.entityStatus.loadedInstance,
               let otherEntityInstance = otherStitchEntity.entityStatus.loadedInstance {
                DispatchQueue.main.async { [weak entityInstance, weak otherEntityInstance] in
                    if let otherEntityInstance = otherEntityInstance {
                        entityInstance?.applyMatrix(newMatrix: otherEntityInstance.transform.matrix)                        
                    }
                }
            }
            stitchEntity.isAnimating = otherStitchEntity.isAnimating
            self = .model3D(stitchEntity)

        case .arAnchor(let anchor):
            guard let otherAnchor = otherMediaObject.arAnchor else {
                return
            }

            DispatchQueue.main.async { [weak anchor, weak otherAnchor] in
                guard let anchor = anchor,
                      let otherAnchor = otherAnchor else {
                    return
                }
                
                anchor.transform = otherAnchor.transform

                let currentEntities = Set(anchor.children)
                let otherEntities = Set(otherAnchor.children)

                // Reset entities in anchors
                anchor.removeAllEntities(currentEntities.map { $0 })
                otherEntities.forEach { anchor.addChild($0) }
            }

            self = .arAnchor(anchor)

        case .coreMLImageModel:
            // Nothing to transfer
            return
        }
    }

    /// Creates a unique refrence copy of some media object.
    func createComputedCopy(nodeId: NodeId?) async -> StitchMediaObject? {
        var copiedMediaObject: StitchMediaObject?

        switch self {
        case .image(let uIImage):
            guard let copy = uIImage.copy() as? UIImage else {
                return nil
            }
            copiedMediaObject = .image(copy)

        case .video(let videoPlayer):
            guard let url = videoPlayer.url else {
                return nil
            }
            let newPlayer = await StitchVideoImportPlayer(url: url,
                                                          videoData: videoPlayer.stitchVideoDelegate.videoData)
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
            
            let newStitchEntity = await StitchEntity(id: .init(),
                                                     nodeId: nodeId,
                                                     sourceURL: entity.sourceURL,
                                                     isAnimating: entity.isAnimating)
            
            copiedMediaObject = .model3D(newStitchEntity)

        case .arAnchor(let arAnchor):
            let newAnchor = await arAnchor.clone(recursive: true)
            copiedMediaObject = .arAnchor(newAnchor)

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
    var name: String {
        switch self {
        case .image(let uIImage):
            return uIImage.accessibilityIdentifier ?? "Image"
        case .video(let videoPlayer):
            return videoPlayer.url?.filename ?? "Video"
        case .soundfile(let soundPlayer):
            return soundPlayer.delegate.url?.filename ?? "Audio"
        case .model3D(let entity):
            return entity.sourceURL.filename
        case .coreMLImageModel(let model):
            return model.model.accessibilityLabel ?? "Model"
        case .mic:
            return "Mic"
        case .arAnchor:
            return "AR Anchor"
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
        case .image, .mic, .coreMLImageModel, .arAnchor:
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
        case .soundfile, .mic, .coreMLImageModel, .arAnchor:
            return nil
        }
    }

    /// Applies to sound and video players
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

    var arAnchor: AnchorEntity? {
        switch self {
        case .arAnchor(let arAnchor):
            return arAnchor
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
        case .mic, .arAnchor:
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
