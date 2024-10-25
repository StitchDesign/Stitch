//
//  Coordinate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import CoreData
import SwiftUI
import StitchSchemaKit

// never serialized, only
enum Coordinate: Equatable, Hashable {
    case output(OutputCoordinate)
    case input(InputCoordinate)
}

extension Coordinate: Identifiable {
    var id: NodeIOCoordinate {
        switch self {
        case .output(let outputCoordinate):
            return outputCoordinate
        case .input(let inputCoordinate):
            return inputCoordinate
        }
    }
}

extension Coordinate {
    var output: OutputCoordinate? {
        switch self {
        case let .output(x): return x
        default: return nil
        }
    }

    var input: InputCoordinate? {
        switch self {
        case let .input(x): return x
        default: return nil
        }
    }

    var nodeId: NodeId {
        self.id.nodeId
    }

    var isInput: Bool {
        self.input.isDefined
    }
}
