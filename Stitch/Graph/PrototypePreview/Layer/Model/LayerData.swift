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
enum LayerData {
    case nongroup(id: UUID,
                  previewCoordinate: PreviewCoordinate,
                  isPinned: Bool)

    case group(id: UUID,
               previewCoordinate: PreviewCoordinate,
               children: LayerDataList,
               isPinned: Bool)

    case mask(masked: LayerDataList,
              masker: LayerDataList)
}


extension LayerData: Identifiable {
    var id: UUID {
        switch self {
        case .nongroup(let id, let previewCoordinate, let isPinned):
            return id
        case .group(let id, let previewCoordinate, let children, let isPinned):
            return id
        case .mask(let masked, let masker):
            return masked.first!.id
        }
    }
    
    var previewCoordinate: PreviewCoordinate {
        switch self {
        case .nongroup(_, let id, _):
            return id
        case .group(_, let id, _, _):
            return id
        case .mask(let masked, let masker):
            return masked.first!.previewCoordinate
        }
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
    
    @MainActor
    func getLayer(graph: GraphState) -> LayerViewModel? {
        let id = self.previewCoordinate
        return graph.getNodeViewModel(id.layerNodeId.asNodeId)?.layerNode?.previewLayerViewModels[safe: id.loopIndex]
    }
    
    @MainActor
    func getZIndex(graph: GraphState) -> CGFloat {
        guard let layer = self.getLayer(graph: graph) else {
            return .zero
        }
        
        return layer.zIndex.getNumber ?? .zero
    }
}

/// Provides equatable equivalent that supports main actor isolation.
protocol MainActorEquatable {
    @MainActor static func equals(_ lhs: Self,
                                  _ rhs: Self,
                                  graph: GraphState) -> Bool
}

// TODO: Can we separate "cached preview layers changed" from the data we need

// Note: we define a custom == on LayerData because
extension LayerData: MainActorEquatable {
    @MainActor
    static func equals(_ lhs: LayerData,
                       _ rhs: LayerData,
                       graph: GraphState) -> Bool {
        lhs.id == rhs.id &&
        lhs.isPinned == rhs.isPinned &&
        lhs.getZIndex(graph: graph) == rhs.getZIndex(graph: graph) &&

        // Did the children change?
        LayerDataList.equals(lhs.groupDataList ?? [],
                             rhs.groupDataList ?? [],
                             graph: graph) &&
        
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
    static func equals(_ lhs: [Element],
                       _ rhs: [Element],
                       graph: GraphState) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }
        
        return zip(lhs, rhs).allSatisfy { lhsElement, rhsElement in
            Element.equals(lhsElement,
                           rhsElement,
                           graph: graph)
        }
    }
}
