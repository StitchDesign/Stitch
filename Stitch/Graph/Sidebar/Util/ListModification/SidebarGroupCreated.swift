//
//  SidebarGroupCreated.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// when a sidebar group is created from a selection of sidebar items,
// we should insert the group at the location of the
extension LayersSidebarViewModel {
    @MainActor
    func sidebarGroupCreated() {
        self.sidebarGroupCreated(id: .init())
    }
    
    @MainActor
    func sidebarGroupCreated(id: NodeId) {
        log("SidebarGroupCreated called")
        
        guard let graph = self.graphDelegate,
              let state = graph.documentDelegate else {
            return
        }
        
        // Create node view model for the new Layer Group
        let newNode = Layer.group.layerGraphNode.createViewModel(
            id: id,
            // TODO: remove the misleading `position` parameter; a layer node's inputs and outputs can have canvas-position but never the layer node itself
            position: state.newCanvasItemInsertionLocation,
            zIndex: graph.highestZIndex + 1,
            graphDelegate: graph)
        
        let primarilySelectedLayers: Set<SidebarListItemId> = self.primary
        
        let candidateGroup = self.items.containsValidGroup(from: primarilySelectedLayers)
        
        newNode.graphDelegate = graph // redundant?
                
        // Add to state
        state.handleNewlyCreatedNode(node: newNode)
            
        // Update sidebar state after node has been added to graph
        guard let newGroupData = self.items
            .createGroup(newGroupId: newNode.id,
                         parentLayerGroupId: candidateGroup.parentId,
                         selections: primarilySelectedLayers,
                         sidebarViewModel: self) else {
            fatalErrorIfDebug()
            return
        }
        
        self.items.insertGroup(group: newGroupData,
                               selections: primarilySelectedLayers)
   
        self.items.updateSidebarIndices()
        
        // Only reset edit mode selections if we're explicitly in edit mode (i.e. on iPad)
        if self.isEditing {
            // Reset selections
            self.selectionState.resetEditModeSelections()
        }
        
        // Focus this, and only this, layer node in inspector
        self.selectionState.resetEditModeSelections()
        self.sidebarItemSelectedViaEditMode(newNode.id)
        self.selectionState.lastFocused = newNode.id
        graph.resetSelectedCanvasItems()
        
        // NOTE: must do this AFTER children have been assigned to the new layer node; else we return preview window size
        
        // TODO: adjust position of children
        // TODO: determine real size of just-created LayerGroup
//        let groupFit: LayerGroupFit = graph.getLayerGroupFit(
//            primarilySelectedLayers,
//            parentSize: graph.getParentSizeForSelectedNodes(selectedNodes: primarilySelectedLayers))

        // TODO: any reason to not use .auto x .auto for a nearly created group? ... perhaps for .background, which can become too big in a group whose children use .position modifiers?
        // TODO: how important is the LayerGroupFit.adjustment/offset etc. ?
//        let assumedLayerGroupSize: LayerSize = groupFit.size
//        let assumedLayerGroupSize: LayerSize = .init(width: .auto, height: .auto)
        // Note: layer groups start out with `size = fill` rather than `size = hug` because orientation
        let assumedLayerGroupSize: LayerSize = .init(width: .fill, height: .fill)
        
        // Update layer group's size input
        newNode.layerNode?.sizePort.updatePortValues([.size(assumedLayerGroupSize)])
                
        graph.persistNewNode(newNode)
    }
}

extension GraphState {
    @MainActor
    func layerGroupForSelections(_ selections: NodeIdSet) -> NodeId? {
        
        // Assumes `selections` all have single parent;
        // this is guaranteed by the way we select layers in the sidebar
        // TODO: is it possible to primarily-select a
        
        var parentId: NodeId?
        selections.forEach { layerId in
            if let layerNode = self.getLayerNode(layerId),
               let parent = layerNode.layerGroupId(self.layersSidebarViewModel) {
                parentId = parent
            }
        }
        
        // log("layerGroupForSelections: parentId: \(parentId)")
        
        return parentId
    }
}

