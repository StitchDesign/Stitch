//
//  DevDebugUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/17/22.
//

#if DEV_DEBUG

import Foundation
import SwiftUI
import StitchSchemaKit

let sampleVideoResourceName: String = "sample_video" // .mov

let sampleVideoMediaURL = MediaKey(filename: sampleVideoResourceName, fileExtension: "mov")

// let sampleVideoMediaFile = StitchMediaFile(sampleVideoMediaURL)

// let sampleVideoMediaFile: StitchMediaFile =
//    StitchMediaFile(bundledResourceName: sampleVideoResourceName, bundledResourceExtension: "mov")

let sampleVideoDuration: Double = 2.5 // approximate

let sampleVideoMetadata: VideoMetadata = VideoMetadata(playing: true)

let DEFAULT_VIDEO_URL = bundledResourceURL(sampleVideoResourceName, "mov")

/// Used to create test file testing all patch nodes for versioning purposes.
// func createAllPatchNodes(state: ProjectState) -> ProjectState {
//    var state = state
//    let allPatches = Patch.allCases
//
//    allPatches.forEach { patch in
//        state = createNode(state: state,
//                           graphStep: GraphStepState(),
//                           choice: .patch(patch),
//                           center: .zero)
//    }
//
//    return state
// }

///// Used to create test file testing all layer nodes for versioning purposes.
// func createAllLayerNodes(state: ProjectState) -> ProjectState {
//    var state = state
//    let allLayers = Layer.allCases
//
//    allLayers.forEach { layer in
//        // Ignore group layer
//        if layer != .group {
//            state = createNode(state: state,
//                               graphStep: GraphStepState(),
//                               choice: .layer(layer),
//                               center: .zero)
//        }
//    }
//
//    return state
// }

// MARK: - Audio

let sampleAudioResourceName = "fur_elise"

let sampleAudioMediaFile = MediaKey(filename: sampleAudioResourceName,
                                    fileExtension: "m4a")

func defaultStitchAudioURL() -> URL {
    bundledResourceURL(sampleAudioResourceName, "m4a")
}

let DEFAULT_SOUNDFILE_URL: URL = defaultStitchAudioURL()

/// Creates a sample project with 50 connected add nodes. Used for perf testing purposes.
// func create50AddNodesProject() -> ProjectSchema {
//    // Create graph
//    var nodes = NodeSchemaList()
//    var connections = Connections()
//
//    var positionIncrement = CGSize(width: 1000, height: 1000)
//    for _ in 0..<50 {
//        var newNode = addPatchNode()
//        newNode.position = positionIncrement
//        newNode.previousPosition = positionIncrement
//
//        if let prevNode = nodes.last {
//            let inputCoordinate = prevNode.instance.inputs.first.coordinate
//            let outputCoordinate = newNode.computedState.outputs.first.coordinate
//            connections.updateValue(Set([inputCoordinate]), forKey: outputCoordinate)
//        }
//
//        nodes.append(VersionableContainer(instance: newNode.schema))
//
//        positionIncrement = CGSize(width: positionIncrement.width - 50, height: positionIncrement.height - 50)
//    }
//
//    let patchNodes = PatchNodeSchemas(nodes: nodes)
//    let versionedPatchNodes = VersionableContainer(instance: patchNodes)
//    let graphSchema = GraphSchema(patchNodes: versionedPatchNodes, connections: connections)
//
//    // Create project from graph
//    let projectSchema = ProjectSchema(metadata: ProjectMetadata(name: "50 Add Nodes"), schema: graphSchema)
//    return projectSchema
// }

#endif
