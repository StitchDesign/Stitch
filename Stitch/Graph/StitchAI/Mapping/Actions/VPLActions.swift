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

typealias VPLLayerConcepts = [VPLLayerConcept]
typealias VPLLayerConceptOrderedSet = OrderedSet<VPLLayerConcept>

enum VPLLayerConcept: Equatable, Codable, Hashable {
    case layer(VPLLayer)
    case layerInputSet(VPLLayerInputSet)
    case incomingEdge(VPLIncomingEdge)
}

// create a layer, including its children
struct VPLLayer: Equatable, Codable, Hashable {
    let id: UUID
    let name: Layer
    let children: [VPLLayer]
}

/// A concrete, typed mapping from a SwiftUI modifier (or initialiser label)
/// to a value in the visual‑programming layer.
struct VPLLayerInputSet: Equatable, Codable, Hashable {
    let id: UUID // WHICH layer's layer input is being updated
    let input: LayerInputPort
    
    // TODO: JUNE 24: use PortValue instead of String; reuse parsing logic from StepAction parsing etc. ?
    // let value: PortValue  // literal the user entered
    let value: String  // literal the user entered
}

// an edge coming into the layer input
struct VPLIncomingEdge: Equatable, Codable, Hashable {
    let name: LayerInputPort // the input which is receiving the edge
}


// TODO: use something like this data structure instead for the PatchService ?
struct VPLLayerData: Equatable, Codable, Hashable {
    var trees: [VPLLayer]
    var setInputs: [VPLLayerInputSet]
}
