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
    var canvasObsever: CanvasItemViewModel?
    
    init(rowObserver: InputNodeRowObserver,
         canvasObsever: CanvasItemViewModel? = nil) {
        self.rowObserver = rowObserver
        self.canvasObsever = canvasObsever
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
