//
//  LayerLoopNodeCoordinate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/9/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// used for eg saying, 'this loop index for this layer node'
struct PreviewCoordinate: Equatable, Hashable, Codable {
    let layerNodeId: LayerNodeId
    let loopIndex: Int

    init(layerNodeId: UUID, loopIndex: Int) {
        self.layerNodeId = LayerNodeId(layerNodeId)
        self.loopIndex = loopIndex
    }

    init(layerNodeId: LayerNodeId, loopIndex: Int) {
        self.layerNodeId = layerNodeId
        self.loopIndex = loopIndex
    }
}
