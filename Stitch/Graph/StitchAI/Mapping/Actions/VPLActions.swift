//
//  VPLActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import StitchSchemaKit
import OrderedCollections


// MARK: 'actions' just in the sense of being something our VPL can consume

typealias VPLActions = [VPLAction]
typealias VPLActionOrderedSet = OrderedSet<VPLAction>


enum VPLAction: Equatable, Codable, Hashable {
    case layer(VPLCreateNode)
    case layerInputSet(VPLSetInput)
    case incomingEdge(VPLCreateEdge)
}

// create a layer, including its children
struct VPLCreateNode: Equatable, Codable, Hashable {
    let id: UUID
    let name: Layer
    let children: [VPLCreateNode]
}

/// A concrete, typed mapping from a SwiftUI modifier (or initialiser label)
/// to a value in the visual‑programming layer.
struct VPLSetInput: Equatable, Codable, Hashable {
    let id: UUID // WHICH layer's layer input is being updated
    let input: LayerInputPort
    
    // TODO: JUNE 24: use PortValue instead of String; reuse parsing logic from StepAction parsing etc. ?
    let value: PortValue  // literal the user entered
//    let value: String  // literal the user entered
}

// an edge coming into the layer input
struct VPLCreateEdge: Equatable, Codable, Hashable {
    let name: LayerInputPort // the input which is receiving the edge
}


//// TODO: use something like this data structure instead for the PatchService ?
//struct VPLLayerResult: Equatable, Codable, Hashable {
//    var trees: [VPLLayer]
//    var setInputs: [VPLLayerInputSet]
//}
