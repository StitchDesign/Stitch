//
//  NodeIOCoordinateUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

typealias InputCoordinateSet = Set<InputCoordinate>
typealias InputCoordinates = [InputCoordinate]

// a coordinate is a port's id: the port id + the node id
// TODO: cleanup typealiases
typealias InputCoordinate = NodeIOCoordinate
typealias OutputCoordinate = NodeIOCoordinate

extension InputCoordinate {
    // used e.g. when a JSON input popover has been opened
    var toSingleFieldCoordinate: FieldCoordinate {
        .init(input: self,
              fieldIndex: 0)
    }

    // Could this input be a media picker?
    // Note that this also depends on which patch/layer
    // this input is on.
    var isMediaSelectorLocation: Bool {
        switch self.portType {
        case .keyPath(let layerInputType):
            return layerInputType.isMediaImport
        case .portIndex(let portId):
            return portId == InputCoordinate.mediaSelectorPortId
        }
    }

    static var fakeInputCoordinate: InputCoordinate {
        InputCoordinate(portId: 0, nodeId: .randomNodeId)
    }

    // Assumes that all import media patch nodes have its media selector at this location.
    static var mediaSelectorPortId: Int { 0 }
}

extension OutputCoordinate {
    static var fakeOutputCoordinate: OutputCoordinate {
        OutputCoordinate(portId: 0, nodeId: .randomNodeId)
    }
}

extension InputCoordinates {
    mutating func modifyNodeId(_ nodeId: NodeId) {
        self = self.map { coordinate in
            var coordinate = coordinate
            coordinate.nodeId = nodeId
            return coordinate
        }
    }
}
