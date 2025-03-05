//
//  NodeViewModelNodeCalculatable.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation
import SwiftUI
import StitchEngine
import StitchSchemaKit

extension NodeViewModel: NodeCalculatable {
    typealias NodeMediaEphemeralObservable = MediaViewModel
    
    var inputsObservers: [InputNodeRowObserver] {
        get {
            self.getAllInputsObservers()
        }
        set(newValue) {
            self.patchNode?.inputsObservers = newValue
        }
    }
    
    var outputsObservers: [OutputNodeRowObserver] {
        get {
            self.getAllOutputsObservers()
        }
        set(newValue) {
            self.patchNode?.outputsObservers = newValue
        }
    }
    
    @MainActor
    func getMediaObservers() -> [MediaViewModel]? {
        if let layerNode = self.layerNode {
            return layerNode.previewLayerViewModels.map { $0.mediaViewModel }
        }
        
        if let mediaEvalOpObservers = self.ephemeralObservers as? [MediaEvalOpViewable] {
            return mediaEvalOpObservers.map(\.mediaViewModel)
        }
        
        return nil
    }
    
    @MainActor
    var isComponentOutputSplitter: Bool {
        let isNodeInComponent = !(self.graphDelegate?.saveLocation.isEmpty ?? true)
        return self.splitterType == .output && isNodeInComponent
    }
        
    @MainActor
    var inputsValuesList: PortValuesList {
        switch self.nodeType {
        case .patch(let patch):
            return patch.inputsObservers.map { $0.allLoopedValues }
        case .layer(let layer):
            return layer.getSortedInputPorts().map { inputPort in
                inputPort.allLoopedValues
            }
        case .group(let canvas):
            return canvas.inputViewModels.compactMap {
                $0.rowDelegate?.allLoopedValues
            }
        case .component(let componentData):
            return componentData.canvas.inputViewModels.compactMap {
                $0.rowDelegate?.allLoopedValues
            }
        }
    }
    
    /*
     After we eval a node, we sets its current inputs to be its previous inputs,
     so that we know we've run the node once,
     and so that we won't run the node again until at least one of the inputs has changed
    
     If unable to run eval for a node (e.g. because it is one of the layer nodes that does not support node eval),
     return `nil` rather than an empty list of inputs.
     */
    @MainActor func evaluate() -> EvalResult? {
        switch self.nodeType {
        case .patch(let patchNodeViewModel):
            // NodeKind.evaluate is our legacy eval caller, cheeck for those first
            if let eval = patchNodeViewModel.patch.evaluate {
                return eval.runEvaluation(
                    node: self
                )
            }

            // New-style eval which doesn't require filling out a switch statement
            guard let nodeType = self.kind.graphNode else {
                fatalErrorIfDebug()
                return nil
            }
            
            return nodeType.evaluate(node: self)
        
        case .layer(let layerNodeViewModel):
            // Only a handful of layer nodes have node evals
            if let eval = layerNodeViewModel.layer.evaluate {
                return eval.runEvaluation(
                    node: self
                )
            } else {
                return nil
            }
            
        case .component(let component):
            return component.evaluate()
            
        case .group:
            fatalErrorIfDebug()
            return nil
        }
    }
    
    @MainActor
    func inputsWillUpdate(values: PortValuesList) {
        // update cache for longest loop length
        self.longestLoopLength = self.kind.determineMaxLoopCount(from: values)
        
        // Updates preview layers if layer specified
        // Must be before runEval check below since most layers don't have eval!
        self.layerNode?.didValuesUpdate(newValuesList: values)
    }
    
    @MainActor
    var isGroupNode: Bool {
        self.kind == .group
    }
}
