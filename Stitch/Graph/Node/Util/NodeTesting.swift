//
//  Node.swift
//  prototype
//
//  Created by cjc on 1/13/21.
//

import CoreData
import Foundation
import StitchSchemaKit
import OrderedCollections
import Tagged
import SwiftUI

typealias NodeIdList = [NodeId]
// typealias NodesDict<Key: Hashable, Value: Node> = [Key: Value]

// TODO: deprecate
typealias IdList = NodeIdList
typealias IdSet = NodeIdSet

struct TestIds: Equatable {
    static let _0: NodeId = NodeId()
    static let _1: NodeId = NodeId()
    static let _2: NodeId = NodeId()
    static let _3: NodeId = NodeId()
    static let _4: NodeId = NodeId()
    static let _5: NodeId = NodeId()
    static let _6: NodeId = NodeId()
    static let _7: NodeId = NodeId()
    static let _8: NodeId = NodeId()
    static let _9: NodeId = NodeId()
    static let _10: NodeId = NodeId()
}

extension UUID {

    static let fakeNodeId: NodeId = Stitch.fakeNodeId

    static var randomNodeId: NodeId {
        UUID()
    }
}

// TODO: make into UUID? handle the Tagged type better here?
// THIS IS ACTUALLY MORE LIKE "NODE ID BASE TYPE"
// TODO: NodeId should be defined on Node protocol, as `typealias Id = Tagged<Node, UUID>`

extension UUID {
    var asLayerNodeId: LayerNodeId {
        LayerNodeId(self)
    }
}

func asLayerNodeId(_ id: NodeId) -> LayerNodeId {
    LayerNodeId(id)
}
