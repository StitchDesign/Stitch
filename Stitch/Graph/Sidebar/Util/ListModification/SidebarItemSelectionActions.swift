//
//  SidebarItemDeselected.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import OrderedCollections

// Sidebar layer 'tapped' while not in
struct SidebarItemTapped: GraphEvent {
    
    let id: LayerNodeId
    
    func handle(state: GraphState) {
        let alreadySelected = state.sidebarSelectionState.inspectorFocusedLayers.contains(id)
        
        // TODO: why does shift-key seem to be interrupted so often?
//        if state.keypressState.isCommandPressed ||  state.keypressState.isShiftPressed {
        if state.keypressState.isCommandPressed {
            
            if alreadySelected {
                state.sidebarSelectionState.inspectorFocusedLayers.remove(id)
            } else {
                state.sidebarSelectionState.inspectorFocusedLayers.insert(id)
            }
            
        } else {
            if alreadySelected {
                state.sidebarSelectionState.inspectorFocusedLayers = .init()
            } else {
                state.sidebarSelectionState.inspectorFocusedLayers = .init([id])
            }
        }
        
        state.updateInspectorFocusedLayers()
                
        // Reset selected row in property sidebar when focused-layers changes
        state.graphUI.propertySidebar.selectedProperty = nil
    }
}


extension GraphState {
    
    @MainActor
    func updateInspectorFocusedLayers() {
        
        // If left sidebar is in edit-mode, "primary selections" become inspector-focused
        if self.sidebarSelectionState.isEditMode {
            self.sidebarSelectionState.inspectorFocusedLayers = self.sidebarSelectionState.primary
        }
        
        if self.sidebarSelectionState.inspectorFocusedLayers.count > 1 {
            self.graphUI.propertySidebar.inputsCommonToSelectedLayers = self.multipleSidebarLayersSelected()
        } else {
            self.graphUI.propertySidebar.inputsCommonToSelectedLayers = nil
        }
        
        // Reset selected-inspector-row whenever inspector-focused layers change
        self.graphUI.propertySidebar.selectedProperty = nil
    }
    
    @MainActor
    func multipleSidebarLayersSelected() -> LayerInputTypeSet? {
        
        let selectedSidebarLayers = self.sidebarSelectionState.inspectorFocusedLayers
                
        let selectedNodes: [NodeViewModel] = selectedSidebarLayers.compactMap {
            self.getNode($0.asNodeId)
        }
        
        guard selectedNodes.count == selectedSidebarLayers.count else {
            // Can happen when we delete a node that is technically still selected
            log("multipleSidebarLayersSelected: could not retrieve nodes for some layers?")
            return nil
        }
        
        guard let firstSelectedLayer = selectedSidebarLayers.first,
              let firstSelectedNode: NodeViewModel = self.getNode(firstSelectedLayer.asNodeId),
              let firstSelectedLayerNode: LayerNodeViewModel = firstSelectedNode.layerNode else {
            log("multipleSidebarLayersSelected: did not have any selected sidebar layers?")
            return nil
        }
      
        var commonLayerInputs = Set<LayerInputPort>()
                
        LayerInputPort.allCases.forEach { layerInputPort in
            
            let everySelectedLayerUsesThisPort = selectedNodes.allSatisfy { selectedNode in
                
                // The layer inputs this layer-node supports
                guard let layerInputs = selectedNode.layerNode?.layer.layerGraphNode.inputDefinitions else {
                    // Did not
                    log("multipleSidebarLayersSelected: Did not have a layer node for a selected layer?")
                    return false
                }
                
                return layerInputs.contains(layerInputPort)
            }
            
            if everySelectedLayerUsesThisPort {
                commonLayerInputs.insert(layerInputPort)
            }
        }
        
        // log("multipleSidebarLayersSelected: commonLayerInputs: \(commonLayerInputs)")
        
        // Doesn't need to be ordered?
        return .init(commonLayerInputs)
    }
}


// group or top level
struct SidebarItemSelected: GraphEvent {
    let id: LayerNodeId
    
    func handle(state: GraphState) {
        
        let sidebarGroups = state.getSidebarGroupsDict()
        
        // we selected a group -- so 100% select the group
        // and 80% all the children further down in the street
        if state.getNodeViewModel(id.id)?.kind.getLayer == .group {

            state.sidebarSelectionState = addExclusivelyToPrimary(
                id, state.sidebarSelectionState)

            sidebarGroups[id]?.forEach({ (childId: LayerNodeId) in
                state.sidebarSelectionState = secondarilySelectAllChildren(
                    id: childId,
                    groups: sidebarGroups,
                    acc: state.sidebarSelectionState)
            })
        }

        // if we selected a child of a group,
        // then deselect that parent and all other children,
        // and primarily select the child.
        // ie deselect everything(?), and only select the child.

        // TRICKY: what if eg
        else if let parent = findGroupLayerParentForLayerNode(id, sidebarGroups) {

            // if the parent is currently selected,
            // then deselect the parent and all other children
            if state.sidebarSelectionState.isSelected(parent) {
                state.sidebarSelectionState.resetSelections()
                state.sidebarSelectionState = addExclusivelyToPrimary(id, state.sidebarSelectionState)
            }

            // ... otherwise, just primarily select the child
            else {
                state.sidebarSelectionState = addExclusivelyToPrimary(
                    id,
                    state.sidebarSelectionState)
            }
        }

        // else: simple case?:
        else {
            state.sidebarSelectionState = addExclusivelyToPrimary(id, state.sidebarSelectionState)
        }
                
        state.updateInspectorFocusedLayers()
    }
}

struct SidebarItemDeselected: GraphEvent {
    let id: LayerNodeId

    func handle(state: GraphState) {

        // if we deselected a group,
        // then we should also deselect all its children.
        let groups = state.getSidebarGroupsDict()
        
        var idsToDeselect = LayerIdSet([id])

        groups[id]?.forEach({ (childId: LayerNodeId) in
            // ids all ids to remove
            let ids = getDescendantsIds(
                id: childId,
                groups: groups,
                acc: idsToDeselect)
            idsToDeselect = idsToDeselect.union(ids)

        })

        // log("SidebarItemDeselected: idsToDeselect: \(idsToDeselect)")

        // now that we've gathered all the ids (ie directly de-selected item + its descendants),
        // we can remove them
        idsToDeselect.forEach { idToRemove in
            state.sidebarSelectionState = removeFromSelections(
                idToRemove,
                state.sidebarSelectionState)
        }
        
        state.updateInspectorFocusedLayers()
    }
}