extension Array where Element: SidebarItemSwipable {
    /// Returns `true` if selections meet the following criteria:
    /// 1. All top-level selections are located in same hierarchy (contain the same parent)
    /// 2. All top-level selections in turn have all of their children selected
    @MainActor func containsValidGroup(from selections: Set<Element.ID>,
                                       // Tracks the parent hierarchy of this candidate group, nil = root
                                       parentLayerGroupId: Element.ID? = nil) -> GroupCandidate<Element> {
        // Invalid if data or selections are empty
        guard !self.isEmpty && !selections.isEmpty else {
            return .invalid
        }
        
        // Keeps track of of what a valid selection set would look like given top-level selections,
        // meaning if some children aren't selected it won't match this.
        let validSelectedSet = self.reduce(into: Set<Element.ID>()) { result, element in
            guard selections.contains(element.id) else {
                return
            }
            
            result = result.union(element.allElementIds)
        }
        
        // Recursively check children if no selections found at this hierarachy
        guard !validSelectedSet.isEmpty else {
            let recursiveChecks = self.compactMap {
                $0.children?.containsValidGroup(from: selections,
                                                parentLayerGroupId: $0.id)
            }
            for result in recursiveChecks {
                switch result {
                case .invalid:
                    continue
                case .valid(let parentId):
                    return .valid(parentId)
                }
            }
            
            return .invalid
        }
        
        // Non-empty selections mean we've identified the highest hierarchy of selections, and
        // therefore must match our valid selection set
        guard validSelectedSet == selections else {
            return .invalid
        }
        
        // All elements are at same hierarchy so we return current visited group
        return .valid(parentLayerGroupId)
    }
    
    @MainActor func createGroup(newGroupId: Element.ID,
                                parentLayerGroupId: Element.ID?,
                                currentVisitedGroupId: Element.ID? = nil, // for recursion
                                selections: Set<Element.ID>,
                                sidebarViewModel: Element.SidebarViewModel) -> Element? {
        let atCorrectHierarchy = parentLayerGroupId == currentVisitedGroupId
        var parentDelegate: Element?
        
        guard atCorrectHierarchy else {
            // Recursively search children until we find the parent layer ID
            return self.compactMap { element in
                element.children?.createGroup(newGroupId: newGroupId,
                                              parentLayerGroupId: parentLayerGroupId,
                                              currentVisitedGroupId: element.id,
                                              selections: selections,
                                              sidebarViewModel: sidebarViewModel)
            }
            .first
        }
        
        if let parentLayerGroupId = parentLayerGroupId {
            parentDelegate = self.get(parentLayerGroupId)
        }
        
        let newGroupData = Element(data: .init(id: newGroupId,
                                               children: [],
                                               isExpandedInSidebar: true),
                                   parentDelegate: parentDelegate,
                                   sidebarViewModel: sidebarViewModel)
        
        // Update selected nodes to report to new group node
        newGroupData.children = self.getSelectedChildrenForNewGroup(selections)
        
        return newGroupData
    }
    
    @MainActor mutating func insertGroup(group: Element,
                                         selections: Set<Element.ID>) {
        // Find the selected element at the minimum index to determine location of new group node
        // Recursively search until selections are found
        guard let newGroupIndex = self.findLowestIndex(amongst: selections) else {
            self = self.map { element in
                element.children?.insertGroup(group: group,
                                              selections: selections)
                return element
            }
            return
        }
        
        // Remove selections from list, complete in order due to grouping
        var newList = self.removeSelections(selections)
        
        // Add new group node to sidebar
        newList.insert(group, at: newGroupIndex)
        self = newList
    }
    
    /// Returns the lowest index amonst a list of selections. Nil result means none found.
    private func findLowestIndex(amongst ids: Set<Element.ID>) -> Int? {
        self.enumerated()
            .filter { ids.contains($0.element.id) }
            .min { $0.offset < $1.offset }?.offset
    }
    
    @MainActor func removeSelections(_ selections: Set<Element.ID>) -> [Element] {
        self.compactMap { item in
            if selections.contains(item.id) {
                return nil
            }
            
            item.children = item.children?.removeSelections(selections)
            return item
        }
    }
    
    @MainActor func getSelectedChildrenForNewGroup(_ selections: Set<Element.ID>) -> [Element] {
        self.flatMap { element -> [Element] in
            // Get layer data from sidebar to add to group
            if selections.contains(element.id) {
                return [element]
            }
            
            // Check children
            guard let children = element.children else { return [] }
            return children.getSelectedChildrenForNewGroup(selections)
        }
    }
}
