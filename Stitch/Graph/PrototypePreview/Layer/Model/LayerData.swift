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
    case nongroup(LayerNonGroupData)
    case group(LayerGroupData)
    
    // TODO: theoretically could just use `[LayerType]` but need to update recursion logic
    // TODO: should be also NonEmpty, i.e. guaranteed to have at least one masked view and one masker view
    case mask(masked: LayerTypeSet, masker: LayerTypeSet)
}

/// Data type used for getting sorted data in views.
indirect enum LayerData {
    case nongroup(LayerViewModel, isPinnedView: Bool)
    case group(LayerViewModel, LayerDataList, isPinnedView: Bool)
    case mask(masked: LayerDataList, masker: LayerDataList)
}

struct LayerNonGroupData: Equatable, Hashable {
    let id: PreviewCoordinate
    let zIndex: CGFloat
    let sidebarIndex: Int
    let layer: Layer // debug
    let pinnedViewType: PinnedViewType?
}

struct LayerGroupData: Equatable, Hashable {
    let id: PreviewCoordinate
    let zIndex: CGFloat
    let sidebarIndex: Int
    let childrenSidebarLayers: SidebarLayerList // why isn't this a list of
    let layer: Layer // debug
    let pinnedViewType: PinnedViewType?
}

// "A is pinned to B" = A is a pinned view;
// but a given pinned view is rendered TWICE in the preview window:
// 1. `PinnedViewA` is the view that user sees, is pinned to some anchor of B, is rendered at same hierarchy level as B etc.
// 2. `GhostViewA` is the view the user DOES NOT see, is rendered at A's normal hierarchy level and is used simply to read how A's parents may have affected A's size etc. (e.g. A's parent layer group is scaled 2x etc.)
enum PinnedViewType {
    // visible to user, seen in pin-anchor; lives at same hierarchy level as B etc.
    case pinnedView
    
    // inivislbe to user but still rendered in preview window; used to read how A's size is modified by parent
    case ghostView
}

extension LayerType {
    var id: PreviewCoordinate {
        switch self {
        case .nongroup(let data):
            return data.id
        case .group(let data):
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
        case .nongroup(let data):
            return data.layer
        case .group(let data):
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
    
    var pinnedViewType: PinnedViewType? {
        switch self {
        case .nongroup(let x):
            return x.pinnedViewType
        case .group(let x):
            // "Is group layer itself pinned?"
            return x.pinnedViewType
        case .mask(masked: let x, masker: _):
            // "Is first masked view pinned?" (is this correct?)
            return x.first?.pinnedViewType
        }
    }
    
    var sidebarIndex: Int {
        switch self {
        case .nongroup(let nongroup):
            return nongroup.sidebarIndex
        case .group(let group):
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
        case .nongroup(let nongroup):
            return nongroup.zIndex
        case .group(let group):
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

// If pinned, the same layer view model is rendered in PreviewLayers twice (GhostView, PinnedView),
// so we need an id that distinguishes
struct LayerDataId: Equatable, Hashable, Codable {
    let coordinate: PreviewCoordinate
    let isPinned: Bool
}

extension LayerData: Identifiable {
    var id: PreviewCoordinate {
        self.layer.id
    }

    // Perf cost?
    var layerDataId: LayerDataId {
        LayerDataId(coordinate: self.layer.id,
                    isPinned: self.isPinned)
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
