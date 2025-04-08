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
final class StitchARView: NSObject {
    // Identifier used to compare AR View instances since many can be created
    let id = UUID()
    
    let arView: ARView
    
    let actor = CameraFeedActor()

    // For camera session delegate
    @MainActor var currentImage: UIImage? {
        self.bufferDelegate.convertedImage
    }
    
    @MainActor
    var bufferDelegate = StitchARViewCaptureDelegate()

    // Non-zero rect import for preventing warning that sometimes appears
    @MainActor
    init(frame: CGRect = .init(x: .zero, y: .zero, width: 100, height: 100),
         cameraMode: ARView.CameraMode = .ar) {
        self.arView = .init(frame: frame,
                            cameraMode: cameraMode,
                            automaticallyConfigureSession: false)

        self.arView.session.delegate = self.bufferDelegate

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
            self.arView.environment.background = .color(.clear)
        case .nonAR:
            // Make static view for non AR
            if let snapshotView = self.arView.snapshotView(afterScreenUpdates: false) {
                self.arView.addSubview(snapshotView)
            }

            // Environment can be used for lighting effects for AR stuff
            self.arView.environment.background = .color(.clear)
        default:
            if let snapshotView = self.arView.snapshotView(afterScreenUpdates: false) {
                self.arView.addSubview(snapshotView)
            }

            self.arView.environment.background = .color(.clear)
        }
    }

    @MainActor
    func makeRaycast(alignmentType: ARRaycastQuery.TargetAlignment,
                     center: CGPoint,
                     x: Float,
                     y: Float) -> ARRaycastResult? {
        let newPoint = CGPoint(x: center.x + CGFloat(x), y: center.y + CGFloat(y))

        let results = self.arView.raycast(from: newPoint,
                                          // Better for pinning to planes
                                          allowing: .estimatedPlane,
                                          alignment: alignmentType)

        return results.first
    }
}

extension StitchARView: StitchCameraSession {
    @MainActor
    func stopRunning() {
        self.arView.session.pause()
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
            self.arView.session.run(worldConfig, options: options)
        } else if position == .front {
            let faceConfig = ARFaceTrackingConfiguration()
            faceConfig.isWorldTrackingEnabled = true

            // Must run on main thread
            self.arView.session.run(faceConfig, options: options)
        }
    }
}

final class StitchARViewCaptureDelegate: NSObject, ARSessionDelegate, Sendable {
    @MainActor var convertedImage: UIImage?
    let cameraActor = CameraFeedActor()
    let iPhone: Bool
    
    @MainActor override init() {
        self.iPhone = StitchDocumentViewModel.isPhoneDevice
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
