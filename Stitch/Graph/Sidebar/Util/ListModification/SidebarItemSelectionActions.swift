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
    let commandHeld: Bool
    
    func handle(state: GraphState) {
        state.layersSidebarViewModel
            .sidebarItemTapped(id: id.asItemId,
                               shiftHeld: shiftHeld,
                               commandHeld: commandHeld)
    }
}

extension ProjectSidebarObservable {
    @MainActor
    func sidebarItemTapped(id: Self.ItemID,
                           shiftHeld: Bool,
                           commandHeld: Bool) {
        log("sidebarItemTapped: id: \(id)")
        log("sidebarItemTapped: shiftHeld: \(shiftHeld)")
        
        let originalSelections = self.selectionState.inspectorFocusedLayers.focused
        
        log("sidebarItemTapped: originalSelections: \(originalSelections)")
        
        if shiftHeld, originalSelections.isEmpty {
            // Special case: if no current selections, shift-click just selects from the top to the clicked item; and the shift-clicked item counts as the 'last selected item'
            let flatList = self.items.flattenedItems
            if let indexOfTappedItem = flatList.firstIndex(where: { $0.id == id }) {
                
                let selectionsFromTop = flatList[0...indexOfTappedItem].map(\.id)
                
                self.selectionState.inspectorFocusedLayers.focused = selectionsFromTop.toSet
                self.selectionState.inspectorFocusedLayers.activelySelected = selectionsFromTop.toSet
                
                self.selectionState.inspectorFocusedLayers.lastFocusedLayer = id
                
                self.editModeSelectTappedItems(tappedItems: self.selectionState.inspectorFocusedLayers.focused)
            } else {
                log("sidebarItemTapped: could not retrieve index of tapped item when")
                fatalErrorIfDebug()
            }
            
        }
        
        else if shiftHeld,
                // We must have at least one layer already selected / focused
                !originalSelections.isEmpty,
                let lastClickedItemId = self.selectionState.inspectorFocusedLayers.lastFocusedLayer {
            
            log("sidebarItemTapped: shift select")
            
            guard let clickedItem = self.retrieveItem(id),
                  let lastClickedItem = self.retrieveItem(lastClickedItemId) else {
                log("sidebarItemTapped: could not get clicked data")
                fatalErrorIfDebug()
                return
            }
            
            log("sidebarItemTapped: lastClickedItemId: \(lastClickedItemId)")
            
            let flatList = self.items.flattenedItems
            
            let originalIsland = flatList.getIsland(startItem: lastClickedItem,
                                                    selections: originalSelections)
            
            // log("sidebarItemTapped: originalIsland around last clicked item \(originalIsland.map(\.id))")
            
            if let itemsBetween = self.itemsBetweenClosestSelectedStart(
                in: flatList,
                clickedItem: clickedItem,
                lastClickedItem: lastClickedItem,
                // Look at focused layers
                selections: originalSelections) {
                let idItemsBetween = itemsBetween.map(\.id).toSet
                
                // ORIGINAL
                self.selectionState.inspectorFocusedLayers.focused =
                self.selectionState.inspectorFocusedLayers.focused.union(idItemsBetween)
                
                self.selectionState.inspectorFocusedLayers.activelySelected = self.selectionState.inspectorFocusedLayers.focused.union(idItemsBetween)
                
                // Shift click does NOT change the `lastFocusedLayer`
                // self.sidebarSelectionState.inspectorFocusedLayers.lastFocusedLayer = id
                
                // If we ended up selecting the exact same as the original,
                // then we actually DE-SELECTED the range.
                let newSelections = self.selectionState.inspectorFocusedLayers.focused
                log("sidebarItemTapped: selected range: newSelections: \(newSelections)")
                if newSelections == originalSelections {
                    log("sidebarItemTapped: selected range; will wipe inspectorFocusedLayers")
                    
                    itemsBetween.forEach { itemBetween in
                        log("sidebarItemTapped: will remove item Between \(itemBetween)")
                        self.selectionState.inspectorFocusedLayers.focused.remove(itemBetween.id)
                        self.selectionState.inspectorFocusedLayers.activelySelected.remove(itemBetween.id)
                    }
                }
                
                self.editModeSelectTappedItems(tappedItems: self.selectionState.inspectorFocusedLayers.focused)
                
                self.graphDelegate?.deselectAllCanvasItems()
                
            } else {
                log("sidebarItemTapped: did not have itemsBetween")
                // TODO: this can happen when just-clicked == last-clicked, but some apps do not any deselection etc.
                // If we shift click the last-clicked item, then remove everything in the island?
                if clickedItem.id == lastClickedItem.id {
                    log("clicked the same item as the last clicked; will deselect original island and select only last selected")
                    originalIsland.forEach {
                        self.selectionState.inspectorFocusedLayers.focused.remove($0.id)
                        self.selectionState.inspectorFocusedLayers.activelySelected.remove($0.id)
                    }
                    
                    self.selectionState.inspectorFocusedLayers.focused.insert(clickedItem.id)
                    self.selectionState.inspectorFocusedLayers.activelySelected.insert(clickedItem.id)
                    
                    self.editModeSelectTappedItems(tappedItems: self.selectionState.inspectorFocusedLayers.focused)
                    
                    self.graphDelegate?.deselectAllCanvasItems()
                }
            }
        }
        //        else {
        //            log("sidebarItemTapped: either shift not held or focused layers were empty")
        //        }
        
        else if commandHeld {
            
            log("sidebarItemTapped: command select")
            
            let alreadySelected = self.selectionState.inspectorFocusedLayers.activelySelected.contains(id)
            
            // Note: Cmd + Click will select a currently-unselected layer or deselect an already-selected layer
            if alreadySelected {
                self.selectionState.inspectorFocusedLayers.focused.remove(id)
                self.selectionState.inspectorFocusedLayers.activelySelected.remove(id)
                self.sidebarItemDeselectedViaEditMode(id)
                
                // Don't set nil, but rather use `orderedSet.dropLast.last` ?
                self.selectionState.inspectorFocusedLayers.lastFocusedLayer = nil
            } else {
                self.selectionState.inspectorFocusedLayers.focused.insert(id)
                self.selectionState.inspectorFocusedLayers.activelySelected.insert(id)
                self.sidebarItemSelectedViaEditMode(id, isSidebarItemTapped: true)
                self.selectionState.inspectorFocusedLayers.lastFocusedLayer = id
                self.graphDelegate?.deselectAllCanvasItems()
            }
            
        } else {
            log("sidebarItemTapped: normal select")
            
            self.selectionState.resetEditModeSelections()
            
            // Note: Click will not deselect an already-selected layer
            self.selectionState.inspectorFocusedLayers.focused = .init([id])
            self.selectionState.inspectorFocusedLayers.activelySelected = .init([id])
            self.sidebarItemSelectedViaEditMode(id, isSidebarItemTapped: true)
            self.selectionState.inspectorFocusedLayers.lastFocusedLayer = id
            self.graphDelegate?.deselectAllCanvasItems()
        }
        
        self.graphDelegate?.updateInspectorFocusedLayers()
        
        // Reset selected row in property sidebar when focused-layers changes
        self.graphDelegate?.documentDelegate?.graphUI.propertySidebar.selectedProperty = nil
    }
}

