//
//  PortViewData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

protocol PortViewData: Equatable, Hashable {
    var portId: Int { get set }
    var nodeId: UUID { get set }
    
    init(portId: Int, nodeId: UUID)
}

struct InputPortViewData: PortViewData {
    var portId: Int
    var nodeId: UUID
}

struct OutputPortViewData: PortViewData {
    var portId: Int
    var nodeId: UUID
}

extension PortViewData {
    init?(from coordinate: NodeIOCoordinate) {
        guard let portId = coordinate.portId else {
            return nil
        }
    
        self.init(portId: portId,
                  nodeId: coordinate.nodeId)
    }
}
