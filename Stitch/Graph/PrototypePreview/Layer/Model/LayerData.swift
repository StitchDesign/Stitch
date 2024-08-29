//
//  LayerData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/16/23.
//

import Foundation
import StitchSchemaKit
import OrderedCollections

typealias LayerTypeSet = OrderedSet<LayerType>
typealias LayerTypes = [LayerType]
typealias LayerDataList = [LayerData]

/// Data type used for getting sorted data.
indirect enum LayerType: Equatable, Hashable {
    case nongroup(LayerNonGroupData, Bool)
    case group(LayerGroupData, Bool)
    
    // TODO: theoretically could just use `[LayerType]` but need to update recursion logic
    // TODO: should be also NonEmpty, i.e. guaranteed to have at least one masked view and one masker view
    case mask(masked: LayerTypeSet, masker: LayerTypeSet)
}

/// Data type used for getting sorted data in views.
indirect enum LayerData {
    case nongroup(LayerViewModel, Bool)
    case group(LayerViewModel, LayerDataList, Bool)
    case mask(masked: LayerDataList, masker: LayerDataList)
}

struct LayerNonGroupData: Equatable, Hashable {
    let id: PreviewCoordinate
    let zIndex: CGFloat
    let sidebarIndex: Int
    let layer: Layer // debug
}

struct LayerGroupData: Equatable, Hashable {
    let id: PreviewCoordinate
    let zIndex: CGFloat
    let sidebarIndex: Int
    let childrenSidebarLayers: SidebarLayerList
    let layer: Layer // debug
}

extension LayerType {
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

extension LayerData: Identifiable {
    var id: PreviewCoordinate {
        self.layer.id
    }

    var groupDataList: LayerDataList? {
        switch self {
        case .nongroup, .mask:
            return nil
        case .group(_, let layerDataList, _):
            return layerDataList
        }
    }

    var isPinned: Bool {
        switch self {
        case .nongroup(_, let isPinned):
            return isPinned
        case .group(_, _, let isPinned):
            return isPinned
        case .mask:
            return false
        }
    }
        
    var layer: LayerViewModel {
        switch self {
        case .nongroup(let layer, _):
            return layer
        case .group(let layer, _, _):
            return layer
        case .mask(masked: let layerDataList, masker: _):
            // TODO: `layerDataList` should be NonEmpty; there's no way to gracefully fail here
            return layerDataList.first!.layer
        }
    }
    
    var zIndex: CGFloat {
        switch self {
        case .nongroup(let layer, _):
            return layer.zIndex.getNumber ?? .zero
        case .group(let layer, _, _):
            return layer.zIndex.getNumber ?? .zero
        case .mask(masked: let masked, masker: _):
            // TODO: is z-index for a LayerData really the first
            return masked.first?.layer.zIndex.getNumber ?? .zero
        }
    }
}
