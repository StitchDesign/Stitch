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
    case nongroup(LayerViewModel)
    case group(LayerViewModel, LayerDataList)
    case mask(masked: LayerDataList, masker: LayerDataList)
}

extension LayerData {
    
    var getNonGroup: LayerViewModel? {
        switch self {
        case .nongroup(let layerViewModel):
            return layerViewModel
        case .group, .mask:
            return nil
        }
    }
    
    var getGroup: (LayerViewModel, LayerDataList)? {
        switch self {
        case .nongroup, .mask:
            return nil
        case .group(let layerViewModel, let layerDataList):
            return (layerViewModel, layerDataList)
        }
    }
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

    // DEBUG ONLY?
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

extension LayerData: Identifiable {
    var id: PreviewCoordinate {
        self.layer.id
    }

    var groupDataList: LayerDataList? {
        switch self {
        case .nongroup, .mask:
            return nil
        case .group(_, let layerDataList):
            return layerDataList
        }
    }

    var layer: LayerViewModel {
        switch self {
        case .nongroup(let layer):
            return layer
        case .group(let layer, _):
            return layer
        case .mask(masked: let layerDataList, masker: _):
            // TODO: `layerDataList` should be NonEmpty; there's no way to gracefully fail here
            return layerDataList.first!.layer
        }
    }
    
    var zIndex: CGFloat {
        switch self {
        case .nongroup(let layer):
            return layer.zIndex.getNumber ?? .zero
        case .group(let layer, _):
            return layer.zIndex.getNumber ?? .zero
        case .mask(masked: let masked, masker: _):
            // TODO: is z-index for a LayerData really the first
            return masked.first?.layer.zIndex.getNumber ?? .zero
        }
    }
}
