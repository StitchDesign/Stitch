//
//  SidebarDeps.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation

import SwiftUI
import StitchSchemaKit
import OrderedCollections

struct SidebarDeps: Equatable {

    // replace with LayerNodesForSidebarDict
    //    var layerNodes: LayerNodesDict
    var layerNodes: LayerNodesForSidebarDict
    var groups = SidebarGroupsDict()
    var expandedItems = LayerIdSet()
}
