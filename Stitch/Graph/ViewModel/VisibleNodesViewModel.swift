//
//  VisibleNodesViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/11/22.
//

import SwiftUI
import StitchSchemaKit

@Observable
final class VisibleNodesViewModel: Sendable {
    // Storage for view models
    @MainActor var nodes = NodesViewModelDict()

    // Saves location and zoom-specific data for groups
    @MainActor var nodesByPage: NodesPagingDict // = [.root: .init()]
    
    // Caches layer node data for perf
    @MainActor var layerDropdownChoiceCache: [NodeId : LayerDropdownChoice] = [:]
    
    @MainActor var visibleCanvasIds = CanvasItemIdSet()
    
    // PERF: Caches visual splitter input/output by group node data
    @MainActor var cachedVisibleSplitterInputRows = [NodeId? : [InputNodeRowObserver]]()
    @MainActor var cachedVisibleSplitterOutputRows = [NodeId? : [OutputNodeRowObserver]]()
    
    // Signals to SwiftUI layout when new sizing data is needed;
    // tracked here to fix stutter that exists if we reset cache before
    // a dispatch updates it on subsequent call.
    @MainActor var needsInfiniteCanvasCacheReset = true
    @MainActor var infiniteCanvasCache: InfiniteCanvas.Cache = .init()
    
    @MainActor init(localPosition: CGPoint) {
        self.nodesByPage = [.root: .init(localPosition: localPosition)]
    }
}

/*
 //        let x: Set<LayersSidebarViewModel.ItemID> = graph.sidebarSelectionState.primary
 //        let k: SidebarLayerIdSet = graph.sidebarSelectionState.primary
 */
typealias SidebarLayerIdSet = Set<LayersSidebarViewModel.ItemID>

extension GraphState {
    
    @MainActor
    var visibleCanvasIds: CanvasItemIdSet {
        get {
            self.visibleNodesViewModel.visibleCanvasIds
        } set(newValue) {
            self.visibleNodesViewModel.visibleCanvasIds = newValue
        }
    }
    
    @MainActor
    var selectedSidebarLayers: SidebarLayerIdSet {
        self.sidebarSelectionState.primary
    }
}

extension VisibleNodesViewModel {
    @MainActor
    var allNodeIds: IdSet {
        self.nodes.keys.toSet
    }

    @MainActor
    var allViewModels: CanvasItemViewModels {
        Array(self.nodes.values.flatMap { node in
            node.getAllCanvasObservers()
        })
    }

    /// Returns list of view models to display given the actively selected group (or lack thereof).
    @MainActor
    func getViewData(groupNodeFocused: NodeId?) -> NodePageData? {
        self.nodesByPage.get(groupNodeFocused.nodePageType)
    }

    // Provide an API more consistent with GraphState, GraphState
    @MainActor
    func getNode(_ id: NodeId) -> NodeViewModel? {
        self.nodes.get(id)
    }

    @MainActor
    func removeOldViewModels(currentIds: NodeIdSet,
                             newIds: NodeIdSet,
                             isRestart: Bool = false) {
        let idsToRemove = isRestart ? currentIds : currentIds.subtracting(newIds)
        // log("removeOldViewModels: idsToRemove: \(idsToRemove)")
        idsToRemove.forEach {
            self.nodes.removeValue(forKey: $0)
        }
    }


    /// Returns all view data to be used by nodes in groups.
    @MainActor
    func updateNodesPagingDict(documentZoomData: CGFloat,
                               documentFrame: CGRect) {

        // TODO: old comment indicated that we removed no-longer-existing group nodes;
        let existingGroupPages = self.nodesByPage.compactMap(\.key.getGroupNodePage).toSet
        
        let newGroupNodeIds = self.nodes.values
            .flatMap { $0.getAllCanvasObservers() }
            .compactMap { $0.parentGroupNodeId }
            .toSet // unqiue parents
            .filter { !existingGroupPages.contains($0) } // only new parents

        // Add position and zoom for new traversal levels
        newGroupNodeIds.forEach { newGroupNodeId in
            
            // When a graph session begins,
            // traversal-levels start in absolute center of graph, like the root level.
            self.nodesByPage.updateValue(NodePageData(localPosition: ABSOLUTE_GRAPH_CENTER),
                                         forKey: .group(newGroupNodeId))
        }
    }
    
