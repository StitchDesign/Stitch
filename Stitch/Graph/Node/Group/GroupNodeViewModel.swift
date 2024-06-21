//
//  GroupNodeViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI


@Observable
final class GroupNodeViewModel: Sendable {
    var id: NodeId
    
    let nodeKind = NodeKind.group
        
    // contains inputs/outputs + position data
    var nodeData: NodeDataViewModel
    
    init(id: NodeId, 
         nodeData: NodeDataViewModel) {
        self.id = id
        self.nodeData = nodeData
    }
}

extension GroupNodeViewModel {
    // TODO: update StitchSchemaKit NodeEntity to contain `.groupNodeEntity` class?
    static func fromSchemaWithoutDelegate(from schema: NodeEntity) -> GroupNodeViewModel {
        let nodeId = schema.id
        
        let nodeData = NodeDataViewModel(id: schema.id,
                                         canvasUIData: .fromSchemaWithoutDelegate(schema),
                                         // Do we need to update
                                         inputs: [],
                                         outputs: [])
        
        return GroupNodeViewModel(id: schema.id,
                                  nodeData: nodeData)
    }
}

extension CanvasItemViewModel {
    static func fromSchemaWithoutDelegate(_ schema: NodeEntity) -> CanvasItemViewModel {
        
        CanvasItemViewModel(id: .node(schema.id),
                            position: schema.position,
                            zIndex: schema.zIndex,
                            parentGroupNodeId: schema.parentGroupNodeId,
                            // IMPORTANT: must be set later
                            nodeDelegate: nil)
    }
}

extension LayerNodeViewModel {
    // TODO: just initalize the LayerNodeViewModel's inputs/properties with the correct values?
    // Update layer inputs' values; they were only initialized with default properties
    @MainActor
    func updateLayerInputsFromSchema(schema: NodeEntity,
                                     activeIndex: ActiveIndex,
                                     nodeDelegate: NodeDelegate) {
        
        guard let layerNodeEntity = schema.layerNodeEntity else {
            fatalErrorIfDebug()
            return
        }
        
        let layerNode = self
        
        for inputType in layerNode.layer.layerGraphNode.inputDefinitions {
                        
            // Set delegate and call update values helper
            let rowObserver = layerNode[keyPath: inputType.layerNodeKeyPath]
            let rowSchema = layerNodeEntity[keyPath: inputType.schemaPortKeyPath]
            rowObserver.nodeDelegate = nodeDelegate
            
            switch rowSchema {
            case .upstreamConnection(let upstreamCoordinate):
                rowObserver.upstreamOutputCoordinate = upstreamCoordinate
            case .values(let values):
                let values = values.isEmpty ? [inputType.getDefaultValue(for: layerNode.layer)] : values
                
                rowObserver.updateValues(values,
                                         activeIndex: activeIndex,
                                         // When first creating/updating a layer input, on-screen visibility should not matter? `NodeViewModel.isVisibleInFrame` is always initialized as false anyway.
                                         isVisibleInFrame: false,
                                         isInitialization: true)
            } // switch
            
            assertInDebug(!rowObserver.allLoopedValues.isEmpty)
        } // for inputType in layerNode.layer ...
    }
}

extension NodeEntity {
        
    @MainActor
    func inputObserversFromSchema(kind: NodeKind,
                                         nodeType: NodeType?,
                                         nodeDelegate: NodeDelegate) -> NodeRowObservers {
        
        let schema = self
        
        if kind.isLayer {
            fatalErrorIfDebug("NodeRowObservers: inputObserversFromSchema: Not intended for layer node input initialization")
        }
        
        return schema.inputs.createInputObservers(
            nodeId: schema.id,
            kind: kind,
            userVisibleType: nodeType,
            nodeDelegate: nodeDelegate)
    }
    
    @MainActor
    func outputObserversFromSchema(rowDefinitions: NodeRowDefinitions,
                                   nodeDelegate: NodeDelegate) -> NodeRowObservers {
        let schema = self
        return rowDefinitions.createOutputObservers(nodeId: schema.id,
                                                    values: nodeDelegate.defaultOutputsList,
                                                    nodeDelegate: nodeDelegate)
    }
}
