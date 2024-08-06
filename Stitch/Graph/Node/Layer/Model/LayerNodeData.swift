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
        
        if let inputType = rowObserver.id.keyPath {
            itemType = .layerInspector(inputType)
        } else {
            fatalErrorIfDebug()
            itemType = .layerInspector(.size)
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
        
        if let inputType = rowObserver.id.keyPath {
            itemType = .layerInspector(inputType)
        } else {
            fatalErrorIfDebug()
            itemType = .layerInspector(.size)
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
                let canvasId = CanvasItemId.layerInput(.init(node: nodeId,
                                                             keyPath: layerInputType))
                
                self.canvasObserver = .init(from: canvas,
                                            id: canvasId,
                                            inputRowObservers: [self.rowObserver],
                                            outputRowObservers: [])
            }
        } else {
            self.canvasObserver = nil
        }
    }
}

extension LayerInputObserverMode {
    var packedObserver: InputLayerNodeRowData? {
        switch self {
        case .packed(let inputLayerNodeRowData):
            return inputLayerNodeRowData
        case .unpacked:
            return nil
        }
    }
    
    @MainActor
    func update(from schema: LayerInputModeEntity,
                layerInputType: LayerInputType,
                layerNode: LayerNodeViewModel,
                nodeId: NodeId) {
        switch schema {
        case .packed(let inputSchema):
            guard let packedInputObserver = layerNode[keyPath: layerInputType.layerNodeKeyPath].packedObserver else {
                // TODO: come back here to create packed observer if not yet created
                fatalErrorIfDebug()
                return
            }
            
            packedInputObserver.update(from: inputSchema,
                                       layerInputType: layerInputType,
                                       layerNode: layerNode,
                                       nodeId: nodeId)
        case .unpacked(let unpackedObserverType):
            fatalErrorIfDebug()
        }
    }
    
    @MainActor
    func createSchema() -> LayerInputModeEntity {
        switch self {
        case .packed(let inputLayerNodeRowData):
            return .packed(inputLayerNodeRowData.createSchema())
        case .unpacked(let unpackedObserverType):
            return .unpacked(unpackedObserverType.createSchema())
        }
    }
}
    
extension InputLayerNodeRowData {
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
