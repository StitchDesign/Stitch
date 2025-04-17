//
//  NodeViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit


extension NodeViewModel {
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
   
    /// Retrieves GroupNode's underlying input-splitters
    @MainActor func getAllInputsObserversForUI(_ graph: GraphState) -> [InputNodeRowObserver] {
        switch self.nodeType {
        case .patch(let patch):
            return patch.inputsObservers
        case .layer(let layer):
            return layer.getSortedInputPorts().flatMap { portObserver in
                // Grabs packed or unpacked data depending on what's used
                portObserver.allInputData.map { $0.rowObserver }
            }
        case .group(let canvas):
            return graph.visibleNodesViewModel.getSplitterInputRowObservers(for: self.id)
        case .component(let component):
            return component.inputsObservers
        }
    }
    
    /// Similar to `getAllInputsObservers` but gets unpacked layer observers if used.
    /// Retrieve inputs for patch, layers or components. Not intented for group nodes.
    @MainActor func getAllInputsObservers() -> [InputNodeRowObserver] {
        switch self.nodeType {
        case .patch(let patch):
            return patch.inputsObservers
        case .layer(let layer):
            return layer.getSortedInputPorts().flatMap { portObserver in
                // Grabs packed or unpacked data depending on what's used
                portObserver.allInputData.map { $0.rowObserver }
            }
        case .group(let canvas):
//            fatalErrorIfDebug("Attempted to retrieve a row observer for a GroupNode input")
            return canvas.inputViewModels.compactMap {
                $0.rowDelegate
            }
        case .component(let component):
            return component.inputsObservers
        }
    }
    
    /// Retrieves GroupNode's underlying output-splitters
    @MainActor func getAllOutputsObserversForUI(_ graph: GraphState) -> [OutputNodeRowObserver] {
        switch self.nodeType {
        case .patch(let patch):
            return patch.outputsObservers
        case .layer(let layer):
            return layer.outputPorts.map { $0.rowObserver }
        case .group:
            return graph.visibleNodesViewModel.getSplitterOutputRowObservers(for: self.id)
        case .component(let component):
            return component.outputsObservers
        }
    }
    
    /// Retrieve outputs for patch, layers or components. Not intented for group nodes.
    @MainActor func getAllOutputsObservers() -> [OutputNodeRowObserver] {
        switch self.nodeType {
        case .patch(let patch):
            return patch.outputsObservers
        case .layer(let layer):
            return layer.outputPorts.map { $0.rowObserver }
        case .group(let canvas):
            //            fatalErrorIfDebug("Attempted to retrieve a row observer for a GroupNode output")
            //             log("Attempted to retrieve a row observer for a GroupNode output")
            return canvas.outputViewModels.compactMap {
                $0.rowDelegate
            }
        case .component(let component):
            return component.outputsObservers
        }
    }
    
    
    @MainActor
    var allInputRowViewModels: [InputNodeRowViewModel] {
        self.getAllInputsObservers()
            .flatMap { $0.allRowViewModels }
    }
    
    @MainActor
    var allNodeInputRowViewModels: [InputNodeRowViewModel] {
        self.allInputRowViewModels
            .filter { $0.id.isNode }
    }
    
    @MainActor
    var allOutputRowViewModels: [OutputNodeRowViewModel] {
        self.getAllOutputsObservers()
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
    
    @MainActor
    var layerNodeReader: LayerNodeReader? {
        switch self.nodeType {
        case .layer(let layerNode):
            return layerNode
        default:
            return nil
        }
    }
}
