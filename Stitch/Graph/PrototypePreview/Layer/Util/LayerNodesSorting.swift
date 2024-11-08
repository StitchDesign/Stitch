//
//  LayerNodesSorting.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/12/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {
    
    /// Recursively creates a sorted list of layers.
    @MainActor
    func recursivePreviewLayers(sidebarLayersAtHierarchy: SidebarLayerList? = nil,
                                sidebarLayersGlobal: SidebarLayerList,
                                pinMap: RootPinMap,
                                isInGroupOrientation: Bool = false) -> LayerDataList {
        
        let isRoot = sidebarLayersAtHierarchy == nil
        let sidebarLayersAtHierarchy = sidebarLayersAtHierarchy ?? sidebarLayersGlobal
        let pinnedLayerIds = pinMap.allPinnedLayerIds.map { $0.id }
        var layerTypesAtThisLevel = LayerTypeSet()
        var handled = LayerIdSet()
        
        // Filter out pinned views for visible layers, they'll be re-inserted in handleRawSidebarLayer
        let filteredSidebarLayersAtHierarchy = sidebarLayersAtHierarchy.filter {
            !pinnedLayerIds.contains($0.id)
        }
        
        filteredSidebarLayersAtHierarchy.forEach { sidebarItem in
            let sidebarIndex = sidebarLayersAtHierarchy.firstIndex { $0.id == sidebarItem.id }
            assertInDebug(sidebarIndex.isDefined)
            
            let (newLayerTypesAtThisLevel,
                 newLayersUsedAsMaskers) = handleRawSidebarLayer(
                    sidebarIndex: sidebarIndex ?? .zero,
                    layerData: sidebarItem,
                    layerTypesAtThisLevel: layerTypesAtThisLevel,
                    handled: handled,
                    sidebarLayersAtHierarchy: filteredSidebarLayersAtHierarchy,
                    sidebarLayersGlobal: sidebarLayersGlobal,
                    layerNodes: self.layerNodes,
                    pinMap: pinMap)
            
            layerTypesAtThisLevel = layerTypesAtThisLevel.union(newLayerTypesAtThisLevel)
            handled = handled.union(newLayersUsedAsMaskers)
        }
        
        // If we're at the root level, we need to also add the LayerTypes for views with `isPinned = true` and `pinToId = .root`, since those views' PinnedViews will not be handled by
        if isRoot,
           let pinnedData = pinMap.get(nil) {
            
            let layerTypesFromRootPinnedViews = getLayerTypesForPinnedViews(
                pinnedData: pinnedData,
                sidebarLayers: sidebarLayersGlobal,
                layerNodes: self.layerNodes,
                layerTypesAtThisLevel: layerTypesAtThisLevel)
            
            layerTypesAtThisLevel = layerTypesAtThisLevel.union(layerTypesFromRootPinnedViews)
        } // if isRoot
        
        
        // log("recursivePreviewLayers: DONE GETTING ALL LAYER TYPES: \(layerTypesAtThisLevel)")
        
        var sortedLayerTypes = layerTypesAtThisLevel.sorted(by: { lhs, rhs in
            Self.layerSortingComparator(lhs: lhs,
                                        rhs: rhs,
                                        pinMap: pinMap)
        })
        
        if isInGroupOrientation {
            sortedLayerTypes = sortedLayerTypes.reversed()
        }
        
        let sortedLayerDataList: LayerDataList = sortedLayerTypes.compactMap { (layerType: LayerType) -> LayerData? in
            self.getLayerDataFromLayerType(layerType,
                                           pinMap: pinMap,
                                           sidebarLayersGlobal: sidebarLayersGlobal,
                                           layerNodes: self.layerNodes)
        }
        
        // log("recursivePreviewLayers: sortedLayerDataList: \(sortedLayerDataList)")
        
        return sortedLayerDataList
    }
    
    /// Sorting comparator for layer data, which drives z-index order.
    /// Sorting tiebreaker:
    ///   1. Pinning
    ///   2. Z-index input
    ///   3. Sidebar order
    static func layerSortingComparator(lhs: LayerType,
                                       rhs: LayerType,
                                       pinMap: RootPinMap) -> Bool {
        // Variables for sorting
        let lhsZIndex = lhs.zIndex
        let rhsZIndex = rhs.zIndex
        let lhsSidebarIndex = lhs.sidebarIndex
        let rhsSidebarIndex = rhs.sidebarIndex
        
        // If both layers are in same pinning linked list, prioritize the lower-level pin over a receiver
        let isPinningScenario = pinMap.areLayersInSamePinFamily(idSet: .init([lhs.id.layerNodeId, rhs.id.layerNodeId]))
        
        // Determines if a view is pinned and if so, how nested that pin is (higher value = more nesting)
        if isPinningScenario {
            let lhsPinNestedCount = pinMap.getPinnedNestedLayerCount(id: lhs.id.layerNodeId)
            let rhsPinNestedCount = pinMap.getPinnedNestedLayerCount(id: rhs.id.layerNodeId)
            
            if lhsPinNestedCount != rhsPinNestedCount {
                return rhsPinNestedCount > lhsPinNestedCount
            }
        }
        
        if lhsZIndex != rhsZIndex {
            return lhsZIndex < rhsZIndex
        }
        
        /*
         Larger sidebar indices should be higher in stack
         
         ... actually, depends on stack-type:
         - ZStack: smallest index = bottom of stack, largest index = top of stack
         - VStack: smallest index = top of column, largest index = bottom of column
         - HStack: smallest index = far left of row, largest index = far right of row
         */
        return lhsSidebarIndex > rhsSidebarIndex
    }
    
    @MainActor
    func getLayerDataFromLayerType(_ layerType: LayerType,
                                   pinMap: RootPinMap,
                                   sidebarLayersGlobal: SidebarLayerList,
                                   layerNodes: NodesViewModelDict) -> LayerData? {
        
        switch layerType {
            
        case .mask(masked: let masked, masker: let masker):
            let maskedLayerData = masked.compactMap { getLayerDataFromLayerType($0,
                                                                                pinMap: pinMap, 
                                                                                sidebarLayersGlobal: sidebarLayersGlobal,
                                                                                layerNodes: layerNodes) }
            let maskerLayerData = masker.compactMap { getLayerDataFromLayerType($0,
                                                                                pinMap: pinMap,
                                                                                sidebarLayersGlobal: sidebarLayersGlobal,
                                                                                layerNodes: layerNodes) }
            
            guard !maskedLayerData.isEmpty,
                  !maskerLayerData.isEmpty else {
                return nil
            }
            
            return .mask(masked: maskedLayerData,
                         masker: maskerLayerData)
            
        case .nongroup(let data, let isPinned): // LayerData
            guard let previewLayer: LayerViewModel = layerNodes
                .get(data.id.layerNodeId.id)?
                .layerNode?
                .previewLayerViewModels[safe: data.id.loopIndex] else {
                
                return nil
            }
            
            return .nongroup(previewLayer, isPinned)
            
        case .group(let layerGroupData, let isPinned): // LayerGroupData
            guard let previewLayer: LayerViewModel = layerNodes
                .get(layerGroupData.id.layerNodeId.asNodeId)?
                .layerNode?
                .previewLayerViewModels[safe: layerGroupData.id.loopIndex] else {
                
                return nil
            }
            
            let isInGroupOrientation = previewLayer.orientation.getOrientation?.isOrientated ?? false
            
            // Pass the pinned-view-type from the LayerType to the LayerViewModel
            //            previewLayer.pinnedViewType = layerType.pinnedViewType
            
            // Recursively call on group data
            // TODO: we start the recursion all over again here? do we need to pass on the same pinMap?
            let childrenData = self.recursivePreviewLayers(
                sidebarLayersAtHierarchy: layerGroupData.childrenSidebarLayers,
                sidebarLayersGlobal: sidebarLayersGlobal,
                pinMap: pinMap,
                isInGroupOrientation: isInGroupOrientation)
            
            return .group(previewLayer,
                          childrenData,
                          isPinned)
        }
    }
}

