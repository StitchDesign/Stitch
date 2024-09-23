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
    let shiftHeld: Bool
    
    func handle(state: GraphState) {
        state.sidebarItemTapped(id: id,
                                shiftHeld: shiftHeld)
    }
}

extension GraphState {
    
    @MainActor
    func sidebarItemTapped(id: LayerNodeId, shiftHeld: Bool) {
        log("sidebarItemTapped: id: \(id)")
        log("sidebarItemTapped: shiftHeld: \(shiftHeld)")
        
        let originalSelections = self.sidebarSelectionState.inspectorFocusedLayers.focused
        
        if shiftHeld,
           // We must have at least one layer already selected / focused
           !originalSelections.isEmpty,
           let lastClickedItemId = self.sidebarSelectionState.inspectorFocusedLayers.lastFocusedLayer {
            
            log("sidebarItemTapped: shift select")
            
            guard let clickedItem: SidebarLayerData = self.orderedSidebarLayers.getSidebarLayerData(id.id),
                  let lastClickedItem: SidebarLayerData = self.orderedSidebarLayers.getSidebarLayerData(lastClickedItemId.id) else {
                log("sidebarItemTapped: could not get clicked data")
                fatalErrorIfDebug()
                return
            }
            
            if let (itemsBetween, clickedEarlierThanStart) = itemsBetweenClosestSelectedStart(
                in: self.orderedSidebarLayers,
                clickedItem: clickedItem,
                lastClickedItem: lastClickedItem,
                // Look at focused layers
                selections: originalSelections) {
                
                log("sidebarItemTapped: itemsBetween: \(itemsBetween)")
                let itemsBetweenSet: LayerIdSet = Set(Array(itemsBetween.map(\.id.asLayerNodeId)))
                log("sidebarItemTapped: itemsBetweenSet: \(itemsBetweenSet)")
                
                // TODO: do you really need this distinction ?
//                if clickedEarlierThanStart {
//                    log("sidebarItemTapped: clickedEarlierThanStart")
//                    self.sidebarSelectionState.inspectorFocusedLayers.focused = itemsBetweenSet
//                    self.sidebarSelectionState.inspectorFocusedLayers.activelySelected = itemsBetweenSet
//                    self.sidebarSelectionState.inspectorFocusedLayers.lastFocusedLayer = id
//                    self.deselectAllCanvasItems()
//                    
//                    // TODO: should not need to return early?
//                    return
                //                } else {
                log("sidebarItemTapped: had NOT clickedEarlierThanStart")
                self.sidebarSelectionState.inspectorFocusedLayers.focused =
                self.sidebarSelectionState.inspectorFocusedLayers.focused.union(itemsBetweenSet)
                self.sidebarSelectionState.inspectorFocusedLayers.activelySelected = self.sidebarSelectionState.inspectorFocusedLayers.focused.union(itemsBetweenSet)
                self.sidebarSelectionState.inspectorFocusedLayers.lastFocusedLayer = id
                
                self.editModeSelectTappedItems(tappedItems: self.sidebarSelectionState.inspectorFocusedLayers.focused)
                
                self.deselectAllCanvasItems()
                // TODO: should not need to return early?
                //                    return
                //                }
                
            } else {
                log("sidebarItemTapped: did not have itemsBetween")
            }
        } 
//        else {
//            log("sidebarItemTapped: either shift not held or focused layers were empty")
//        }
                
        else if self.keypressState.isCommandPressed {
            
            log("sidebarItemTapped: command select")
            
            let alreadySelected = self.sidebarSelectionState.inspectorFocusedLayers.activelySelected.contains(id)
            
            // Note: Cmd + Click will select a currently-unselected layer or deselect an already-selected layer
            if alreadySelected {
                self.sidebarSelectionState.inspectorFocusedLayers.focused.remove(id)
                self.sidebarSelectionState.inspectorFocusedLayers.activelySelected.remove(id)
                self.sidebarItemDeselectedViaEditMode(id)
                
                // Don't set nil, but rather use `orderedSet.dropLast.last` ?
                self.sidebarSelectionState.inspectorFocusedLayers.lastFocusedLayer = nil
            } else {
                self.sidebarSelectionState.inspectorFocusedLayers.focused.insert(id)
                self.sidebarSelectionState.inspectorFocusedLayers.activelySelected.insert(id)
                self.sidebarItemSelectedViaEditMode(id, isSidebarItemTapped: true)
                self.sidebarSelectionState.inspectorFocusedLayers.lastFocusedLayer = id
                self.deselectAllCanvasItems()
            }
            
        } else {
            log("sidebarItemTapped: normal select")
            
            self.sidebarSelectionState.resetEditModeSelections()
            
            // Note: Click will not deselect an already-selected layer
            self.sidebarSelectionState.inspectorFocusedLayers.focused = .init([id])
            self.sidebarSelectionState.inspectorFocusedLayers.activelySelected = .init([id])
            self.sidebarItemSelectedViaEditMode(id, isSidebarItemTapped: true)
            self.sidebarSelectionState.inspectorFocusedLayers.lastFocusedLayer = id
            self.deselectAllCanvasItems()
        }
        
        self.updateInspectorFocusedLayers()
                
        // Reset selected row in property sidebar when focused-layers changes
        self.graphUI.propertySidebar.selectedProperty = nil
    }
    