extension GraphState {
    @MainActor
    func updateInspectorFocusedLayers() {
        
        #if !targetEnvironment(macCatalyst)
        // If left sidebar is in edit-mode, "primary selections" become inspector-focused
        if self.layersSidebarViewModel.isEditing {
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
        self.graphUI.closeFlyout()
    }
    
    @MainActor
    func multipleSidebarLayersSelected() -> LayerInputTypeSet? {
        
        let selectedSidebarLayers = self.sidebarSelectionState.inspectorFocusedLayers
                
        let selectedNodes: [NodeViewModel] = selectedSidebarLayers.focused.compactMap {
            self.getNode($0)
        }
        
        guard selectedNodes.count == selectedSidebarLayers.focused.count else {
            // Can happen when we delete a node that is technically still selected
            log("multipleSidebarLayersSelected: could not retrieve nodes for some layers?")
            return nil
        }
        
        guard let firstSelectedLayer = selectedSidebarLayers.focused.first,
              let firstSelectedNode: NodeViewModel = self.getNode(firstSelectedLayer),
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
        state.layersSidebarViewModel
            .sidebarItemSelectedViaEditMode(id.asItemId,
                                            isSidebarItemTapped: false)
    }
}

extension ProjectSidebarObservable {
    
    @MainActor
    func sidebarItemSelectedViaEditMode(_ id: Self.ItemID,
                                        isSidebarItemTapped: Bool) {
        // if we actively-selected (non-edit-mode-selected) an item that is already secondarily-selected, we don't need to change the
        if isSidebarItemTapped,
           self.selectionState.secondary.contains(id) {
            log("sidebarItemSelectedViaEditMode: \(id) was already secondarily selected")
            return
        }
        
        // we selected a group -- so 100% select the group
        // and 80% all the children further down in the street
        guard let item = self.retrieveItem(id) else {
            return
        }
           
        if item.isGroup {
            self.addExclusivelyToPrimary(id)

            item.children?.forEach{ child in
                child.secondarilySelectAllChildren()
            }
        }

        // If we selected a child of a group,
        // then deselect that parent and all other children,
        // and primarily select the child.
        // ie deselect everything(?), and only select the child.
        else if let parent = item.parentDelegate {

            // if the parent is currently selected,
            // then deselect the parent and all other children
            if self.selectionState.isSelected(parent.id) {
                self.selectionState.resetEditModeSelections()
                self.addExclusivelyToPrimary(id)
            }

            // ... otherwise, just primarily select the child
            else {
                self.addExclusivelyToPrimary(id)
            }
        }

        // else: simple case?:
        else {
            self.addExclusivelyToPrimary(id)
        }
                
        self.graphDelegate?.updateInspectorFocusedLayers()
    }
}

struct SidebarItemDeselected: GraphEvent {
    let id: SidebarListItemId

    func handle(state: GraphState) {
        state.layersSidebarViewModel.sidebarItemDeselectedViaEditMode(id)
    }
}

extension ProjectSidebarObservable {
    // If we deselected a group,
    // then we should also deselect all its children.
    @MainActor
    func sidebarItemDeselectedViaEditMode(_ id: Self.ItemID) {
        guard let item = self.items.get(id) else {
            fatalErrorIfDebug()
            return
        }

        item.removeFromSelections()

        self.graphDelegate?.updateInspectorFocusedLayers()
    }
}
