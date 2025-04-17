//
//  PortViewData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

// fka `PortViewData`
/// A port-id-based way of representing an input's or output's address
protocol PortIdAddress: Hashable {
    var portId: Int { get set }
    var canvasId: CanvasItemId { get set }
    
    init(portId: Int, canvasId: CanvasItemId)
}

struct InputPortIdAddress: PortIdAddress {
    var portId: Int
    var canvasId: CanvasItemId
}

// TODO: rename to `OutputPortIdAddress`
struct OutputPortIdAddress: PortIdAddress {
    var portId: Int
    var canvasId: CanvasItemId
}
