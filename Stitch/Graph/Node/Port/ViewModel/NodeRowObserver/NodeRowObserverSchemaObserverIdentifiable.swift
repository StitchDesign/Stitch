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
        if self.upstreamOutputCoordinate != schema.portData.upstreamConnection {
            self.upstreamOutputCoordinate = schema.portData.upstreamConnection
        }

        // Update values if no upstream connection
        if let values = schema.portData.values {
            self.updateValuesInInput(values)
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
            if self.upstreamOutputCoordinate != upstreamOutputCoordinate {
                self.upstreamOutputCoordinate = upstreamOutputCoordinate                
            }
            
        case .values(let values):
            let values = values.isEmpty ? [inputType.getDefaultValue(for: layer)] : values
            self.updateValuesInInput(values)
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
    
    // Set connected inputs to defaultValue
    @MainActor
    func onPrototypeRestart(document: StitchDocumentViewModel) {
                
        guard self.upstreamOutputCoordinate.isDefined,
              let node = document.visibleGraph.getNode(self.id.nodeId),
              let patch = node.kind.getPatch,
              let portId = self.id.portId else {
            return
        }
                
        let defaultInputs: NodeInputDefinitions = node.kind
            .rowDefinitions(for: node.userVisibleType)
            .inputs
        
        guard let defaultValues = getDefaultValueForPatchNodeInput(portId,
                                                                   defaultInputs,
                                                                   patch: patch) else {
            fatalErrorIfDebug()
            return
        }
        
        // NOTE: important to use `setValuesInInput` so that field observers are updated as well
        self.setValuesInInput(defaultValues)
        // self.updateValues(defaultValues)
    }
}

extension OutputNodeRowObserver {
    @MainActor
    func onPrototypeRestart(document: StitchDocumentViewModel) {
        // Set outputs to be empty
        // MARK: no longer seems necessary, removing for fixing flashing media on restart
        self.allLoopedValues = []
    }
}
