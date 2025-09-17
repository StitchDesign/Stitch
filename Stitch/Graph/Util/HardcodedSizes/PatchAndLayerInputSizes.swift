//
//  PatchAndLayerInputSizes.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/23/25.
//

import Foundation
import SwiftUI

typealias PatchSizes = [Patch: [NodeType?: CGSize]]
typealias LayerInputSizes = [LayerInputPort: CGSize]

extension CGSize {
    // A layer input-fields on the canvas are a single size
    static let ASSUMED_LAYER_FIELD_SIZE: CGSize = .init(width: 200, height: 120)
    static let ASSUMED_LAYER_OUTPUT_SIZE: CGSize = .init(width: 300, height: 200)
}

struct PatchOrLayerSizes {
    static let patches: PatchSizes = CANVAS_SIZES_FOR_PATCH_BY_NODE_TYPE
    static let layerInputs: LayerInputSizes = LAYER_INPUT_SIZES_FOR_LAYER_INPUT_PORT
    static let layerFieldSize: CGSize = .ASSUMED_LAYER_FIELD_SIZE
    static let layerOutputSize: CGSize = .ASSUMED_LAYER_OUTPUT_SIZE
}

extension CanvasItemViewModel {
    @MainActor
    func getHardcodedSize(_ graph: GraphReader) -> CGSize? {
        
        switch self.id {
        
        case .node(let nodeId):
            if let patchNode = graph.getNode(nodeId)?.patchNode {
                return PatchOrLayerSizes.patches[patchNode.patch]?[patchNode.userVisibleType]
            } else {
                return nil
            }
        
        case .layerInput(let layerInputCoordinate):
            switch layerInputCoordinate.keyPath.portType {
            case .packed:
                return PatchOrLayerSizes.layerInputs[layerInputCoordinate.keyPath.layerInput]
            case .unpacked:
                return PatchOrLayerSizes.layerFieldSize
            }
            
        case .layerOutput(_):
            return PatchOrLayerSizes.layerOutputSize
        }
    }
}

