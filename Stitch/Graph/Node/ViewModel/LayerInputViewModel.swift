//
//  LayerInputViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/24.
//

import Foundation
import StitchSchemaKit

// Unlike the inputs on a patch or group node,
// the individual inputs of a layer node can be added to a graph (canvas), dragged etc.

@Observable
final class LayerInputViewModel {
    let id: InputCoordinate // really, can only be (nodeId, layerInputType)
    
    var input: NodeRowObserver
    var canvasUIData: CanvasItemViewModel
    
    init(id: InputCoordinate, 
         input: NodeRowObserver,
         canvasUIData: CanvasItemViewModel) {
        self.id = id
        self.input = input
        self.canvasUIData = canvasUIData
    }
    
    convenience init(input: NodeRowObserver,
                     canvasUIData: CanvasItemViewModel) {
        self.init(id: input.id,
                  input: input,
                  canvasUIData: canvasUIData)
    }
}

@Observable
final class NodeDataViewModel {
    // Needed for e.g. group nodes, since a group node may not have an input or output that we can query
    let id: NodeId
    
    var canvasUIData: CanvasItemViewModel
    
    init(id: NodeId, 
         canvasUIData: CanvasItemViewModel) {
        self.id = id
        self.canvasUIData = canvasUIData
    }
    
//    private var _inputsObservers: NodeRowObservers = []
//    private var _outputsObservers: NodeRowObservers = []
//        
//    init(id: NodeId, 
//         inputs: NodeRowObservers,
//         outputs: NodeRowObservers) {
//        self.id = id
//        self._inputsObservers = inputs
//        self._outputsObservers = outputs
//    }
}
