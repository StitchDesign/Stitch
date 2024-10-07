//
//  NodeDuplicationActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/3/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct DuplicateShortcutKeyPressed: StitchDocumentEvent {
    
    // Duplicates BOTH nodes AND comments
    @MainActor
    func handle(state: StitchDocumentViewModel) {
        Task(priority: .high) { [weak state] in
            await state?.duplicateShortcutKeyPressed()
        }
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func duplicateShortcutKeyPressed() async {
        let state = self
        
        guard !state.llmRecording.isRecording else {
            log("Duplication disabled during LLM Recording")
            return
        }
        
        // TODO: `graph` vs `visibleGraph` ?
        let activelySelectedLayers = state.visibleGraph.sidebarSelectionState.inspectorFocusedLayers.activelySelected
        
        if !activelySelectedLayers.isEmpty {
            state.visibleGraph.sidebarSelectedItemsDuplicatedViaEditMode()
        } else {
            let copiedComponentResult = state.visibleGraph.createCopiedComponent(
                groupNodeFocused: state.graphUI.groupNodeFocused,
                selectedNodeIds: state.visibleGraph.selectedNodeIds.compactMap(\.nodeCase).toSet)
            
            await state.visibleGraph.insertNewComponent(copiedComponentResult,
                                                        encoder: state.visibleGraph.documentEncoderDelegate)
        }
        
        Task { [weak self] in
            self?.visibleGraph.encodeProjectInBackground()
        }
    }
}

extension GraphState {
    /// Inserts new component in state and processes media effects
    @MainActor
    func insertNewComponent<T>(_ copiedComponentResult: StitchComponentCopiedResult<T>,
                               encoder: (any DocumentEncodable)?) async where T: StitchComponentable {
        await self.insertNewComponent(component: copiedComponentResult.component,
                                      encoder: encoder,
                                      copiedFiles: copiedComponentResult.copiedSubdirectoryFiles)
    }

    @MainActor
    func insertNewComponent<T>(component: T,
                               encoder: (any DocumentEncodable)?,
                               copiedFiles: StitchDocumentDirectory) async where T: StitchComponentable {
        let newComponent = self.updateCopiedNodes(component: component)
        
        guard let encoder = encoder,
              let document = self.documentDelegate,
              let encoderDelegate = self.documentEncoderDelegate else {
            return
        }
        
        // Copy files before inserting component
        await encoder.importComponentFiles(copiedFiles,
                                           destUrl: encoderDelegate.rootUrl)
        
        // Update top-level nodes to match current focused group
        let newNodes: [NodeEntity] = self.createNewNodes(from: newComponent)
        let graph = self.duplicateCopiedNodes(newComponent: newComponent,
                                              newNodes: newNodes)
        
        // Create master component if any imported
        if let decodedFiles = GraphDecodedFiles(importedFilesDir: copiedFiles) {
            let components = decodedFiles.components.createComponentsDict(parentGraph: self)
            self.components = components.reduce(into: self.components) { result, newComponentEntry in
                result.updateValue(newComponentEntry.value, forKey: newComponentEntry.key)
            }
        } else {
            fatalErrorIfDebug()
        }
        
        
        self.initializeDelegate(document: document,
                                documentEncoderDelegate: encoderDelegate)
        await self.update(from: graph)
        
        self.updateGraphAfterPaste(newNodes: newNodes)
    }
    
    func updateCopiedNodes<T>(component: T) -> T where T: StitchComponentable {
        // Change all IDs
        var newComponent = component
        newComponent.graph = newComponent.graph.changeIds()
        
        // Update nodes in the follow ways:
        // 1. Stagger position
        // 2. Increment z-index
        newComponent.graph.nodes = newComponent.nodes.map { node in
            var node = node
            
            // Update positional data            
            node.canvasEntityMap { node in
                var node = node
                node.position.shiftNodePosition()
                node.zIndex += 1
                return node
            }
            
            return node
        }
        
        return newComponent
    }
    
    func createNewNodes<T>(from newComponent: T) -> [NodeEntity] where T: StitchComponentable {
        newComponent.nodes
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
    }
    
    @MainActor
    func duplicateCopiedNodes<T>(newComponent: T,
                                 newNodes: [NodeEntity]) -> GraphEntity where T: StitchComponentable {
        guard let document = self.documentDelegate,
              let encoderDelegate = self.documentEncoderDelegate else {
            fatalErrorIfDebug()
            return .createEmpty()
        }
        
        var graph = self.createSchema()
        
        // Add new nodes
        graph.nodes += newNodes
        graph.orderedSidebarLayers = newComponent.graph.orderedSidebarLayers + graph.orderedSidebarLayers
        
        return graph
    }
        
    @MainActor
    func updateGraphAfterPaste(newNodes: [NodeEntity]) {
        // Reset selected nodes
        self.resetSelectedCanvasItems()

        // Reset edit mode selections + inspector focus and actively-selected
        self.sidebarSelectionState.resetEditModeSelections()
        self.sidebarSelectionState.inspectorFocusedLayers.focused = .init()
        self.sidebarSelectionState.inspectorFocusedLayers.activelySelected = .init()
        
        // NOTE: we can either duplicate layers OR patch nodes; but NEVER both
        // Update selected nodes
        newNodes
            .forEach { nodeEntity in
                switch nodeEntity.nodeTypeEntity {
                case .layer(let layerNode):
                    
                    // Actively-select the new layer node
                    let id = nodeEntity.id.asLayerNodeId
                    self.sidebarSelectionState.inspectorFocusedLayers.focused.insert(id)
                    self.sidebarSelectionState.inspectorFocusedLayers.activelySelected.insert(id)
                                        
                    self.sidebarItemSelectedViaEditMode(
                        id,
                        // Can treat as always true?
                        isSidebarItemTapped: true)
                    
                    self.updateInspectorFocusedLayers()
                    
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
                    
                case .patch, .group, .component:
                    let stitch = self.getNodeViewModel(nodeEntity.id)
                    if let canvasItem = stitch?.patchCanvasItem {
                        canvasItem.select()
                    }
                }
        }
        
        // Also wipe sidebar selection state
        self.sidebarSelectionState = .init()
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
