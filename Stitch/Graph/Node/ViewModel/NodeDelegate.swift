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
    
    /// Similar to `getAllInputsObservers` but gets unpacked layer observers if used.
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
            return canvas.inputViewModels.compactMap {
                $0.rowDelegate
            }
        case .component(let component):
            return component.canvas.inputViewModels.compactMap {
                $0.rowDelegate
            }
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
}
