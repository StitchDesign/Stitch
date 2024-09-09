//
//  CameraFeedNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/18/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import AVFoundation

struct CameraFeedNodeInputLocations {
    static let cameraEnabled = 0
    static let cameraDirection = 1
    static let cameraOrientation = 2
}

// e.g. AVCaptureDevice.Position.front
extension CameraDirection: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.cameraDirection
    }

    static let defaultCameraDirection: Self = .front

    var display: String {
        switch self {
        case .front:
            return "Front"
        case .back:
            return "Back"
        }
    }

    var avCapturePosition: AVCaptureDevice.Position {
        switch self {
        case .front:
            return .front
        case .back:
            return .back
        }
    }
}

// Camera feed patch node has a single 'image' output,
// which is updated at eg 30 FPS,
// creating a video.
struct CameraFeedPatchNode: PatchNodeDefinition {
    static let patch = Patch.cameraFeed

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.bool(true)],
                    label: "Enable"
                ),
                .init(
                    defaultValues: [.cameraDirection(.front)],
                    label: "Camera"
                ),
                .init(
                    defaultValues: [.cameraOrientation(.landscapeRight)],
                    label: "Orientation"
                )
            ],
            outputs: [
                .init(
                    label: "Stream",
                    type: .media
                ),
                .init(
                    label: LayerInputPort.size.label(),
                    type: .size
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        SingletonMediaNodeCoordinator()
    }
}

@MainActor
func createCameraFeedManager(document: StitchDocumentViewModel,
                             graph: GraphDelegate,
                             nodeId: NodeId) -> StitchSingletonMediaObject {
    let _node = graph.getNodeViewModel(nodeId)
    assertInDebug(_node != nil)
    let node = _node ?? .createEmpty()
    let nodeKind = node.kind
    
    let camera = document.createCamera(for: nodeKind,
                                       graph: graph,
                                       newNode: node.id)
    return .cameraFeedManager(camera)
}

/// Logic that checks if we can run the eval for some camera node or if we should tear down this camera.
/// Used by the camera feed and raycast nodes.
@MainActor
func cameraManagerEval(node: PatchNode,
                       graph: GraphDelegate,
                       document: StitchDocumentViewModel,
                       cameraEnabledInputIndex: Int,
                       mediaOp: @escaping AsyncSingletonMediaEvalOp) -> ImpureEvalResult {
    // Check if any instance is enabled
    let isNodeEnabled = node.inputs[safe: cameraEnabledInputIndex]?
        .compactMap { $0.getBool }
        .contains(where: { $0 }) ?? false

    // If node doesn't contain any inputs marking enabled, send info to CameraFeedManager
    // to possibly tear down camera
    guard isNodeEnabled else {
        if graph.enabledCameraNodeIds.contains(node.id) {
            graph.enabledCameraNodeIds.remove(node.id)
        }

        // Better: returns two separate outputs, where each output does not contain a loop
        return ImpureEvalResult(
            outputsValues: [
                [mediaDefault],
                [.size(.zero)]
            ])
    }
    
    if isNodeEnabled && !graph.enabledCameraNodeIds.contains(node.id) {
        graph.enabledCameraNodeIds.insert(node.id)
    }

    return asyncSingletonMediaEval(node: node,
                                   graph: graph,
                                   mediaCreation: createCameraFeedManager,
                                   mediaManagerKeyPath: \.cameraFeedManager,
                                   mediaOp: mediaOp)
    .toImpureEvalResult()
}

@MainActor
func cameraFeedEval(node: PatchNode,
                    graph: GraphDelegate) -> ImpureEvalResult {
    guard let document = graph.documentDelegate else {
        fatalErrorIfDebug()
        return .noChange(node)
    }
    
    return cameraManagerEval(node: node,
                             graph: graph,
                             document: document,
                             cameraEnabledInputIndex: 0) { values, _, loopIndex in
        
        guard !document.isGeneratingProjectThumbnail else {
            log("cameraFeedEval: generating project thumbnail, so will not use camera image")
            return node.defaultOutputs
        }
        
        guard let isEnabled = values.first?.getBool else {
            log("cameraFeedEval: issue decoding values")
            return node.defaultOutputs
        }
        
        guard isEnabled else {
            return node.defaultOutputs
        }
        
        guard let currentCamearaImage = document.cameraFeed?.currentCameraImage else {
            return node.defaultOutputs
        }
        
        let newId = UUID()
        
        return [
            .asyncMedia(AsyncMediaValue(id: newId,
                                        dataType: .computed,
                                        mediaObject: .image(currentCamearaImage))),
            .size(currentCamearaImage.layerSize)
        ]
    }
}
