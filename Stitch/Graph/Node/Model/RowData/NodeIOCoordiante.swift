//
//  NodeIOCoordiante.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/2/24.
//

import StitchSchemaKit

typealias NodeIOCoordinates = [NodeIOCoordinate]

extension NodeIOCoordinate {
    var portId: Int? {
        switch self.portType {
        case .keyPath:
            return nil
        case .portIndex(let portId):
            return portId
        }
    }
    
    public init(portId: Int, nodeId: NodeEntity.ID) {
        self.init(portType: .portIndex(portId),
                  nodeId: nodeId)
    }
    
    var keyPath: LayerInputType? {
        switch self.portType {
        case .keyPath(let keyPath):
            return keyPath
        default:
            return nil
        }
    }
}

extension NodeConnectionType {
    var values: PortValues? {
        switch self {
        case .values(let values):
            return values
        case .upstreamConnection:
            return nil
        }
    }
    
    var upstreamConnection: NodeIOCoordinate? {
        switch self {
        case .values:
            return nil
        case .upstreamConnection(let connection):
            return connection
        }
    }
}


extension NodeIOPortType {
    var keyPath: LayerInputType? {
        switch self {
        case .keyPath(let keyPath):
            return keyPath
        default:
            return nil
        }
    }
    
    var portId: Int? {
        switch self {
        case .portIndex(let x):
            return x
        default:
            return nil
        }
    }
}

extension LayerInputPort {
    var isMediaImport: Bool {
        switch self {
        case .image, .video, .model3D:
            return true
        default:
            return false
        }
    }
}
