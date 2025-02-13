//
//  NodeRowObserverSchemaObserverIdentifiable.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit

extension InputNodeRowObserver: SchemaObserverIdentifiable {
    static func createObject(from entity: NodePortInputEntity) -> Self {
        self.init(from: entity)
    }

    // for easier search: `updateInputNodeRowObserverFromSchema`
    /// Updates values for inputs.
    @MainActor
    func update(from schema: NodePortInputEntity) {
        self.upstreamOutputCoordinate = schema.portData.upstreamConnection

        // Update values if no upstream connection
        if let values = schema.portData.values {
            self.updateValues(values)
        }
    }

    // for easier search: `updateInputNodeRowObserverFromConnectionType`
    /// Schema updates from layer.
    @MainActor
    func update(from nodeConnection: NodeConnectionType,
                layer: Layer,
                inputType: LayerInputType) {
                        
        switch nodeConnection {
        case .upstreamConnection(let upstreamOutputCoordinate):
            self.upstreamOutputCoordinate = upstreamOutputCoordinate
            
        case .values(let values):
            let values = values.isEmpty ? [inputType.getDefaultValue(for: layer)] : values
            self.updateValues(values)
        }
    }

    @MainActor
    func createSchema() -> NodePortInputEntity {
        guard let upstreamOutputObserver = self.upstreamOutputObserver else {
            return NodePortInputEntity(id: id, 
                                       portData: .values(self.allLoopedValues))
        }

        return NodePortInputEntity(id: id,
                                   portData: .upstreamConnection(upstreamOutputObserver.id))
    }
    
    // Set inputs to defaultValue
    @MainActor
    func onPrototypeRestart() {
        // test out first on just non-layer-node inputs
        if self.upstreamOutputCoordinate.isDefined,
           let patch = self.nodeKind.getPatch,
           let portId = self.id.portId {
            
            let defaultInputs: NodeInputDefinitions = self.nodeKind
                .rowDefinitions(for: self.userVisibleType)
                .inputs
            
            if let defaultValues = getDefaultValueForPatchNodeInput(portId,
                                                                    defaultInputs,
                                                                    patch: patch) {
                
                // log("will reset patch node input \(self.id) to default value \(defaultValues)")
                self.updateValues(defaultValues)
            }
            //                else {
            //                    log("was not able to reset patch node input to default value")
            //                }
            
        }
    }
}

extension OutputNodeRowObserver {
    @MainActor
    func onPrototypeRestart() {
        // Set outputs to be empty
        self.allLoopedValues = []
    }
}
