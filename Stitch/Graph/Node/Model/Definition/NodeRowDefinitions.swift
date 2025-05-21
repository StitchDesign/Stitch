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

extension NodeKind {
    @MainActor
    func rowDefinitions(for nodeType: UserVisibleType?) -> NodeRowDefinitions {

        // TODO: Most GraphNodes' input and output counts do not vary by nodeType, so we can just coerce the inputs like we do for `legacyRowDefinitions`
        //        if let rowDefinitions = self.graphNode?.newStyleRowDefinitions(for: nodeType) {
        if let rowDefinitions = self.newStyleRowDefinitions(for: nodeType) {
            return rowDefinitions
        }

        let rowDefinitions = self.legacyRowDefinitions
        if let nodeType = nodeType {
            return .init(inputs: rowDefinitions.inputs.coerce(to: nodeType),
                         outputs: rowDefinitions.outputs)
        } else {
            return rowDefinitions
        }
    }

    // TODO: define on patch or layer but not group, i.e. not on NodeKind itself
    @MainActor
    func newStyleRowDefinitions(for nodeType: UserVisibleType?) -> NodeRowDefinitions? {
        switch self {
        case .layer(let x):
            return x.newStyleRowDefinitions()
        case .patch(let x):
            return x.newStyleRowDefinitions(for: nodeType)
        default:
            return nil // i.e. .group
        }
    }
}

extension Layer {
    @MainActor
    func newStyleRowDefinitions() -> NodeRowDefinitions {
        self.graphNode.rowDefinitions(for: nil)
    }
}

extension Patch {
    @MainActor
    func newStyleRowDefinitions(for nodeType: NodeType?) -> NodeRowDefinitions? {
        
        guard let graphNode = self.graphNode else {
            return nil
        }
                    
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
