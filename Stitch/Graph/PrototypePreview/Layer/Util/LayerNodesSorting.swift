//
//  LayerNodesSorting.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/12/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit





/* --------------- */

/*
 Oval A
 pinTo input: [B, B, C]
 i.e. "pin A to B", "pin A to B," "pin A to C" -> 3 layer view models
 
 i.e. 
 "pin A Loop Index 0 to B",
 "pin A Loop Index 1 to B",
 "pin A Loop Index 2 to C"
 = 3 layer view models total
 
 
 
 e.g. color input: [Red, Blue, Green] -> 3 layer view models
 
 3 layer view models (2 are pinned to B, 1 is pinned to C)
 */


/*
 START
 
 Oval A
 
 Group 1
 - B
 
 Group 2
 - C

 RESULTING SIDEBAR LAYER DATA LIST ?
 [
    A,
    Group 1 { children: [B, A] }
    Group 2 { children: [C, A] }
 ]
 */


/*
 WANT
 
 Oval A
 
 Group 1
 - B, A
 
 Group 2
 - C, A
 */

/*
 start with A, is it pinned to any views?
 */

/*
 []
 */


/*
 Raw side bar order (nested, but no notion of loops)
 
 LayerType set/list (nested + notion of loops)
 
 
 LayerDataList
 */


extension VisibleNodesViewModel {
    
    /// Recursively creates a sorted list of layers.
    ///
    
    // NEEDS TO TAKE A PIN-MAP
    @MainActor
    func recursivePreviewLayers(sidebarLayers: SidebarLayerList) -> LayerDataList {
        // let layerIdsInHierarchy = sidebarLayers.map { $0.id.asLayerNodeId }
        
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
        
        // TODO: at proper hierarchy level, insert
        
        
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
                // Larger sidebar indices should be higher in stack
                
                // ^^ no, it's the opposite, right? The first item in the ordered sidebar will have index=0 but should actually be on top ?
                //
                // Depends on ZStack vs VStack
                // - ZStack: smallest index = bottom of stack, largest index = top of stack
                // - VStack: smallest index = top of column, largest index = bottom of column
                // - HStack: smallest index = far left of row, largest index = far right of row
                return lhsSidebarIndex > rhsSidebarIndex
            }
            
            return lhsZIndex < rhsZIndex
        }
                
        let sortedLayerTypes = layerTypesAtThisLevel.sorted(by: comparator)
        
        let sortedLayerDataList: LayerDataList = sortedLayerTypes.compactMap { (layerType: LayerType) -> LayerData? in
            
            self.getLayerDataFromLayerType(layerType, layerNodes: self.layerNodes)
        }
        
        log("recursivePreviewLayers: sortedLayerDataList: \(sortedLayerDataList)")
        
        return sortedLayerDataList
    }
    
    @MainActor
    func getLayerDataFromLayerType(_ layerType: LayerType,
                                   layerNodes: NodesViewModelDict) -> LayerData? {
        
        log("getLayerDataFromLayerType: on layerType: \(layerType.layer)")
        log("getLayerDataFromLayerType: on layerType pinnedViewType: \(layerType.pinnedViewType)")
        
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
            
//            log("getLayerDataFromLayerType: previewLayer.pinnedViewType was: \(previewLayer.pinnedViewType)")
//            
//            // Pass the pinned-view-type from the LayerType to the LayerViewModel
//            previewLayer.pinnedViewType = layerType.pinnedViewType
//            log("getLayerDataFromLayerType: previewLayer.pinnedViewType is now: \(previewLayer.pinnedViewType)")
            
            return .nongroup(previewLayer, 
                             isPinnedView: layerType.pinnedViewType == .pinnedView,
                             pinnedId: .init())

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
            let childrenData = self.recursivePreviewLayers(
                sidebarLayers: layerGroupData.childrenSidebarLayers)

            return .group(previewLayer, 
                          childrenData,
                          isPinnedView: layerType.pinnedViewType == .pinnedView,
                          pinnedId: .init())
        }
    }
}

