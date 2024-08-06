//
//  NodeDuplicationActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/3/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SelectedGraphItemsDuplicated: GraphEventWithResponse {
    
    // Duplicates BOTH nodes AND comments
    @MainActor
    func handle(state: GraphState) -> GraphResponse {
        
        guard !state.graphUI.llmRecording.isRecording else {
            log("Duplication disabled during LLM Recording")
            return .noChange
        }
        
        let copiedComponentResult = state.createCopiedComponent(
            groupNodeFocused: state.graphUI.groupNodeFocused?.asNodeId,
            selectedNodeIds: state.selectedNodeIds.compactMap(\.nodeCase).toSet)
        
        state.insertNewComponent(copiedComponentResult)
        
        return .persistenceResponse
    }
}

extension GraphState {
    /// Inserts new component in state and processes media effects
    @MainActor
    func insertNewComponent(_ copiedComponentResult: StitchComponentCopiedResult) {
        self.insertNewComponent(component: copiedComponentResult.component,
                                effects: copiedComponentResult.effects)
    }

    @MainActor
    func insertNewComponent(component: StitchComponent,
                            effects: AsyncCallbackList) {
        let hasEffectsToRun = !effects.isEmpty

        // Change all IDs
        var newComponent = component.changeIds()

        // Update nodes in the follow ways:
        // 1. Stagger position
        // 2. Increment z-index
        newComponent.nodes = newComponent.nodes.map { node in
            var node = node
            node.canvasEntityMap { node in
                var node = node
                node.position.shiftNodePosition()
                node.zIndex += 1
                return node
            }
            return node
        }

        guard hasEffectsToRun else {
            // Update state synchronously
            self._insertNewComponent(newComponent)
            return
        }

        // Display loading status for imported media effects
        self.libraryLoadingStatus = .loading

        Task {
            await effects.processEffects()

            await MainActor.run { [weak self] in
                self?._insertNewComponent(newComponent)

                // Hide loading status
                self?.libraryLoadingStatus = .loaded
            }
        }
    }

    @MainActor
    func _insertNewComponent(_ component: StitchComponent) {
        var document = self.createSchema()

        // Update top-level nodes to match current focused group
        let newNodes: [NodeEntity] = component.nodes
            .map { stitch in
                var stitch = stitch
                stitch.canvasEntityMap { node in
                    var node = node
                    
                    let isTopLevel = node.parentGroupNodeId == nil
                    guard isTopLevel else {
                        return node
                    }
                    
                    node.parentGroupNodeId = self.graphUI.groupNodeFocused?.asNodeId
                    return node
                }
                
                return stitch
            }

        // Add new nodes
        document.nodes += newNodes
        document.orderedSidebarLayers = component.orderedSidebarLayers + document.orderedSidebarLayers
        self.update(from: document)

        // Reset selected nodes
        self.resetSelectedCanvasItems()

        // Update selected nodes
        newNodes
            .forEach { nodeEntity in
                switch nodeEntity.nodeTypeEntity {
                case .layer(let layerNode):
                    layerNode.layer.layerGraphNode.inputDefinitions.forEach { inputType in
                        let portData = layerNode[keyPath: inputType.schemaPortKeyPath]
                        let isPacked = portData.mode == .packed
                        portData.allInputData.enumerated().forEach { portId, inputData in
                            let unpackedId = UnpackedPortType(rawValue: portId)
                            
                            // If unpacked, make sure we get valid ID
                            assertInDebug(isPacked || (!isPacked && unpackedId.isDefined))
                            
                            let portType: LayerInputKeyPathType = isPacked ? .packed : .unpacked(unpackedId ?? .port0)
                            let layerId = LayerInputType(layerInput: inputType,
                                                         portType: portType)
                            if let canvas = inputData.canvasItem,
                               let canvasItem = self.getCanvasItem(.layerInput(.init(node: nodeEntity.id,
                                                                                     keyPath: layerId))) {
                                canvasItem.select()
                            }
                        }
                        
                    }
                    
                case .patch, .group:
                    let stitch = self.getNodeViewModel(nodeEntity.id)
                    if let canvasItem = stitch?.patchCanvasItem {
                        canvasItem.select()
                    }
                }
        }
        
        // update sidebar UI data
        self.updateSidebarListStateAfterStateChange()
        
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: self.sidebarListState,
            expanded: self.getSidebarExpandedItems(),
            graphState: self)
        
        // Also wipe sidebar selection state
        self.sidebarSelectionState = .init()
        
        self.calculateFullGraph() // not needed?
        self.updateOrderedPreviewLayers()
    }
    
    // Duplicate ONLY the selected comment boxes
    func selectedCommentBoxesDuplicated() {
        // TODO: come back here
        return
        //        .stateOnly(
        //            duplicateSelectedCommentBoxes(
        //                graphSchema: graphSchema,
        //                graphState: graphState,
        //                // If we're duplicating ONLY comment boxes, we should deselect any selected nodes
        //                duplicatingCommentsOnly: true))
    }
}
