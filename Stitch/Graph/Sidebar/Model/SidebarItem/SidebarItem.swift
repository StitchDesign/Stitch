//
//  SidebarItemsData.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/7/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias SidebarItems = [SidebarItem]

struct SidebarItem: Equatable, Identifiable, Hashable, Codable {

    let layerName: LayerNodeTitle
    let layerNodeId: LayerNodeId

    var id: LayerNodeId {
        layerNodeId
    }
    var groupInfo: GroupInfo?

    var childItems: [SidebarItem] {
        groupInfo?.elements ?? []
    }

    var children: SidebarItems {
        childItems
    }
}

struct LayerNodeTitle: Equatable, Hashable, Codable {
    let value: String

    init(_ s: String) {
        value = s
    }
}

struct GroupInfo: Equatable, Hashable, Codable {
    let groupdId: LayerNodeId
    var elements: [SidebarItem]
}
