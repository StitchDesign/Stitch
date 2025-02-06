//
//  VideoFramerate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/17/21.
//

import ARKit
import AVFoundation
import SwiftUI
import UIKit
import StitchSchemaKit

// TODO: Revisit this with iPhone device orientation, which seems incorrect.
// TODO: Move this onto graph state rather than a node view; handle a camera as media state just like eg an audio player etc.
protocol StitchCameraSession: AnyObject, Sendable {
    var actor: CameraFeedActor { get }
    
    @MainActor func stopRunning()

    @MainActor
    func configureSession(device: StitchCameraDevice,
                          position: AVCaptureDevice.Position,
                          cameraOrientation: StitchCameraOrientation)

    @MainActor
    var currentImage: UIImage? { get }
}

final class CameraFeedManager: Sendable, MiddlewareService {

    // Keep this constant. Good way to ensure we don't create multiple instances
    let session: StitchCameraSession?

    // Tracks nodes with enabled camera to determine setup/teardown
//    var isEnabledInDocument: Bool = false {
//        didSet(oldValue) {
//            guard oldValue != isEnabledInDocument else {
//                // No change
//                return
//            }
//
//            if !isEnabledInDocument {
//                // Tear down if no nodes enabled camera
//                self.documentDelegate?.deactivateCamera()
//
//                DispatchQueue.main.async {
//                    dispatch(SingletonMediaTeardown(keyPath: \.cameraFeedManager))
//                }
//            }
//        }
//    }

    @MainActor weak var documentDelegate: StitchDocumentViewModel?

    @MainActor
    var currentCameraImage: UIImage? {
        self.session?.currentImage
    }

    @MainActor
    init(cameraSettings: CameraSettings,
         isEnabled: Bool,
         documentDelegate: StitchDocumentViewModel,
         isCameraFeedNode: Bool) {
        self.documentDelegate = documentDelegate

        if isEnabled {
            self.session = Self.createSession(cameraSettings: cameraSettings,
                                              isCameraFeedNode: isCameraFeedNode)
        } else {
            self.session = nil
        }

//        assertInDebug(!isEnabled ? !self.session.isDefined : self.session.isDefined)
    }

    var isRunning: Bool {
        self.session.isDefined
    }

    var arView: StitchARView? {
        self.session as? StitchARView
    }

    @MainActor
    static func createSession(cameraSettings: CameraSettings,
                              isCameraFeedNode: Bool) -> StitchCameraSession? {
        let cameraPosition = cameraSettings.direction.avCapturePosition
        
        guard let cameraPref = UserDefaults.standard.getCameraPref(position: cameraPosition) else {
            dispatch(ReceivedStitchFileError(error: .cameraDeviceNotFound))
            return nil
        }
        
        return Self.createSession(device: cameraPref,
                                  position: cameraPosition,
                                  cameraOrientation: cameraSettings.orientation,
                                  isCameraFeedNode: isCameraFeedNode)
    }

    // This needs to be called before changing direction of camera
    @MainActor
    static func createSession(device: StitchCameraDevice,
                              position: AVCaptureDevice.Position,
                              cameraOrientation: StitchCameraOrientation,
                              isCameraFeedNode: Bool) -> StitchCameraSession {

        // Only use AR if supported by device and the camera is from a RealityView layer node (not a CameraFeed patch node)
        // MARK: isCameraFeedNode is a necessary check to prevent crashes on iPad
        let useAR = device.isARSupported && !isCameraFeedNode

        // Must get called on main thread
        let session: StitchCameraSession = useAR ? StitchARView() : StitchAVCaptureSession()

        session.actor.startCamera(session: session,
                          device: device,
                          position: position,
                          cameraOrientation: cameraOrientation) {
            if !useAR {
                guard let session = session as? StitchAVCaptureSession else {
                    fatalErrorIfDebug()
                    return
                }
                
                // AV capture session must run on background thread;
                // nothing to do here for ARView
                Task.detached(priority: .high) { [weak session] in
                    log(session?.cameraSession.isRunning)
                    session?.cameraSession.startRunning()
                }
            }
        }

        return session
    }

    @MainActor
    func stopCamera() {
        self.session?.stopRunning()
    }
}

struct CameraFeedNodeDeleted: GraphEvent {
    let nodeId: NodeId

    func handle(state: GraphState) {
        state.enabledCameraNodeIds.remove(nodeId)
    }
}