// TODO: should SidebarLayerData be an enum on children (can be empty list) vs no-children ?
// TODO: rename `SidebarLayerData` to `SidebarLayer` ?
func getLayerTypesFromSidebarLayerData(_ layerData: SidebarLayerData,
                                       sidebarIndex: Int,
                                       layerNodes: NodesViewModelDict,
                                       isPinnedView: Bool) -> LayerTypeSet {
    
    guard let layerNode = layerNodes.get(layerData.id)?.layerNode else {
        // Can happen when we e.g. ungroup a layer
        // fatalErrorIfDebug("Could not find layer node for sidebar layer \(layerData.id)")
        return .init()
    }
    
    if let children = layerData.children {
        let layerTypes: LayerTypeSet = layerNode.previewLayerViewModels
            .map { layerViewModel in
                    .group(.init(id: layerViewModel.id,
                                 zIndex: layerViewModel.zIndex.getNumber ?? .zero,
                                 sidebarIndex: sidebarIndex,
                                 childrenSidebarLayers: children,
                                 layer: layerNode.layer),
                           isPinnedView)
            }
            .toOrderedSet
        
        return layerTypes
    }
    
    // Non-group case
    else {
        let layerTypes: LayerTypeSet = layerNode.previewLayerViewModels
            .reversed() // Reverse loop's layer view models, for default "ZStack" case
            .map { layerViewModel in
                    .nongroup(.init(id: layerViewModel.id,
                                    zIndex: layerViewModel.zIndex.getNumber ?? .zero,
                                    sidebarIndex: sidebarIndex,
                                    layer: layerNode.layer),
                              isPinnedView)
            }
            .toOrderedSet
        
        return layerTypes
    }
}

