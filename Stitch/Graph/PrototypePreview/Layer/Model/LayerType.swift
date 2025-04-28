//
//  LayerType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/25.
//

import Foundation
import StitchSchemaKit
import OrderedCollections

typealias LayerTypeOrderedSet = OrderedSet<LayerType>

/// Data type used for getting sorted data.
indirect enum LayerType: Equatable, Hashable {
    case nongroup(data: LayerTypeNonGroupData, isPinned: Bool)
    
    case group(data: LayerTypeGroupData, isPinned: Bool)
    
    // TODO: theoretically could just use `[LayerType]` but need to update recursion logic
    // TODO: should be also NonEmpty, i.e. guaranteed to have at least one masked view and one masker view
    case mask(masked: LayerTypeOrderedSet,
              masker: LayerTypeOrderedSet)
}

struct LayerTypeNonGroupData: Equatable, Hashable {
    let id: PreviewCoordinate
    let zIndex: CGFloat
    let sidebarIndex: Int
    let layer: Layer // debug
}

struct LayerTypeGroupData: Equatable, Hashable {
    let id: PreviewCoordinate
    let zIndex: CGFloat
    let sidebarIndex: Int
    let childrenSidebarLayers: SidebarLayerList
    let layer: Layer // debug
}

extension LayerType {
    
    // Only used for pinning?
    var id: PreviewCoordinate {
        switch self {
        case .nongroup(let data, _):
            return data.id
        case .group(let data, _):
            return data.id
        case .mask(masked: let masked, masker: _):
            // TODO: what is the the layer-node-id of a LayerType in a masking situation? Really, it's nil, there's no single LayerNode
            // return masked.id
            return masked.first!.id
        }
    }

    // DEBUG ONLY?
    var layer: Layer {
        switch self {
        case .nongroup(let data, _):
            return data.layer
        case .group(let data, _):
            return data.layer
        case .mask(masked: let masked, masker: _):
            // TODO: what is the the layer-node-id of a LayerType in a masking situation? Really, it's nil, there's no single LayerNode
            // return masked.id
            return masked.first!.layer
        }
    }
    
    var isGroup: Bool {
        switch self {
        case .group:
            return true
        case .nongroup, .mask:
            return false
        }
    }
    
    var isPinnedView: Bool {
        switch self {
        case .nongroup(_, let isPinned):
            return isPinned
        case .group(_, let isPinned):
            // "Is group layer itself pinned?"
            return isPinned
        case .mask(masked: let x, masker: _):
            // "Is first masked view pinned?" (is this correct?)
            return x.first?.isPinnedView ?? false
        }
    }
    
    var sidebarIndex: Int {
        switch self {
        case .nongroup(let nongroup, _):
            return nongroup.sidebarIndex
        case .group(let group, _):
            return group.sidebarIndex
        case .mask(masked: let masked, masker: _):
#if DEV_DEBUG || DEBUG
            return masked.first!.sidebarIndex
#else
            return masked.first?.sidebarIndex ?? .zero
#endif
        }
    }

    var zIndex: CGFloat {
        switch self {
        case .nongroup(let nongroup, _):
            return nongroup.zIndex
        case .group(let group, _):
            return group.zIndex
        case .mask(masked: let maskedLayerTypes, masker: _):
//            return masked.zIndex
#if DEV_DEBUG || DEBUG
            return maskedLayerTypes.first!.zIndex
#else
            return maskedLayerTypes.first?.zIndex ?? .zero
#endif
        }
    }
}
