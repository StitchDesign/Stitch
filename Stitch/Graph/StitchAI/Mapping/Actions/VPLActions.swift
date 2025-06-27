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

// Data associated with a layer; usually values
// e.g. `SyntaxViewName.vStack` corresponds to `Layer.group` + `LayerInputPort.orientation = .vertical`
//struct VPLLayerSettings: Equatable, Codable, Hashable {
//}

// Maybe better to just have the `deriveLayer` function return `(VPLLayer, VPLLayerInputSet)`

typealias VPLLayerDerivationResult = (
    
    // the layer created from code
    layer: VPLLayer,
    
    // the value or edge required for creating the layer from code
    valueOrEdges: [VPLLayerConcept]
)


//enum VPLLayerDerivationResult: Equatable, Codable, Hashable {
//    
//    // a layer group always needs an orientation
//    // SwiftUI code -> Stitch layer.group + orientation input
//    case group(orientation: StitchOrientation)
//    
//    // SwiftUI RoundedRectangle -> Stitch layer.rectangle + cornerRadius input
//    // TODO: what about `cornerSize: CGSize` ?
//    case roundedRectangle(cornerRadius: CGFloat)
//    
//    // A simple
//    case simple(Layer)
//    
//    var layer: Layer {
//        switch self {
//        case .group: return .group
//        case .roundedRectangle: return .rectangle
//        case .simple(let x): return x
//        }
//    }
//}

//extension VPLLayerDerivationResult {
//    func deriveActions() -> [VPLLayerConcept] {
//        // layer becomes a VPLLayer
//        [
//            .layer(.init(id: <#T##UUID#>, name: <#T##Layer#>, children: <#T##[VPLLayer]#>))
//        ]
//    }
//}

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
    let value: PortValue  // literal the user entered
//    let value: String  // literal the user entered
}

// an edge coming into the layer input
struct VPLIncomingEdge: Equatable, Codable, Hashable {
    let name: LayerInputPort // the input which is receiving the edge
}


//// TODO: use something like this data structure instead for the PatchService ?
//struct VPLLayerResult: Equatable, Codable, Hashable {
//    var trees: [VPLLayer]
//    var setInputs: [VPLLayerInputSet]
//}
