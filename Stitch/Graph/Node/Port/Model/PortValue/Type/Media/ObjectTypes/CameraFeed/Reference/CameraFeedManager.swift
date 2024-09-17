//
//  VideoFramerate.swift
//  prototype
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
    func startRunning()
    func stopRunning()

    func configureSession(device: StitchCameraDevice,
                          position: AVCaptureDevice.Position,
                          cameraOrientation: StitchCameraOrientation)

    @MainActor
    var currentImage: UIImage? { get }
}

final class CameraFeedManager: Sendable, MiddlewareService {
    // we need to do some work asynchronously
    //    private let sessionQueue = DispatchQueue(label: "session queue")
    let actor = CameraFeedActor()

    // Keep this constant. Good way to ensure we don't create multiple instances
    let session: StitchCameraSession?

    // Tracks nodes with enabled camera to determine setup/teardown
    var enabledNodeIds = Set<NodeId>() {
        didSet(oldValue) {
            guard oldValue != enabledNodeIds else {
                // No change
                return
            }

            if enabledNodeIds.isEmpty {
                // Tear down if no nodes enabled camera
                self.documentDelegate?.deactivateCamera()

                DispatchQueue.main.async {
                    dispatch(SingletonMediaTeardown(keyPath: \.cameraFeedManager))
                }
            }
        }
    }

    weak var documentDelegate: StitchDocumentViewModel?

    @MainActor
    var currentCameraImage: UIImage? {
        self.session?.currentImage
    }

    @MainActor
    init(cameraSettings: CameraSettings,
         enabledNodeIds: Set<NodeId>,
         isCameraFeedNode: Bool,
         documentDelegate: StitchDocumentViewModel) {
        let isEnabled = !enabledNodeIds.isEmpty

        self.enabledNodeIds = enabledNodeIds
        self.documentDelegate = documentDelegate

        if isEnabled {
            self.session = Self.createSession(cameraSettings: cameraSettings,
                                              isCameraFeedNode: isCameraFeedNode,
                                              actor: self.actor)
        } else {
            self.session = nil
        }

        #if DEBUG
        assert(enabledNodeIds.isEmpty ? !self.session.isDefined : self.session.isDefined)
        #endif
    }

    var isRunning: Bool {
        self.session.isDefined
    }

    var arView: StitchARView? {
        self.session as? StitchARView
    }

    @MainActor
    static func createSession(cameraSettings: CameraSettings,
                              isCameraFeedNode: Bool,
                              actor: CameraFeedActor) -> StitchCameraSession {
        let cameraPosition = cameraSettings.direction.avCapturePosition
        let cameraPref = UserDefaults.standard.getCameraPref(position: cameraPosition)
        return Self.createSession(device: cameraPref,
                                  position: cameraPosition,
                                  cameraOrientation: cameraSettings.orientation,
                                  isCameraFeedNode: isCameraFeedNode,
                                  actor: actor)
    }

    // This needs to be called before changing direction of camera
    @MainActor
    static func createSession(device: StitchCameraDevice,
                              position: AVCaptureDevice.Position,
                              cameraOrientation: StitchCameraOrientation,
                              isCameraFeedNode: Bool,
                              actor: CameraFeedActor) -> StitchCameraSession {

        // Only use AR if supported by device and the camera is from a RealityView layer node (not a CameraFeed patch node)
        let useAR = device.isARSupported && !isCameraFeedNode

        // Must get called on main thread
        let session: StitchCameraSession = useAR ? StitchARView() : StitchAVCaptureSession(actor: actor)

        Task { [weak actor, weak session] in
            guard let _session = session else {
                return
            }

            await actor?.startCamera(session: _session,
                                     device: device,
                                     position: position,
                                     cameraOrientation: cameraOrientation)
        }

        return session
    }

    func stopCamera() {
        self.session?.stopRunning()
    }
}

struct CameraFeedNodeDeleted: StitchDocumentEvent {
    let nodeId: NodeId

    func handle(state: StitchDocumentViewModel) {
        state.removeCameraNode(id: nodeId)
    }
}

extension StitchDocumentViewModel {
    func removeCameraNode(id: NodeId) {
        self.cameraFeedManager?.loadedInstance?.cameraFeedManager?.enabledNodeIds.remove(id)
    }
}
