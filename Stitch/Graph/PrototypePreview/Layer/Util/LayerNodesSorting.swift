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
    func recursivePreviewLayers(sidebarLayers: SidebarLayerList) -> LayerDataList {
        // let layerIdsInHierarchy = sidebarLayers.map { $0.id.asLayerNodeId }
        
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
                    layerNodes: self.layerNodes)
            
            layerTypesAtThisLevel = layerTypesAtThisLevel.union(newLayerTypesAtThisLevel)
            handled = handled.union(newLayersUsedAsMaskers)
        }
               
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
                return lhsSidebarIndex > rhsSidebarIndex
            }
            
            return lhsZIndex < rhsZIndex
        }
                
        let sortedLayerTypes = layerTypesAtThisLevel.sorted(by: comparator)
        
        let sortedLayerDataList: LayerDataList = sortedLayerTypes.compactMap { (layerType: LayerType) -> LayerData? in
            
            self.getLayerDataFromLayerType(layerType, layerNodes: self.layerNodes)
        }
        
//        log("recursivePreviewLayers: sortedLayerDataList: \(sortedLayerDataList)")
        
        return sortedLayerDataList
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
            guard let previewLayer = layerNodes.get(data.id.layerNodeId.id)?
                .layerNode?.previewLayerViewModels[safe: data.id.loopIndex] else {
                return nil
            }
            return .nongroup(previewLayer)

        case .group(let layerGroupData): // LayerGroupData
            guard let previewLayer = layerNodes.get(layerGroupData.id.layerNodeId.asNodeId)?
                .layerNode?.previewLayerViewModels[safe: layerGroupData.id.loopIndex] else {
                return nil
            }

            // Recursively call on group data
            let childrenData = self.recursivePreviewLayers(
                sidebarLayers: layerGroupData.childrenSidebarLayers)

            return .group(previewLayer, childrenData)
        }
    }
}

// TODO: should SidebarLayerData be an enum on children (can be empty list) vs no-children ?
// TODO: rename `SidebarLayerData` to `SidebarLayer` ?
func getLayerTypesFromSidebarLayerData(_ layerData: SidebarLayerData,
                                       sidebarIndex: Int,
                                       layerNodes: NodesViewModelDict) -> LayerTypeSet {
        
    guard let layerNode = layerNodes.get(layerData.id)?.layerNode else {
        // Can happen when we e.g. ungroup a layer
        // fatalErrorIfDebug("Could not find layer node for sidebar layer \(layerData.id)")
        return .init()
    }
    
    if let children = layerData.children {
        let layerTypes: LayerTypeSet = layerNode.previewLayerViewModels
            .map {
                .group(.init(id: $0.id,
                             zIndex: $0.zIndex.getNumber ?? .zero,
                             sidebarIndex: sidebarIndex,
                             childrenSidebarLayers: children,
                             layer: layerNode.layer))
            }
            .toOrderedSet
        
        return layerTypes
    }
    
    // Non-group case
    else {
        let layerTypes: LayerTypeSet = layerNode.previewLayerViewModels
            .reversed() // Reverse loop's layer view models, for default "ZStack" case
            .map {
                .nongroup(.init(id: $0.id,
                                zIndex: $0.zIndex.getNumber ?? .zero,
                                sidebarIndex: sidebarIndex,
                                layer: layerNode.layer))
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
                           layerNodes: NodesViewModelDict) -> (LayerTypeSet,
                                                               // layers used as masks
                                                               // TODO: not needed anymore?
                                                               LayerIdSet) {
    
    var layerTypesAtThisLevel = layerTypesAtThisLevel
    var handled = handled
    
//    log("recursivePreviewLayers: on sidebarIndex \(sidebarIndex)")
//    log("recursivePreviewLayers: layerData id: \(layerData.id)")
//    log("recursivePreviewLayers: layerTypesAtThisLevel: \(layerTypesAtThisLevel)")
    
    guard !handled.contains(layerData.id.asLayerNodeId) else {
        // log("recursivePreviewLayers: this layerData was already handled, returning early")
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
        
//         log("recursivePreviewLayers: HAD MASKER BELOW")
//         log("recursivePreviewLayers: maskerLayerData \(maskerLayerData.id)")
        
        // Note: a given masked/masker view might be a loop, so we get back not 1 but a list of LayerTypes
        let masked = getLayerTypesFromSidebarLayerData(
            layerData,
            sidebarIndex: sidebarIndex,
            layerNodes: layerNodes)
        
        // this masked view has now been handled
        handled.insert(layerData.id.asLayerNodeId)
        
        // Recur, since masker could have its own masker
        let (acc1, acc2) = handleRawSidebarLayer(
            sidebarIndex: maskerSidebarIndex,
            layerData: maskerLayerData,
            layerTypesAtThisLevel: .init(), // each mask-recur-level has own layer types
            handled: handled, // ... but a given layer can only appear at a single mask-recur-level
            sidebarLayers: sidebarLayers,
            layerNodes: layerNodes)
        
        handled = handled.union(acc2)
                
        let maskLayerType: LayerType = .mask(masked: masked,
                                             masker: acc1)
        
        layerTypesAtThisLevel.append(maskLayerType)
        
        // this masker view has now been handled, but can't add until end, i.e. here
        handled.insert(maskerLayerData.id.asLayerNodeId)
        
    } // if haskMask
    
    // WE DID NOT HAVE A MASKER FOR THIS SIDEBAR LAYER
    else {
//         log("recursivePreviewLayers: DID NOT HAVE MASKER BELOW")
        
        if !handled.contains(layerData.id.asLayerNodeId) {
            
            let layerTypesFromThisSidebar = getLayerTypesFromSidebarLayerData(
                layerData,
                sidebarIndex: sidebarIndex,
                layerNodes: layerNodes)
            
            //             log("recursivePreviewLayers: layerTypesFromThisSidebar: \(layerTypesFromThisSidebar)")
            //             log("recursivePreviewLayers: layerTypesFromThisSidebar.count: \(layerTypesFromThisSidebar.count)")
            
            layerTypesAtThisLevel = layerTypesAtThisLevel.union(layerTypesFromThisSidebar)
            
            handled.insert(layerData.id.asLayerNodeId)
        }
//        else {
//            log("recursivePreviewLayers: skipping this layerData since it was already used as a masker: handled: \(handled)")
//        }
        
    } // else
    
//    log("recursivePreviewLayers: done: layerTypesAtThisLevel for sidebar index \(sidebarIndex): \(layerTypesAtThisLevel)")
//    log("recursivePreviewLayers: done: handled for sidebar index \(sidebarIndex): \(handled)")
    
    return (layerTypesAtThisLevel, handled)
}