    // traditionally called in `updateNodesPagingDict` after updating `nodesByPage` dict
    @MainActor
    func updateNodeRowObserversUpstreamAndDownstreamReferences() {
        // Toggle output downstream connections to false, will correct later
        self.nodes.values.forEach { node in
            node.getAllOutputsObservers().forEach {
                $0.containsDownstreamConnection = false
            }
        }
        
        // Build weak references to connected nodes
        self.nodes.values.forEach { node in
            self.buildUpstreamReferences(nodeViewModel: node)
        }
    }
    
    
    
    @MainActor
    func buildUpstreamReferences(nodeViewModel: NodeViewModel) {
        // Layers use keypaths
        if let layerNodeViewModel = nodeViewModel.layerNode {
            layerNodeViewModel.layer.layerGraphNode.inputDefinitions.forEach { inputType in
                
                // Loop over ports for each layer input--multiple if in unpacked mode
                layerNodeViewModel[keyPath: inputType.layerNodeKeyPath].allInputData.forEach { inputData in
                    let inputObserver = inputData.rowObserver
                    inputObserver.buildUpstreamReference()
                }
            }
        } else {
            nodeViewModel.getAllInputsObservers().enumerated().forEach { portId, inputObserver in
                inputObserver.buildUpstreamReference()
            }
        }   
    }

    @MainActor
    func getNodesAtThisTraversalLevel(at focusedGroup: NodeId?) -> [NodeViewModel] {
        self.getCanvasItemsAtTraversalLevel(at: focusedGroup)
            .filter { $0.parentGroupNodeId ==  focusedGroup }
            .compactMap { $0.nodeDelegate }
    }

    @MainActor
    func getCanvasItems() -> CanvasItemViewModels {
        self.nodes.values.flatMap { node in
            switch node.nodeType {
            case .patch(let patchNode):
                return [patchNode.canvasObserver]
            case .layer(let layerNode):
                return layerNode.getAllCanvasObservers()
            case .group(let canvas):
                return [canvas]
            case .component(let component):
                return [component.canvas]
            }
        }
    }
    
    // TODO: "visible" is ambiguous between "canvas item is on-screen" vs "canvas item is at this traversal level"
    @MainActor
    func getCanvasItemsAtTraversalLevel(at focusedGroup: NodeId?) -> CanvasItemViewModels {
        self.getCanvasItems()
            .filter { $0.parentGroupNodeId == focusedGroup }
    }

    @MainActor
    func getSplitterInputRowObserverIds(for groupNodeId: NodeId?) -> CanvasItemIdSet {
        self.cachedVisibleSplitterInputRows.get(groupNodeId)?
            .reduce(into: CanvasItemIdSet()) { $0.insert(.node($1.id.nodeId)) } ?? .init()
    }
            
    @MainActor
    func getSplitterOutputRowObserverIds(for groupNodeId: NodeId?) -> CanvasItemIdSet {
        self.cachedVisibleSplitterOutputRows.get(groupNodeId)?
            .reduce(into: CanvasItemIdSet()) { $0.insert(.node($1.id.nodeId)) } ?? .init()
    }
    
    @MainActor
    func isGroupNode(_ id: NodeId) -> Bool {
        self.getNode(id)?.kind.isGroup ?? false
    }
    
    @MainActor
    var patchNodes: NodesViewModelDict {
        self.nodes.filter {
            $0.value.patchNode.isDefined
        }
    }

    @MainActor
    var layerNodes: NodesViewModelDict {
        self.nodes.filter {
            $0.value.layerNode.isDefined
        }
    }

    @MainActor
    var groupNodes: NodesViewModelDict {
        self.nodes.filter {
            $0.value.kind == .group
        }
    }
   
    @MainActor
    func setAllCanvasItemsVisible() {
        let newIds = self.allViewModels.map(\.id).toSet
        if self.visibleCanvasIds != newIds {
            self.visibleCanvasIds = newIds
        }
    }
    
    @MainActor
    /// Updates node visibility data.
    func resetVisibleCanvasItemsCache() {
        if !self.needsInfiniteCanvasCacheReset {
            self.needsInfiniteCanvasCacheReset = true
        }
        self.setAllCanvasItemsVisible()
        
        // Fixes issues where new rows don't have port locations
        for node in self.nodes.values {
            // NOTE: what about layer canvas inputs' ?
            node.nonLayerCanvasItem?.updateAnchorPoints()
        }
    }
}

