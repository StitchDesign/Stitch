//
//  StitchARView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/29/22.
//

import ARKit
import RealityKit
import StitchSchemaKit

// https://stackoverflow.com/questions/65591637/play-usdz-animation-in-realitykit
// https://gist.github.com/MickaelCruzDB/010ebd85390799a5b43c048e0e6be0fa

/// Wrapper class for ARView.
// TODO: should make this an actor, right now inheritence prevents this
final class StitchARView: ARView {
    let actor = CameraFeedActor()
    var anchorMap: [UInt64: AnchorEntity] = [:]

    // For camera session delegate
    @MainActor var currentImage: UIImage? {
        self.bufferDelegate.convertedImage
    }
    
    var bufferDelegate = StitchARViewCaptureDelegate()

    // Non-zero rect import for preventing warning that sometimes appears
    @MainActor
    init(frame: CGRect = .init(x: .zero, y: .zero, width: 100, height: 100),
         anchors: [AnchorEntity] = [],
         cameraMode: ARView.CameraMode = .ar) {
        super.init(frame: frame, cameraMode: cameraMode, automaticallyConfigureSession: false)
        updateAnchors(anchors: anchors)

        self.session.delegate = self.bufferDelegate

        switch cameraMode {
        case .ar:
            // Add coaching overlay
            /*
             let coachingOverlay = ARCoachingOverlayView()
             coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
             coachingOverlay.session = session
             coachingOverlay.goal = .anyPlane
             self.addSubview(coachingOverlay)
             */
            self.environment.background = .color(.clear)
        case .nonAR:
            // Make static view for non AR
            if let snapshotView = self.snapshotView(afterScreenUpdates: false) {
                self.addSubview(snapshotView)
            }

            // Environment can be used for lighting effects for AR stuff
            self.environment.background = .color(.clear)
        default:
            if let snapshotView = self.snapshotView(afterScreenUpdates: false) {
                self.addSubview(snapshotView)
            }

            self.environment.background = .color(.clear)
        }
    }

    required init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    /// Updates entity anchors in place with already existing AR view.
    func updateAnchors(mediaList: [StitchMediaObject]) {
        // Get objects for entities to potentially add to scene
        let incomingAnchors = mediaList
            .compactMap {
                $0.arAnchor
            }

        // Abstract away loaded from unloaded anchors
        let incomingAnchorIDs = incomingAnchors.map { $0.id }

        // Remove entity objects which don't exist in incoming list but exist in current scene
        let anchorsToRemove = self.anchorMap.keys.filter { !incomingAnchorIDs.contains($0) }
        anchorsToRemove.forEach { anchorToRemove in
            if let anchor = self.anchorMap.get(anchorToRemove) {
                // removeFromParent might not be necessary
                anchor.removeFromParent()
                self.scene.removeAnchor(anchor)

                anchorMap.removeValue(forKey: anchorToRemove)
            }
        }

        let anchorsToAdd = incomingAnchors.filter { !self.anchorMap.keys.contains($0.id) }
        self.updateAnchors(anchors: anchorsToAdd)
    }

    func updateAnchors(anchors: [AnchorEntity]) {
        anchors.forEach { anchorEntity in
            // MARK: - addAnchor API causes a memory leak when called at a high frequency (GitHub issue #2388)
            // Crashes sometimes when not called on main thread
            self.scene.addAnchor(anchorEntity)
            self.anchorMap.updateValue(anchorEntity, forKey: anchorEntity.id)
        }
    }

    func makeRaycast(alignmentType: ARRaycastQuery.TargetAlignment,
                     center: CGPoint,
                     x: Float,
                     y: Float) -> ARRaycastResult? {
        let newPoint = CGPoint(x: center.x + CGFloat(x), y: center.y + CGFloat(y))

        let results = self.raycast(from: newPoint,
                                   // Better for pinning to planes
                                   allowing: .estimatedPlane,
                                   alignment: alignmentType)

        return results.first
    }
}

extension StitchARView: StitchCameraSession {
    @MainActor
    func stopRunning() {
        self.session.pause()
    }

    /*
     TODO: set camera orientation when using ARSession/ARView

     Have to look at eulerAngles ?
     Setting vs merely retrieving current rotation ?

     https://stackoverflow.com/questions/65908038/best-way-to-obtain-arkit-or-realitykit-camera-rotation?noredirect=1&lq=1

     https://stackoverflow.com/questions/68193399/what-is-the-difference-between-arview-session-currentframe-camera-transform-and

     https://medium.com/@ios_guru/arkit-and-arcamera-for-accessing-the-camera-information-in-an-ar-session-90d43ad9e2bd
     */

    @MainActor
    func configureSession(device: StitchCameraDevice,
                          position: AVCaptureDevice.Position,
                          cameraOrientation: StitchCameraOrientation) {
        let options: ARSession.RunOptions = [
            .resetTracking,
            .removeExistingAnchors,
            .resetSceneReconstruction,
            .stopTrackedRaycasts
        ]

        // Sets the session delegate
        if position == .back {
            let worldConfig = ARWorldTrackingConfiguration()
            worldConfig.planeDetection = [.horizontal, .vertical]
            worldConfig.userFaceTrackingEnabled = true

            // Must run on main thread
            self.session.run(worldConfig, options: options)
        } else if position == .front {
            let faceConfig = ARFaceTrackingConfiguration()
            faceConfig.isWorldTrackingEnabled = true

            // Must run on main thread
            self.session.run(faceConfig, options: options)
        }
    }
}

final class StitchARViewCaptureDelegate: NSObject, ARSessionDelegate, Sendable {
    @MainActor var convertedImage: UIImage?
    let cameraActor = CameraFeedActor()
    let iPhone: Bool
    
    @MainActor override init() {
        self.iPhone = GraphUIState.isPhoneDevice
        super.init()
        
        self.cameraActor.imageConverterDelegate = self
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let iPhone = self.iPhone
        
        // UIImage conversion moved to background thread for perf
        Task(priority: .high) { [weak self, weak frame] in
            guard let frame = frame else { return }
            
            await self?.cameraActor.createUIImage(from: frame,
                                                  iPhone: iPhone)
        }
    }
}

extension StitchARViewCaptureDelegate: ImageConverterDelegate {
    func imageConverted(image: UIImage) {
        image.accessibilityIdentifier = CAMERA_DESCRIPTION
        self.convertedImage = image
        
        dispatch(RecalculateCameraNodes())
    }
}
