//
//  GroupNode.swift
//  prototype
//
//  Created by Elliot Boschwitz on 11/20/21.
//

import SwiftUI
import StitchSchemaKit

extension GroupNodeId {
    var asNodeId: NodeId {
        self.id
    }
}

extension UUID {
    var asGroupNodeId: GroupNodeId {
        GroupNodeId(self)
    }
}

typealias GroupIdSet = Set<GroupNodeId>
