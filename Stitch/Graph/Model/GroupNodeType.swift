//
//  GroupNodeType.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/4/24.
//

import SwiftUI
import StitchSchemaKit

/// Used to represent group data with visual graph hierarchical data.
enum GroupNodeType: Hashable, Equatable {
    case groupNode(NodeId)
    case component(UUID) // NodeID of component node
}

extension GroupNodeType {
    var component: UUID? {
        switch self {
        case .groupNode:
            return nil
        case .component(let nodeId):
            return nodeId
        }
    }
    
    var groupNodeId: NodeId? {
        switch self {
        case .groupNode(let id):
            return id
        case .component:
            return nil
        }
    }
    
    var isComponent: Bool {
        self.component != nil
    }
    
    var asNodeId: NodeId? {
        self.groupNodeId
    }
}
