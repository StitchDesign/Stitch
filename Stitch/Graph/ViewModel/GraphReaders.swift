//
//  CanvasItemReader.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/11/25.
//

import Foundation

// Protocol for functions that only need to retrieve certain objects from GraphState

protocol GraphReader {
    @MainActor func getNode(_ id: NodeId) -> NodeViewModel?
    
    // Reading from, writing to a layer node
    @MainActor func getLayerNode(_ id: NodeId) -> LayerNodeViewModel?
    // Reading from a layer node
    @MainActor func getLayerNodeReader(_ id: NodeId) -> LayerNodeReader?
    
    @MainActor func getGroupNode(_ id: NodeId) -> CanvasItemViewModel?
    
    @MainActor func getCanvasItem(_ id: CanvasItemId) -> CanvasItemViewModel?
    
    @MainActor func getInputRowObserver(_ id: InputCoordinate) -> InputNodeRowObserver?
    
    @MainActor func getOutputRowObserver(_ id: OutputCoordinate) -> OutputNodeRowObserver?
    
    @MainActor var nodes: NodesViewModelDict { get }
    
    @MainActor func layerNodes() -> LayerNodes
    
    @MainActor func layerNodesDict() -> LayerNodesDict
    
    
    // Sidebar data
    
    @MainActor var layersSidebarViewModel: LayersSidebarViewModel { get }
    
    @MainActor func getLayerChildren(for groupId: NodeId) -> NodeIdSet
    
    @MainActor func createSchema() -> GraphEntity

#if DEV_DEBUG || DEBUG
    @MainActor var DEBUG_GENERATING_CANVAS_ITEM_ITEM_SIZES: Bool { get }
#else
    @MainActor var DEBUG_GENERATING_CANVAS_ITEM_ITEM_SIZES: Bool { get }
#endif
    
}

extension GraphState: GraphReader {
    func getLayerNode(_ id: NodeId) -> LayerNodeViewModel? {
        self.getNode(id)?.layerNodeViewModel
    }
    
    func getLayerNodeReader(_ id: NodeId) -> LayerNodeReader? {
        self.getNode(id)?.layerNodeViewModel
    }

    func getGroupNode(_ id: NodeId) -> CanvasItemViewModel? {
        self.getNode(id)?.nodeType.groupNode
    }
    
    @MainActor
    func layerNodes() -> LayerNodes {
        self.nodes.values.compactMap(\.layerNode)
    }
    
    @MainActor
    func layerNodesDict() -> LayerNodesDict {
        self.nodes.reduce(into: LayerNodesDict()) { partialResult, kv in
            if let layerNode = kv.value.layerNode {
                partialResult.updateValue(layerNode,
                                          forKey: kv.key)
            }
        }
    }
}




// TODO: remove
extension GraphReader {
    @MainActor
    func updateCanvasItemFields(canvasItemId: CanvasItemId,
                                activeIndex: ActiveIndex) {
        guard let canvasItem = self.getCanvasItem(canvasItemId) else {
            // Crashes in some valid examples
            // fatalErrorIfDebug()
            return
        }
        
        canvasItem.inputViewModels.forEach {
            if let observer = self.getInputRowObserver($0.nodeIOCoordinate) {
                $0.updateFields(observer.getActiveValue(activeIndex: activeIndex))
            }
        }
        
        canvasItem.outputViewModels.forEach {
            if let observer = self.getOutputRowObserver($0.nodeIOCoordinate) {
                $0.updateFields(observer.getActiveValue(activeIndex: activeIndex))
            }
        }
    }
}
