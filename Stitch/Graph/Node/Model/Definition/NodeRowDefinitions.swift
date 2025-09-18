//
//  NodeRowDefinitions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/2/24.
//

import Foundation
import StitchSchemaKit

struct NodeRowDefinitions {
    let inputs: [NodeInputDefinition]
    let outputs: [NodeOutputDefinition]
}

extension [NodeInputDefinition] {
    static func singleUnlabeledInput(_ nodeRowType: UserVisibleType) -> Self {
        [
            .init(label: "",
                  defaultType: nodeRowType)
        ]
    }

    func coerce(to nodeType: UserVisibleType) -> Self {
        self.map { (inputInfo: NodeInputDefinition) in
            guard !inputInfo.isTypeStatic else {
                return inputInfo
            }
            // TODO: should we pass in `graphTime` and a real `mediaDict` here?
            // The `rowDefinitions` property is actually used for deserializing an input that has an upstream observer?
            var inputInfo = inputInfo
            inputInfo.defaultValues = inputInfo.defaultValues.coerce(to: nodeType.defaultPortValue,
                                                                     currentGraphTime: .zero)
            return inputInfo
        }
    }
}

extension [NodeOutputDefinition] {
    var defaultList: PortValuesList {
        self.map { [$0.value] }
    }
}

extension NodeRowDefinitions {
    init(layerInputs: LayerInputPortSet,
         outputs: [NodeOutputDefinition] = [],
         layer: Layer) {
        let inputs = layerInputs.map { layerInput in
            NodeInputDefinition(defaultValues: [layerInput.getDefaultValue(for: layer)],
                                label: layerInput.label(),
                                layerInputType: layerInput)
        }
        
        self = .init(inputs: inputs, outputs: outputs)
    }
    
    func coerce(to nodeType: UserVisibleType) -> Self {
        .init(inputs: self.inputs.coerce(to: nodeType),
              outputs: self.outputs)
    }
}

// row-definitions are only for Patches and Layers, never Groups or Components
extension PatchOrLayer {
    @MainActor
    func rowDefinitions(for nodeType: UserVisibleType?) -> NodeRowDefinitions {
        switch self {
        case .layer(let x):
            return x.rowDefinitions()
        case .patch(let x):
            return x.rowDefinitions(for: nodeType)
        }
    }
}

extension Layer {
    @MainActor
    func rowDefinitions() -> NodeRowDefinitions {
        self.graphNode.rowDefinitions(for: nil)
    }
}

extension Patch {
    func rowDefinitions(for nodeType: NodeType?) -> NodeRowDefinitions {
        
        let graphNode = self.graphNode
                    
        let rowDefinitions = graphNode.rowDefinitions(for: nodeType)
        
        if graphNode.inputCountVariesByType || graphNode.outputCountVariesByType {
            return rowDefinitions
        } else if let nodeType = nodeType {
            return rowDefinitions.coerce(to: nodeType)
        } else {
            return rowDefinitions
        }
    }
}
