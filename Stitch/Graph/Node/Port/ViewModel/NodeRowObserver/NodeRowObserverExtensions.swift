//
//  NodeRowObserverExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit
import StitchEngine

// MARK: non-derived data: values, assigned interactions, label, upstream/downstream connection

extension NodeRowObserver {
        
    // Called by both `updateValuesInInput` and `updateValuesInOutput`;
    // handles logic common to both
    @MainActor
    func setValuesInRowObserver(_ newValues: PortValues,
                                selectedEdges: Set<PortEdgeUI>,
                                selectedCanvasItems: CanvasItemIdSet,
                                drawingObserver: EdgeDrawingObserver) {
        
        self.allLoopedValues = newValues
        
        // Always update "hasLoop", since offscreen node may have an onscreen edge.
        let hasLoop = newValues.hasLoop
        if hasLoop != self.hasLoopedValues {
            self.hasLoopedValues = hasLoop
        }
        
        self.allRowViewModels.forEach {
            if let canvasItemId = $0.id.graphItemType.getCanvasItemId {
                $0.portUIViewModel.updatePortColor(
                    canvasItemId: canvasItemId,
                    hasEdge: self.hasEdge,
                    hasLoop: self.hasLoopedValues,
                    selectedEdges: selectedEdges,
                    selectedCanvasItems: selectedCanvasItems,
                    drawingObserver: drawingObserver)
            }
        }
    }
    
    // TODO: this is currently invoked by StitchEngine, but does this overlap with `portsToUpdate`? `portsToUpdate` is for field-UI
    /// Updates port view models when the backend port observer has been updated.
    /// Also invoked when nodes enter the viewframe incase they need to be udpated.
    @MainActor
    func updatePortViewModels(_ graph: any GraphCalculatable) {
        
        // TODO: this actually works? We don't have to extend the GraphCalculatable protocol to have `visibleCanvasIds`, `selectedSidebarLayers`, `isFullScreenMode` and `groupNodeFocused`? ... Swift is tracking the concrete type?
        guard let graph = graph as? GraphState,
              let document = graph.documentDelegate else {
            log("updatePortViewModels: could not ")
            return
        }
        
        guard let node: NodeViewModel = graph.getNode(self.id.nodeId) else {
            // Should this be a fatalError?
//            fatalErrorIfDebug("updatePortViewModels: no node delegate")
            log("updatePortViewModels: no node delegate")
            return
        }
        
        guard node.isVisibleInFrame(graph.visibleCanvasIds,
                                    graph.selectedSidebarLayers) else {
            // Node not visible, so nothing to do
            return
        }
        
        let visibleRowViewModels = Self.getVisibleRowViewModels(
            allRowViewModels: self.allRowViewModels,
            visibleCanvasIds: graph.visibleCanvasIds,
            isFullScreenMode: document.isFullScreenMode,
            groupNodeFocused: document.groupNodeFocused?.groupNodeId)
        
        visibleRowViewModels.forEach { rowViewModel in
            rowViewModel.didPortValuesUpdate(
                values: self.allLoopedValues,
                layerFocusedInPropertyInspector: graph.layerFocusedInPropertyInspector,
                activeIndex: document.activeIndex)
        }
    }
    
    // Just reads GraphState, does not modify it?
    @MainActor
    static func getVisibleRowViewModels(allRowViewModels: [Self.RowViewModelType],
                                        visibleCanvasIds: CanvasItemIdSet,
                                        isFullScreenMode: Bool,
                                        groupNodeFocused: NodeId?) -> [Self.RowViewModelType] {
        // Make sure we're not in full screen mode
//        guard !graph.isFullScreenMode else {
        guard !isFullScreenMode else {
            return []
        }
        
        return allRowViewModels.filter { rowViewModel in
            
            switch rowViewModel.id.graphItemType {
                
            // A row for a layer inspector is visible just if layer inspector is open
            case .layerInspector:
                
                // TODO: why can't we the proper condition here? Why must we always return `true`? For perf, we only want to update inspector UI-fields if that inspector is open and this row observer's layer is actually focused; otherwise it's same as if we're updating an off-screen node
                // let showsLayerInspector = graph.showsLayerInspector
                // let layerFocused = graph.sidebarSelectionState.all.contains(rowViewModel.id.nodeId)
                // return showsLayerInspector && layerFocused
                return true
                
                
            case .canvas:
                
                guard let canvas = rowViewModel.canvasItemDelegate else {
                    log("Had row view model for canvas item but no canvas item delegate")
                    return false
                }
                
//                let isVisibleInCurrentGroup = canvas.isVisibleInFrame(graph) && canvas.parentGroupNodeId == graph.groupNodeFocused
                let isVisibleInCurrentGroup = canvas.isVisibleInFrame(visibleCanvasIds) && canvas.parentGroupNodeId == groupNodeFocused
             
                // always update group node, whose row view models don't otherwise update
                let isGroupNode = canvas.nodeDelegate?.nodeType.groupNode.isDefined ?? false
                   
                return isVisibleInCurrentGroup || isGroupNode
            }
        }
    }
    
    @MainActor
    func getActiveValue(activeIndex: ActiveIndex) -> PortValue {
        // TODO: remove the use of `PortValue.none` here? Should default to a sensible value?
        self.allLoopedValues[safe: activeIndex.adjustedIndex(self.allLoopedValues.count)] ?? .none
    }
            
    // MARK: change args here if working
    @MainActor
    func label(useShortLabel: Bool = false,
               node: NodeViewModel,
               coordinate: Coordinate,
               graph: GraphState) -> String {
        
        getLabelForRowObserver(useShortLabel: useShortLabel,
                               node: node,
                               coordinate: coordinate,
                               graph: graph)
    }
}

@MainActor
func getLabelForRowObserver(useShortLabel: Bool = false,
                            node: NodeViewModel,
                            coordinate: Coordinate,
                            graph: GraphState) -> String {
    /*
     Two scenarios re: a Group Node and its splitters:
     
     1. We are looking at the Group Node itself; so we want to use its underlying group node input- and output-splitters' titles as labels for the group node's rows
     
     2. We are INSIDE THE GROUP NODE, looking at its input- and output-splitters at that traversal level; so we do not use the splitters' titles as labels
     */
    if node.kind == .group {
        // Cached values which get underlying splitter node's title
        guard let labelFromSplitter = graph.cachedGroupPortLabels.get(coordinate) else {
            // Could be loading initially
//                fatalErrorIfDebug()
            return ""
        }

        // Don't show label on group node's input/output row unless it is custom
        if labelFromSplitter == Patch.splitter.defaultDisplayTitle() {
            return ""
        }
                    
        return labelFromSplitter
    }
    
    let rowDefinitions = node.kind.graphNode?.rowDefinitions(for: node.userVisibleType) ?? node.kind.rowDefinitions(for: node.userVisibleType)
    
    switch coordinate {
        
    case .output(let outputCoordinate):
        
        switch outputCoordinate.portType {
            
        case .portIndex(let portId):
            return rowDefinitions.outputs[safe: portId]?.label ?? ""
            
        case .keyPath:
            fatalErrorIfDebug()
            return ""
        }
        
    case .input(let inputCoordinate):
        
        switch inputCoordinate.portType {
            
        case .portIndex(let portId):
            if let mathExpr = node.getMathExpression?.getSoulverVariables(),
               let variableChar = mathExpr[safe: portId] {
                return String(variableChar)
            }
            return rowDefinitions.inputs[safe: portId]?.label ?? ""
            
        case .keyPath(let keyPath):
            return keyPath.layerInput.label(useShortLabel: useShortLabel)
        }
        
    }
}

