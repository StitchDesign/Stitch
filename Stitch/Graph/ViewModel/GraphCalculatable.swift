//
//  GraphCalculatable.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/25.
//

import Foundation
import StitchEngine

extension GraphState: GraphCalculatable {
    @MainActor
    var currentGraphTime: TimeInterval {
        self.graphStepManager.graphTime
    }
    
    @MainActor
    func didPortsUpdate(ports: Set<StitchEngine.NodePortType<NodeViewModel>>) {
        // Update multi-selected layers in sidebar with possible heterogenous values
        if let currentMultiselectionMap = self.propertySidebar.heterogenousFieldsMap {
            let newMultiselectionMap = Set(currentMultiselectionMap.keys)
                .getHeterogenousFieldsMap(graph: self)
            
            if currentMultiselectionMap != newMultiselectionMap {
                self.propertySidebar.heterogenousFieldsMap = newMultiselectionMap
            }
        }
    }
    
    @MainActor
    func updateOrderedPreviewLayers() {
        guard let activeIndex = self.documentDelegate?.activeIndex else {
            fatalErrorIfDebug()
            return
        }
        
        let layerNodes: LayerNodesDict = self.layerNodesDict()
        
        // TODO: needs to take layer nodes explicitly
        let flattenedPinMap = getFlattenedPinMap(
            layerNodes: layerNodes,
            graph: self)
        
        let rootPinMap = getRootPinMap(pinMap: flattenedPinMap)
                
        let nonHiddenSidebarLayers: [SidebarLayerData] = self.layersSidebarViewModel
            .items
            .recursiveCompactMap { item in
                item.isHidden(graph: self) ? nil : item.createSchema()
            } children: { item in
                item.children
            } makeWithChildren: { sidebarLayerData, sidebarLayerDataList in
                var sidebarLayerData = sidebarLayerData
                // Important: non-nil `children` = "this is a group"
                if sidebarLayerData.children.isDefined {
                    sidebarLayerData.children = sidebarLayerDataList
                }
                return sidebarLayerData
            }
                        
        // TODO: can `recursivePreviewLayers` return a LayerTypeList, which we cache instead of a LayerDataList? If the LayerTypeList changes, we produce a new LayerDataList (which is consumed by GeneratePreview)
        let previewLayers: LayerDataList = recursivePreviewLayers(
            layerNodes: layerNodes,
            sidebarLayersGlobal: nonHiddenSidebarLayers,
            pinMap: rootPinMap,
            activeIndex: activeIndex)
                
        let layersChanged = !LayerDataList.equals(self.cachedOrderedPreviewLayers, previewLayers)
        log("updateOrderedPreviewLayers: layersChanged: \(layersChanged)")
        
//        if !LayerDataList.equals(self.cachedOrderedPreviewLayers, previewLayers) {
            self.cachedOrderedPreviewLayers = previewLayers
//        }
        if self.flattenedPinMap != flattenedPinMap {
            self.flattenedPinMap = flattenedPinMap
        }
        if self.pinMap != rootPinMap {
            self.pinMap = rootPinMap
        }
    }
    
    @MainActor
    func getNodesToAlwaysRun() -> Set<UUID> {
        Array(self.nodes
                .values
                .filter { $0.patch?.willAlwaysRunEval ?? false }
                .map(\.id))
            .toSet
    }
    
    @MainActor
    func getAnimationNodes() -> Set<UUID> {
        Array(self.nodes
                .values
                .filter { $0.patch?.isAnimationNode ?? false }
                .map(\.id))
            .toSet
    }
    
    @MainActor
    func getNodeViewModel(id: UUID) -> NodeViewModel? {
        self.getNodeViewModel(id)
    }
}
