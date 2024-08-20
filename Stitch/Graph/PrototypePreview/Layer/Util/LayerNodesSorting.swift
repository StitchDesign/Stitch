//
//  LayerNodesSorting.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/12/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension VisibleNodesViewModel {
    
    /// Recursively creates a sorted list of layers.
    @MainActor
    func recursivePreviewLayers(sidebarLayers: SidebarLayerList,
                                isRoot: Bool) -> (LayerDataList, PinMap) {
        
        let pinMap: PinMap = self.getPinMap()
        
        var layerTypesAtThisLevel = LayerTypeSet()
        var handled = LayerIdSet()
        
        sidebarLayers.enumerated().forEach {
            
            let (newLayerTypesAtThisLevel,
                 newLayersUsedAsMaskers) = handleRawSidebarLayer(
                    sidebarIndex: $0.offset,
                    layerData: $0.element,
                    layerTypesAtThisLevel: layerTypesAtThisLevel,
                    handled: handled,
                    sidebarLayers: sidebarLayers,
                    layerNodes: self.layerNodes,
                    pinMap: pinMap)
            
            layerTypesAtThisLevel = layerTypesAtThisLevel.union(newLayerTypesAtThisLevel)
            handled = handled.union(newLayersUsedAsMaskers)
        }
        
        // If we're at the root level, we need to also add the LayerTypes for views with `isPinned = true` and `pinToId = .root`, since those views' PinnedViews will not be handled by
        if isRoot,
           let rootPinnedViews = pinMap.get(nil) {
            
            let layerTypesFromRootPinnedViews = getLayerTypesForPinnedViews(
                pinnedViews: rootPinnedViews,
                sidebarLayers: sidebarLayers,
                layerNodes: self.layerNodes,
                layerTypesAtThisLevel: layerTypesAtThisLevel)
            
            layerTypesAtThisLevel = layerTypesAtThisLevel.union(layerTypesFromRootPinnedViews)
        } // if isRoot
        
        
        // log("recursivePreviewLayers: DONE GETTING ALL LAYER TYPES: \(layerTypesAtThisLevel)")
        
        // Sorting comparator
        let comparator = { (lhs: LayerType, rhs: LayerType) in
            // Variables for sorting
            let lhsZIndex = lhs.zIndex
            let rhsZIndex = rhs.zIndex
            let lhsSidebarIndex = lhs.sidebarIndex
            let rhsSidebarIndex = rhs.sidebarIndex
            
            // Sorting tiebreaker:
            // 1. Z-index input
            // 2. Sidebar order
            
            guard lhsZIndex != rhsZIndex else {
                /*
                 Larger sidebar indices should be higher in stack
                 
                 ... actually, depends on stack-type:
                 - ZStack: smallest index = bottom of stack, largest index = top of stack
                 - VStack: smallest index = top of column, largest index = bottom of column
                 - HStack: smallest index = far left of row, largest index = far right of row
                 */
                return lhsSidebarIndex > rhsSidebarIndex
            }
            
            return lhsZIndex < rhsZIndex
        }
        
        let sortedLayerTypes = layerTypesAtThisLevel.sorted(by: comparator)
        
        let sortedLayerDataList: LayerDataList = sortedLayerTypes.compactMap { (layerType: LayerType) -> LayerData? in
            self.getLayerDataFromLayerType(layerType, layerNodes: self.layerNodes)
        }
        
        log("recursivePreviewLayers: sortedLayerDataList: \(sortedLayerDataList)")
        
        return (sortedLayerDataList, pinMap)
    }
    
    @MainActor
    func getLayerDataFromLayerType(_ layerType: LayerType,
                                   layerNodes: NodesViewModelDict) -> LayerData? {
        
        switch layerType {
            
        case .mask(masked: let masked, masker: let masker):
            let maskedLayerData = masked.compactMap { getLayerDataFromLayerType($0, layerNodes: layerNodes) }
            let maskerLayerData = masker.compactMap { getLayerDataFromLayerType($0, layerNodes: layerNodes) }
            
            guard !maskedLayerData.isEmpty,
                  !maskerLayerData.isEmpty else {
                return nil
            }
            
            return .mask(masked: maskedLayerData,
                         masker: maskerLayerData)
            
        case .nongroup(let data): // LayerData
            guard let previewLayer: LayerViewModel = layerNodes
                .get(data.id.layerNodeId.id)?
                .layerNode?
                .previewLayerViewModels[safe: data.id.loopIndex] else {
                
                return nil
            }
            
            return .nongroup(previewLayer,
                             isPinnedView: layerType.pinnedViewType == .pinnedView)
            
        case .group(let layerGroupData): // LayerGroupData
            guard let previewLayer: LayerViewModel = layerNodes
                .get(layerGroupData.id.layerNodeId.asNodeId)?
                .layerNode?
                .previewLayerViewModels[safe: layerGroupData.id.loopIndex] else {
                
                return nil
            }
            
            // Pass the pinned-view-type from the LayerType to the LayerViewModel
            //            previewLayer.pinnedViewType = layerType.pinnedViewType
            
            // Recursively call on group data
            // TODO: we start the recursion all over again here? do we need to pass on the same pinMap?
            let (childrenData, _) = self.recursivePreviewLayers(
                sidebarLayers: layerGroupData.childrenSidebarLayers,
                isRoot: false)
            
            return .group(previewLayer,
                          childrenData,
                          isPinnedView: layerType.pinnedViewType == .pinnedView)
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
                                 layer: layerNode.layer,
                                 pinnedViewType: isPinnedView ? .pinnedView : nil))
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
                                    layer: layerNode.layer,
                                    pinnedViewType: isPinnedView ? .pinnedView : nil))
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
                           sidebarLayers: SidebarLayerList, // raw sidebar layers
                           layerNodes: NodesViewModelDict,
                           pinMap: PinMap) -> (LayerTypeSet,
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
    let maskerLayerData: SidebarLayerData? = sidebarLayers[safe: maskerSidebarIndex]
    
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
            sidebarLayers: sidebarLayers,
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
                    pinnedViews: pinnedViews, 
                    sidebarLayers: sidebarLayers,
                    layerNodes: layerNodes,
                    layerTypesAtThisLevel: layerTypesAtThisLevel)
                
                layerTypesAtThisLevel = layerTypesAtThisLevel.union(layerTypesFromPinnedViews)
            }
        }
    } // else
    
    return (layerTypesAtThisLevel, handled)
}

