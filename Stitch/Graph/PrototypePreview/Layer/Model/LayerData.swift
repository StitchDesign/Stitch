//
//  LayerData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/16/23.
//

import Foundation
import StitchSchemaKit
import OrderedCollections

typealias LayerDataList = [LayerData]

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

// TODO: Can we separate "cached preview layers changed" from the data we need

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