// TODO: properly handle a loop in the `mask: Bool` input of a layer node
// TODO: write tests for this logic
@MainActor
func handleRawSidebarLayer(sidebarIndex: Int,
                           layerData: SidebarLayerData,
                           layerTypesAtThisLevel: LayerTypeSet, // i.e. acc
                           handled: LayerIdSet, // i.e. acc2
                           sidebarLayersAtHierarchy: SidebarLayerList, // raw sidebar layers
                           sidebarLayersGlobal: SidebarLayerList, // all sidebar layers, needed for pinning
                           layerNodes: NodesViewModelDict,
                           pinMap: RootPinMap) -> (LayerTypeSet,
                                               // layers used as masks
                                               // TODO: not needed anymore?
                                               LayerIdSet) {
    
    var layerTypesAtThisLevel = layerTypesAtThisLevel
    var handled = handled
    
    guard !handled.contains(layerData.id.asLayerNodeId) else {
        // log("handleRawSidebarLayer: this layerData was already handled, returning early")
        return (layerTypesAtThisLevel, handled)
    }
    
    // if this sidebar layer has a masker, the masker's index will be *immediately* below
    let maskerSidebarIndex = sidebarIndex + 1
    let maskerLayerData: SidebarLayerData? = sidebarLayersAtHierarchy[safe: maskerSidebarIndex]
    
    /*
     TODO: need to iterate through each preview layer view model on layer node and check, *at that particular index*, whether the `mask input = true`; rather than checking just at top level.
     
     i.e. need rather to do something like:
     
     let layerNode = layerNodes.get(layerData.id).previewLayerViewModels.enumerated().forEach {
     let index = $0.offset
     let layerViewModel = $0.element
     if layerViewModel.masks { ... }
     }
     */
    let hasMask = maskerLayerData
        .flatMap { layerNodes.get($0.id)?.layerNode?.masksPort.activeValue.getBool }
    ?? false
    
    // WE HAD A MASKER FOR THIS SIDEBAR LAYER
    if hasMask,
       let maskerLayerData = maskerLayerData {
        
        //        log("handleRawSidebarLayer: HAD MASKER BELOW")
        //        log("handleRawSidebarLayer: maskerLayerData \(maskerLayerData.id)")
        
        // Note: a given masked/masker view might be a loop, so we get back not 1 but a list of LayerTypes
        let masked = getLayerTypesFromSidebarLayerData(
            layerData,
            sidebarIndex: sidebarIndex,
            layerNodes: layerNodes,
            isPinnedView: false)
        
        // this masked view has now been handled
        handled.insert(layerData.id.asLayerNodeId)
        
        // Recur, since masker could have its own masker
        let (acc1, acc2) = handleRawSidebarLayer(
            sidebarIndex: maskerSidebarIndex,
            layerData: maskerLayerData,
            layerTypesAtThisLevel: .init(), // each mask-recur-level has own layer types
            handled: handled, // ... but a given layer can only appear at a single mask-recur-level
            sidebarLayersAtHierarchy: sidebarLayersAtHierarchy,
            sidebarLayersGlobal: sidebarLayersGlobal,
            layerNodes: layerNodes,
            pinMap: pinMap)
        
        handled = handled.union(acc2)
        
        let maskLayerType: LayerType = .mask(masked: masked,
                                             masker: acc1)
        
        layerTypesAtThisLevel.append(maskLayerType)
        
        // this masker view has now been handled, but can't add until end, i.e. here
        handled.insert(maskerLayerData.id.asLayerNodeId)
        
    } // if haskMask
    
    // WE DID NOT HAVE A MASKER FOR THIS SIDEBAR LAYER
    else {
        // log("handleRawSidebarLayer: DID NOT HAVE MASKER BELOW")
        
        if !handled.contains(layerData.id.asLayerNodeId) {
            
            let layerTypesFromThisSidebar = getLayerTypesFromSidebarLayerData(
                layerData,
                sidebarIndex: sidebarIndex,
                layerNodes: layerNodes,
                isPinnedView: false)
            
            layerTypesAtThisLevel = layerTypesAtThisLevel.union(layerTypesFromThisSidebar)
            
            handled.insert(layerData.id.asLayerNodeId)
            
            // Does this layer have other layers pinned to it?
            // e.g. in the "A is pinned on top of B" scenario, B has A as a pinned view.
            // TODO: how does this work with masking?
            
            // "Does this layer have other views pinned to it?"
            // i.e. "Is this layer the B to some A and C?"
            if let pinnedViews = pinMap.get(layerData.id.asLayerNodeId) {
                let layerTypesFromPinnedViews = getLayerTypesForPinnedViews(
                    pinnedData: pinnedViews,
                    sidebarLayers: sidebarLayersGlobal,
                    layerNodes: layerNodes,
                    layerTypesAtThisLevel: layerTypesAtThisLevel)
                
                layerTypesAtThisLevel = layerTypesAtThisLevel.union(layerTypesFromPinnedViews)
            }
        }
    } // else
    
    return (layerTypesAtThisLevel, handled)
}

