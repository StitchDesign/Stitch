//
//  Groups.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/28/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LayerGroupFit {
    // size for the Group Layer node
    let size: LayerSize

    // position for the Group Layer node
    let position: StitchPosition

    // How much to adjust the children's positions.
    // Only non-zero when a child was north and/or west
    let childAdjustment: CGSize

    init(_ size: LayerSize,
         _ position: StitchPosition,
         _ childAdjustment: CGSize) {
        self.size = size
        self.position = position
        self.childAdjustment = childAdjustment
    }
}