/*
 LayerType list / ordered-set
 
 "A is pinned on top of B"
 
 [
    LayerType,
    LayerType
        children: [
            LayerType, <-- for B
            LayerType
            LayerType <-- for A; inserted when we iterated over B
        ],
    LayerType <-- for A; the "ghost view"
 ]
 
 
 */

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
    
    log("handleRawSidebarLayer: on sidebarIndex \(sidebarIndex)")
    log("handleRawSidebarLayer: layerData id: \(layerData.id)")
    log("handleRawSidebarLayer: layerTypesAtThisLevel: \(layerTypesAtThisLevel)")
    
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
        .flatMap { layerNodes.get($0.id)?.layerNode?.masksPort.rowObserver.allLoopedValues.first?.getBool }
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
         log("handleRawSidebarLayer: DID NOT HAVE MASKER BELOW")
        
        if !handled.contains(layerData.id.asLayerNodeId) {
            
            let layerTypesFromThisSidebar = getLayerTypesFromSidebarLayerData(
                layerData,
                sidebarIndex: sidebarIndex,
                layerNodes: layerNodes,
                isPinnedView: false)
            
            log("handleRawSidebarLayer: layerTypesFromThisSidebar: \(layerTypesFromThisSidebar)")
            log("handleRawSidebarLayer: layerTypesFromThisSidebar.count: \(layerTypesFromThisSidebar.count)")
            
            layerTypesAtThisLevel = layerTypesAtThisLevel.union(layerTypesFromThisSidebar)
            
//            handled.insert(layerData.id.asLayerNodeId)
            
            // Does this layer have other layers pinned to it?
            // e.g. in the "A is pinned on top of B" scenario, B has A as a pinned view.
            // TODO: how does this work with masking?
            
            // "Does this layer have other views pinned to it?"
            // i.e. "Is this layer the B to some A and C?"
            if let pinnedViews = pinMap.get(layerData.id.asLayerNodeId) {
                log("handleRawSidebarLayer: the view \(layerData.id) had the following views pinned to it: \(pinnedViews)")
                
                // ... if so, iterate through B and C
                pinnedViews.forEach { (pinnedView: LayerNodeId) in
                    
                    log("handleRawSidebarLayer: handling the view \(pinnedView) that is pinned to view \(layerData.id)")
                    
                    // `.get` uses
//                    if let layerDataForPinnedView = sidebarLayers.get(pinnedView.id) {
                    if let layerDataForPinnedView = sidebarLayers.first(where: { $0.id == pinnedView.id
                    }) {
                        
                        log("handleRawSidebarLayer: layerDataForPinnedView: \(layerDataForPinnedView)")
                        
                        // the pinned view A could have a loop, so we get back multiple `LayerType`s, not just one.
                        let layerTypesFromThisPinnedView = getLayerTypesFromSidebarLayerData(
                            
                            // use the layer data for the pinned view A, not the pin-receiving view B
                            layerDataForPinnedView, // layerData,
                            
                            /*
                             Tricky -- sidebar index is for comparing z-ordering, but pinned views could live at different hierarchy levels:
                             
                             Group 1
                                - B
                             Group 2
                                - C
                                - Q
                             A
                             
                             Supposed A and Q are both pinned to B. Is Q's sidebar-index higher?
                             */
                            sidebarIndex: sidebarIndex,
                            
                            // unchanged
                            layerNodes: layerNodes,
                            
                            isPinnedView: true
                            
//                            // unchanged, right? doesn't need to be modified etc.
//                            pinMap: pinMap
                        )
                        
                        log("handleRawSidebarLayer: layer types from this pinned view \(pinnedView.id) were \(layerTypesFromThisPinnedView)")
                            
                        layerTypesAtThisLevel = layerTypesAtThisLevel.union(layerTypesFromThisPinnedView)
                    } else {
                        log("handleRawSidebarLayer: no pinned views for \(layerData.id)")
                    }
                    
                    
                } // pinnedViews.forEach
                
                // Note: we do NOT add the pinned-view A to `handled`; another copy/version of A must be handled separately and 'normally' so that its ghost view can live at its proper hierarchy level to be affected by parent scale etc.
                
                
                
            }
            
            handled.insert(layerData.id.asLayerNodeId)
            
            
            
            
        }
        else {
            log("handleRawSidebarLayer: skipping this layerData since it was already used as a masker: handled: \(handled)")
        }
        
    } // else
    
    log("handleRawSidebarLayer: done: layerTypesAtThisLevel for sidebar index \(sidebarIndex): \(layerTypesAtThisLevel)")
    log("handleRawSidebarLayer: done: handled for sidebar index \(sidebarIndex): \(handled)")
    
    return (layerTypesAtThisLevel, handled)
}
