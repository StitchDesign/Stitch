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

final class OutputLayerNodeRowData {
    let rowObserver: OutputNodeRowObserver
    var canvasObsever: CanvasItemViewModel?
    
    init(rowObserver: OutputNodeRowObserver,
         canvasObsever: CanvasItemViewModel? = nil) {
        self.rowObserver = rowObserver
        self.canvasObsever = canvasObsever
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
                layerInputType: LayerInputType) {
        self.rowObserver.update(from: schema.inputPort,
                                inputType: layerInputType)
        
        if let canvas = schema.canvasItem {
            self.canvasObsever?.update(from: canvas)
        }
    }
    
    @MainActor
    func createSchema() -> LayerInputDataEntity {
        .init(inputPort: self.rowObserver.createSchema().portData,
              canvasItem: self.canvasObsever?.createSchema())
    }
}
