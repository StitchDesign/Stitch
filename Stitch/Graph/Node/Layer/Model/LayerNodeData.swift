//
//  LayerNodeData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/18/24.
//

import Foundation
import StitchSchemaKit

struct LayerNodeRowData {
    let rowObserver: NodeRowObserver
    var canvasObsever: NodeCanvasViewModel?
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