func getLayerTypesForPinnedViews(pinnedViews: LayerIdSet, // views pinned to this layer
                                 sidebarLayers: SidebarLayerList,
                                 layerNodes: NodesViewModelDict,
                                 layerTypesAtThisLevel: LayerTypeSet) -> LayerTypeSet {
    
    var layerTypesAtThisLevel = layerTypesAtThisLevel
    
    pinnedViews.forEach { (pinnedView: LayerNodeId) in
        
        // Note: we do NOT add the pinned-view A to `handled`; another copy/version of A must be handled separately and 'normally' so that its ghost view can live at its proper hierarchy level to be affected by parent scale etc.
        
        let sidebarIndexOfPinnedView = sidebarLayers.getSidebarLayerDataIndex(pinnedView.id) ?? .zero
        
        if let layerDataForPinnedView = sidebarLayers.getSidebarLayerData(pinnedView.id) {
            
            // the pinned view A could have a loop, so we get back multiple `LayerType`s, not just one.
            let layerTypesFromThisPinnedView = getLayerTypesFromSidebarLayerData(
                
                // use the layer data for the pinned view A, not the pin-receiving view B
                layerDataForPinnedView,
                
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
                sidebarIndex: sidebarIndexOfPinnedView,
                
                layerNodes: layerNodes,
                isPinnedView: true)
            
            layerTypesAtThisLevel = layerTypesAtThisLevel.union(layerTypesFromThisPinnedView)
        }
    } // pinnedViews.forEach
    
    return layerTypesAtThisLevel
}

extension SidebarLayerList {
    
    // TODO: remove after StitchViewModelKit's `StitchNestedList.get` method is fixed
    func getSidebarLayerData(_ layerId: NodeId) -> SidebarLayerData? {
        let layer: SidebarLayerData? = nil
        
        for sidebarLayerData in self {
            
            if sidebarLayerData.id == layerId {
                return sidebarLayerData
            }
            
            else if let layerFoundInChildren = sidebarLayerData.children?.getSidebarLayerData(layerId) {
                return layerFoundInChildren
            }
        } // self.forEach
        
        return layer
    }
    
    func getSidebarLayerDataIndex(_ layerId: NodeId) -> Int? {
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

