//
//  NodeRowObserverSchemaObserverIdentifiable.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit

extension NodeRowObserver: SchemaObserverIdentifiable {
    static func createObject(from entity: NodePortInputEntity) -> Self {
        self.init(from: entity,
                  activeIndex: .init(.zero),
                  nodeDelegate: nil)
    }

    /// Only updates values for inputs without connections.
    @MainActor
    func update(from schema: NodePortInputEntity,
                activeIndex: ActiveIndex) {
        self.upstreamOutputCoordinate = schema.upstreamOutputCoordinate

        // Update values if no upstream connection
        if let values = schema.values {
            self.updateValues(values,
                              activeIndex: activeIndex,
                              isVisibleInFrame: true)
        }
    }

    /// Only updates values for inputs without connections.
    @MainActor
    func update(from schema: NodePortInputEntity) {
        self.update(from: schema, activeIndex: .init(.zero))
    }
    
    /// Schema updates from layer.
    @MainActor
    func update(from nodeConnection: NodeConnectionType,
                inputType: LayerInputType) {
        switch nodeConnection {
        case .upstreamConnection(let upstreamOutputCoordinate):
            self.upstreamOutputCoordinate = upstreamOutputCoordinate
            
        case .values(let values):
            guard let layer = self.nodeKind.getLayer else {
                fatalErrorIfDebug()
                return
            }
            
            let values = values.isEmpty ? [inputType.getDefaultValue(for: layer)] : values
            self.updateValues(values,
                              activeIndex: .init(.zero),
                              isVisibleInFrame: true)
        }
    }

    func createSchema() -> NodePortInputEntity {
        guard let upstreamOutputObserver = self.upstreamOutputObserver else {
            return NodePortInputEntity(id: id,
                                       nodeKind: self.nodeKind,
                                       userVisibleType: self.userVisibleType,
                                       values: self.allLoopedValues,
                                       upstreamOutputCoordinate: self.upstreamOutputCoordinate)
        }

        return NodePortInputEntity(id: id,
                                   nodeKind: self.nodeKind,
                                   userVisibleType: self.userVisibleType,
                                   values: nil,
                                   upstreamOutputCoordinate: upstreamOutputObserver.id)
    }
    
    func onPrototypeRestart() {
        
        // Set inputs to defaultValue
        if self.nodeIOType == .input {
            
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
                    self.updateValues(
                        defaultValues,
                        activeIndex: self.nodeDelegate?.graphDelegate?.activeIndex ?? .init(0),
                        isVisibleInFrame: true)
                }
                //                else {
                //                    log("was not able to reset patch node input to default value")
                //                }
                                
            }
        }
        
        // Set outputs to be empty
        if self.nodeIOType == .output {
            self.allLoopedValues = []
        }
    }
}
