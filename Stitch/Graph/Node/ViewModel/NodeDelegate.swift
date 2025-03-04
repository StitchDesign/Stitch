//
//  NodeDelegate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit

typealias NodeDelegate = NodeViewModel

extension NodeDelegate {
    @MainActor
    var defaultOutputs: PortValues {
        guard let values = self.kind.graphNode?.rowDefinitions(for: self.userVisibleType).outputs
            .map({ $0.value }),
              !values.isEmpty else {
            return []
        }
        
        return values
    }
    
    @MainActor
    var defaultOutputsList: PortValuesList {
        self.defaultOutputs.map { [$0] }
    }
    
    // USE THIS AS THE SOURCE OF TRUTH FOR A NODE VIEW MODEL'S INPUTS,
    // WHETHER NODE IS LAYER, PATCH, GROUP OR COMPONENT
    // ... except it's more efficient to use keyPaths to grab an input from a layer node ?
    
    /// Similar to `getAllInputsObservers` but gets unpacked layer observers if used.
    @MainActor func getAllInputsObservers(_ graph: GraphState) -> [InputNodeRowObserver] {
        
        switch self.nodeType {
        
        case .patch(let patch):
            return patch.inputsObservers
        
        // NOTE: if we're looking for a specific input, it's better to use keyPath access, see `getInputRowObserver`
        case .layer(let layer):
            return layer.getSortedInputPorts().flatMap { portObserver in
                // Grabs packed or unpacked data depending on what's used
                portObserver.allInputData.map { $0.rowObserver }
            }
            
        case .group(let group):
            return graph.visibleNodesViewModel.getSplitterInputRowObservers(for: self.id)
//            return canvas.inputViewModels.compactMap {
//                $0.rowDelegate
//            }
        
        case .component(let component):
            return component.inputsObservers
//            return component.canvas.inputViewModels.compactMap {
//                $0.rowDelegate
//            }
        }
    }
    
    @MainActor func getAllOutputsObservers(_ graph: GraphState) -> [OutputNodeRowObserver] {
        switch self.nodeType {
        case .patch(let patch):
            return patch.outputsObservers
        case .layer(let layer):
            return layer.outputPorts.map { $0.rowObserver }
        case .group(let canvas):
            return graph.visibleNodesViewModel.getSplitterOutputRowObservers(for: self.id)
//            return canvas.outputViewModels.compactMap {
//                $0.rowDelegate
//            }
        case .component(let component):
            return component.outputsObservers
//            return component.canvas.outputViewModels.compactMap {
//                $0.rowDelegate
//            }
        }
    }
    
    @MainActor
    func allInputRowViewModels(_ graph: GraphState) -> [InputNodeRowViewModel] {
        self.getAllInputsObservers(graph)
            .flatMap { $0.allRowViewModels }
    }
    
    @MainActor
    func allOutputRowViewModels(_ graph: GraphState) -> [OutputNodeRowViewModel] {
        self.getAllOutputsObservers(graph)
            .flatMap { $0.allRowViewModels }
    }
    
    @MainActor var patchNodeViewModel: PatchNodeViewModel? {
        switch self.nodeType {
        case .patch(let patchNode):
            return patchNode
        default:
            return nil
        }
    }
    
    @MainActor
    var layerNodeViewModel: LayerNodeViewModel? {
        switch self.nodeType {
        case .layer(let layerNode):
            return layerNode
        default:
            return nil
        }
    }
}
