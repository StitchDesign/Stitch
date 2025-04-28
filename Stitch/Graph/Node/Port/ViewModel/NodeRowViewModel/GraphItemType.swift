//
//  GraphItemType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation


// Used to distinguish whether a row view model is for canvas vs inspector
// TODO: separate row view model
enum GraphItemType: Hashable {
    case canvas(CanvasItemId) // i.e. canvas
    
    // Passing in layer input type ensures uniqueness of IDs in inspector
    case layerInspector(NodeIOPortType) // portId (layer output) or layer-input-type (layer input)
}

extension GraphItemType {
    static let empty: Self = .layerInspector(.keyPath(.init(layerInput: .size,
                                                            portType: .packed)))
    
    var getCanvasItemId: CanvasItemId? {
        switch self {
        case .canvas(let x):
            return x
        default:
            return nil
        }
    }
    
    var isLayerInspector: Bool {
        switch self {
        case .layerInspector:
            return true
        default:
            return false
        }
    }
    
    var layerInputPort: LayerInputPort? {
        switch self {
        case .canvas(let canvasItemId):
            return canvasItemId.layerInputCase?.keyPath.layerInput
        case .layerInspector(let nodeIOPortType):
            return nodeIOPortType.keyPath?.layerInput
        }
    }
    
    var getLayerInputCoordinateOnGraph: LayerInputCoordinate? {
        switch self {
        case .canvas(let x):
            switch x {
            case .layerInput(let x):
                return x
            default:
                return nil
            }
        default:
            return nil
        }
    }
}
