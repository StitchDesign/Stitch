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
    var canvasObsever: CanvasItemViewModel? { get set }
}

@Observable
final class InputLayerNodeRowData {
    let rowObserver: InputNodeRowObserver
    let inspectorRowViewModel: InputNodeRowViewModel
    var canvasObsever: CanvasItemViewModel?
    
    @MainActor
    init(rowObserver: InputNodeRowObserver,
         canvasObsever: CanvasItemViewModel? = nil) {
        self.rowObserver = rowObserver
        self.canvasObsever = canvasObsever
        
        self.inspectorRowViewModel = .init(id: .init(graphItemType: .layerInspector,
                                                     nodeId: rowObserver.id.nodeId,
                                                     portType: rowObserver.id.portType),
                                           activeValue: rowObserver.activeValue,
                                           nodeRowIndex: nil,
                                           rowDelegate: rowObserver,
                                           // specifically not a row view model for canvas
                                           canvasItemDelegate: nil)
    }
}

@Observable
final class OutputLayerNodeRowData {
    let rowObserver: OutputNodeRowObserver
    let inspectorRowViewModel: OutputNodeRowViewModel
    var canvasObsever: CanvasItemViewModel?
    
    @MainActor
    init(rowObserver: OutputNodeRowObserver,
         canvasObsever: CanvasItemViewModel? = nil) {
        self.rowObserver = rowObserver
        self.canvasObsever = canvasObsever
        
        self.inspectorRowViewModel = .init(id: .init(graphItemType: .layerInspector,
                                                     nodeId: rowObserver.id.nodeId,
                                                     portType: rowObserver.id.portType),
                                           activeValue: rowObserver.activeValue,
                                           nodeRowIndex: nil,
                                           rowDelegate: rowObserver,
                                           // specifically not a row view model for canvas
                                           canvasItemDelegate: nil)
    }
}

extension LayerNodeRowData {
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
                nodeId: NodeId,
                node: NodeDelegate?) {
        self.rowObserver.update(from: schema.inputPort,
                                inputType: layerInputType)
        
        if let canvas = schema.canvasItem {
            if let canvasObsever = self.canvasObsever {
                self.canvasObsever?.update(from: canvas)
            } else {
                self.canvasObsever = .init(from: canvas,
                                           id: .layerInput(.init(node: nodeId,
                                                                 keyPath: layerInputType)),
                                           node: node)
            }
        } else {
            self.canvasObsever = nil
        }
    }
    
    @MainActor
    func createSchema() -> LayerInputDataEntity {
        .init(inputPort: self.rowObserver.createSchema().portData,
              canvasItem: self.canvasObsever?.createSchema())
    }
}

extension OutputLayerNodeRowData: Identifiable {
    var id: NodeIOCoordinate {
        self.rowObserver.id
    }
}