    @MainActor
    func updateInspectorFocusedLayers() {
        
        #if !targetEnvironment(macCatalyst)
        // If left sidebar is in edit-mode, "primary selections" become inspector-focused
        if self.sidebarSelectionState.isEditMode {
            self.sidebarSelectionState.inspectorFocusedLayers.focused = self.sidebarSelectionState.primary
            self.sidebarSelectionState.inspectorFocusedLayers.activelySelected = self.sidebarSelectionState.primary
        }
        #endif
        
        if self.sidebarSelectionState.inspectorFocusedLayers.focused.count > 1 {
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
                
        let selectedNodes: [NodeViewModel] = selectedSidebarLayers.focused.compactMap {
            self.getNode($0.asNodeId)
        }
        
        guard selectedNodes.count == selectedSidebarLayers.focused.count else {
            // Can happen when we delete a node that is technically still selected
            log("multipleSidebarLayersSelected: could not retrieve nodes for some layers?")
            return nil
        }
        
        guard let firstSelectedLayer = selectedSidebarLayers.focused.first,
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
        state.sidebarItemSelectedViaEditMode(id, isSidebarItemTapped: false)
    }
}

extension GraphState {
    
    @MainActor
    func sidebarItemSelectedViaEditMode(_ id: LayerNodeId,
                                        isSidebarItemTapped: Bool) {
        let sidebarGroups = self.getSidebarGroupsDict()
        
        // if we actively-selected (non-edit-mode-selected) an item that is already secondarily-selected, we don't need to change the
        if isSidebarItemTapped,
            self.sidebarSelectionState.secondary.contains(id) {
            log("sidebarItemSelectedViaEditMode: \(id) was already secondarily selected")
            return
        }
        
        
        // we selected a group -- so 100% select the group
        // and 80% all the children further down in the street
        if self.getNodeViewModel(id.id)?.kind.getLayer == .group {

            self.sidebarSelectionState = addExclusivelyToPrimary(
                id, self.sidebarSelectionState)

            sidebarGroups[id]?.forEach({ (childId: LayerNodeId) in
                self.sidebarSelectionState = secondarilySelectAllChildren(
                    id: childId,
                    groups: sidebarGroups,
                    acc: self.sidebarSelectionState)
            })
        }

        // If we selected a child of a group,
        // then deselect that parent and all other children,
        // and primarily select the child.
        // ie deselect everything(?), and only select the child.
        else if let parent = findGroupLayerParentForLayerNode(id, sidebarGroups) {

            // if the parent is currently selected,
            // then deselect the parent and all other children
            if self.sidebarSelectionState.isSelected(parent) {
                    self.sidebarSelectionState.resetEditModeSelections()
                    self.sidebarSelectionState = addExclusivelyToPrimary(id, self.sidebarSelectionState)
            }

            // ... otherwise, just primarily select the child
            else {
                self.sidebarSelectionState = addExclusivelyToPrimary(
                    id,
                    self.sidebarSelectionState)
            }
        }

        // else: simple case?:
        else {
            self.sidebarSelectionState = addExclusivelyToPrimary(id, self.sidebarSelectionState)
        }
                
        self.updateInspectorFocusedLayers()
    }
}

struct SidebarItemDeselected: GraphEvent {
    let id: LayerNodeId

    func handle(state: GraphState) {
        state.sidebarItemDeselectedViaEditMode(id)
    }
}

extension GraphState {
    @MainActor
    func sidebarItemDeselectedViaEditMode(_ id: LayerNodeId) {
        // If we deselected a group,
        // then we should also deselect all its children.
        let groups = self.getSidebarGroupsDict()
        
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
            self.sidebarSelectionState = removeFromSelections(
                idToRemove,
                self.sidebarSelectionState)
        }
        
        self.updateInspectorFocusedLayers()
    }
}
