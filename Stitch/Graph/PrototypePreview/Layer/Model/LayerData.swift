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
    case nongroup(data: LayerTypeNonGroupData, isPinned: Bool)
    
    case group(data: LayerTypeGroupData, isPinned: Bool)
    
    // TODO: theoretically could just use `[LayerType]` but need to update recursion logic
    // TODO: should be also NonEmpty, i.e. guaranteed to have at least one masked view and one masker view
    case mask(masked: LayerTypeSet,
              masker: LayerTypeSet)
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

/// Data type used for getting sorted data in views.
indirect enum LayerData {
    case nongroup(layerNode: LayerNodeViewModel,
                  layerViewModel: LayerViewModel,
                  isPinned: Bool)

    case group(layerNode: LayerNodeViewModel,
               layerViewModel: LayerViewModel,
               children: LayerDataList,
               isPinned: Bool)

    case mask(masked: LayerDataList,
              masker: LayerDataList)
}


extension LayerData: Identifiable {
    var id: PreviewCoordinate {
        self.layer.id
    }

    var groupDataList: LayerDataList? {
        switch self {
        case .nongroup, .mask:
            return nil
        case .group(_, _, let layerDataList, _):
            return layerDataList
        }
    }

    var isPinned: Bool {
        switch self {
        case .nongroup(_, _, let isPinned):
            return isPinned
        case .group(_, _, _, let isPinned):
            return isPinned
        case .mask:
            return false
        }
    }
    
    var layer: LayerViewModel {
        switch self {
        case .nongroup(_, let layer, _):
            return layer
        case .group(_, let layer, _, _):
            return layer
        case .mask(masked: let layerDataList, masker: _):
            // TODO: `layerDataList` should be NonEmpty; there's no way to gracefully fail here
            return layerDataList.first!.layer
        }
    }
    
    @MainActor
    var zIndex: CGFloat {
        switch self {
        case .nongroup(_, let layer, _):
            return layer.zIndex.getNumber ?? .zero
        case .group(_, let layer, _, _):
            return layer.zIndex.getNumber ?? .zero
        case .mask(masked: let masked, masker: _):
            // TODO: is z-index for a LayerData really the first
            return masked.first?.layer.zIndex.getNumber ?? .zero
        }
    }
}

/// Provides equatable equivalent that supports main actor isolation.
protocol MainActorEquatable {
    @MainActor static func equals(_ lhs: Self, _ rhs: Self) -> Bool
}

// TODO: Can we separate "cached preview layers changed" from the data we need to g x

// Note: we define a custom == on LayerData because
extension LayerData: MainActorEquatable {
    @MainActor
    static func equals(_ lhs: LayerData, _ rhs: LayerData) -> Bool {
        lhs.id == rhs.id &&
        lhs.isPinned == rhs.isPinned &&
        lhs.zIndex == rhs.zIndex &&

        // Did the children change?
        LayerDataList.equals(lhs.groupDataList ?? [], rhs.groupDataList ?? []) &&
        
        // Important to check if the case changed
        // (e.g. we hid a masker layer, so a previously masked layer now became .nonGroup or .group instead of .mask)
        LayerData.areSameCase(lhs: lhs, rhs: rhs)
    }
}

extension LayerData {
    static func areSameCase(lhs: Self, rhs: Self) -> Bool {
        switch lhs {
        case .nongroup:
            return rhs.isNonGroupCase
        case .group:
            return rhs.isGroupCase
        case .mask:
            return rhs.isMaskCase
        }
    }
 
    var isNonGroupCase: Bool {
        switch self {
        case .nongroup: return true
        default: return false
        }
    }
    
    var isGroupCase: Bool {
        switch self {
        case .group: return true
        default: return false
        }
    }
    
    var isMaskCase: Bool {
        switch self {
        case .mask: return true
        default: return false
        }
    }
}

extension Array where Element: MainActorEquatable {
    @MainActor
    static func equals(_ lhs: [Element], _ rhs: [Element]) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }
        
        return zip(lhs, rhs).allSatisfy { lhsElement, rhsElement in
            Element.equals(lhsElement, rhsElement)
        }
    }
}
