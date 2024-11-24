//
//  CameraActions.swift
//  prototype
//
//  Created by Elliot Boschwitz on 12/5/21.
//

import SwiftUI
import AVFoundation
import StitchSchemaKit

/// Updates UI for all camera nodes to reflect declined camera permissions.
struct CameraPermissionDeclined: GraphEvent {
    func handle(state: GraphState) {
        state.updateAllCameras(with: .bool(false),
                               at: CameraFeedNodeInputLocations.cameraEnabled)
    }
}

extension GraphState {
    // Updates fields with new camera direction
    @MainActor
    func updateAllCameras(with value: PortValue,
                          at inputIndex: Int) {
        // Search for all camera feed nodes AND RealityView nodes
        let cameraFeedNodes = self.nodes.values
            .filter {
                $0.kind == .patch(.cameraFeed) ||
                    $0.kind == .layer(.realityView)
            }

        // Update all camera nodes
        cameraFeedNodes.forEach { node in
            let coordinate = InputCoordinate(portId: inputIndex, nodeId: node.id)
            self.handleInputEditCommitted(
                input: coordinate,
                value: value,
                // TODO: is this accurate? Can we change camera direction via any of the layers (i.e. via layer inspector)?
                isFieldInsideLayerInspector: false)
        }
    }
}

/// Responds to new user-selected camera in app settings.
/// This is only an effect because we don't expect any current camera session running, given that app settings
/// are at the home screen.
struct CameraPreferenceChanged: AppEvent {
    let cameraId: String

    func handle(state: AppState) -> AppResponse {
        let effect = newCameraSelectedEffect(cameraId: cameraId)
        return .effectOnly(effect)
    }
}

/// Effect that's used to save new camera preference to `UserDefaults`.
func newCameraSelectedEffect(cameraId: String) -> Effect {
    {
        // First save new setting to user defaults before updating CameraFeedManager
        switch UserDefaults.standard.saveCameraPref(cameraID: cameraId) {
        case .success:
            return NoOp()
        case .failure(let error):
            return ReceivedStitchFileError(error: error)
        }
    }
}

extension StitchDocumentViewModel {
    /// Update GraphSchema.CameraSettings and MediaManager after a Camera Feed Node's camera-orientation input received a new orientation value.
    @MainActor
    func cameraOrientationUpdated(input: InputCoordinate,
                                  graph: GraphDelegate,
                                  cameraOrientation: StitchCameraOrientation) {
        
        guard cameraOrientation != self.cameraSettings.orientation else {
            log("CameraOrientationUpdated: already using cameraOrientation \(cameraOrientation); will exit early")
            return
        }
        
        guard let node = graph.getNodeViewModel(input.nodeId),
              node.kind.usesCamera else {
            log("CameraOrientationUpdated: the updated input was not on a camera node; will exit early")
            return
        }
        
        log("CameraOrientationUpdated: cameraOrientation: \(cameraOrientation)")
        
        // Update graph schema's camera settings
        self.cameraSettings.orientation = cameraOrientation
        
        self.refreshCamera(for: node.kind,
                           graph: graph)
    }
    
    @MainActor
    func refreshCamera(for nodeKind: NodeKind,
                       graph: GraphDelegate,
                       newNode: NodeId? = nil) {
        // Update camera in media manager
        let cameraFeed = self.createCamera(for: nodeKind,
                                           graph: graph,
                                           newNode: newNode)
        self.cameraFeedManager = .loaded(.cameraFeedManager(cameraFeed))
    }

    @MainActor
    func createCamera(for nodeKind: NodeKind,
                      graph: GraphDelegate,
                      newNode: NodeId? = nil) -> CameraFeedManager {
        if let newNode = newNode {
            graph.enabledCameraNodeIds.insert(newNode)
        }

        // Reset camera
        if self.cameraFeedManager != nil {
            self.deactivateCamera()
        }

        let cameraFeed = CameraFeedManager(cameraSettings: self.cameraSettings,
                                           isEnabled: true,
                                           isCameraFeedNode: nodeKind == .patch(.cameraFeed),
                                           documentDelegate: self)
        return cameraFeed
    }

    @MainActor
    func cameraDirectionUpdated(input: InputCoordinate,
                                graph: GraphDelegate,
                                cameraDirection: CameraDirection) {
        guard cameraDirection != self.cameraSettings.direction else {
            log("CameraDirectionUpdated: already using cameraDirection \(cameraDirection); will exit early")
            return
        }
        
        guard let node = graph.getNodeViewModel(input.nodeId),
              node.kind.usesCamera else {
            log("CameraDirectionUpdated: the updated input was not on a camera node; will exit early")
            return
        }
        
        log("CameraDirectionUpdated: cameraDirection: \(cameraDirection)")
        
        // Update graph schema's camera settings
        self.cameraSettings.direction = cameraDirection
        
        // Update camera in media manager
        self.refreshCamera(for: node.kind,
                           graph: graph)
    }
    
    @MainActor
    func cameraInputChange(input: InputCoordinate,
                           originalValue: PortValue,
                           coercedValue: PortValue) {
        
        self.allGraphs.forEach { graph in
            switch originalValue {
                
            case .cameraOrientation(let x):
                if let y = coercedValue.getCameraOrientation,
                   x != y {
                    self.cameraOrientationUpdated(
                        input: input,
                        graph: graph,
                        cameraOrientation: y)
                }
            case .cameraDirection(let x):
                if let y = coercedValue.getCameraDirection,
                   x != y {
                    self.cameraDirectionUpdated(
                        input: input,
                        graph: graph,
                        cameraDirection: y)
                }
            default:
                break
            }
        }
    }
    
    @MainActor
    func deactivateCamera() {
        self.cameraFeedManager?.loadedInstance?.cameraFeedManager?.stopCamera()
        self.cameraFeedManager = nil
    }
}

extension NodeKind {
    var usesCamera: Bool {
        self == .patch(.cameraFeed) || self == .layer(.realityView)
    }

    var shouldClearMediaOnEdgeDisconnect: Bool {
        switch self {
        case .layer(.video), .layer(.model3D), .patch(.speaker):
            return true
        default:
            return false
        }
    }
}

