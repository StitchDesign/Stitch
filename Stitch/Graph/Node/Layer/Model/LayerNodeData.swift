//
//  LayerNodeData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/18/24.
//

import Foundation
import StitchSchemaKit


protocol LayerNodeRowData: AnyObject {
    associatedtype RowObserverable: NodeRowObserver
    
    var rowObserver: RowObserverable { get set }
    var canvasObserver: CanvasItemViewModel? { get set }
    var inspectorRowViewModel: RowObserverable.RowViewModelType { get set }
}

@Observable
final class InputLayerNodeRowData: LayerNodeRowData {
    var rowObserver: InputNodeRowObserver
    var inspectorRowViewModel: InputNodeRowViewModel
    var canvasObserver: CanvasItemViewModel?
    
    @MainActor
    init(rowObserver: InputNodeRowObserver,
         canvasObserver: CanvasItemViewModel? = nil,
         isEmpty: Bool = false) {
        self.rowObserver = rowObserver
        self.canvasObserver = canvasObserver
        var itemType: GraphItemType
        
        if FeatureFlags.USE_LAYER_INSPECTOR {
            if let inputType = rowObserver.id.keyPath {
                itemType = .layerInspector(inputType)
            } else {
                fatalErrorIfDebug()
                itemType = .layerInspector(.position)
            }
        } else if let canvasObserver = canvasObserver {
            itemType = .node(canvasObserver.id)
        } else {
            if !isEmpty {
                fatalErrorIfDebug()
            }
            itemType = .node(.node(.init()))
        }
        
        self.inspectorRowViewModel = .init(id: .init(graphItemType: itemType,
                                                     nodeId: rowObserver.id.nodeId,
                                                     portId: 0),
                                           activeValue: rowObserver.activeValue,
                                           rowDelegate: rowObserver,
                                           // specifically not a row view model for canvas
                                           canvasItemDelegate: nil)
    }
}

@Observable
final class OutputLayerNodeRowData: LayerNodeRowData {
    var rowObserver: OutputNodeRowObserver
    var inspectorRowViewModel: OutputNodeRowViewModel
    var canvasObserver: CanvasItemViewModel?
    
    @MainActor
    init(rowObserver: OutputNodeRowObserver,
         canvasObserver: CanvasItemViewModel? = nil) {
        self.rowObserver = rowObserver
        self.canvasObserver = canvasObserver
        var itemType: GraphItemType
        
        if FeatureFlags.USE_LAYER_INSPECTOR {
            if let inputType = rowObserver.id.keyPath {
                itemType = .layerInspector(inputType)
            } else {
                fatalErrorIfDebug()
                itemType = .layerInspector(.position)
            }
        } else if let canvasObserver = canvasObserver {
            itemType = .node(canvasObserver.id)
        } else {
            fatalErrorIfDebug()
            itemType = .node(.node(.init()))
        }
        
        self.inspectorRowViewModel = .init(id: .init(graphItemType: itemType,
                                                     nodeId: rowObserver.id.nodeId,
                                                     portId: 0),
                                           activeValue: rowObserver.activeValue,
                                           rowDelegate: rowObserver,
                                           // specifically not a row view model for canvas
                                           canvasItemDelegate: nil)
    }
    
    @MainActor func initializeDelegate(_ node: NodeDelegate) {
        self.rowObserver.initializeDelegate(node)
        self.canvasObserver?.initializeDelegate(node)
        self.inspectorRowViewModel.initializeDelegate(node)
    }
}

extension LayerNodeRowData {
    @MainActor func initializeDelegate(_ node: NodeDelegate) {
        self.rowObserver.initializeDelegate(node)
        self.canvasObserver?.initializeDelegate(node)
        self.inspectorRowViewModel.initializeDelegate(node)
    }
    
    var allLoopedValues: PortValues {
        get {
            self.rowObserver.allLoopedValues
        }
        set(newValue) {
            self.rowObserver.allLoopedValues = newValue
        }
    }
}

extension InputLayerNodeRowData {
    @MainActor
    func update(from schema: LayerInputDataEntity,
                layerInputType: LayerInputType,
                layerNode: LayerNodeViewModel,
                nodeId: NodeId) {
        self.rowObserver.update(from: schema.inputPort,
                                inputType: layerInputType)
        
        if let canvas = schema.canvasItem {
            if let canvasObserver = self.canvasObserver {
                canvasObserver.update(from: canvas)
            } else {
                // Make new canvas observer since none yet created
                let canvasId = FeatureFlags.USE_LAYER_INSPECTOR ?
                CanvasItemId.layerInput(.init(node: nodeId,
                                              keyPath: layerInputType)) :
                CanvasItemId.node(nodeId)
                
                if FeatureFlags.USE_LAYER_INSPECTOR {
                    let inputObserver = layerNode[keyPath: layerInputType.layerNodeKeyPath].rowObserver
                    self.canvasObserver = .init(from: canvas,
                                                id: canvasId,
                                                inputRowObservers: [inputObserver],
                                                outputRowObservers: [])
                } else {
                    // MARK: this is a hacky solution to support old-style layer nodes.
                    // Via persistence, we arbitrarily pick one input in a layer to save canvas info.
                    // So we load all ports here.
                    let inputRowObservers = layerNode.layer.layerGraphNode.inputDefinitions
                        .map { keyPath in
                            layerNode[keyPath: keyPath.layerNodeKeyPath].rowObserver
                        }
                    
                    self.canvasObserver = .init(from: canvas,
                                                id: canvasId,
                                                inputRowObservers: inputRowObservers,
                                                outputRowObservers: layerNode.outputPorts.map { $0.rowObserver })
                }
            }
        } else {
            self.canvasObserver = nil
        }
    }
    
    @MainActor
    func createSchema() -> LayerInputDataEntity {
        .init(inputPort: self.rowObserver.createSchema().portData,
              canvasItem: self.canvasObserver?.createSchema())
    }
}

extension OutputLayerNodeRowData: Identifiable {
    var id: NodeIOCoordinate {
        self.rowObserver.id
    }
}