/*
 Tricky -- sidebar index is for comparing z-ordering, but pinned views could live at different hierarchy levels:
 
 Group 1
 - B
 Group 2
 - C
 - Q
 A
 
 Supposed A and Q are both pinned to B. Is Q's sidebar-index higher?
 
 
 
 Another tricky case:
 
 Group
 - Blue
 - Red
 
 Blue is pinned to Group; but, if we just go by list-item-index in each layer's respective hierarchy level (without any pinning changes),
 *both* Blue and Group have the same index: 0
 And so our comparator logic is indeterminate.
 
 
 A possible solution?: flatten the hierarchy so that each layer has unique index; e.g.:
 
 Group 1
 - Blue
 - Red
 - Group 2
    - Yellow
 
 ... becomes: [Group 1, Blue, Red, Group 2, Yellow]
 */
func getLayerTypesForPinnedViews(pinnedData: LayerPinData, // views pinned to this layer
                                 sidebarLayers: SidebarLayerList,
                                 layerNodes: NodesViewModelDict,
                                 layerTypesAtThisLevel: LayerTypeSet) -> LayerTypeSet {
    
    var layerTypesAtThisLevel = layerTypesAtThisLevel
    
    pinnedData
        .pins?
        .flatMap { $0.getAllPins() }
        .toSet
        .compactMap { $0 }
        .forEach { (pinnedView: LayerNodeId) in
        
        // Note: we do NOT add the pinned-view A to `handled`; another copy/version of A must be handled separately and 'normally' so that its ghost view can live at its proper hierarchy level to be affected by parent scale etc.
        
        let sidebarIndexOfPinnedView = sidebarLayers.getSidebarLayerDataIndex(pinnedView.id) ?? .zero
        
        if let layerDataForPinnedView = sidebarLayers.getSidebarLayerData(pinnedView.id) {
            
            // the pinned view A could have a loop, so we get back multiple `LayerType`s, not just one.
            let layerTypesFromThisPinnedView = getLayerTypesFromSidebarLayerData(
                // use the layer data for the pinned view A, not the pin-receiving view B
                layerDataForPinnedView,
                sidebarIndex: sidebarIndexOfPinnedView,
                layerNodes: layerNodes,
                isPinnedView: true)
            
            layerTypesAtThisLevel = layerTypesAtThisLevel.union(layerTypesFromThisPinnedView)
        }
    } // pinnedViews.forEach
    
    return layerTypesAtThisLevel
}

import StitchViewKit
extension Array where Element: StitchNestedListElement & Equatable {
    
    func insertSidebarLayerData(_ itemId: Element.ID, parent: Element.ID) -> Element? {
        let layer: Element? = nil
        
        for sidebarLayerData in self {
            
            if sidebarLayerData.id == itemId {
                return sidebarLayerData
            }
            
            else if let layerFoundInChildren = sidebarLayerData.children?.getSidebarLayerData(itemId) {
                return layerFoundInChildren
            }
        } // self.forEach
        
        return layer
    }
    
    // TODO: remove after StitchViewModelKit's `StitchNestedList.get` method is fixed
    func getSidebarLayerData(_ itemId: Element.ID) -> Element? {
        let layer: Element? = nil
        
        for sidebarLayerData in self {
            
            if sidebarLayerData.id == itemId {
                return sidebarLayerData
            }
            
            else if let layerFoundInChildren = sidebarLayerData.children?.getSidebarLayerData(itemId) {
                return layerFoundInChildren
            }
        } // self.forEach
        
        return layer
    }
    
    func getSidebarLayerDataIndex(_ layerId: Element.ID) -> Int? {
        let index: Int? = nil
        
        for sidebarLayerData in self {
            
            if sidebarLayerData.id == layerId {
                return self.firstIndex(of: sidebarLayerData)
            }
            
            else if let indexFoundInChildren = sidebarLayerData.children?.getSidebarLayerDataIndex(layerId) {
                return indexFoundInChildren
            }
        }
        
        return index
    }
}

