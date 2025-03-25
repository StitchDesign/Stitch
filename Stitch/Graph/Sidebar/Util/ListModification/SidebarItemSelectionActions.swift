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

extension ProjectSidebarObservable {
    @MainActor
    func sidebarItemTapped(id: Self.ItemID,
                           shiftHeld: Bool,
                           commandHeld: Bool,
                           graph: GraphState,
                           graphUI: GraphUIState) {
        // log("sidebarItemTapped: id: \(id)")
        // log("sidebarItemTapped: shiftHeld: \(shiftHeld)")
        
        let originalSelections = self.selectionState.primary
        
        // Set sidebar to be focused:
        if !self.isSidebarFocused {
            self.isSidebarFocused = true            
        }
        
        // log("sidebarItemTapped: originalSelections: \(originalSelections)")
        
        if shiftHeld, originalSelections.isEmpty {
            // Special case: if no current selections, shift-click just selects from the top to the clicked item; and the shift-clicked item counts as the 'last selected item'
            let flatList = self.items.flattenedItems
            if let indexOfTappedItem = flatList.firstIndex(where: { $0.id == id }) {
                
                let selectionsFromTop = flatList[0...indexOfTappedItem].map(\.id)
                
                self.selectionState.primary = selectionsFromTop.toSet
                
                self.selectionState.lastFocused = id
                
                self.editModeSelectTappedItems(tappedItems: self.selectionState.primary)
            } else {
                log("sidebarItemTapped: could not retrieve index of tapped item when")
                fatalErrorIfDebug()
            }
            
        }
        
        else if shiftHeld,
                // We must have at least one layer already selected / focused
                !originalSelections.isEmpty,
                let lastClickedItemId = self.selectionState.lastFocused {
            
            // log("sidebarItemTapped: shift select")
            
            guard let clickedItem = self.retrieveItem(id),
                  let lastClickedItem = self.retrieveItem(lastClickedItemId) else {
                log("sidebarItemTapped: could not get clicked data")
                fatalErrorIfDebug()
                return
            }
            
            // log("sidebarItemTapped: lastClickedItemId: \(lastClickedItemId)")
            
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
                self.selectionState.primary = self.selectionState.primary.union(idItemsBetween)
                
                // Shift click does NOT change the `lastFocusedLayer`
                // self.sidebarSelectionState.inspectorFocusedLayers.lastFocusedLayer = id
                
                // If we ended up selecting the exact same as the original,
                // then we actually DE-SELECTED the range.
                let newSelections = self.selectionState.primary
                // log("sidebarItemTapped: selected range: newSelections: \(newSelections)")
                if newSelections == originalSelections {
                    // log("sidebarItemTapped: selected range; will wipe inspectorFocusedLayers")
                    
                    itemsBetween.forEach { itemBetween in
                        // log("sidebarItemTapped: will remove item Between \(itemBetween)")
                        self.selectionState.primary.remove(itemBetween.id)
                    }
                }
                
                self.editModeSelectTappedItems(tappedItems: self.selectionState.primary)
                
                graph.resetSelectedCanvasItems()
                
            } else {
                // log("sidebarItemTapped: did not have itemsBetween")
                // TODO: this can happen when just-clicked == last-clicked, but some apps do not any deselection etc.
                // If we shift click the last-clicked item, then remove everything in the island?
                if clickedItem.id == lastClickedItem.id {
                    // log("clicked the same item as the last clicked; will deselect original island and select only last selected")
                    originalIsland.forEach {
                        self.selectionState.primary.remove($0.id)
                    }
                    
                    self.selectionState.primary.insert(clickedItem.id)
                    
                    self.editModeSelectTappedItems(tappedItems: self.selectionState.primary)
                    
                    graph.resetSelectedCanvasItems()
                }
            }
        }
        //        else {
        //            log("sidebarItemTapped: either shift not held or focused layers were empty")
        //        }
        
        else if commandHeld {
            
            // log("sidebarItemTapped: command select")
            
            let alreadySelected = self.selectionState.primary.contains(id)
            
            // Note: Cmd + Click will select a currently-unselected layer or deselect an already-selected layer
            if alreadySelected {
                self.selectionState.primary.remove(id)
                self.sidebarItemDeselectedViaEditMode(id)
                
                // Don't set nil, but rather use `orderedSet.dropLast.last` ?
                self.selectionState.lastFocused = nil
            } else {
                self.selectionState.primary.insert(id)
                self.sidebarItemSelectedViaEditMode(id)
                self.selectionState.lastFocused = id
                graph.resetSelectedCanvasItems()
            }
            
        } else {
            // log("sidebarItemTapped: normal select")
            
            self.selectionState.resetEditModeSelections()
            
            // Note: Click will not deselect an already-selected layer
            self.selectionState.primary = .init([id])
            self.sidebarItemSelectedViaEditMode(id)
            self.selectionState.lastFocused = id
            graph.resetSelectedCanvasItems()
        }
        
        graph.updateInspectorFocusedLayers()
        
        // Reset selected row in property sidebar when focused-layers changes
        graph.propertySidebar.selectedProperty = nil
    }
}

extension GraphState {
    @MainActor
    func updateInspectorFocusedLayers() {        
        if self.sidebarSelectionState.primary.count > 1 {
            self.propertySidebar.heterogenousFieldsMap = self.multipleSidebarLayersSelected()
        } else {
            self.propertySidebar.heterogenousFieldsMap = nil
        }
        
        // Reset selected-inspector-row whenever inspector-focused layers change
        self.propertySidebar.selectedProperty = nil
        self.closeFlyout()
    }
    
    @MainActor
    func multipleSidebarLayersSelected() -> [LayerInputPort : Set<Int>]? {
                
        let selectedNodes: [NodeViewModel] = self.sidebarSelectionState.primary.compactMap {
            self.getNode($0)
        }
        
        guard selectedNodes.count == self.sidebarSelectionState.primary.count else {
            // Can happen when we delete a node that is technically still selected
            log("multipleSidebarLayersSelected: could not retrieve nodes for some layers?")
            return nil
        }
        
        guard let firstSelectedLayer = self.sidebarSelectionState.primary.first else {
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
        
        let heterogenousMap = commonLayerInputs.getHeterogenousFieldsMap(graph: self)
        return heterogenousMap
    }
}

extension Set where Element == LayerInputPort {
    @MainActor
    func getHeterogenousFieldsMap(graph: GraphState) -> [LayerInputPort : Set<Int>] {
        self.reduce(into: [LayerInputPort : Set<Int>]()) { result, layerPort in
                // Check each layer node to find values
            let fieldsWithHeterogenousValues = layerPort
                .fieldsInMultiselectInputWithHeterogenousValues(graph)
            result.updateValue(fieldsWithHeterogenousValues, forKey: layerPort)
        }
    }
}

// group or top level
struct SidebarItemSelected: GraphEvent {
    let id: LayerNodeId
    
    func handle(state: GraphState) {
        state.layersSidebarViewModel
            .sidebarItemSelectedViaEditMode(id.asItemId)
    }
}

extension ProjectSidebarObservable {
    
    @MainActor
    func sidebarItemSelectedViaEditMode(_ id: Self.ItemID) {
        self.addExclusivelyToPrimary(id)
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