@MainActor
func getGroupSplitters(for groupNodeId: NodeId?,
                       node: NodeViewModel,
                       ofType: SplitterType) -> SplitterNodeEntity? {
    guard let patchNode = node.patchNode,
          let splitterNode = patchNode.splitterNode,
          patchNode.splitterType == ofType,
          patchNode.canvasObserver.parentGroupNodeId == groupNodeId else {
        return nil
    }
    return splitterNode
}

@MainActor
func getSplitterInputRowObservers(for groupNodeId: NodeId?,
                                  from graph: GraphReader) -> [InputNodeRowObserver] {
    graph.nodes.values
    // retrieve only the input splitters for this group
        .compactMap { getGroupSplitters(for: groupNodeId, node: $0, ofType: .input) }
    // sort by splitter's creation data
        .sorted { $0.lastModifiedDate < $1.lastModifiedDate }
    // retrieve the input row observers
        .compactMap {
            graph.getInputRowObserver(.init(portId: 0, // always first input
                                            nodeId: $0.id))
        }
}

/// Obtains output row observers directly from splitter patch nodes given its parent group node.
@MainActor
func getSplitterOutputRowObservers(for groupNodeId: NodeId?,
                                   from graph: GraphReader) -> [OutputNodeRowObserver] {
    graph.nodes.values
    // retrieve only the output splitters for this group
        .compactMap { getGroupSplitters(for: groupNodeId, node: $0, ofType: .output) }
    // sort by splitter's creation data
        .sorted { $0.lastModifiedDate < $1.lastModifiedDate }
    // retrieve the output row observers
        .compactMap {
            graph.getOutputRowObserver(.init(portId: 0, // always first output
                                             nodeId: $0.id))
        }
}

// traditionally called in `updateNodesPagingDict`, after `updateNodeRowObserversUpstreamAndDownstreamReferences`
@MainActor
func syncRowViewModels(activeIndex: ActiveIndex, graph: GraphReader) {
    // Sync port view models for applicable nodes
    graph.nodes.values.forEach { node in
        switch node.nodeType {
        case .patch(let patchNode):
            // Syncs ports if nodes had inputs added/removed
            patchNode.canvasObserver.syncRowViewModels(inputRowObservers: patchNode.inputsObservers,
                                                       outputRowObservers: patchNode.outputsObservers,
                                                       activeIndex: activeIndex)
            
        case .group(let canvasGroup):
            // Create port view models for group nodes once row observers have been established
            let inputRowObservers = getSplitterInputRowObservers(for: node.id, from: graph)
            let outputRowObservers = getSplitterOutputRowObservers(for: node.id, from: graph)
            // Note: What is `syncRowViewModels` vs `NodeRowViewModel.initialize`?
            canvasGroup.syncRowViewModels(inputRowObservers: inputRowObservers,
                                          outputRowObservers: outputRowObservers,
                                          activeIndex: activeIndex)
            
            // Initializes view models for canvas
            guard let node = canvasGroup.nodeDelegate else {
                fatalErrorIfDebug()
                return
            }
            
            assertInDebug(node.kind == .group)
            
            // Note: A Group Node's inputs and outputs are actually underlying input-splitters and output-splitters.
            // TODO: shouldn't the row view models already have been initialized when we initialized patch nodes?
            canvasGroup.initializeDelegate(node,
                                           activeIndex: activeIndex,
                                           // Layer inputs can never be inputs for group nodes
                                           unpackedPortParentFieldGroupType: nil,
                                           unpackedPortIndex: nil)
                            
        case .component(let componentViewModel):
            // Similar logic to patch nodes, where we have inputs/outputs observers stored directly in component
            componentViewModel.canvas.syncRowViewModels(
                inputRowObservers: componentViewModel.inputsObservers,
                outputRowObservers: componentViewModel.outputsObservers,
                activeIndex: activeIndex)

        case .layer(let layerNode):
            // We must refresh all the blocked layer inputs
            layerNode.refreshBlockedInputs(graph: graph,
                                           activeIndex: activeIndex)
        }
    }
}
