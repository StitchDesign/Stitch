//
//  PortViewData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

// TODO: rename to `PortIdAddress`, since this is really a port-id-based way of representing an input's or output's address
protocol PortViewData: Hashable {
    var portId: Int { get set }
    var canvasId: CanvasItemId { get set }
    
    init(portId: Int, canvasId: CanvasItemId)
}

// TODO: rename to `InputPortIdAddress`
struct InputPortViewData: PortViewData {
    var portId: Int
    var canvasId: CanvasItemId
}

// TODO: rename to `OutputPortIdAddress`
struct OutputPortViewData: PortViewData {
    var portId: Int
    var canvasId: CanvasItemId
}

//extension PortViewData {
//    init?(from coordinate: NodeIOCoordinate) {
//        guard let portId = coordinate.portId else {
//            return nil
//        }
//    
//        self.init(portId: portId,
//                  nodeId: coordinate.nodeId)
//    }
//}
