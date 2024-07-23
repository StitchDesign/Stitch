//
//  PortViewType.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation


enum PortViewType: Equatable, Hashable {
    case input(InputPortViewData)
    case output(OutputPortViewData)
}

extension PortViewType {
    init(nodeIO: NodeIO,
         portId: Int,
         nodeId: UUID) {
        switch nodeIO {
        case .input:
            self = .input(.init(portId: portId, nodeId: nodeId))
        case .output:
            self = .output(.init(portId: portId, nodeId: nodeId))
        }
    }
    
    var output: OutputPortViewData? {
        switch self {
        case let .output(x): return x
        default: return nil
        }
    }

    var input: InputPortViewData? {
        switch self {
        case let .input(x): return x
        default: return nil
        }
    }

    var nodeId: NodeId {
        switch self {
        case .output(let output):
            return output.nodeId
        case .input(let input):
            return input.nodeId
        }
    }

    var isInput: Bool {
        self.input.isDefined
    }
    
    var nodeIO: NodeIO {
        switch self {
        case .input:
            return .input
        case .output:
            return .output
        }
    }
}
